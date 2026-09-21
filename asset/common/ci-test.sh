#!/bin/bash

# CI测试失败不会回退部署，测试可针对单个测试文件运行
# 运行测试： ./ci-test.sh https://PROJECT_PLACEHOLDER.openai36.com "--very-verbose" e2e/xxxxxx [测试名称]

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

E2E_TEST_BASE_URL=$1

TEST_MODE=${2:-"--test"}
TEST_FILE=${3:-"e2e"}
TEST_NAME=${4:-""}

echo "Testing application at base URL: $E2E_TEST_BASE_URL"
echo "Using mode: $TEST_MODE, file: $TEST_FILE, test: ${TEST_NAME:-all}"

if find e2e -type f -name "*.hurl" -print -quit | grep -q .; then
	if [[ -f "$TEST_FILE" ]]; then
		hurl "${TEST_MODE}" \
			--header "X-Execution-Mode: CI" \
			--report-junit out/e2e-junit.xml \
			--variable base_url="${E2E_TEST_BASE_URL}" \
			--variables-file e2e/vars.env \
			--file-root . \
			"$TEST_FILE"
	elif [[ -d "$TEST_FILE" ]]; then
		if ! find "$TEST_FILE" -type f -name "*.hurl" -print -quit | grep -q .; then
			echo "No .hurl files found in directory: $TEST_FILE"
			exit 1
		fi
		hurl "${TEST_MODE}" \
			--header "X-Execution-Mode: CI" \
			--glob "${TEST_FILE}/**/*.hurl" \
			--report-junit out/e2e-junit.xml \
			--variable base_url="${E2E_TEST_BASE_URL}" \
			--variables-file e2e/vars.env \
			--file-root .
	else
		echo "Invalid TEST_FILE: $TEST_FILE"
		exit 1
	fi
elif find e2e -type f -name "*.ts" -print -quit | grep -q .; then
	PLAYWRIGHT_ARGS=()
	if [[ "$TEST_MODE" == "--very-verbose" ]]; then
		PLAYWRIGHT_ARGS+=("--headed")
		PLAYWRIGHT_SLOW_MO=1000
	fi
	if [[ "${CI:-}" == "true" ]]; then
		PLAYWRIGHT_SLOW_MO=500
	fi
	if [[ -n "$TEST_NAME" ]]; then
		PLAYWRIGHT_ARGS+=("--grep" "$TEST_NAME")
	fi
	if command -v playwright >/dev/null 2>&1; then
		PLAYWRIGHT_COMMAND=(playwright)
	else
		PLAYWRIGHT_COMMAND=(pnpm exec playwright)
	fi
	COLLECT_E2E_COVERAGE="${CI:-false}" PLAYWRIGHT_SLOW_MO=$PLAYWRIGHT_SLOW_MO E2E_TEST_BASE_URL="${E2E_TEST_BASE_URL}" "${PLAYWRIGHT_COMMAND[@]}" test "${PLAYWRIGHT_ARGS[@]}" "${TEST_FILE}"

	if [[ "${CI:-}" == "true" && "${CI_DEFER_COVERAGE_REPORT:-false}" != "true" ]]; then
		bash ./ci-coverage-report.sh
	fi
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
