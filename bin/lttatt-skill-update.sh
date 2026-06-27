#!/usr/bin/env bash
set -euo pipefail

echo "功能介绍："
echo "  更新 lttatt-skill 仓库"
echo

REPO_DIR="$HOME/Workspaces/VsCode/lttatt-skill"

if [[ ! -d "$REPO_DIR" ]]; then
  echo "目录不存在：$REPO_DIR"
  exit 1
fi

echo "进入仓库目录：$REPO_DIR"
cd "$REPO_DIR"

echo "拉取 origin/master..."
git pull origin master

echo
echo "完成。"
