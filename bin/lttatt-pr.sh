#!/usr/bin/env bash
set -euo pipefail

print_intro() {
  echo "功能介绍："
  echo "  将当前 master 分支上的未提交改动安全转移到新分支，提交后推送，并创建 GitHub 草稿 PR。"
  echo
}

BASE_BRANCH="master"

print_intro

echo "检查必需命令..."
command -v git >/dev/null || { echo "缺少必需命令：git"; exit 1; }
command -v gh >/dev/null || { echo "缺少必需命令：GitHub CLI：gh"; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "当前目录不是 git 仓库。"
  exit 1
}

echo "检查远程仓库..."
git remote get-url origin >/dev/null || {
  echo "未找到远程仓库origin。"
  exit 1
}

echo "检查当前分支..."
CURRENT_BRANCH=$(git branch --show-current)

if [[ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]]; then
  echo "当前分支是 '$CURRENT_BRANCH'，但预期分支是 '$BASE_BRANCH'。"
  echo "请先切换到 '$BASE_BRANCH'："
  echo "  git switch $BASE_BRANCH"
  exit 1
fi

echo "检查工作区改动..."
if git diff --quiet && git diff --cached --quiet; then
  echo "没有需要提交的本地改动。"
  exit 0
fi

echo
echo "当前状态："
git status --short

echo
DEFAULT_BRANCH_NAME="choco/p-$(date +%Y%m%d%H%M%S)"
read -rp "请输入分支名，以feature/、fix/、chore/开头[默认值：$DEFAULT_BRANCH_NAME]：" BRANCH_NAME
BRANCH_NAME="${BRANCH_NAME:-$DEFAULT_BRANCH_NAME}"

if [[ ! "$BRANCH_NAME" =~ ^[a-z]+/[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "分支名格式不正确，请使用 feature/xxx-yyy、fix/xxx-yyy 或 chore/xxx-yyy 这样的格式。"
  exit 1
fi

if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  echo "本地分支已存在：$BRANCH_NAME"
  exit 1
fi

echo
read -rp "请输入提交信息[默认值：p]：" COMMIT_MESSAGE
COMMIT_MESSAGE="${COMMIT_MESSAGE:-p}"

if [[ -z "$COMMIT_MESSAGE" ]]; then
  echo "提交信息不能为空。"
  exit 1
fi

echo
echo "安全暂存当前改动..."
STASH_MSG="auto-stash-before-$BRANCH_NAME-$(date +%Y%m%d%H%M%S)"
git stash push --include-untracked -m "$STASH_MSG"

echo "获取最新远程代码..."
git fetch origin

echo "基于最新的 origin/$BASE_BRANCH 创建新分支..."
git switch -c "$BRANCH_NAME" "origin/$BASE_BRANCH"

echo "将你的改动恢复到新分支..."
if ! git stash pop; then
  echo
  echo "恢复改动时发生冲突或错误。"
  echo "请手动处理以下文件："
  git status --short
  echo
  echo "你的 stash 可能仍然存在，可用以下命令查看："
  echo "  git stash list"
  exit 1
fi

echo
echo "检查恢复改动后的状态..."
git status --short

echo
echo "暂存所有相关改动..."
git add -A

if git diff --cached --quiet; then
  echo "恢复 stash 后没有已暂存的改动。"
  exit 1
fi

echo "提交改动..."
git commit -m "$COMMIT_MESSAGE"

echo "推送分支..."
git push -u origin "$BRANCH_NAME"

echo "创建草稿 PR..."
gh pr create --draft --fill

echo
echo "完成。"
