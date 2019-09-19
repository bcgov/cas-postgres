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
