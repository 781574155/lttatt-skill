#!/usr/bin/env bash
set -euo pipefail

REMOTE="origin"
PR_LIMIT="1000"

PROTECTED_BRANCHES=(
  "master"
  "main"
  "develop"
  "dev"
  "release"
)

die() {
  echo "错误：$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null || die "缺少必需命令：$1"
}

usage() {
  echo "用法：${0##*/}"
}

print_intro() {
  echo "功能介绍："
  echo "  清除远程仓库中已合并或已关闭 PR 对应的分支。"
  echo "  同时清除远程仓库已删除、只存在于本地仓库的分支。"
  echo
}

is_protected_branch() {
  local branch="$1"
  local protected

  for protected in "${PROTECTED_BRANCHES[@]}"; do
    if [[ "$branch" == "$protected" ]]; then
      return 0
    fi
  done

  return 1
}

append_unique() {
  local value="$1"
  local existing

  [[ -n "$value" ]] || return

  for existing in "${UNIQUE_VALUES[@]}"; do
    if [[ "$existing" == "$value" ]]; then
      return
    fi
  done

  UNIQUE_VALUES+=("$value")
}

collect_open_pr_branches() {
  local branch

  UNIQUE_VALUES=()
  while IFS= read -r branch; do
    [[ -n "$branch" ]] || continue
    append_unique "$branch"
  done < <(
    gh pr list \
      --state open \
      --limit "$PR_LIMIT" \
      --json headRefName,isCrossRepository \
      --jq '.[] | select(.isCrossRepository == false) | .headRefName'
  )

  OPEN_PR_BRANCHES=("${UNIQUE_VALUES[@]}")
}

has_open_pr() {
  local branch="$1"
  local open_branch

  for open_branch in "${OPEN_PR_BRANCHES[@]}"; do
    if [[ "$open_branch" == "$branch" ]]; then
      return 0
    fi
  done

  return 1
}

collect_remote_closed_pr_branches() {
  local branch

  UNIQUE_VALUES=()
  while IFS= read -r branch; do
    [[ -n "$branch" ]] || continue
    is_protected_branch "$branch" && continue
    has_open_pr "$branch" && continue
    git show-ref --verify --quiet "refs/remotes/$REMOTE/$branch" || continue
    append_unique "$branch"
  done < <(
    gh pr list \
      --state closed \
      --limit "$PR_LIMIT" \
      --json headRefName,isCrossRepository \
      --jq '.[] | select(.isCrossRepository == false) | .headRefName'
  )

  REMOTE_BRANCHES_TO_DELETE=("${UNIQUE_VALUES[@]}")
}

collect_gone_local_branches() {
  local current_branch branch track

  current_branch=$(git branch --show-current)
  UNIQUE_VALUES=()

  while IFS='|' read -r branch track; do
    [[ "$track" == "[gone]" ]] || continue
    [[ "$branch" != "$current_branch" ]] || continue
    is_protected_branch "$branch" && continue
    append_unique "$branch"
  done < <(git for-each-ref --format='%(refname:short)|%(upstream:track)' refs/heads)

  LOCAL_BRANCHES_TO_DELETE=("${UNIQUE_VALUES[@]}")
}

print_branch_list() {
  local title="$1"
  shift
  local branches=("$@")
  local branch

  echo "$title"
  if [[ "${#branches[@]}" -eq 0 ]]; then
    echo "  无"
    return
  fi

  for branch in "${branches[@]}"; do
    echo "  - $branch"
  done
}

delete_remote_branches() {
  local branch

  for branch in "${REMOTE_BRANCHES_TO_DELETE[@]}"; do
    echo "删除远程分支：$REMOTE/$branch"
    git push "$REMOTE" --delete "$branch"
  done
}

delete_local_branches() {
  local branch

  for branch in "${LOCAL_BRANCHES_TO_DELETE[@]}"; do
    echo "删除本地分支：$branch"
    git branch -D "$branch"
  done
}

if [[ "$#" -gt 0 ]]; then
  usage
  exit 1
fi

print_intro

echo "检查必需命令..."
need_cmd git
need_cmd gh

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "当前目录不是 git 仓库。"

echo "检查远程仓库..."
git remote get-url "$REMOTE" >/dev/null || die "未找到远程仓库 '$REMOTE'。"

echo "同步远程分支并清理已失效的远程引用..."
git fetch "$REMOTE" --prune

echo "读取打开中的 PR 分支..."
collect_open_pr_branches

echo "读取已合并或已关闭的 PR 分支..."
collect_remote_closed_pr_branches

echo "读取只存在于本地的分支..."
collect_gone_local_branches

echo
print_branch_list "将删除的远程分支：" "${REMOTE_BRANCHES_TO_DELETE[@]}"
echo
print_branch_list "将删除的本地分支：" "${LOCAL_BRANCHES_TO_DELETE[@]}"

if [[ "${#REMOTE_BRANCHES_TO_DELETE[@]}" -eq 0 && "${#LOCAL_BRANCHES_TO_DELETE[@]}" -eq 0 ]]; then
  echo
  echo "没有需要清理的分支。"
  exit 0
fi

echo
delete_remote_branches
delete_local_branches

echo
echo "完成。"
