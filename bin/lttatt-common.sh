#!/usr/bin/env bash

# 一些通用的函数

lttatt_need_cmd() {
  local cmd="$1"
  local label="${2:-$cmd}"

  command -v "$cmd" >/dev/null || {
    echo "缺少必需命令：$label"
    exit 1
  }
}

lttatt_check_git_remote_prerequisites() {
  local remote="${1:-origin}"

  echo "检查必需命令..."
  lttatt_need_cmd git
  lttatt_need_cmd gh "GitHub CLI：gh"

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "当前目录不是 git 仓库。"
    exit 1
  }

  echo "检查远程仓库..."
  git remote get-url "$remote" >/dev/null || {
    echo "未找到远程仓库${remote}。"
    exit 1
  }
}