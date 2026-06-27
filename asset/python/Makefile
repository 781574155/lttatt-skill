PACKAGE_NAME := drama-processor
PACKAGE_VERSION := 2.4.0-SNAPSHOT

########################################
.PHONY: help package release git-check

DOCKER_REGISTRY := registry.openai36.com/tanqi/
TARGET_PLATFORM ?= linux/amd64      # 自动设置：package时为linux/amd64，release时为linux/amd64,linux/arm64

help:
	@echo "Available targets:"
	@echo "  make package        - Build and push Docker image (multi-platform)"
	@echo "  make release        - Perform full release workflow"

package:
	@echo "Building Docker image for $(PACKAGE_NAME):v$(PACKAGE_VERSION)..."
	docker build --push --platform=$(TARGET_PLATFORM) -t $(DOCKER_REGISTRY)$(PACKAGE_NAME):v$(PACKAGE_VERSION) .

git-check:
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Error: There are uncommitted changes. Please commit or stash your changes before proceeding."; \
		exit 1; \
	fi

version-check:
	@if ! echo "$(PACKAGE_VERSION)" | grep -q -- -SNAPSHOT; then \
		echo "Error: PACKAGE_VERSION must end with -SNAPSHOT for release."; \
		exit 1; \
	fi

release: version-check git-check
	@echo "Starting release process for version $(PACKAGE_VERSION)..."
	@ PV="$(PACKAGE_VERSION)"; \
	BASE_VERSION=$${PV%-SNAPSHOT}; \
	echo "Releasing version $$BASE_VERSION"; \
	IFS='.' read -r MAJOR MINOR PATCH <<< "$$BASE_VERSION"; \
	DEFAULT_NEXT_VERSION="$$MAJOR.$$MINOR.$$((PATCH + 1))-SNAPSHOT"; \
	read -p "Next version (default: $$DEFAULT_NEXT_VERSION): " NEW_VERSION; \
	NEW_VERSION=$${NEW_VERSION:-$$DEFAULT_NEXT_VERSION}; \
	if ! [[ $$NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+-SNAPSHOT$$ ]]; then \
		echo "version must be in the format X.Y.Z-SNAPSHOT"; \
		exit 1; \
	fi; \
	sed -i "s/^PACKAGE_VERSION := .*/PACKAGE_VERSION := $$BASE_VERSION/" Makefile; \
	git add Makefile; \
	git commit -m "[Release] prepare release v$$BASE_VERSION"; \
	git tag "v$$BASE_VERSION"; \
	$(MAKE) package PACKAGE_NAME=$(PACKAGE_NAME) PACKAGE_VERSION=$$BASE_VERSION TARGET_PLATFORM=linux/amd64,linux/arm64; \
	sed -i "s/^PACKAGE_VERSION := .*/PACKAGE_VERSION := $$NEW_VERSION/" Makefile; \
	git add Makefile; \
	git commit -m "[Release] prepare for next development iteration" \
	echo "Release process completed. Don't forget to push the changes and tags:"

print-%:
	@echo $($*)
