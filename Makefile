TEST=$(shell which test)

GIT=$(shell which git)
GIT_SHA1=$(shell echo "$${CIRCLE_SHA1:-`$(GIT) rev-parse HEAD`}")
GIT_BRANCH=$(shell $(GIT) rev-parse --abbrev-ref HEAD)
GIT_BRANCH_NORM=$(subst /,-,$(GIT_BRANCH)) # openshift doesn't like slashes 

OC=$(shell which oc)
OC_PROJECT=$(shell echo "$${ENVIRONMENT}")
OC_TOOLS_PROJECT=wksv3k-tools
OC_TEST_PROJECT=wksv3k-test
OC_DEV_PROJECT=wksv3k-dev
OC_PROD_PROJECT=wksv3k-prod
OC_REGISTRY=docker-registry.default.svc:5000
OC_REGISTRY_EXT=docker-registry.pathfinder.gov.bc.ca

define switch_project
	@@echo ✓ logged in as: $(shell $(OC) whoami)
	@@$(TEST) $(OC_PROJECT)
	@@$(OC) project $(OC_PROJECT) >/dev/null
	@@echo ✓ switched project to: $(OC_PROJECT)
endef

define oc_apply
	@@$(OC) process -f openshift/$(1).yml $(2) | $(OC) apply --wait=true --overwrite=true -f-
endef

.PHONY: configure
configure: OC_PROJECT=$(OC_TOOLS_PROJECT)
configure:
	$(call switch_project)
	$(call oc_apply,build/imagestream/cas-postgres,GIT_SHA1=$(GIT_SHA1))
	$(call oc_apply,build/buildconfig/cas-postgres,GIT_SHA1=$(GIT_SHA1))

.PHONY: build
build: OC_PROJECT=$(OC_TOOLS_PROJECT)
build:
	$(call switch_project)
	@@echo ✓ building cas-postgres
	@@$(OC) start-build cas-postgres --follow
	@@$(OC) tag cas-postgres:$(GIT_SHA1) cas-postgres:$(GIT_BRANCH_NORM)

.PHONY: deploy
deploy:
deploy:
	$(call switch_project)
	@@$(OC) tag $(OC_TOOLS_PROJECT)/cas-postgres:$(GIT_SHA1) cas-postgres:$(GIT_SHA1) --reference-policy=local

.PHONY: deploy_test
deploy_test: OC_PROJECT=$(OC_TEST_PROJECT)
deploy_test: deploy

.PHONY: deploy_dev
deploy_dev: OC_PROJECT=$(OC_DEV_PROJECT)
deploy_dev: deploy

.PHONY: deploy_prod
deploy_prod: OC_PROJECT=$(OC_PROD_PROJECT)
deploy_prod: deploy
