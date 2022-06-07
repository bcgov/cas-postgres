# cas-postgres

[![CircleCI](https://circleci.com/gh/bcgov/cas-postgres.svg?style=svg)](https://circleci.com/gh/bcgov/cas-postgres)
![Lifecycle:Stable](https://img.shields.io/badge/Lifecycle-Stable-97ca00)

This repository contains the [Spilo](https://github.com/zalando/spilo/) + [pgtap](https://pgtap.org/) docker container and helm chart used by the various applications deployed by the CAS team.

## Docker container

The docker container adds the `pgtap` extension (unit testing for PostgreSQL) and a couple of utility scripts to the official Spilo container developed by Zalando.

BATS tests for the aforementioned scripts can be run using the corresponding `make` commands (run `make help` for more information).

## Helm Charts

The [`helm/patroni`](helm/patroni) folder contains a fork of the patroni helm chart that was in the (now deprecated) helm charts incubator, and can be reused by other teams.
The [`helm/cas-patroni](helm/cas-patroni) folder contains helm values used by the CAS team, as well as a job definition for the [`cas-shelf`](https://github.com/bcgov/cas-shelf/) image, which provisions object storage buckets when [WAL-G](https://github.com/wal-g/wal-g) backups are enabled.

### Installation

Installation of the cas-postgres helm chart is simply done via the `helm install` command. See [`helm/cas-postgres/values.yaml`](helm/cas-postgres/values.yaml) for more information on the values that should be provided

### Steps for a complete fresh install (will lose all data)

- helm delete the cas-ciip-portal release `ex: helm delete --namespace wksv3k-dev cas-ciip-portal`
- delete the cas-ciip-portal patroni pvcs's `(can be done from the openshift ui under storage)`
- delete the cas-ciip-portal patroni configmaps `(can be done from the openshift ui under Resources -> Configmaps)`
- the trigger-dag job may possibly need to be deleted as well. Look for the job in the openshift ui under `Resources -> Other Resources`, if you find the job, delete it.
- clear the namespace's gcs ciip-backup box in google storage `ex: wksv3k-dev-ciip-backups`
