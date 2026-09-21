#!/bin/bash

set -e

test -s out/coverage/jacoco.exec
java -jar drama-backend-app/target/jacoco/jacococli.jar report out/coverage/jacoco.exec \
	--name "E2E Coverage" \
	--classfiles drama-backend-common/target/classes \
	--classfiles drama-backend-notify/target/classes \
	--classfiles drama-backend-user/target/classes \
	--classfiles drama-backend-file/target/classes \
	--classfiles drama-backend-app/target/classes \
	--sourcefiles drama-backend-common/src/main/java \
	--sourcefiles drama-backend-notify/src/main/java \
	--sourcefiles drama-backend-user/src/main/java \
	--sourcefiles drama-backend-file/src/main/java \
	--sourcefiles drama-backend-app/src/main/java \
	--xml out/coverage/jacoco.xml \
	--html out/coverage/html

if ! grep -Eq '<counter type="LINE" missed="[0-9]+" covered="[1-9][0-9]*"' out/coverage/jacoco.xml; then
	echo "JaCoCo 未采集到任何 e2e 行覆盖率"
	exit 1
fi
grep -o '<counter type="LINE"[^>]*/>' out/coverage/jacoco.xml | tail -1
