#!/bin/bash

set -e

CI_SCRIPT_NAME=$(basename "$0")
CI_SCRIPT_STARTED_SECONDS=$(date +%s)
CI_SCRIPT_STARTED_AT=$(date '+%Y-%m-%d %H:%M:%S %z')
echo "CI script ${CI_SCRIPT_NAME} started at: ${CI_SCRIPT_STARTED_AT}"
trap 'CI_SCRIPT_EXIT_CODE=$?; CI_SCRIPT_ENDED_SECONDS=$(date +%s); CI_SCRIPT_ENDED_AT=$(date "+%Y-%m-%d %H:%M:%S %z"); CI_SCRIPT_ELAPSED_SECONDS=$((CI_SCRIPT_ENDED_SECONDS - CI_SCRIPT_STARTED_SECONDS)); echo "CI script ${CI_SCRIPT_NAME} ended at: ${CI_SCRIPT_ENDED_AT}"; echo "CI script ${CI_SCRIPT_NAME} elapsed seconds: ${CI_SCRIPT_ELAPSED_SECONDS}"; exit "${CI_SCRIPT_EXIT_CODE}"' EXIT

TAG_NAME=$1
DEPLOYMENT_REPO=$2
PACKAGE_NAME=$3

git config --global user.name "jenkins-bot"
git config --global user.email "jenkins-bot@users.noreply.github.com"
git config --global http.proxy "${TANQI_HTTPS_PROXY}"

git clone "$DEPLOYMENT_REPO" deployment-repo

cd deployment-repo

sed -i "s|  tag:.*|  tag: \"${TAG_NAME}\"|" "apps/${PACKAGE_NAME}/values.yaml"

git add "apps/${PACKAGE_NAME}/values.yaml"
git commit -m "chore: update ${PACKAGE_NAME} image tag to ${TAG_NAME}"
git push
