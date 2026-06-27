#!/bin/bash

set -e

TAG_NAME=$1
DEPLOYMENT_REPO=$2
PACKAGE_NAME=$3

git config --global user.name "jenkins-bot"
git config --global user.email "jenkins-bot@users.noreply.github.com"
git config --global http.proxy "${TANQI_HTTPS_PROXY}"

git clone "$DEPLOYMENT_REPO" deployment-repo

cd deployment-repo

sed -i "s|  tag:.*|  tag: \"${TAG_NAME}\"|" "apps/${PACKAGE_NAME}/values.yaml"

git add "apps/${PACKAGE_NAME}/values.yaml"
git commit -m "chore: update ${PACKAGE_NAME} image tag to ${TAG_NAME}"
git push
