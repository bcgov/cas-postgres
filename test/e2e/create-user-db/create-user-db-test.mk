SHELL := /usr/bin/env bash
include $(abspath $(realpath $(lastword $(MAKEFILE_LIST)))/../../../../.pipeline/oc.mk)
comma := ,
.PHONY: create-user-db
create-user-db:
	$(call oc_exec_all_pods,cas-postgres-patroni,create-user-db -u $(USER) -d $(DB) -p $(PASS) --owner)

.PHONY: create-user-db-privileges
create-user-db-privileges:
	$(call oc_exec_all_pods,cas-postgres-patroni,psql -d $(DB) -c "create schema schema_foo;create schema schema_bar;create schema schema_baz;")
	## The schemas must have tables for the privileges to appear in the role_table_grants table
	$(call oc_exec_all_pods,cas-postgres-patroni,psql -d $(DB) -c "create table schema_foo.foo (blah int);")
	$(call oc_exec_all_pods,cas-postgres-patroni,psql -d $(DB) -c "create table schema_bar.foo (blah int);")
	$(call oc_exec_all_pods,cas-postgres-patroni,psql -d $(DB) -c "create table schema_baz.foo (blah int);")

	$(call oc_exec_all_pods,cas-postgres-patroni,create-user-db -u $(USER) -d $(DB) -p $(PASS) --schemas schema_foo$(comma)schema_bar --privileges select$(comma)insert)

.PHONY: get-user-schema-privileges
get-user-tables-privileges:
	$(call oc_exec_all_pods,cas-postgres-patroni,psql -tq -d $(DB) -c "select distinct privilege_type from information_schema.role_table_grants where table_schema=\'$(SCHEMA)\' and grantee=\'$(USER)\' order by privilege_type;")

.PHONY: drop-user-db
drop-user-db:
	$(call oc_exec_all_pods,cas-postgres-patroni,dropdb --if-exists $(DB))
	$(call oc_exec_all_pods,cas-postgres-patroni,dropuser --if-exists $(USER))

.PHONY: test-user-password
test-user-password:
	$(call oc_exec_all_pods,cas-postgres-patroni,PGPASSWORD="$(PASS)" psql -tq -U "$(USER)" -d "$(DB)" -c "select \'ok\';")
