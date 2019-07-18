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

RED_HAT_DOCKER_SERVER=$(shell echo "$$RED_HAT_DOCKER_SERVER")
RED_HAT_DOCKER_USERNAME=$(shell echo "$$RED_HAT_DOCKER_USERNAME")
RED_HAT_DOCKER_PASSWORD=$(shell echo "$$RED_HAT_DOCKER_PASSWORD")
RED_HAT_DOCKER_EMAIL=$(shell echo "$$RED_HAT_DOCKER_EMAIL")

define switch_project
	@@echo ✓ logged in as: $(shell $(OC) whoami)
	@@$(TEST) $(OC_PROJECT)
	@@$(OC) project $(OC_PROJECT) >/dev/null
	@@echo ✓ switched project to: $(OC_PROJECT)
endef

define oc_validate
	@@echo ✓ validating $(1).yml
	@@$(OC) process -f openshift/$(1).yml --local $(2) | $(OC) -n "$(OC_PROJECT)" apply --dry-run --validate -f- >/dev/null
endef

define oc_lint
	$(call oc_validate,build/imagestream/$(1),GIT_SHA1=$(GIT_SHA1))
	$(call oc_validate,build/buildconfig/$(1),GIT_SHA1=$(GIT_SHA1))
endef

define oc_apply
	@@echo ✓ applying $(1).yml
	@@$(OC) process -f openshift/$(1).yml $(2) | $(OC) -n "$(OC_PROJECT)" apply --wait --overwrite --validate -f-
endef

define oc_configure
	$(call oc_apply,build/imagestream/$(1),GIT_SHA1=$(GIT_SHA1))
	$(call oc_apply,build/buildconfig/$(1),GIT_SHA1=$(GIT_SHA1))
endef

define oc_build
	@@echo ✓ building $(1)
	@@$(OC) start-build $(1) --follow
	@@echo ✓ tagging $(GIT_BRANCH_NORM)@$(GIT_SHA1)
	@@$(OC) tag $(1):$(GIT_SHA1) $(1):$(GIT_BRANCH_NORM)
endef

define oc_promote
	@@$(OC) tag $(OC_TOOLS_PROJECT)/$(1):$(2) $(1):$(2) --reference-policy=local
endef

.PHONY: lint
lint:
	$(call oc_lint,cas-postgres)

.PHONY: configure
configure: OC_PROJECT=$(OC_TOOLS_PROJECT)
configure:
	$(call switch_project)
	$(call oc_configure,cas-postgres)

.PHONY: build
build: OC_PROJECT=$(OC_TOOLS_PROJECT)
build:
	$(call switch_project)
	$(call oc_build,cas-postgres)

.PHONY: deploy
deploy:
deploy:
	$(call switch_project)
	$(call oc_promote,cas-postgres)

.PHONY: deploy_test
deploy_test: OC_PROJECT=$(OC_TEST_PROJECT)
deploy_test: deploy

.PHONY: deploy_dev
deploy_dev: OC_PROJECT=$(OC_DEV_PROJECT)
deploy_dev: deploy

.PHONY: deploy_prod
deploy_prod: OC_PROJECT=$(OC_PROD_PROJECT)
deploy_prod: deploy

# @see https://access.redhat.com/RegistryAuthentication#allowing-pods-to-reference-images-from-other-secured-registries-9
define oc_configure_credentials
	@@if ! $(OC) -n "$(1)" get secret io-redhat-registry  >/dev/null; then \
		$(OC) -n "$(1)" create secret docker-registry io-redhat-registry \
			--docker-server="$(RED_HAT_DOCKER_SERVER)" \
			--docker-username="$(RED_HAT_DOCKER_USERNAME)" \
			--docker-password="$(RED_HAT_DOCKER_PASSWORD)" \
			--docker-email="$(RED_HAT_DOCKER_EMAIL)"; \
		$(OC) -n "$(1)" secrets link default io-redhat-registry --for=pull; \
		$(OC) -n "$(1)" secrets link builder io-redhat-registry; \
	fi
endef

define oc_new_project
	@@if ! $(OC) get project $(1) >/dev/null; then $(OC) new-project $(1); fi
	$(call oc_configure_credentials,$(1))
	@@echo "✓ oc new-project $(1)"
endef

.PHONY: provision
provision:
	$(call oc_new_project,$(OC_TOOLS_PROJECT))
	$(call oc_new_project,$(OC_TEST_PROJECT))
	$(call oc_new_project,$(OC_DEV_PROJECT))
	$(call oc_new_project,$(OC_PROD_PROJECT))
