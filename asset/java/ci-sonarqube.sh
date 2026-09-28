#!/bin/bash

set -e

mvn -B \
	org.sonarsource.scanner.maven:sonar-maven-plugin:sonar \
	-Dsonar.projectKey="$SONAR_PROJECT_KEY" \
	-Dsonar.scm.disabled=true \
	-Dsonar.coverage.jacoco.aggregateXmlReportPaths="$WORKSPACE/out/coverage/jacoco.xml"
