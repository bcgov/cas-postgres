[Master and all workers need the same `.pgpass` file.](http://docs.citusdata.com/en/v8.3/admin_guide/cluster_management.html#increasing-worker-security)
```
cas-postgres-master:5432:postgres:postgres:tzq2HYVALeuco4Pz
cas-postgres-worker-0.cas-postgres-workers:5432:postgres:postgres:tzq2HYVALeuco4Pz
cas-postgres-worker-1.cas-postgres-workers:5432:postgres:postgres:tzq2HYVALeuco4Pz
cas-postgres-worker-2.cas-postgres-workers:5432:postgres:postgres:tzq2HYVALeuco4Pz
cas-postgres-worker-3.cas-postgres-workers:5432:postgres:postgres:tzq2HYVALeuco4Pz
cas-postgres-worker-4.cas-postgres-workers:5432:postgres:postgres:tzq2HYVALeuco4Pz
cas-postgres-worker-5.cas-postgres-workers:5432:postgres:postgres:tzq2HYVALeuco4Pz
cas-postgres-worker-6.cas-postgres-workers:5432:postgres:postgres:tzq2HYVALeuco4Pz
cas-postgres-worker-7.cas-postgres-workers:5432:postgres:postgres:tzq2HYVALeuco4Pz
```
https://www.postgresql.org/docs/current/libpq-pgpass.html

How can we check worker health? `select run_command_on_workers('select true');`

How do we handle making workers healthy again?
https://docs.citusdata.com/en/v8.3/admin_guide/cluster_management.html#worker-node-failures

# cas-postgres
Postgres container image intended for OpenShift and general usage

# Fork Credit
This project is derived from [Red Hat's PostgreSQL container image repository](https://github.com/sclorg/postgresql-container) and meant to be used as a drop-in replacement for the official images.

# Working with the Makefile

The usual approach is to `make configure`, `make build`, and `make install`. Since containers are usually installed in either `-dev`, `-test`, or `-prod` environments, special `make install-dev` etc targets are provided to simplify the process.

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
