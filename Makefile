SHELL := /usr/bin/env bash
PATHFINDER_PREFIX := wksv3k
PROJECT_PREFIX := cas-

THIS_FILE := $(lastword $(MAKEFILE_LIST))
PROJECT_FOLDER := $(abspath $(realpath $(lastword $(MAKEFILE_LIST)))/../)
include .pipeline/*.mk

# We define the default values of the template variables here to make them available in the lint target.
POSTGRESQL_WORKERS="4"
MASTER_CPU_REQUEST="500m"
MASTER_CPU_LIMIT="2"
MASTER_MEMORY_REQUEST="4096Mi"
MASTER_MEMORY_LIMIT="8192Mi"
WORKER_CPU_REQUEST="250m"
WORKER_CPU_LIMIT="1"
WORKER_MEMORY_REQUEST="2048Mi"
WORKER_MEMORY_LIMIT="4096Mi"

OC_TEMPLATE_VARS += POSTGRESQL_WORKERS="$(POSTGRESQL_WORKERS)"
OC_TEMPLATE_VARS += MASTER_CPU_REQUEST=$(MASTER_CPU_REQUEST) MASTER_CPU_LIMIT=$(MASTER_CPU_LIMIT)
OC_TEMPLATE_VARS += MASTER_MEMORY_REQUEST=$(MASTER_MEMORY_REQUEST) MASTER_MEMORY_LIMIT=$(MASTER_MEMORY_LIMIT)
OC_TEMPLATE_VARS += WORKER_CPU_REQUEST=$(WORKER_CPU_REQUEST) WORKER_CPU_LIMIT=$(WORKER_CPU_LIMIT)
OC_TEMPLATE_VARS += WORKER_MEMORY_REQUEST=$(WORKER_MEMORY_REQUEST) WORKER_MEMORY_LIMIT=$(WORKER_MEMORY_LIMIT)

.PHONY: help
help: $(call make_help,help,Explains how to use this Makefile)
	@@exit 0

.PHONY: targets
targets: $(call make_help,targets,Lists all targets in this Makefile)
	$(call make_list_targets,$(THIS_FILE))

.PHONY: whoami
whoami: $(call make_help,whoami,Prints the name of the user currently authenticated via `oc`)
	$(call oc_whoami)

.PHONY: project
project: whoami
project: $(call make_help,project,Switches to the desired $$OC_PROJECT namespace)
	$(call oc_project)

.PHONY: lint
lint: $(call make_help,lint,Checks the configured yml template definitions against the remote schema using the tools namespace)
lint: OC_PROJECT=$(OC_TOOLS_PROJECT)
lint: whoami
	$(call oc_lint)

.PHONY: configure
configure: $(call make_help,configure,Configures the tools project namespace for a build)
configure: OC_PROJECT=$(OC_TOOLS_PROJECT)
configure: whoami
	$(call oc_configure)

.PHONY: build
build: $(call make_help,build,Builds the source into an image in the tools project namespace)
build: OC_PROJECT=$(OC_TOOLS_PROJECT)
build: whoami
	$(call oc_build,$(PROJECT_PREFIX)postgres)

# The != operator assigns the ouput of a bash command to the variable, this allows us to override the
# default value depending on the value OC_PROJECT in the install target
.PHONY: install
install: POSTGRESQL_WORKERS != if [ "$(OC_PROJECT)" == "$(OC_PROD_PROJECT)" ]; then echo 8; else echo 4; fi;
install: MASTER_CPU_REQUEST != if [ "$(OC_PROJECT)" == "$(OC_PROD_PROJECT)" ]; then echo 1; else echo "500m"; fi;
install: WORKER_CPU_REQUEST != if [ "$(OC_PROJECT)" == "$(OC_PROD_PROJECT)" ]; then echo "500m"; else echo "250m"; fi;
install: POSTGRESQL_ADMIN_PASSWORD=$(shell openssl rand -base64 32 | tr -d /=+ | cut -c -16 | base64)
install: OC_TEMPLATE_VARS += POSTGRESQL_ADMIN_PASSWORD="$(POSTGRESQL_ADMIN_PASSWORD)"
install: whoami
	$(call oc_create_secrets)
	$(call oc_promote,$(PROJECT_PREFIX)postgres)
	$(call oc_deploy)
	$(call oc_wait_for_deploy_ready,$(PROJECT_PREFIX)postgres-master)
	@@echo "TODO: wait for statefulset to be ready"
	@@echo "waiting for all $(PROJECT_PREFIX)postgres-workers to be connected to $(PROJECT_PREFIX)postgres-master..."; \
		POD=$$($(OC) -n $(OC_PROJECT) get pods --selector deploymentconfig=$(PROJECT_PREFIX)postgres-master --field-selector status.phase=Running -o name | cut -d '/' -f 2 ); \
		AVAILABLE_COUNT="-1"; \
		while [ "$(POSTGRESQL_WORKERS)" != "$$AVAILABLE_COUNT" ]; do \
			AVAILABLE_COUNT="$$($(OC) -n $(OC_PROJECT) exec $$POD -- psql -qtA -v "ON_ERROR_STOP=1" -c "select count(success) from run_command_on_workers('select true') where success = true;")"; \
			echo "connected nodes: $$AVAILABLE_COUNT"; \
			if [ "$(POSTGRESQL_WORKERS)" != "$$AVAILABLE_COUNT" ]; then \
				sleep 5; \
			fi; \
		done; \
		if [ "$(POSTGRESQL_WORKERS)" != "$$($(OC) -n $(OC_PROJECT) exec $$POD -- psql -qtA -v "ON_ERROR_STOP=1" -c "select count(isactive) from pg_dist_node where isactive = true;")" ]; then \
			echo "list configured workers..."; \
			$(OC) -n $(OC_PROJECT) exec $$POD -- psql -c "select * from pg_dist_node;"; \
			echo "try connecting to all enabled workers..."; \
			$(OC) -n $(OC_PROJECT) exec $$POD -- psql -c "select * from run_command_on_workers('select true');"; \
		fi;

.PHONY: install_dev
install_dev: OC_PROJECT=$(OC_DEV_PROJECT)
install_dev: install

.PHONY: install_test
install_test: OC_PROJECT=$(OC_TEST_PROJECT)
install_test: install

.PHONY: install_prod
install_prod: OC_PROJECT=$(OC_PROD_PROJECT)
install_prod: install

.PHONY: mock_storageclass
mock_storageclass:
	$(call oc_mock_storageclass,gluster-file gluster-file-db gluster-block)

.PHONY: provision
provision:
	$(call oc_new_project,$(OC_TOOLS_PROJECT))
	$(call oc_new_project,$(OC_TEST_PROJECT))
	$(call oc_new_project,$(OC_DEV_PROJECT))
	$(call oc_new_project,$(OC_PROD_PROJECT))

OC_CIRCLECI_SECRET=$(shell $(OC) -n $(OC_PROJECT) describe sa $(PROJECT_PREFIX)circleci | awk '$$1 == "Mountable" { print $$3 }')
OC_CIRCLECI_TOKEN=$(shell $(OC) -n $(OC_PROJECT) get secret $(OC_CIRCLECI_SECRET) -o=template --template '{{base64decode .data.token}}')
OC_SHIPIT_SECRET=$(shell $(OC) -n $(OC_PROJECT) describe sa $(PROJECT_PREFIX)shipit | awk '$$1 == "Mountable" { print $$3 }')
OC_SHIPIT_TOKEN=$(shell $(OC) -n $(OC_PROJECT) get secret $(OC_SHIPIT_SECRET) -o=template --template '{{base64decode .data.token}}')
.PHONY: token
token: OC_PROJECT=$(OC_TOOLS_PROJECT)
token:
	@@echo "\n$(OC_CIRCLECI_SECRET)"
	@@echo "$(OC_CIRCLECI_TOKEN)\n"
	@@echo "\n$(OC_SHIPIT_SECRET)"
	@@echo "$(OC_SHIPIT_TOKEN)\n"


.PHONY: scan
scan:
	curl https://ftp.postgresql.org/pub/source/v11.4/postgresql-11.4.tar.gz | tar xz
	git clone -b 'v1.0.0' --single-branch https://github.com/theory/pgtap.git
	git clone -b 'v8.2.2' --single-branch  https://github.com/citusdata/citus.git
	docker run -d --name sonarqube -p 9000:9000 sonarqube
	wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.0.0.1744-macosx.zip
	unzip sonar-scanner-cli-4.0.0.1744-macosx.zip
	./sonar-scanner-4.0.0.1744-macosx/bin/sonar-scanner \
		-Dsonar.projectKey=cas-postgres \
		-Dsonar.sources=. \
		-Dsonar.projectVersion=`git rev-parse --abbrev-ref HEAD` \
		-Dsonar.coverage.exclusions='**/*'

.PHONY: old_tags
old_tags:
	oc get is/cas-postgres -o go-template='{{range .status.tags}}{{$$tag := .tag}}{{range .items}}{{.created}}{{"\t"}}{{$$tag}}{{"\n"}}{{end}}{{end}}' | sort -r | tail -n +8 | awk '{print $$2}'

ifeq ($(MAKECMDGOALS),$(filter $(MAKECMDGOALS),test_e2e test_unit))
include $(PROJECT_FOLDER)/.pipeline/test/bats.mk
endif


.PHONY: test_e2e
test_e2e: # https://github.com/bats-core/bats-core
	$(call bats_test,$(call make_recursive_wildcard,$(PROJECT_FOLDER)/test/e2e,*.bats))

.PHONY: test_unit
test_unit: # https://github.com/bats-core/bats-core
	$(call bats_test,$(call make_recursive_wildcard,$(PROJECT_FOLDER)/test/unit,*.bats))

