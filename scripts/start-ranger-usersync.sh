#!/bin/bash
set -e
source /ranger-common.sh

cd ${RANGER_USERSYNC_HOME}

[[ -z $rangerUsersync_password ]] && export rangerUsersync_password=$(aws secretsmanager get-secret-value --secret-id ${ranger_admin_arn}|jq .SecretString -r|jq .rangerUsersync_password -r)
[[ -z $SYNC_LDAP_BIND_DN ]] && export SYNC_LDAP_BIND_DN=$(aws secretsmanager get-secret-value --secret-id ${ldap_user_arn}|jq .SecretString -r|jq .username -r)
#TODO: need to find better way to escape special characters in password
[[ -z $SYNC_LDAP_BIND_PASSWORD ]] && export SYNC_LDAP_BIND_PASSWORD=$(aws secretsmanager get-secret-value --secret-id ${ldap_user_arn}|jq .SecretString -r|jq .password -r|sed 's/&/\\&/')


#edit settings
sed -i 's/SYNC_SOURCE.*/SYNC_SOURCE=ldap/' install.properties
sed -i 's/SYNC_LDAP_USERNAME_CASE_CONVERSION.*/SYNC_LDAP_USERNAME_CASE_CONVERSION=none/' install.properties
sed -i 's/SYNC_LDAP_GROUPNAME_CASE_CONVERSION.*/SYNC_LDAP_GROUPNAME_CASE_CONVERSION=none/' install.properties
sed -i 's/SYNC_GROUP_SEARCH_ENABLED.*/SYNC_GROUP_SEARCH_ENABLED=true/' install.properties
sed -i 's/SYNC_GROUP_USER_MAP_SYNC_ENABLED.*/SYNC_GROUP_USER_MAP_SYNC_ENABLED=true/' install.properties
sed -i 's/SYNC_GROUP_OBJECT_CLASS.*/SYNC_GROUP_OBJECT_CLASS=group/' install.properties

#update install.properties using docker env variables
for ini in rangerUsersync_password POLICY_MGR_URL SYNC_LDAP_URL SYNC_LDAP_BIND_DN SYNC_LDAP_BIND_PASSWORD SYNC_LDAP_SEARCH_BASE SYNC_LDAP_USER_SEARCH_BASE SYNC_GROUP_SEARCH_BASE SYNC_LDAP_USER_NAME_ATTRIBUTE SYNC_GROUP_NAME_ATTRIBUTE SYNC_PAGED_RESULTS_SIZE SYNC_INTERVAL GROUP_BASED_ROLE_ASSIGNMENT_RULES
do
    [[ -n ${!ini} ]] && sed -i "s/^${ini}.*$/${ini}=${!ini}/" install.properties
done

[[ -z $LOGLEVEL ]] && LOGLEVEL="info"
[[ $LOGLEVEL == "debug" ]] && cat install.properties

./setup.sh
[[ $LOGLEVEL == "debug" ]] && cat conf/ranger-ugsync-site.xml

sed -i "s/log4j.rootLogger.*/log4j.rootLogger = ${LOGLEVEL},console/" conf/log4j.properties

#start service
export USERSYNC_CONF_DIR="${RANGER_USERSYNC_HOME}/conf"
export RANGER_USERSYNC_HADOOP_CONF_DIR=/etc/hadoop/conf
export logdir="${RANGER_USERSYNC_HOME}/logs"

java -Dproc_rangerusersync -Dlog4j.configuration=file:${USERSYNC_CONF_DIR}/log4j.properties ${JAVA_OPTS} -Duser=${USER} -Dhostname=${HOSTNAME} -Dlogdir="${logdir}" -cp "${RANGER_USERSYNC_HOME}/dist/*:${RANGER_USERSYNC_HOME}/lib/*:${RANGER_USERSYNC_HOME}/conf:${RANGER_USERSYNC_HADOOP_CONF_DIR}/*" org.apache.ranger.authentication.UnixAuthenticationService -enableUnixAuth
