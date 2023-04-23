#!/bin/bash

echo -e "*************** \nRequesting Token for edgesite alpha. \n ***************"
encrypted_token=`curl --request POST  --data '{"password": "site1.edgesite.com"}'  http://127.0.0.1:8200/v1/auth/userpass/login/site1.edgesite.com | jq -r .auth.client_token  | base64 | tr-d "\n"`

echo -e "*************** \n Token generation Success! \n ***************"


ssh 192.168.56.109 -n "microk8s kubectl delete secret vault-cert-secret-tls; microk8s kubectl delete secret/my-vault-token; microk8s kubectl delete issuer.cert-manager.io/vault-issuer; microk8s kubectl delete certificate.cert-manager.io/cert-from-vault"


echo -e "*************** \n Pushing New Token to the Edge Site ! \n ***************"

ssh 192.168.56.109 -n "microk8s kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: my-vault-token
  namespace: default
data:
  token: \"$encrypted_token\"
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: vault-issuer
  namespace: default
spec:
  vault:
    server: http://192.168.56.108:8200
    path: pki_int/sign/edgesite-dot-com
    auth:
      tokenSecretRef:
          name: my-vault-token
          key: token
---
 apiVersion: cert-manager.io/v1
 kind: Certificate
 metadata:
   name: cert-from-vault
   namespace: default
 spec:
   commonName: alpha.edgesite.com
   secretName: vault-cert-secret-tls
   issuerRef:
     name: vault-issuer
   dnsNames:
   - alpha.edgesite.com
EOF"
echo -e "*************** \n Token Push Success \n ***************"
