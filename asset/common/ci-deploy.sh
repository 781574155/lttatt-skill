#!/bin/bash

set -e

CI_SCRIPT_NAME=$(basename "$0")
CI_SCRIPT_STARTED_SECONDS=$(date +%s)
CI_SCRIPT_STARTED_AT=$(date '+%Y-%m-%d %H:%M:%S %z')
echo "CI script ${CI_SCRIPT_NAME} started at: ${CI_SCRIPT_STARTED_AT}"
trap 'CI_SCRIPT_EXIT_CODE=$?; CI_SCRIPT_ENDED_SECONDS=$(date +%s); CI_SCRIPT_ENDED_AT=$(date "+%Y-%m-%d %H:%M:%S %z"); CI_SCRIPT_ELAPSED_SECONDS=$((CI_SCRIPT_ENDED_SECONDS - CI_SCRIPT_STARTED_SECONDS)); echo "CI script ${CI_SCRIPT_NAME} ended at: ${CI_SCRIPT_ENDED_AT}"; echo "CI script ${CI_SCRIPT_NAME} elapsed seconds: ${CI_SCRIPT_ELAPSED_SECONDS}"; exit "${CI_SCRIPT_EXIT_CODE}"' EXIT

PACKAGE_NAME=$1
PACKAGE_VERSION=$2
APP_DIR=$3
COMPONENT_VAR_NAME=$4
COMPONENT_HEALTHY_URL=$5
HEALTHY_MAX_ATTEMPTS=$6

echo "Deploying package: $PACKAGE_NAME, version: $PACKAGE_VERSION"

CURRENT_VERSION=$(grep -m1 "^${COMPONENT_VAR_NAME}=" "$APP_DIR"/.env | cut -d'=' -f2-)
echo "${COMPONENT_VAR_NAME}=${CURRENT_VERSION}" >>"$APP_DIR"/.versions

sed -i "s/^${COMPONENT_VAR_NAME}=.*/${COMPONENT_VAR_NAME}=$PACKAGE_VERSION/" "$APP_DIR"/.env
"$APP_DIR"/deploy.sh

echo "Deployment script completed. Waiting for the application to become reachable..."

attempt=0
until curl -sSf "$COMPONENT_HEALTHY_URL" >/dev/null || [ $attempt -ge "$HEALTHY_MAX_ATTEMPTS" ]; do
	attempt=$((attempt + 1))
	echo "Waiting for $COMPONENT_HEALTHY_URL (attempt ${attempt}/${HEALTHY_MAX_ATTEMPTS})..."
	sleep 1
done
if ! curl -sSf "$COMPONENT_HEALTHY_URL" >/dev/null; then
	echo "ERROR: $COMPONENT_HEALTHY_URL not reachable after ${HEALTHY_MAX_ATTEMPTS} seconds"

	echo "Try to rollback to previous version"
	BACKUP_VERSION=$(grep "^${COMPONENT_VAR_NAME}=" "$APP_DIR"/.versions | tail -n1 | cut -d'=' -f2-)
	echo "Rolling back to version: $BACKUP_VERSION"
	sed -i "s/^${COMPONENT_VAR_NAME}=.*/${COMPONENT_VAR_NAME}=$BACKUP_VERSION/" "$APP_DIR"/.env
	"$APP_DIR"/deploy.sh
	exit 1
fi

echo "Deployment completed successfully and application is reachable."
