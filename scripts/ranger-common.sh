#!/bin/sh
if [ ! -z $ldap_ca_cert ]; then
    #update catrust
    echo ${ldap_ca_cert}|base64 -d > /etc/pki/ca-trust/source/anchors/ldapca.crt
    update-ca-trust
    update-ca-trust enable
fi
