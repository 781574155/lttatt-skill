#!/bin/bash

set -e

CI_SCRIPT_NAME=$(basename "$0")
CI_SCRIPT_STARTED_SECONDS=$(date +%s)
CI_SCRIPT_STARTED_AT=$(date '+%Y-%m-%d %H:%M:%S %z')
echo "CI script ${CI_SCRIPT_NAME} started at: ${CI_SCRIPT_STARTED_AT}"

ci_script_log_exit() {
	local ci_script_exit_code
	local ci_script_ended_seconds
	local ci_script_ended_at
	local ci_script_elapsed_seconds

	ci_script_exit_code=$1
	ci_script_ended_seconds=$(date +%s)
	ci_script_ended_at=$(date "+%Y-%m-%d %H:%M:%S %z")
	ci_script_elapsed_seconds=$((ci_script_ended_seconds - CI_SCRIPT_STARTED_SECONDS))
	echo "CI script ${CI_SCRIPT_NAME} ended at: ${ci_script_ended_at}"
	echo "CI script ${CI_SCRIPT_NAME} elapsed seconds: ${ci_script_elapsed_seconds}"
	exit "${ci_script_exit_code}"
}

trap 'ci_script_log_exit "$?"' EXIT

PACKAGE_NAME=$1
PACKAGE_VERSION=$2
TARGET_PLATFORM=$3
BRANCH_NAME=$4

echo "Building package: $PACKAGE_NAME, version: $PACKAGE_VERSION, for platform: $TARGET_PLATFORM, branch: $BRANCH_NAME"

mvn clean compile checkstyle:check pmd:check package

CACHE_BRANCH=$(echo "$BRANCH_NAME" | tr '/:' '--')
docker buildx build --builder container-builder \
	--cache-from=type=registry,ref=registry.openai36.com/tanqi/"$PACKAGE_NAME":buildcache-master \
	--cache-from=type=registry,ref=registry.openai36.com/tanqi/"$PACKAGE_NAME":buildcache-"$CACHE_BRANCH" \
	--cache-to=type=registry,ref=registry.openai36.com/tanqi/"$PACKAGE_NAME":buildcache-"$CACHE_BRANCH",mode=max \
	--ulimit nofile=65536:65536 \
	--build-arg PACKAGE_VERSION="$PACKAGE_VERSION" \
	--push \
	--platform "$TARGET_PLATFORM" \
	-t registry.openai36.com/tanqi/"$PACKAGE_NAME":"$PACKAGE_VERSION" .

echo "Package $PACKAGE_NAME version $PACKAGE_VERSION built successfully."
