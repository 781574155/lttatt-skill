#!/bin/bash

set -e

rm -rf out/coverage/html out/coverage/coverage-report
tar -xzf out/coverage/coverage-report.tar.gz -C out/coverage
mv out/coverage/coverage-report out/coverage/html

if ! grep -Eq 'lines-covered="[1-9][0-9]*"' out/coverage/coverage.xml; then
	echo "Coverage.py 未采集到任何 e2e 行覆盖率"
	exit 1
fi
