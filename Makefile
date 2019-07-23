PREFIX=cas-

TEST=$(shell which test)

GIT=$(shell which git)
GIT_SHA1=$(shell echo "$${CIRCLE_SHA1:-`$(GIT) rev-parse HEAD`}")
GIT_BRANCH=$(strip $(shell $(GIT) rev-parse --abbrev-ref HEAD))
GIT_BRANCH_NORM=$(subst /,-,$(GIT_BRANCH)) # openshift doesn't like slashes 

FIND=$(shell which find)

OC=$(shell which oc)
OC_PROJECT=$(shell echo "$${ENVIRONMENT:-$${OC_PROJECT}}")
OC_TOOLS_PROJECT=wksv3k-tools
OC_TEST_PROJECT=wksv3k-test
OC_DEV_PROJECT=wksv3k-dev
OC_PROD_PROJECT=wksv3k-prod
OC_REGISTRY=docker-registry.default.svc:5000
OC_REGISTRY_EXT=docker-registry.pathfinder.gov.bc.ca
OC_TEMPLATE_VARS=PREFIX=$(PREFIX) GIT_SHA1=$(GIT_SHA1)

RED_HAT_DOCKER_SERVER=$(shell echo "$$RED_HAT_DOCKER_SERVER")
RED_HAT_DOCKER_USERNAME=$(shell echo "$$RED_HAT_DOCKER_USERNAME")
RED_HAT_DOCKER_PASSWORD=$(shell echo "$$RED_HAT_DOCKER_PASSWORD")
RED_HAT_DOCKER_EMAIL=$(shell echo "$$RED_HAT_DOCKER_EMAIL")

define switch_project
	@@echo ✓ logged in as: $(shell $(OC) whoami)
	@@$(TEST) $(OC_PROJECT) # ensure OC_PROJECT is defined
	@@$(OC) project $(OC_PROJECT) >/dev/null
	@@echo ✓ switched project to: $(OC_PROJECT)
endef

define oc_validate
	$(OC) process -f $(1) --local $(2) \
		| $(OC) -n "$(OC_PROJECT)" apply --dry-run --validate -f- >/dev/null \
		&& echo ✓ $(1) is valid \
		|| (echo ✘ $(1) is invalid && exit 1)
endef

define oc_lint
	@@for FILE in $(shell $(FIND) openshift -name \*.yml -print); \
		do $(call oc_validate,$$FILE,$(OC_TEMPLATE_VARS)); \
	done
endef

define oc_apply
	$(OC) process -f $(1) $(2) \
		| $(OC) -n "$(OC_PROJECT)" apply --wait --overwrite --validate -f-
endef

define oc_configure
	@@for FILE in $(shell $(FIND) openshift/build -name \*.yml -print); \
		do $(call oc_apply,$$FILE,$(OC_TEMPLATE_VARS)); \
	done
endef

define oc_build
	@@echo ✓ building $(1)
	@@$(OC) start-build $(1) --follow
	@@echo ✓ tagging $(1):$(GIT_SHA1) to $(1):$(GIT_BRANCH_NORM)
	@@$(OC) tag $(1):$(GIT_SHA1) $(1):$(GIT_BRANCH_NORM)
endef

define oc_promote
	@@$(OC) -n $(OC_PROJECT) tag $(OC_TOOLS_PROJECT)/$(1):$(GIT_SHA1) $(1):$(GIT_SHA1) --reference-policy=local
	@@$(OC) -n $(OC_PROJECT) tag $(1):$(GIT_SHA1) $(1):latest --reference-policy=local
endef

define oc_provision
	@@for FILE in $(shell $(FIND) openshift/deploy -name \*.yml -print); \
		do $(call oc_apply,$$FILE,$(OC_TEMPLATE_VARS)); \
	done
endef

.PHONY: lint
lint: OC_PROJECT=$(OC_TOOLS_PROJECT)
lint:
	$(call switch_project)
	$(call oc_lint)

.PHONY: configure
configure: OC_PROJECT=$(OC_TOOLS_PROJECT)
configure:
	$(call switch_project)
	$(call oc_configure)

.PHONY: build
build: OC_PROJECT=$(OC_TOOLS_PROJECT)
build:
	$(call switch_project)
	$(call oc_build,$(PREFIX)postgres)

.PHONY: deploy
deploy:
	$(call switch_project)
	$(call oc_promote,$(PREFIX)postgres)

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
			--docker-email="$(RED_HAT_DOCKER_EMAIL)" \
			>/dev/null; \
		$(OC) -n "$(1)" secret link default io-redhat-registry --for=pull; \
		$(OC) -n "$(1)" secret link builder io-redhat-registry; \
	fi
endef

define oc_new_project
	@@if ! $(OC) get project $(1) >/dev/null; then \
		$(OC) new-project $(1) >/dev/null \
		&& echo "✓ oc new-project $(1)"; \
	fi
	$(call oc_configure_credentials,$(1))
	@@echo "✓ oc project $(1) exists"
endef

.PHONY: provision
provision:
	$(call oc_new_project,$(OC_TOOLS_PROJECT))
	$(call oc_new_project,$(OC_TEST_PROJECT))
	$(call oc_new_project,$(OC_DEV_PROJECT))
	$(call oc_new_project,$(OC_PROD_PROJECT))

define oc_create
	@@if ! $(OC) -n "$(1)" get $(2)/$(3) >/dev/null; then \
		$(OC) -n "$(1)" create $(2) $(3) >/dev/null; \
	fi;
	@@echo "✓ oc create $(2)/$(3)"
endef

.PHONY: authorize
authorize: OC_PROJECT=$(OC_TOOLS_PROJECT)
authorize:
	$(call switch_project)
	@@for FILE in $(shell $(FIND) openshift/authorize/clusterrole -name \*.yml -print); \
		do $(call oc_apply,$$FILE,$(OC_TEMPLATE_VARS)); \
	done
	$(call oc_create,$(OC_TOOLS_PROJECT),serviceaccount,circleci)
	$(OC) -n $(OC_TOOLS_PROJECT) policy add-role-to-user $(PREFIX)linter system:serviceaccount:$(OC_TOOLS_PROJECT):circleci --role-namespace=$(OC_TOOLS_PROJECT)
	$(OC) -n $(OC_TOOLS_PROJECT) policy add-role-to-user $(PREFIX)builder system:serviceaccount:$(OC_TOOLS_PROJECT):circleci --role-namespace=$(OC_TOOLS_PROJECT)

# oc get clusterrole
# oc describe clusterrole.rbac
# ssh -L 8443:127.0.0.1:8443 -p 54782 35.229.72.44
