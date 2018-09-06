#!/bin/sh
if [ ! -z $VAULT_ADDR ]; then
    export VAULT_SKIP_VERIFY=true
    export VAULT_TOKEN=`vault login -method=aws -token-only`
    #update catrust
    vault read -field=cacert ${vault_path}/ldap_user > /etc/pki/ca-trust/source/anchors/ldapca.crt
    update-ca-trust
    update-ca-trust enable
fi
