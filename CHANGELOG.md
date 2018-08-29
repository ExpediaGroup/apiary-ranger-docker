# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2018-08-28
### Added
- initial commit https://github.com/ExpediaInc/apiary-ranger-docker/issues/1
- Dockerfile to build common docker image for running ranger-admin & ranger-userssync
- ranger-admin & ranger-usersync startup scripts
    startup script also initializes database
    configures service during runtime
    read database paswords from vault
    logic to read custom cacerts from vault, used by ldap libraries to connect to activedirectory
    usersync configs to sync users & groups from LDAP.
    usersync configs to sync ranger admin groups from LDAP
    configures mysql access for rangerlogger(auditing) user.
    manages log4j.properties
    *ranger admin LDAP logins disabled in intial commit as it is not working reliably
- fixes to enable ranger auditing using DB provider.
