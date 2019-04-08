# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2019-02-26

### Added
- Migrate from Vault to AWS Secrets Manager - see [#6](https://github.com/ExpediaGroup/apiary-authorization/issues/6).
- Update Ranger version to 1.2.0

## [1.0.0] - 2018-10-31
### Added
- Initial commit: See [#1](https://github.com/ExpediaGroup/apiary-ranger-docker/issues/1).
- Dockerfile to build common docker image for running ranger-admin & ranger-userssync.
- ranger-admin & ranger-usersync startup scripts.
- Fixes to enable ranger auditing using DB provider.
