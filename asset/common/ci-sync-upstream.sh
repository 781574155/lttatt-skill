#!/bin/bash

set -e

CI_SCRIPT_NAME=$(basename "$0")

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

if [[ ${2:-} != --local ]]; then
	CI_SCRIPT_STARTED_SECONDS=$(date +%s)
	CI_SCRIPT_STARTED_AT=$(date '+%Y-%m-%d %H:%M:%S %z')
	echo "CI script ${CI_SCRIPT_NAME} started at: ${CI_SCRIPT_STARTED_AT}"
	trap 'ci_script_log_exit "$?"' EXIT
fi

if [[ $# -lt 1 || $# -gt 2 || -z $1 || $1 == -* || ( $# -eq 2 && $2 != --local ) ]]; then
	echo "Usage: ${CI_SCRIPT_NAME} UPSTREAM_NAME [--local]" >&2
	exit 1
fi

read_upstream_url() {
	jq -er --arg name "$1" '
	first(.upstreams[] | select(.name == $name) | .url | select(type == "string" and length > 0))
	// error("未找到上游 \($name) 的有效 URL")
	| rtrimstr("/")
	' lttatt.json
}

generate_java_client() (
	upstream_name=$1
	if [[ ! $upstream_name =~ ^[a-z][a-z0-9]*(-[a-z][a-z0-9]*)*$ ]]; then
		echo "上游名称 ${upstream_name} 无法转换为 Java 包名" >&2
		exit 1
	fi

	java_client_directory="src/main/java/com/lttatt/client/${upstream_name//-/\/}"

	upstream_url=$(read_upstream_url "$upstream_name")
	openapi_path=$(jq -er --arg name "$upstream_name" '
		first(.upstreams[] | select(.name == $name) | .openapiPath
			| select(type == "string" and startswith("/")))
		// error("未找到上游 \($name) 的有效 OpenAPI 路径")
	' lttatt.json)
	java_package="com.lttatt.client.${upstream_name//-/.}"
	generated_metadata=()
	for metadata in .openapi-generator .openapi-generator-ignore; do
		if [[ ! -e $metadata && ! -L $metadata ]]; then
			generated_metadata+=("$metadata")
		fi
	done
	trap 'rm -rf -- "${generated_metadata[@]}"' EXIT

	rm -rf -- "$java_client_directory"
	mvn --no-transfer-progress org.openapitools:openapi-generator-maven-plugin:generate \
		"-Dopenapi.input=${upstream_url}${openapi_path}" \
		"-Dopenapi.package=${java_package}"

	shopt -s nullglob
	generated_sources=("${java_client_directory}"/*.java "${java_client_directory}/rep/"*.java)
	if ((${#generated_sources[@]} == 0)); then
		echo "上游 ${upstream_name} 未生成 Java 源码" >&2
		exit 1
	fi
)

UPSTREAM_NAME=$1
UPSTREAM_URL=$(read_upstream_url "$UPSTREAM_NAME")
if [[ ${2:-} != --local ]]; then
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
fi

git_paths=()
if [ -f "openapi2ts.config.ts" ]; then
	if [[ ${2:-} != --local ]]; then
		cp -r /openapi2ts/node_modules ./
	fi
	pnpm openapi2ts "${UPSTREAM_NAME}"
	git_paths=("src/http/api/${UPSTREAM_NAME}")
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
	git_paths=("${upstream_directory}/types.py")
elif [ -f "pom.xml" ]; then
	generate_java_client "$UPSTREAM_NAME"
	git_paths=("src/main/java/com/lttatt/client/${UPSTREAM_NAME//-/\/}")
fi

if [[ ${2:-} == --local ]]; then
	exit 0
fi

if ((${#git_paths[@]} > 0)); then
	git add -A -- "${git_paths[@]}"
fi
git diff --cached --quiet && echo "No changes to commit" && exit 0
git commit -m "chore: sync with upstream!"
git push origin "HEAD:${BRANCH_NAME}"
