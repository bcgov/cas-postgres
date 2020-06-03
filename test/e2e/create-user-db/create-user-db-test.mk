SHELL := /usr/bin/env bash
include $(abspath $(realpath $(lastword $(MAKEFILE_LIST)))/../../../../.pipeline/oc.mk)
comma := ,
.PHONY: create-user-db
create-user-db:
	$(call oc_exec_all_pods,cas-postgres,create-user-db -u $(USER) -d $(DB) -p $(PASS) --owner --enable-citus)
	$(call oc_exec_all_pods,cas-postgres-workers,create-citus-in-db $(DB))

.PHONY: create-user-db-privileges
create-user-db-privileges:
	$(call oc_exec_all_pods,cas-postgres,psql -d $(DB) -c "create schema schema_foo;create schema schema_bar;create schema schema_baz;")
	## The schemas must have tables for the privileges to appear in the role_table_grants table
	$(call oc_exec_all_pods,cas-postgres,psql -d $(DB) -c "create table schema_foo.foo (blah int);")
	$(call oc_exec_all_pods,cas-postgres,psql -d $(DB) -c "create table schema_bar.foo (blah int);")
	$(call oc_exec_all_pods,cas-postgres,psql -d $(DB) -c "create table schema_baz.foo (blah int);")

	$(call oc_exec_all_pods,cas-postgres,create-user-db -u $(USER) -d $(DB) -p $(PASS) --enable-citus --schemas schema_foo$(comma)schema_bar --privileges select$(comma)insert)

.PHONY: get-user-schema-privileges
get-user-tables-privileges:
	$(call oc_exec_all_pods,cas-postgres,psql -tq -d $(DB) -c "select distinct privilege_type from information_schema.role_table_grants where table_schema=\'$(SCHEMA)\' and grantee=\'$(USER)\' order by privilege_type;")

.PHONY: drop-user-db
drop-user-db:
	$(call oc_exec_all_pods,cas-postgres,dropdb --if-exists $(DB))
	$(call oc_exec_all_pods,cas-postgres,dropuser --if-exists $(USER))
	$(call oc_exec_all_pods,cas-postgres-workers,dropdb --if-exists $(DB))
	$(call oc_exec_all_pods,cas-postgres-workers,dropuser --if-exists $(USER))

.PHONY: test-user-password
test-user-password:
	$(call oc_exec_all_pods,cas-postgres,PGPASSWORD="$(PASS)" psql -tq -U "$(USER)" -d "$(DB)" -c "select \'ok\';")
