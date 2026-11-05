#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "用法：${0##*/}"
  echo
  echo "  当前分支的 PR 已合并或关闭时，切换到 master 并执行 git pull origin master。"
  echo "  本地有未提交改动时保持当前分支；所有保持当前分支的情况都会提示原因。"
}

if [[ "$#" -gt 0 ]]; then
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lttatt-common.sh"

lttatt_check_git_remote_prerequisites origin

CURRENT_BRANCH=$(git branch --show-current)
if [[ -z "$CURRENT_BRANCH" ]]; then
  echo "当前处于 detached HEAD 状态，保持当前检出状态，请先切换到一个分支。" >&2
  exit 1
fi

echo "检查本地未提交改动..."
if ! WORKTREE_STATUS=$(git status --porcelain --untracked-files=all); then
  echo "无法检查本地改动，保持当前分支。" >&2
  exit 1
fi

if [[ -n "$WORKTREE_STATUS" ]]; then
  echo "本地存在未提交改动（包括已暂存、未暂存或未跟踪文件），保持当前分支。"
  exit 0
fi

get_pr_state() {
  gh pr list \
    --head "$CURRENT_BRANCH" \
    --state "$1" \
    --limit 1 \
    --json state \
    --jq '.[0].state // empty'
}

echo "检查分支 '$CURRENT_BRANCH' 的 PR 状态..."
# 同一分支可能关联多个 PR，优先保留仍有开放 PR 的分支。
if ! PR_STATE=$(get_pr_state open); then
  echo "查询当前分支的开放 PR 失败，保持当前分支。" >&2
  exit 1
fi
if [[ -z "$PR_STATE" ]]; then
  if ! PR_STATE=$(get_pr_state all); then
    echo "查询当前分支的 PR 历史失败，保持当前分支。" >&2
    exit 1
  fi
fi

case "$PR_STATE" in
  "")
    echo "当前分支没有 PR，保持当前分支。"
    exit 0
    ;;
  OPEN)
    echo "当前分支的 PR 仍处于开放状态，保持当前分支。"
    exit 0
    ;;
  MERGED|CLOSED)
    echo "当前分支的 PR 已合并或关闭（$PR_STATE）。"
    ;;
  *)
    echo "无法识别 PR 状态：$PR_STATE，保持当前分支。" >&2
    exit 1
    ;;
esac

echo "切换到 master 分支..."
if ! git switch master; then
  echo "切换到 master 失败，保持当前分支。" >&2
  exit 1
fi

echo "拉取最新的 origin/master..."
git pull origin master

echo "完成。"
