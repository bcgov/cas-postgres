PATHFINDER_PREFIX=wksv3k
PROJECT_PREFIX=cas-

THIS_FILE := $(lastword $(MAKEFILE_LIST))
include .pipeline/*.mk

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

.PHONY: install
install: whoami
	$(call oc_promote,$(PROJECT_PREFIX)postgres)

.PHONY: install-dev
install.dev: OC_PROJECT=$(OC_DEV_PROJECT)
install.dev: install

.PHONY: install-test
install.test: OC_PROJECT=$(OC_TEST_PROJECT)
install.test: install

.PHONY: install-prod
install.prod: OC_PROJECT=$(OC_PROD_PROJECT)
install.prod: install

.PHONY: provision
provision:
	$(call oc_new_project,$(OC_TOOLS_PROJECT))
	$(call oc_new_project,$(OC_TEST_PROJECT))
	$(call oc_new_project,$(OC_DEV_PROJECT))
	$(call oc_new_project,$(OC_PROD_PROJECT))

.PHONY: authorize
authorize: OC_PROJECT=$(OC_TOOLS_PROJECT)
authorize:
	$(call switch_project)
	@@for FILE in $(shell $(FIND) openshift/authorize/role -name \*.yml -print); do \
			for PROJECT in $(OC_TOOLS_PROJECT) $(OC_TEST_PROJECT) $(OC_DEV_PROJECT) $(OC_PROD_PROJECT); do \
				$(call oc_apply,$$FILE,$(OC_TEMPLATE_VARS),$$PROJECT); \
			done; \
		done;
	$(call oc_create,$(OC_PROJECT),serviceaccount,$(PROJECT_PREFIX)circleci)
	$(OC) -n $(OC_PROJECT) policy add-role-to-user $(PROJECT_PREFIX)linter system:serviceaccount:$(OC_PROJECT):$(PROJECT_PREFIX)circleci --role-namespace=$(OC_PROJECT)
	$(OC) -n $(OC_PROJECT) policy add-role-to-user $(PROJECT_PREFIX)builder system:serviceaccount:$(OC_PROJECT):$(PROJECT_PREFIX)circleci --role-namespace=$(OC_PROJECT)
	$(call oc_create,$(OC_PROJECT),serviceaccount,$(PROJECT_PREFIX)shipit)
	$(OC) -n $(OC_TOOLS_PROJECT) policy add-role-to-user $(PROJECT_PREFIX)deployer system:serviceaccount:$(OC_TOOLS_PROJECT):$(PROJECT_PREFIX)shipit --role-namespace=$(OC_TOOLS_PROJECT)
	$(OC) -n $(OC_TEST_PROJECT) policy add-role-to-user $(PROJECT_PREFIX)deployer system:serviceaccount:$(OC_TOOLS_PROJECT):$(PROJECT_PREFIX)shipit --role-namespace=$(OC_TEST_PROJECT)
	$(OC) -n $(OC_DEV_PROJECT) policy add-role-to-user $(PROJECT_PREFIX)deployer system:serviceaccount:$(OC_TOOLS_PROJECT):$(PROJECT_PREFIX)shipit --role-namespace=$(OC_DEV_PROJECT)
	$(OC) -n $(OC_PROD_PROJECT) policy add-role-to-user $(PROJECT_PREFIX)deployer system:serviceaccount:$(OC_TOOLS_PROJECT):$(PROJECT_PREFIX)shipit --role-namespace=$(OC_PROD_PROJECT)

# oc get clusterrole
# oc describe clusterrole.rbac
# ssh -L 8443:127.0.0.1:8443 -p 54782 35.229.72.44

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
