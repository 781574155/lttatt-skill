#!/bin/bash

set -e

mvn -B \
	org.sonarsource.scanner.maven:sonar-maven-plugin:sonar \
	-Dsonar.projectKey="$SONAR_PROJECT_KEY" \
	-Dsonar.coverage.jacoco.xmlReportPaths="$WORKSPACE/out/coverage/jacoco.xml"
