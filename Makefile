# Makefile for creating container file
# Override these with environmental variables
VERSION?=3.2
FULL_VERSION?=3.2.5

### Do not override below

user=legalio
app=redis
version=$(VERSION)
#registry=docker.io

all: container

container:
	docker build --tag=$(user)/$(app):$(version) .
	docker tag $(user)/$(app):$(version) $(user)/$(app):${FULL_VERSION}
	docker tag $(user)/$(app):$(version) $(user)/$(app):latest

push:
	docker push $(user)/$(app):$(version)
	docker push $(user)/$(app):$(FULL_VERSION)

push-latest:
	docker push $(user)/$(app):latest

push-all: push push-latest

.PHONY: all container push push-latest push-all
