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
