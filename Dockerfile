# Copyright (C) 2018 Expedia Inc.
# Licensed under the Apache License, Version 2.0 (the "License");

from amazonlinux:latest

ENV VAULT_VERSION 0.10.3
ENV RANGER_VERSION 1.1.0
ENV MAVEN_VERSION 3.5.4

RUN yum -y install wget tar gzip which git gcc hostname bc procps-ng unzip patch
RUN yum -y install java-1.8.0-openjdk java-1.8.0-openjdk-devel mysql-connector-java mysql

RUN wget -qN https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip && unzip -q -o vault_${VAULT_VERSION}_linux_amd64.zip -d /usr/local/bin/ && rm -f vault_${VAULT_VERSION}_linux_amd64.zip
RUN wget -q -O - http://www-us.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz|tar -C /opt -xzf - && ln -sf /opt/apache-maven-${MAVEN_VERSION}/bin/mvn /bin/mvn

COPY files/XAccessAuditService.patch /tmp/XAccessAuditService.patch
RUN wget -q -O - https://dist.apache.org/repos/dist/release/ranger/${RANGER_VERSION}/apache-ranger-${RANGER_VERSION}.tar.gz| tar -xzf - && \
cd apache-ranger-${RANGER_VERSION} && patch ./security-admin/src/main/java/org/apache/ranger/service/XAccessAuditService.java /tmp/XAccessAuditService.patch && \
mvn -DskipTests=true clean compile package install assembly:assembly && mkdir -p /usr/lib/ranger && \
tar -C /usr/lib/ranger -xzf target/ranger-${RANGER_VERSION}-admin.tar.gz && \
tar -C /usr/lib/ranger -xzf target/ranger-${RANGER_VERSION}-usersync.tar.gz && \
rm -rf /root/.m2 && rm -rf /apache-ranger-1.1.0 && \
mv /usr/lib/ranger/ranger-${RANGER_VERSION}-admin /usr/lib/ranger/ranger-admin && \
mv /usr/lib/ranger/ranger-${RANGER_VERSION}-usersync /usr/lib/ranger/ranger-usersync && \
mv /usr/lib/ranger/ranger-admin/db/mysql/patches/audit/* /usr/lib/ranger/ranger-admin/db/mysql/patches/

ENV JAVA_HOME /usr/lib/jvm/java
ENV RANGER_ADMIN_HOME /usr/lib/ranger/ranger-admin
ENV RANGER_USERSYNC_HOME /usr/lib/ranger/ranger-usersync

COPY scripts/ranger-common.sh scripts/start-ranger-admin.sh scripts/start-ranger-usersync.sh /

EXPOSE 6080
