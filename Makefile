EXECUTABLE ?= telescopes
IMAGE ?= banzaicloud/$(EXECUTABLE)
TAG ?= dev-$(shell git log -1 --pretty=format:"%h")

LD_FLAGS = -X "main.version=$(TAG)"
GOFILES_NOVENDOR = $(shell find . -type f -name '*.go' -not -path "./vendor/*")
PKGS=$(shell go list ./... | grep -v /vendor)

SWAGGER_TMP_FILE = ./docs/openapi/recommender.json
SWAGGER_FILE = ./docs/openapi/recommender.yaml

.PHONY: _no-target-specified
_no-target-specified:
	$(error Please specify the target to make - `make list` shows targets.)

.PHONY: list
list:
	@$(MAKE) -pRrn : -f $(MAKEFILE_LIST) 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | sort

all: clean deps fmt vet docker push

clean:
	go clean -i ./...

deps-swagger:
ifeq ($(shell which swagger),)
	go get -u github.com/go-swagger/go-swagger/cmd/swagger
endif
ifeq ($(shell which swagger2openapi),)
	npm install -g swagger2openapi
endif

deps: deps-swagger
	go get ./...

fmt:
	@gofmt -w ${GOFILES_NOVENDOR}

vet:
	@go vet -composites=false ./...

docker:
	docker build --rm -t $(IMAGE):$(TAG) .

push:
	docker push $(IMAGE):$(TAG)

run-dev:
	. .env
	go run $(wildcard *.go)

swagger:
	swagger generate spec -o $(SWAGGER_TMP_FILE) 
	swagger2openapi -y $(SWAGGER_TMP_FILE) > $(SWAGGER_FILE)
	rm $(SWAGGER_TMP_FILE)

build:
	go build .

check-fmt:
	PKGS="${GOFILES_NOVENDOR}" GOFMT="gofmt" ./scripts/fmt-check.sh

check-misspell: install-misspell
	PKGS="${GOFILES_NOVENDOR}" MISSPELL="misspell" ./scripts/misspell-check.sh

misspell: install-misspell
	misspell -w ${GOFILES_NOVENDOR}

lint: install-golint
	golint -min_confidence 0.9 -set_exit_status $(PKGS)

test:
	@go test -v ./...

install-golint:
	GOLINT_CMD=$(shell command -v golint 2> /dev/null)
ifndef GOLINT_CMD
	go get github.com/golang/lint/golint
endif

install-misspell:
	MISSPELL_CMD=$(shell command -v misspell 2> /dev/null)
ifndef MISSPELL_CMD
	go get -u github.com/client9/misspell/cmd/misspell
endif
