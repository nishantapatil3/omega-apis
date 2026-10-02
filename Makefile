PROTO_DIR := protos
PY_OUT := sdk/python
GOBIN := $(shell go env GOPATH)/bin
PROTO_FILES := $(shell find $(PROTO_DIR) -name '*.proto')

VENV := .venv
VENV_PYTHON := $(VENV)/bin/python3
VENV_STAMP := $(VENV)/.deps-installed

.PHONY: all
all: generate

$(VENV_PYTHON):
	python3 -m venv $(VENV)

$(VENV_STAMP): $(VENV_PYTHON)
	$(VENV_PYTHON) -m pip install --upgrade pip grpcio-tools mypy-protobuf
	touch $(VENV_STAMP)

.PHONY: venv
venv: $(VENV_STAMP)

.PHONY: tools
tools: $(VENV_STAMP)
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

.PHONY: lint
lint:
	buf lint

.PHONY: breaking
breaking:
	buf breaking --against ".git#branch=main"

.PHONY: generate
generate: generate-go generate-python

.PHONY: generate-go
generate-go:
	PATH="$(GOBIN):$$PATH" buf generate

.PHONY: generate-python
generate-python: $(VENV_STAMP)
	mkdir -p $(PY_OUT)
	$(VENV_PYTHON) -m grpc_tools.protoc \
		-I $(PROTO_DIR) \
		--python_out=$(PY_OUT) \
		--grpc_python_out=$(PY_OUT) \
		--pyi_out=$(PY_OUT) \
		$(PROTO_FILES)
	find $(PY_OUT) -type d -exec sh -c 'test -f "$$1/__init__.py" || touch "$$1/__init__.py"' _ {} \;

.PHONY: build-go
build-go:
	cd sdk/go && go build ./...

.PHONY: check
check: lint breaking generate
	git diff --exit-code -- sdk/go sdk/python

.PHONY: clean
clean:
	rm -rf sdk/go/omega sdk/python/omega
	find sdk/python -name '__pycache__' -type d -exec rm -rf {} +

.PHONY: distclean
distclean: clean
	rm -rf $(VENV)
