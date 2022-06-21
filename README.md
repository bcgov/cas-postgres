# cas-postgres

[![CircleCI](https://circleci.com/gh/bcgov/cas-postgres.svg?style=svg)](https://circleci.com/gh/bcgov/cas-postgres)

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


### Point in Time Recovery

In the event a database needs to be recovered from a backup to a specific point in time, these are the steps to follow. Spilo is shipped with a [clone_with_wale](https://github.com/zalando/spilo/blob/30977cc4bb041dcf2d461d39e109eef4d377272f/postgres-appliance/scripts/configure_spilo.py#L227) method that we can leverage to handle this for us with the addition of a few environment variables.

These steps assume you are using Google Cloud to store backups. If you are using something else (like S3), the process should be similar for other providers and the necessary environment variables are described in the `configure_spilo` script [here](https://github.com/zalando/spilo/blob/30977cc4bb041dcf2d461d39e109eef4d377272f/postgres-appliance/scripts/configure_spilo.py#L753).

#### Steps

- Scale the patroni statefulset down to 0
- Delete the patroni configmaps (any configmaps prefixed by your patroni-cluster-name)
  - example: \<patroni-cluster\>-leader, \<patroni-cluster\>-config, \<patroni-cluster\>-failover
- Delete the patroni PVCs relating to your cluster
  - example: storage-volume-\<patroni-cluster\>-0, storage-volume-\<patroni\>-1
- Add the following environment variables to your patroni statefulset:
  - `CLONE_SCOPE`: \<patroni-cluster-name\>
  - `CLONE_METHOD`: CLONE_WITH_WALE
  - `CLONE_TARGET_TIME`: \<timestamp-with-timezone-to-recover-to\>
    - example: 2022-06-05 08:00:00-08:00
  - `CLONE_WALG_GS_PREFIX`: \<google-cloud-prefix\>
    - example: gs://[bucket-name]/[folder-name]
  - `CLONE_GOOGLE_APPLICATION_CREDENTIALS`: \<path-to-json-credentials\>
    - documentation: [Google Cloud Authentication](https://cloud.google.com/docs/authentication/production#passing_variable)
  - `PGVERSION`: \<major-postgres-version-to-restore-to\> example: 12
    - `PGVERSION` is optional, but if the major version of your postgres backup is older than the psql version you are using, then it will automatically upgrade Posgtgres during restore and begin an entirely new timeline starting at 00000001. This will cause issues with replication as the replica will become confused about what timeline to bootstrap from when starting up.

  Note: You likely already have `WALG_GS_PREFIX` and `GOOGLE_APPLICATION_CREDENTIALS` set as environment variables since they're needed to perform backups. The `clone_with_wale` method specifically looks for these variables with the `CLONE_` prefix, so just copying the contents of these existing environment variables into new variables prefixed with `CLONE_` is all that is needed here.

- Scale up the patroni statefulset

Patroni will then start up your database and restore to the point defined in `CLONE_TARGET_TIME`.
