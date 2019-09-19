SHELL := /usr/bin/env bash
include $(abspath $(realpath $(lastword $(MAKEFILE_LIST)))/../../../../.pipeline/oc.mk)

.PHONY: create-user-db
create-user-db:
	$(call oc_exec_all_pods,cas-postgres-master,create-user-db $(USER) $(DB) $(PASS_LEN))

.PHONY: drop-user-db
drop-user-db:
	$(call oc_exec_all_pods,cas-postgres-master,dropdb $(DB))
	$(call oc_exec_all_pods,cas-postgres-master,dropuser $(USER))

.PHONY: test-user-password
test-user-password:
	$(call oc_exec_all_pods,cas-postgres-master,PGPASSWORD="$(PASS)" psql -tq -U "$(USER)" -d "$(DB)" -c "select \'ok\';")
