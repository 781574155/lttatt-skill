#!/bin/bash

# CI测试失败不会回退部署，测试可针对单个测试文件运行
# 运行单个文件测试： ./ci-test.sh https://PROJECT_PLACEHOLDER.openai36.com "--very-verbose" e2e/xxxxxx

set -e

CI_SCRIPT_NAME=$(basename "$0")
CI_SCRIPT_STARTED_SECONDS=$(date +%s)
CI_SCRIPT_STARTED_AT=$(date '+%Y-%m-%d %H:%M:%S %z')
echo "CI script ${CI_SCRIPT_NAME} started at: ${CI_SCRIPT_STARTED_AT}"
trap 'CI_SCRIPT_EXIT_CODE=$?; CI_SCRIPT_ENDED_SECONDS=$(date +%s); CI_SCRIPT_ENDED_AT=$(date "+%Y-%m-%d %H:%M:%S %z"); CI_SCRIPT_ELAPSED_SECONDS=$((CI_SCRIPT_ENDED_SECONDS - CI_SCRIPT_STARTED_SECONDS)); echo "CI script ${CI_SCRIPT_NAME} ended at: ${CI_SCRIPT_ENDED_AT}"; echo "CI script ${CI_SCRIPT_NAME} elapsed seconds: ${CI_SCRIPT_ELAPSED_SECONDS}"; exit "${CI_SCRIPT_EXIT_CODE}"' EXIT

E2E_TEST_BASE_URL=$1

TEST_MODE=${2:-"--test"}
TEST_FILE=${3:-"e2e"}

echo "Testing application at base URL: $E2E_TEST_BASE_URL"
echo "Using mode: $TEST_MODE, file: $TEST_FILE"

run_hurl_file() {
	local file="$1"
	echo "----------------------------------------"
	echo "Running Hurl test: $file"
	echo "----------------------------------------"

	hurl "${TEST_MODE}" \
		--jobs 1 \
		--report-junit out/e2e-junit.xml \
		--variable base_url="${E2E_TEST_BASE_URL}" \
		--variable timestamp="$(date +%s)" \
		--variables-file e2e/vars.env \
		--file-root . \
		"$file"
}

if find e2e -type f -name "*.hurl" -print -quit | grep -q .; then
	if [[ -f "$TEST_FILE" ]]; then
		run_hurl_file "$TEST_FILE"
	elif [[ -d "$TEST_FILE" ]]; then
		mapfile -t files < <(find "$TEST_FILE" -type f -name "*.hurl" | sort)
		if [[ ${#files[@]} -eq 0 ]]; then
			echo "No .hurl files found in directory: $TEST_FILE"
			exit 1
		fi
		for file in "${files[@]}"; do
			run_hurl_file "$file"
		done
	else
		echo "Invalid TEST_FILE: $TEST_FILE"
		exit 1
	fi
elif find e2e -type f -name "*.ts" -print -quit | grep -q .; then
	PLAYWRIGHT_ARGS=""
	if [[ "$TEST_MODE" == "--very-verbose" ]]; then
		PLAYWRIGHT_ARGS="--headed"
		PLAYWRIGHT_SLOW_MO=1000
	fi
	PLAYWRIGHT_SLOW_MO=$PLAYWRIGHT_SLOW_MO E2E_TEST_BASE_URL="${E2E_TEST_BASE_URL}" pnpm exec playwright test ${PLAYWRIGHT_ARGS} "${TEST_FILE}" --workers=1
else
	echo "No test files found in the e2e directory."
	mkdir -p out
	cat >out/e2e-junit.xml <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="E2E Tests" tests="0" failures="0">
	<testcase classname="E2E Tests" name="No tests found" />
  </testsuite>
</testsuites>
EOL
fi

echo "E2E tests completed successfully."
