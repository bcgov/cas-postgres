# cas-postgres

[![CircleCI](https://circleci.com/gh/bcgov/cas-postgres.svg?style=svg)](https://circleci.com/gh/bcgov/cas-postgres)

Postgres container image intended for OpenShift and general usage

# Fork Credit

This project is derived from [Red Hat's PostgreSQL container image repository] and meant to be used as a drop-in replacement for the official images.

# Working with the Makefile

The usual approach is to `make configure`, `make build`, and `make install`. Since containers are usually installed in either `dev`, `test`, or `prod` environments, special `make install_dev` etc targets are provided to simplify the process.

## `make configure`

This step applies the yaml configurations defined under `openshift/build` in the `OC_TOOLS_PROJECT` namespace (`wksv3k-tools` in for the CAS team in the [pathfinder] cluster)

## `make build`

This step starts the builds configured in the prevous steps, and tags the produced imagestreams with the current git commit sha1 and the branch name.

## `make install`

This step deploys the postgres Citus cluster in the `OC_PROJECT` namespace.
Using the `install_dev`, `install_test` or `install_prod` make target will execute `install` with the `OC_DEV_PROJECT`, `OC_TEST_PROJECT` or `OC_PROD_PROJECT`, respectively.
As a convenience for deployment by [Shipit], the `OC_PROJECT` variable has default value set to be equal to the `ENVIRONMENT` variable defined by Shipit (see the [pipeline submodule] for more details).

The `install` and `install_*` targets also supports the following variables (usage: `make install POSTGRESQL_WORKERS=4`):

| Name                  | Description                                                   | Default value                          |
| --------------------- | ------------------------------------------------------------- | -------------------------------------- |
| POSTGRESQL_WORKERS    | The number of citus workers                                   | 8 in prod, 4 in other namespaces       |
| MASTER_CPU_REQUEST    | The number of CPUs requested by the Citus coordinator node    | 1 in prod, 500m in other namespaces    |
| MASTER_CPU_LIMIT      | The maximum number of CPUs used by the Citus coordinator node | 2                                      |
| MASTER_MEMORY_REQUEST | The RAM requested by the Citus coordinator node               | 4096Mi                                 |
| MASTER_MEMORY_LIMIT   | The maximum RAM used by the Citus coordinator node            | 8192Mi                                 |
| WORKER_CPU_REQUEST    | The number of CPUs requested by each Citus worker node        | 500m in prod, 250m in other namespaces |
| WORKER_CPU_LIMIT      | The maximum number of CPUs used by each Citus worker node     | 1                                      |
| WORKER_MEMORY_REQUEST | The RAM requested by each Citus worker node                   | 2048Mi                                 |
| WORKER_MEMORY_LIMIT   | The maximum RAM used by each Citus worker node                | 4096Mi                                 |

## Understanding Targets

For more information on the available targets, use the special `help` target:

```bash
make help
```

## Dry Run

If you want to see what a target is going to do before your run it, use the `--dry-run` option for the target:

```bash
make lint --dry-run
```

[red hat's postgresql container image repository]: https://github.com/sclorg/postgresql-container
[pathfinder]: https://developer.gov.bc.ca/What-is-Pathfinder
[shipit]: https://github.com/Shopify/shipit-engine
[pipeline submodule]: https://github.com/bcgov/cas-pipeline/
