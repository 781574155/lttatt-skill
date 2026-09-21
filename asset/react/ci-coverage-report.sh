#!/bin/bash

set -e

if ! find out/e2e-coverage/raw -type f -name "*.json" -print -quit | grep -q .; then
	echo "Playwright 未采集到前端覆盖率，请确认部署的是启用覆盖率插桩的测试镜像。"
	exit 1
fi

nyc report \
	--temp-dir out/e2e-coverage/raw \
	--report-dir out/coverage/html \
	--reporter html \
	--reporter lcovonly \
	--reporter text-summary \
	--exclude-after-remap=false

mv out/coverage/html/lcov.info out/coverage/lcov.info

LCOV_REPORT=out/coverage/lcov.info
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
