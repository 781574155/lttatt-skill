#!/bin/bash

set -e

PACKAGE_NAME=$1
PACKAGE_VERSION=$2
TARGET_PLATFORM=$3
BRANCH_NAME=$4

echo "Building package: $PACKAGE_NAME, version: $PACKAGE_VERSION, for platform: $TARGET_PLATFORM, branch: $BRANCH_NAME"

CACHE_BRANCH=$(echo "$BRANCH_NAME" | tr '/:' '--')
docker buildx build --builder container-builder \
	--cache-from=type=registry,ref=registry.openai36.com/tanqi/"$PACKAGE_NAME":buildcache-master \
	--cache-from=type=registry,ref=registry.openai36.com/tanqi/"$PACKAGE_NAME":buildcache-"$CACHE_BRANCH" \
	--cache-to=type=registry,ref=registry.openai36.com/tanqi/"$PACKAGE_NAME":buildcache-"$CACHE_BRANCH",mode=max \
	--push \
	--platform "$TARGET_PLATFORM" \
	-t registry.openai36.com/tanqi/"$PACKAGE_NAME":"$PACKAGE_VERSION" .

echo "Package $PACKAGE_NAME version $PACKAGE_VERSION built successfully."
