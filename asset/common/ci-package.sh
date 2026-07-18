#!/bin/bash

set -e

CI_SCRIPT_NAME=$(basename "$0")
CI_SCRIPT_STARTED_SECONDS=$(date +%s)
CI_SCRIPT_STARTED_AT=$(date '+%Y-%m-%d %H:%M:%S %z')
echo "CI script ${CI_SCRIPT_NAME} started at: ${CI_SCRIPT_STARTED_AT}"
trap 'CI_SCRIPT_EXIT_CODE=$?; CI_SCRIPT_ENDED_SECONDS=$(date +%s); CI_SCRIPT_ENDED_AT=$(date "+%Y-%m-%d %H:%M:%S %z"); CI_SCRIPT_ELAPSED_SECONDS=$((CI_SCRIPT_ENDED_SECONDS - CI_SCRIPT_STARTED_SECONDS)); echo "CI script ${CI_SCRIPT_NAME} ended at: ${CI_SCRIPT_ENDED_AT}"; echo "CI script ${CI_SCRIPT_NAME} elapsed seconds: ${CI_SCRIPT_ELAPSED_SECONDS}"; exit "${CI_SCRIPT_EXIT_CODE}"' EXIT

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
