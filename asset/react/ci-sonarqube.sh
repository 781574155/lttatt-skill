#!/bin/bash

set -e

SONAR_TOKEN="$SONAR_AUTH_TOKEN" sonar-scanner-npm \
	-Dsonar.projectKey="$SONAR_PROJECT_KEY" \
	-Dsonar.javascript.lcov.reportPaths="$WORKSPACE/out/coverage/lcov.info"
