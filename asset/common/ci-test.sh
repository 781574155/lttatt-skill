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
	COLLECT_E2E_COVERAGE="${CI:-false}" PLAYWRIGHT_SLOW_MO=$PLAYWRIGHT_SLOW_MO E2E_TEST_BASE_URL="${E2E_TEST_BASE_URL}" pnpm exec playwright test "${PLAYWRIGHT_ARGS[@]}" "${TEST_FILE}"

	if [[ "${CI:-}" == "true" ]]; then
		if ! find out/e2e-coverage/raw -type f -name "*.json" -print -quit | grep -q .; then
			echo "Playwright 未采集到前端覆盖率，请确认部署的是启用覆盖率插桩的测试镜像。"
			exit 1
		fi

		pnpm exec nyc report \
			--temp-dir out/e2e-coverage/raw \
			--report-dir out/e2e-coverage-report \
			--reporter html \
			--reporter lcovonly \
			--reporter text-summary \
			--exclude-after-remap=false

		LCOV_REPORT=out/e2e-coverage-report/lcov.info
		LCOV_NORMALIZED_REPORT=${LCOV_REPORT}.normalized
		awk '
		/^SF:/ {
			source_path = substr($0, 4)
			gsub(/\\\\/, "/", source_path)
			sub(/^.*\/src\//, "src/", source_path)
			print "SF:" source_path
			next
		}
		{ print }
		' "$LCOV_REPORT" >"$LCOV_NORMALIZED_REPORT"
		mv "$LCOV_NORMALIZED_REPORT" "$LCOV_REPORT"

		test -s "$LCOV_REPORT"
		LCOV_PATH_INVALID=false
		while IFS= read -r source_path; do
			if [[ ! -f "$source_path" ]]; then
				echo "LCOV 源文件路径无法映射到工作区: $source_path"
				LCOV_PATH_INVALID=true
			fi
		done < <(sed -n 's/^SF://p' "$LCOV_REPORT" | sort -u)
		if [[ "$LCOV_PATH_INVALID" == "true" ]]; then
			exit 1
		fi

		if ! awk -F '[:,]' '$1 == "DA" && $3 + 0 > 0 { found = 1 } END { exit found ? 0 : 1 }' "$LCOV_REPORT"; then
			echo "LCOV 报告未包含任何已覆盖行。"
			exit 1
		fi
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
