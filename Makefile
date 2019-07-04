IMAGE_NAME = cas-postgres

.PHONY: build
build:
	docker build -t $(IMAGE_NAME) .
