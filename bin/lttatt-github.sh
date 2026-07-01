#!/usr/bin/env bash
set -euo pipefail

print_intro() {
  echo "功能介绍："
  echo "  从配置文件读取 GitHub 仓库配置和标签名，并应用到当前 GitHub 仓库。"
  echo "  如果要清空当前仓库标签，请使用 --clean 参数。"
  echo
}

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
if [[ "$SCRIPT_SOURCE" != */* ]]; then
  SCRIPT_SOURCE="$(command -v -- "$SCRIPT_SOURCE")"
fi
SCRIPT_DIR="$(cd -- "${SCRIPT_SOURCE%/*}" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# 加载公共检测方法：lttatt_check_git_remote_prerequisites
source "$SCRIPT_DIR/lttatt-common.sh"

REMOTE="origin"
CONFIG_FILE="$REPO_DIR/config/github.conf"
LABEL_COLOR="9DD2B8"
CLEAN_LABELS=0
AUTO_DELETE_BRANCH_ON_MERGE="false"
AUTO_MERGE_BRANCH="false"
CONFIG_LABELS=()
EXISTING_LABELS=()

usage() {
  echo "用法：${0##*/} [--clean] [--config 配置文件]"
  echo
  echo "  --clean     先删除当前仓库所有标签，再按配置重新创建"
  echo "  --config    指定 GitHub 配置文件，默认值：$CONFIG_FILE"
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --clean)
        CLEAN_LABELS=1
        shift
        ;;
      --config)
        if [[ -z "${2:-}" ]]; then
          echo "--config 需要指定配置文件。"
          exit 1
        fi
        CONFIG_FILE="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage
        exit 1
        ;;
    esac
  done
}

validate_bool() {
  local key="$1"
  local value="$2"

  if [[ "$value" != "true" && "$value" != "false" ]]; then
    echo "配置 ${key} 的值不正确：$value。请使用 true 或 false。"
    exit 1
  fi
}

validate_label() {
  local line_no="$1"
  local name="$2"

  if [[ -z "$name" ]]; then
    echo "配置第 ${line_no} 行缺少标签名。"
    exit 1
  fi
}

load_config() {
  local line line_no section key value

  line_no=0
  section="github"
  CONFIG_LABELS=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    line="${line%$'\r'}"

    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    case "$line" in
      "[labels]")
        section="labels"
        continue
        ;;
    esac

    if [[ "$section" == "labels" ]]; then
      if [[ "$line" == *$'\t'* ]]; then
        echo "配置第 ${line_no} 行字段过多，请每行只填写一个标签名。"
        exit 1
      fi
      validate_label "$line_no" "$line"
      CONFIG_LABELS+=("$line")
      continue
    fi

    if [[ "$line" != *=* ]]; then
      echo "配置第 ${line_no} 行格式不正确：$line"
      exit 1
    fi

    key="${line%%=*}"
    value="${line#*=}"

    case "$key" in
      AUTO_DELETE_BRANCH_ON_MERGE)
        validate_bool "$key" "$value"
        AUTO_DELETE_BRANCH_ON_MERGE="$value"
        ;;
      AUTO_MERGE_BRANCH)
        validate_bool "$key" "$value"
        AUTO_MERGE_BRANCH="$value"
        ;;
      *)
        echo "配置第 ${line_no} 行包含未知配置项：$key"
        exit 1
        ;;
    esac
  done < "$CONFIG_FILE"

  if [[ "${#CONFIG_LABELS[@]}" -eq 0 ]]; then
    echo "配置文件中没有可同步的标签：$CONFIG_FILE"
    exit 1
  fi
}

apply_repo_settings() {
  local repo="$1"

  echo "应用仓库配置..."
  echo "合并 PR 后自动删除分支：$AUTO_DELETE_BRANCH_ON_MERGE"
  echo "允许 PR 自动合并：$AUTO_MERGE_BRANCH"

  gh api \
    -X PATCH \
    "repos/$repo" \
    -F "delete_branch_on_merge=$AUTO_DELETE_BRANCH_ON_MERGE" \
    -F "allow_auto_merge=$AUTO_MERGE_BRANCH" >/dev/null
}

collect_existing_labels() {
  local repo="$1"
  local label

  EXISTING_LABELS=()
  while IFS= read -r label || [[ -n "$label" ]]; do
    [[ -n "$label" ]] || continue
    EXISTING_LABELS+=("$label")
  done < <(gh label list --repo "$repo" --limit 1000 --json name --jq '.[].name')
}

label_exists() {
  local name="$1"
  local existing

  for existing in "${EXISTING_LABELS[@]}"; do
    if [[ "$existing" == "$name" ]]; then
      return 0
    fi
  done

  return 1
}

confirm_clean_author_labels() {
  local label answer
  local author_labels=()

  for label in "${EXISTING_LABELS[@]}"; do
    if [[ "$label" == author:* ]]; then
      author_labels+=("$label")
    fi
  done

  if [[ "${#author_labels[@]}" -eq 0 ]]; then
    return 0
  fi

  echo "检测到当前仓库包含 author: 开头的标签："
  for label in "${author_labels[@]}"; do
    echo "  $label"
  done
  echo "标签删除后，原来PR和Issue中的这些标签将被移除。"
  read -r -p "请再次确认是否继续删除所有标签？输入 yes 继续：" answer

  if [[ "$answer" != "yes" ]]; then
    echo "已取消清空标签。"
    exit 1
  fi
}

clean_labels() {
  local repo="$1"
  local label label_count

  label_count=0

  collect_existing_labels "$repo"
  confirm_clean_author_labels

  echo "清空当前仓库标签..."
  for label in "${EXISTING_LABELS[@]}"; do
    echo "删除标签：$label"
    gh label delete "$label" \
      --repo "$repo" \
      --yes >/dev/null

    label_count=$((label_count + 1))
  done

  echo "已删除 ${label_count} 个 GitHub 标签。"
  echo
}

sync_labels() {
  local repo="$1"
  local name configured_count created_count skipped_count

  configured_count=0
  created_count=0
  skipped_count=0

  collect_existing_labels "$repo"

  for name in "${CONFIG_LABELS[@]}"; do
    configured_count=$((configured_count + 1))

    if label_exists "$name"; then
      echo "标签已存在，跳过：$name"
      skipped_count=$((skipped_count + 1))
      continue
    fi

    echo "创建标签：$name"
    gh label create "$name" \
      --repo "$repo" \
      --color "$LABEL_COLOR" >/dev/null

    EXISTING_LABELS+=("$name")
    created_count=$((created_count + 1))
  done

  echo
  echo "已处理 ${configured_count} 个 GitHub 标签，创建 ${created_count} 个，跳过 ${skipped_count} 个。"
}

parse_args "$@"
print_intro

lttatt_check_git_remote_prerequisites "$REMOTE"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "未找到 GitHub 配置文件：$CONFIG_FILE"
  exit 1
fi

if [[ ! -r "$CONFIG_FILE" ]]; then
  echo "无法读取 GitHub 配置文件：$CONFIG_FILE"
  exit 1
fi

load_config

echo "读取 GitHub 仓库..."
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')

if [[ -z "$REPO" ]]; then
  echo "无法识别当前 GitHub 仓库。"
  exit 1
fi

echo "目标仓库：$REPO"
echo "读取 GitHub 配置：$CONFIG_FILE"
echo "统一标签颜色：#$LABEL_COLOR"

apply_repo_settings "$REPO"

if [[ "$CLEAN_LABELS" -eq 1 ]]; then
  clean_labels "$REPO"
fi

sync_labels "$REPO"

echo "完成。"
