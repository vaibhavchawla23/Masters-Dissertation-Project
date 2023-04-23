#!/bin/bash
kubectl config set-cluster killswitch-cluster  --server=$APISERVER --insecure-skip-tls-verify
kubectl config set-credentials killswitch@killswitch-cluster --token=`cat /var/run/secrets/kubernetes.io/serviceaccount/token`
kubectl config set-context killswitch@killswitch-cluster --cluster=killswitch-cluster --user killswitch@killswitch-cluster --namespace=default
kubectl config use-context killswitch@killswitch-cluster
ns='default'
item=$(kubectl get secret -n $ns | grep kubernetes.io/tls | awk '{ print $1}')
rm -rf *.crt  *.crl *.key
kubectl get secret -n $ns "$item" -o json | jq -r '.data."tls.crt"' | base64 -d > /mnt/k8s-$ns-"$item".crt
kubectl get secret -n $ns "$item" -o json | jq -r '.data."tls.key"' | base64 -d > /mnt/k8s-$ns-"$item".key
presentcertserial=$(openssl x509 -in /mnt/k8s-$ns-"$item".crt -text -noout | grep -A1 'Serial Number' | tail -n1| sed 's/\(.*\)/\U\1/' | sed 's/://g' | tr -d ' ')
if [ -z $presentcertserial ];then
   presentcertserial="No Certificates Present"
   echo $presentcertserial
fi

FILESIZE=$(stat -c%s "/mnt/k8s-$ns-$item.crt")

if ! `curl --silent --show-error --fail --connect-timeout 3 --retry 2 http://192.168.56.108:8200/v1/pki_int/crl --output pki_int.crl`;then
        echo "Cannot connect to Certificate Revocation List; Deleting local certificates!";
        kubectl delete secrets -n default --all
elif  [ -f "/mnt/k8s-$ns-$item.crt"  ] && [  "$FILESIZE" -lt 4 ];then
        echo "Cannot verify local certificates; ERROR EXIT";
elif [ true ] ; then
       /mnt/cert-trustchain-validator.sh -v
fi

if [ $(openssl crl -inform DER -text -noout -in pki_int.crl | grep "Serial Number" | awk '{print $3}' | grep "${presentcertserial}") ]; then
        echo "Local CERTIFICATE is listed in the revocation list; Deleting local token and certificates to initiate **Self-Quarantine**"
        kubectl delete secret -n $ns  my-vault-token
   kubectl delete secret -n $ns "$item"
fi
