SHELL := /usr/bin/env bash
include $(abspath $(realpath $(lastword $(MAKEFILE_LIST)))/../../../../.pipeline/oc.mk)

.PHONY: create-user-db
create-user-db:
	$(call oc_exec_all_pods,cas-postgres-master,create-user-db -u $(USER) -d $(DB) -p $(PASS) --owner --enable-citus)
	$(call oc_exec_all_pods,cas-postgres-workers,create-citus-in-db $(DB))

.PHONY: create-user-db-privileges
create-user-db-privileges:
	$(call oc_exec_all_pods,cas-postgres-master,psql -c "create schema schema_foo;create schema schema_bar;create schema schema_baz;"')
	$(call oc_exec_all_pods,cas-postgres-master,create-user-db -u $(USER) -d $(DB) -p $(PASS) --enable-citus --schemas schema_foo,schema_bar --privileges select,insert)

.PHONY: get-user-schema-privileges
get-user-tables-privileges:
	$(call oc_exec_all_pods,cas-postgres-master,psql -d $(DB) -c "select distinct privilege_type from information_schema.role_table_grants where table_schema=\'$(SCHEMA)\' and grantee=\'$(USER)\' order by privilege_type;")

.PHONY: drop-user-db
drop-user-db:
	$(call oc_exec_all_pods,cas-postgres-master,dropdb --if-exists $(DB))
	$(call oc_exec_all_pods,cas-postgres-master,dropuser --if-exists $(USER))
	$(call oc_exec_all_pods,cas-postgres-workers,dropdb --if-exists $(DB))
	$(call oc_exec_all_pods,cas-postgres-workers,dropuser --if-exists $(USER))

.PHONY: test-user-password
test-user-password:
	$(call oc_exec_all_pods,cas-postgres-master,PGPASSWORD="$(PASS)" psql -tq -U "$(USER)" -d "$(DB)" -c "select \'ok\';")
