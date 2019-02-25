#!/bin/bash
set -e
source /ranger-common.sh

cd ${RANGER_ADMIN_HOME}
[[ -z $rangerAdmin_password ]] && export rangerAdmin_password=$(aws secretsmanager get-secret-value --secret-id ${ranger_admin_arn}|jq .SecretString -r|jq .rangerAdmin_password -r)
[[ -z $rangerTagsync_password ]] && export rangerTagsync_password=$(aws secretsmanager get-secret-value --secret-id ${ranger_admin_arn}|jq .SecretString -r|jq .rangerTagsync_password -r)
[[ -z $rangerUsersync_password ]] && export rangerUsersync_password=$(aws secretsmanager get-secret-value --secret-id ${ranger_admin_arn}|jq .SecretString -r|jq .rangerUsersync_password -r)
[[ -z $keyadmin_password ]] && export keyadmin_password=$(aws secretsmanager get-secret-value --secret-id ${ranger_admin_arn}|jq .SecretString -r|jq .keyadmin_password -r)

[[ -z $db_user ]] && export db_user=$(aws secretsmanager get-secret-value --secret-id ${db_master_user_arn}|jq .SecretString -r|jq .username -r)
[[ -z $db_password ]] && export db_password=$(aws secretsmanager get-secret-value --secret-id ${db_master_user_arn}|jq .SecretString -r|jq .password -r)
[[ -z $audit_db_user ]] && export audit_db_user=$(aws secretsmanager get-secret-value --secret-id ${db_audit_user_arn}|jq .SecretString -r|jq .username -r)
[[ -z $audit_db_password ]] && export audit_db_password=$(aws secretsmanager get-secret-value --secret-id ${db_audit_user_arn}|jq .SecretString -r|jq .password -r)

if [ -z $audit_solr_urls ]; then
    audit_store="db"
else
    audit_store="solr"
fi

#disable DBA mode
sed -i 's/#setup_mode=SeparateDBA/setup_mode=SeparateDBA/' install.properties

#only enable AD authentication when domain name is configured
#if [ ! -z $xa_ldap_ad_domain ]; then
#    #configure to use AD authentication
#    sed -i "s/^authentication_method=.*$/authentication_method=ACTIVE_DIRECTORY/" install.properties
#    #disable AD ldap referral
#    sed -i "s/^xa_ldap_ad_referral=.*$/xa_ldap_ad_referral=follow/" install.properties
#    sed -i "s/^xa_ldap_ad_userSearchFilter=.*$/xa_ldap_ad_userSearchFilter=(sAMAccountName={0})/" install.properties
#    [[ -z $xa_ldap_ad_bind_dn ]] && export xa_ldap_ad_bind_dn=$(aws secretsmanager get-secret-value --secret-id ${ldap_user_arn}|jq .SecretString -r|jq .username -r)
#    [[ -z $xa_ldap_ad_bind_password ]] && export xa_ldap_ad_bind_password=$(aws secretsmanager get-secret-value --secret-id ${ldap_user_arn}|jq .SecretString -r|jq .password -r|sed 's/&/\\&/')
#fi

#update install.properties using docker env variables
for ini in audit_store audit_solr_urls db_host db_name db_user db_password rangerAdmin_password rangerTagsync_password rangerUsersync_password keyadmin_password xa_ldap_ad_domain xa_ldap_ad_url xa_ldap_ad_base_dn xa_ldap_ad_bind_dn xa_ldap_ad_bind_password
do
    [[ -n ${!ini} ]] && sed -i "s/^${ini}=.*$/${ini}=${!ini}/" install.properties
done

cat >> install.properties << EOF

audit_db_host=${db_host}
audit_db_name=${db_name}
EOF


./setup.sh

#fix ranger db entries
python update_property.py ranger.jpa.jdbc.url "jdbc:mysql://${db_host}/${db_name}" ./ews/webapp/WEB-INF/classes/conf/ranger-admin-default-site.xml
python update_property.py ranger.jpa.jdbc.driver "com.mysql.jdbc.Driver" ./ews/webapp/WEB-INF/classes/conf/ranger-admin-default-site.xml
python update_property.py ranger.jpa.audit.jdbc.url "jdbc:mysql://${db_host}/${db_name}" ./ews/webapp/WEB-INF/classes/conf/ranger-admin-default-site.xml
python update_property.py ranger.jpa.audit.jdbc.driver "com.mysql.jdbc.Driver" ./ews/webapp/WEB-INF/classes/conf/ranger-admin-default-site.xml
#grant audit user access
echo "GRANT INSERT ON ranger.xa_access_audit TO '$audit_db_user'@'%' IDENTIFIED BY '$audit_db_password';"|mysql -h$db_host -u$db_user -p$db_password

#todo: configre admin AD group
[[ -z $HEAPSIZE ]] && export HEAPSIZE="1024"
JAVA_OPTS=" ${JAVA_OPTS} -Xmx${HEAPSIZE}m -Xms${HEAPSIZE}m "

XAPOLICYMGR_EWS_DIR="${RANGER_ADMIN_HOME}/ews"
RANGER_ADMIN_LOG_DIR="${XAPOLICYMGR_EWS_DIR}/logs"
RANGER_JAAS_LIB_DIR="${XAPOLICYMGR_EWS_DIR}/ranger_jaas"
RANGER_JAAS_CONF_DIR="${XAPOLICYMGR_EWS_DIR}/webapp/WEB-INF/classes/conf/ranger_jaas"

[[ -z $LOGLEVEL ]] && LOGLEVEL="info"
cat > ews/webapp/WEB-INF/log4j.properties << EOF
log4j.rootLogger = $LOGLEVEL,console
log4j.appender.console=org.apache.log4j.ConsoleAppender
log4j.appender.console.Target=System.out
log4j.appender.console.layout=org.apache.log4j.PatternLayout
log4j.appender.console.layout.ConversionPattern=%d{dd MMM yyyy HH:mm:ss} %5p %c{1} [%t] - %m%n

log4j.category.org.hibernate.SQL=warn,console
log4j.additivity.org.hibernate.SQL=false
EOF


java -Dproc_rangeradmin -Dlog4j.configuration=file:${RANGER_ADMIN_HOME}/ews/webapp/WEB-INF/log4j.properties ${JAVA_OPTS} \
-Duser=${USER} ${DB_SSL_PARAM} -Dservername=rangeradmin -Dlogdir=${RANGER_ADMIN_LOG_DIR} -Dcatalina.base=${XAPOLICYMGR_EWS_DIR} \
-cp "${XAPOLICYMGR_EWS_DIR}/webapp/WEB-INF/classes/conf:${XAPOLICYMGR_EWS_DIR}/lib/*:${RANGER_JAAS_LIB_DIR}/*:${RANGER_JAAS_CONF_DIR}:${JAVA_HOME}/lib/*:/etc/hadoop/conf/*:$CLASSPATH" \
org.apache.ranger.server.tomcat.EmbeddedServer
