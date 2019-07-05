IMAGE_NAME = cas-postgres

.PHONY: configure
configure:
	oc apply -f openshift/imagestream/cas-postgres.yml
	oc apply -f openshift/buildconfig/cas-postgres.yml

.PHONY: build
build:
	oc start-build cas-postgres --follow

.PHONY: docker_build
docker_build:
	docker build -t $(IMAGE_NAME) .
