#!/bin/bash

set -e

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
		--url https://drama-backend.openai36.com/backend-api/v3/api-docs/mq-types \
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
