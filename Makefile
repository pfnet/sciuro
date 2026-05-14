TAG := $(shell git describe --tags --always --dirty)
IMG ?= ghcr.io/pfnet/sciuro:$(TAG)

DOCKER_BUILD ?= docker build --progress=plain
OUTPUT_DIR ?= out

.PHONY: default
default: build;

.PHONY: clean
clean:
	@echo cleaning build targets
	@rm -rf $(OUTPUT_DIR)

.PHONY: check
check:
	@echo running checks
	@$(DOCKER_BUILD) --target check .

.PHONY: dep-update
dep-update:
	@echo updating dependencies
	@$(DOCKER_BUILD) --target export-dep-update --output . .

.PHONY: test
test:
	@echo unit testing
	$(DOCKER_BUILD) --target test .

.PHONY: test-coverage
test-coverage:
	@echo unit testing with coverage
	$(DOCKER_BUILD) --target export-test-coverage --output $(OUTPUT_DIR) .

.PHONY: build
build:
	@echo building cmds and images
	@$(DOCKER_BUILD) --target export --output $(OUTPUT_DIR) .
	@$(DOCKER_BUILD) -t $(IMG) .

.PHONY: manifests
manifests:
	@echo generating manifests
	@$(DOCKER_BUILD) --build-arg TAG=$(TAG) --target export-manifests --output $(OUTPUT_DIR) .

.PHONY: push
push:
	@echo pushing images
	@docker push $(IMG)
