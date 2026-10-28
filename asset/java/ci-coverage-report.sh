#!/bin/bash

set -e

test -s out/coverage/jacoco.exec
java -jar target/jacoco/jacococli.jar report out/coverage/jacoco.exec \
	--name "E2E Coverage" \
	--classfiles target/classes \
	--sourcefiles src/main/java \
	--xml out/coverage/jacoco.xml \
	--html out/coverage/html

if ! grep -Eq '<counter type="LINE" missed="[0-9]+" covered="[0-9]+"' out/coverage/jacoco.xml; then
	echo "JaCoCo 报告缺少行覆盖率统计"
	exit 1
fi

LINE_COUNTER=$(grep -o '<counter type="LINE"[^>]*/>' out/coverage/jacoco.xml | tail -1)
echo "$LINE_COUNTER"
if [[ "$LINE_COUNTER" == *'covered="0"'* ]]; then
	echo "e2e 未覆盖任何项目代码，行覆盖率为 0%。"
fi
