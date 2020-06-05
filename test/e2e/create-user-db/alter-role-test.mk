SHELL := /usr/bin/env bash
include $(abspath $(realpath $(lastword $(MAKEFILE_LIST)))/../../../../.pipeline/oc.mk)

.PHONY: alter-role
alter-role:
	$(call oc_exec_all_pods,cas-postgres-patroni,alter-role $(USER) $(PRIVILEGE))

.PHONY: test-alter-role
test-alter-role:
	$(call oc_exec_all_pods,cas-postgres-patroni,PGPASSWORD="$(PASS)" psql -tq -U "$(USER)" -d "$(DB)" -c "select rolcreaterole from pg_roles where rolname=\'$(USER)\';")
