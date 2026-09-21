#!/bin/bash

set -e

sonar-scanner-npm \
	-Dsonar.projectKey="$SONAR_PROJECT_KEY" \
	-Dsonar.python.coverage.reportPaths="$WORKSPACE/out/coverage/coverage.xml"
