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

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
	echo "Usage: ${CI_SCRIPT_NAME} UPSTREAM_NAME" >&2
	exit 1
fi
UPSTREAM_NAME=$1

UPSTREAM_URL=$(jq -er --arg name "${UPSTREAM_NAME}" '
first(.upstreams[] | select(.name == $name) | .url | select(type == "string" and length > 0))
// error("未找到上游 \($name) 的有效 URL")
| rtrimstr("/")
' lttatt.json)

DEPLOYMENT_INFO=$(curl -sf -X GET "${UPSTREAM_URL}/backend-api/pub/deployment-info")
DEPLOYED_VERSION=$(printf '%s' "${DEPLOYMENT_INFO}" | jq -r '.data.version // ""')
echo "Upstream ${UPSTREAM_NAME} deployed version: ${DEPLOYED_VERSION}"
if [[ "${DEPLOYED_VERSION}" != master* ]]; then
	echo "Upstream ${UPSTREAM_NAME} deployed version does not start with master, abort packaging."
	exit 75
fi

git config user.name "jenkins-bot"
git config user.email "jenkins-bot@users.noreply.github.com"
git config http.proxy "${TANQI_HTTPS_PROXY}"

if [ -f "openapi2ts.config.ts" ]; then
	cp -r /openapi2ts/node_modules ./
	pnpm openapi2ts "${UPSTREAM_NAME}"
	git add "src/http/api/${UPSTREAM_NAME}"
elif [ -f "requirements.txt" ]; then
	upstream_directory="tanqi/mq/${UPSTREAM_NAME//-/_}"
	mkdir -p "${upstream_directory}"
	datamodel-codegen \
		--url "${UPSTREAM_URL}/backend-api/v3/api-docs/mq-types" \
		--input-file-type openapi \
		--formatters ruff-check ruff-format \
		--use-subclass-enum \
		--no-use-union-operator \
		--disable-timestamp \
		--output-model-type pydantic_v2.BaseModel \
		--output "${upstream_directory}/types.py"
	git add "${upstream_directory}/types.py"
fi

git diff --cached --quiet && echo "No changes to commit" && exit 0
git commit -m "chore: sync with upstream!"
git push origin "HEAD:${BRANCH_NAME}"
