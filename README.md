# cas-postgres

[![CircleCI](https://circleci.com/gh/bcgov/cas-postgres.svg?style=svg)](https://circleci.com/gh/bcgov/cas-postgres)

Postgres container image intended for OpenShift and general usage

### Steps for a complete fresh install (will lose all data)
  - helm delete the cas-ciip-portal release `ex: helm delete --namespace wksv3k-dev cas-ciip-portal`
  - delete the cas-ciip-portal patroni pvcs's `(can be done from the openshift ui under storage)`
  - delete the cas-ciip-portal patroni configmaps `(can be done from the openshift ui under Resources -> Configmaps)`
  - the trigger-dag job may possibly need to be deleted as well. Look for the job in the openshift ui under `Resources -> Other Resources`, if you find the job, delete it.
  - clear the namespace's gcs ciip-backup box in google storage `ex: wksv3k-dev-ciip-backups`

  Once these steps are complete, triggering a deploy from ship-it should be able to automatically re-deploy everything into the namespace.

# Fork Credit

This project is derived from [spilo]


[red hat's postgresql container image repository]: https://github.com/sclorg/postgresql-container
[pathfinder]: https://developer.gov.bc.ca/What-is-Pathfinder
[shipit]: https://github.com/Shopify/shipit-engine
[pipeline submodule]: https://github.com/bcgov/cas-pipeline/
