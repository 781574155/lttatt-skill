#!/bin/bash

set -e

CI_SCRIPT_NAME=$(basename "$0")
CI_SCRIPT_STARTED_SECONDS=$(date +%s)
CI_SCRIPT_STARTED_AT=$(date '+%Y-%m-%d %H:%M:%S %z')
echo "CI script ${CI_SCRIPT_NAME} started at: ${CI_SCRIPT_STARTED_AT}"
trap 'CI_SCRIPT_EXIT_CODE=$?; CI_SCRIPT_ENDED_SECONDS=$(date +%s); CI_SCRIPT_ENDED_AT=$(date "+%Y-%m-%d %H:%M:%S %z"); CI_SCRIPT_ELAPSED_SECONDS=$((CI_SCRIPT_ENDED_SECONDS - CI_SCRIPT_STARTED_SECONDS)); echo "CI script ${CI_SCRIPT_NAME} ended at: ${CI_SCRIPT_ENDED_AT}"; echo "CI script ${CI_SCRIPT_NAME} elapsed seconds: ${CI_SCRIPT_ELAPSED_SECONDS}"; exit "${CI_SCRIPT_EXIT_CODE}"' EXIT

if [ -f ".env.lttatt" ]; then
	set -a
	. ./.env.lttatt
	set +a
fi

: "${UPSTREAM:?Missing UPSTREAM in .env.lttatt}"
UPSTREAM="${UPSTREAM%/}"

DEPLOYMENT_INFO=$(curl -sf -X GET "${UPSTREAM}/backend-api/pub/deployment-info")
DEPLOYED_VERSION=$(printf '%s' "${DEPLOYMENT_INFO}" | jq -r '.data.version // ""')
echo "Upstream deployed version: ${DEPLOYED_VERSION}"
if [[ "${DEPLOYED_VERSION}" != master* ]]; then
	echo "Upstream deployed version does not start with master, abort packaging."
	exit 75
fi

git config user.name "jenkins-bot"
git config user.email "jenkins-bot@users.noreply.github.com"
git config http.proxy "${TANQI_HTTPS_PROXY}"

if [ -f "openapi2ts.config.ts" ]; then
	cp -r /openapi2ts/node_modules ./
	pnpm openapi2ts
	git add src/http/api
elif [ -f "requirements.txt" ]; then
	mkdir -p tanqi/mq
	datamodel-codegen \
		--url "${UPSTREAM}/backend-api/v3/api-docs/mq-types" \
		--input-file-type openapi \
		--formatters ruff-check ruff-format \
		--use-subclass-enum \
		--no-use-union-operator \
		--disable-timestamp \
		--output-model-type pydantic_v2.BaseModel \
		--output tanqi/mq/types.py
	git add tanqi/mq/types.py
fi

git diff --cached --quiet && echo "No changes to commit" && exit 0
git commit -m "chore: sync with upstream!"
git push origin "HEAD:${BRANCH_NAME}"
