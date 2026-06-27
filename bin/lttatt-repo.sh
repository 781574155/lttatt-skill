#!/usr/bin/env bash
set -euo pipefail

print_intro() {
  echo "功能介绍："
  echo "  将 lttatt-skill 的通用项目文件复制到当前项目。"
  echo "  根据当前项目中的 pom.xml、main.py 或 package.json，继续复制 Java、Python 或 React 对应文件。"
  echo
}

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
if [[ "$SCRIPT_SOURCE" != */* ]]; then
  SCRIPT_SOURCE="$(command -v -- "$SCRIPT_SOURCE")"
fi
SCRIPT_DIR="$(cd -- "${SCRIPT_SOURCE%/*}" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ASSET_DIR="$REPO_DIR/asset"
TARGET_DIR="$(pwd)"

usage() {
  echo "用法：${0##*/}"
}

die() {
  echo "错误：$*" >&2
  exit 1
}

check_git_work_tree() {
  command -v git >/dev/null || die "缺少必要命令：git"

  git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    die "当前目录不是 git 仓库，无法设置可执行权限到 Git 索引。"
  }
}

set_copied_shell_files_executable() {
  local source_dir="$1"
  local had_globstar had_nullglob source_file relative_path target_file

  if shopt -q globstar; then
    had_globstar=1
  else
    had_globstar=0
  fi

  if shopt -q nullglob; then
    had_nullglob=1
  else
    had_nullglob=0
  fi

  shopt -s globstar nullglob

  for source_file in "$source_dir"/**/*.sh; do
    relative_path="${source_file#"$source_dir"/}"
    target_file="$TARGET_DIR/$relative_path"

    if [[ -f "$target_file" ]]; then
      echo "设置脚本可执行权限：$relative_path"
      git -C "$TARGET_DIR" update-index --add --chmod=+x -- "$relative_path"
    fi
  done

  if [[ "$had_globstar" -eq 0 ]]; then
    shopt -u globstar
  fi

  if [[ "$had_nullglob" -eq 0 ]]; then
    shopt -u nullglob
  fi
}

copy_template_dir() {
  local source_dir="$1"
  local label="$2"

  [[ -d "$source_dir" ]] || die "模板目录不存在：$source_dir"

  echo "复制 ${label} 文件：$source_dir -> $TARGET_DIR"
  cp -R "$source_dir"/. "$TARGET_DIR"/
  set_copied_shell_files_executable "$source_dir"
}

detect_project_type() {
  local types=()

  [[ -f "$TARGET_DIR/pom.xml" ]] && types+=("java")
  [[ -f "$TARGET_DIR/main.py" ]] && types+=("python")
  [[ -f "$TARGET_DIR/package.json" ]] && types+=("react")

  if [[ "${#types[@]}" -eq 0 ]]; then
    die "无法识别项目类型，请确认当前目录存在 pom.xml、main.py 或 package.json。"
  fi

  if [[ "${#types[@]}" -gt 1 ]]; then
    die "当前目录同时匹配多个项目类型：${types[*]}。请在具体项目目录中执行。"
  fi

  PROJECT_TYPE="${types[0]}"
}

if [[ "$#" -gt 0 ]]; then
  usage
  exit 1
fi

print_intro

[[ -d "$ASSET_DIR/common" ]] || die "通用模板目录不存在：$ASSET_DIR/common"

check_git_work_tree
detect_project_type

echo "当前项目目录：$TARGET_DIR"
echo "识别项目类型：$PROJECT_TYPE"
echo

copy_template_dir "$ASSET_DIR/common" "通用"
copy_template_dir "$ASSET_DIR/$PROJECT_TYPE" "$PROJECT_TYPE"

echo
echo "完成。"
