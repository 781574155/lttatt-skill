#!/usr/bin/env bash
set -euo pipefail

BASE_BRANCH="master"
REMOTE="origin"
CONFIG_FILE="${PLANE_CONFIG_FILE:-$HOME/.plane}"
DEFAULT_PLANE_SERVER="https://plane.openai36.com"

die() {
  echo "错误：$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null || die "缺少必需命令：$1"
}

usage() {
  echo "用法：$(basename "$0") [--clean]"
  echo
  echo "  --clean    删除Plane配置文件：$CONFIG_FILE"
}

clean_plane_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    rm -f "$CONFIG_FILE"
    echo "已删除Plane配置文件：$CONFIG_FILE"
  else
    echo "Plane 配置文件不存在，无需清理：$CONFIG_FILE"
  fi
}

normalize_server() {
  local server="$1"
  server="${server%/}"

  if [[ ! "$server" =~ ^https?:// ]]; then
    server="https://$server"
  fi

  printf '%s\n' "$server"
}

save_plane_config() {
  {
    printf 'export PLANE_SERVER=%q\n' "$PLANE_SERVER"
    printf 'export PLANE_PAT=%q\n' "$PLANE_PAT"
    printf 'export PLANE_WORKSPACE=%q\n' "$PLANE_WORKSPACE"
  } >"$CONFIG_FILE"

  chmod 600 "$CONFIG_FILE" 2>/dev/null || true
}

prompt_plane_config_if_missing() {
  local changed=0

  if [[ -z "${PLANE_SERVER:-}" ]]; then
    read -rp "请输入Plane域名[默认值：${DEFAULT_PLANE_SERVER}]：" PLANE_SERVER
    PLANE_SERVER="${PLANE_SERVER:-$DEFAULT_PLANE_SERVER}"
    PLANE_SERVER=$(normalize_server "$PLANE_SERVER")
    changed=1
  else
    PLANE_SERVER=$(normalize_server "$PLANE_SERVER")
  fi

  if [[ -z "${PLANE_PAT:-}" ]]; then
    while [[ -z "${PLANE_PAT:-}" ]]; do
      read -rsp "请输入Plane个人访问令牌（Personal Access Token）：" PLANE_PAT
      echo
    done
    changed=1
  fi

  if [[ -z "${PLANE_WORKSPACE:-}" ]]; then
    while [[ -z "${PLANE_WORKSPACE:-}" ]]; do
      read -rp "请输入Plane工作空间标识（打开Plane，如果浏览器地址为 https://plane.openai36.com/qsyy/....，则工作空间标识为 qsyy）：" PLANE_WORKSPACE
    done
    changed=1
  fi

  if [[ "$changed" -eq 1 || ! -f "$CONFIG_FILE" ]]; then
    save_plane_config
    echo "已保存Plane配置到 $CONFIG_FILE"
  fi
}

load_plane_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "未找到 $CONFIG_FILE，需要配置 Plane。"
    prompt_plane_config_if_missing
  fi

  # shellcheck source=/dev/null
  source "$CONFIG_FILE"

  prompt_plane_config_if_missing
}

json_field() {
  local file="$1"
  local field="$2"

  if command -v jq >/dev/null; then
    jq -r --arg field "$field" '.[$field] // empty' "$file"
    return
  fi

  if command -v python3 >/dev/null; then
    python3 - "$file" "$field" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)

value = data.get(sys.argv[2], "")
print(value if value is not None else "")
PY
    return
  fi

  if command -v python >/dev/null; then
    python - "$file" "$field" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)

value = data.get(sys.argv[2], "")
print(value if value is not None else "")
PY
    return
  fi

  die "缺少 jq、python3 或 python，无法解析PlaneAPI 响应。"
}

fetch_plane_work_item_title() {
  local work_item="$1"
  local tmp_body http_status api_url title

  tmp_body=$(mktemp)
  api_url="${PLANE_SERVER%/}/api/v1/workspaces/${PLANE_WORKSPACE}/work-items/${work_item}/"

  http_status=$(curl -sS -w "%{http_code}" -o "$tmp_body" \
    -H "X-API-Key: $PLANE_PAT" \
    "$api_url") || {
    rm -f "$tmp_body"
    die "调用PlaneAPI 失败。"
  }

  if [[ ! "$http_status" =~ ^2 ]]; then
    echo "Plane API 请求失败，HTTP 状态码：$http_status"
    echo "URL：$api_url"
    echo "响应："
    cat "$tmp_body"
    rm -f "$tmp_body"
    exit 1
  fi

  title=$(json_field "$tmp_body" "name")
  rm -f "$tmp_body"

  [[ -n "$title" ]] || die "Plane API 响应中没有找到工作项标题字段 name。"
  printf '%s\n' "$title"
}

if [[ "$#" -eq 1 && "${1:-}" == "--clean" ]]; then
  clean_plane_config
  exit 0
fi

if [[ "$#" -gt 0 ]]; then
  usage
  exit 1
fi

echo "检查必需命令..."
need_cmd git
need_cmd gh
need_cmd curl

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "当前目录不是 git 仓库。"

echo "检查远程仓库..."
git remote get-url "$REMOTE" >/dev/null || die "未找到远程仓库 '$REMOTE'。"

echo "检查工作区改动..."
if [[ -n "$(git status --porcelain)" ]]; then
  echo "当前状态："
  git status --short
  die "当前目录有未提交的改动，请先提交或暂存。"
fi

echo "切换到 $BASE_BRANCH 分支..."
git switch "$BASE_BRANCH"

echo "同步 $REMOTE/$BASE_BRANCH..."
git fetch "$REMOTE"
git pull --ff-only "$REMOTE" "$BASE_BRANCH"

echo "加载Plane配置..."
load_plane_config

echo
WORK_ITEM=""
while [[ -z "${WORK_ITEM:-}" ]]; do
  read -rp "请输入Plane工作项编号，例如 QSAI-123：" WORK_ITEM
done
WORK_ITEM="${WORK_ITEM^^}"

if [[ ! "$WORK_ITEM" =~ ^[A-Z][A-Z0-9]*-[0-9]+$ ]]; then
  die "工作项编号格式不正确，请使用 QSAI-123 这样的格式。"
fi

BRANCH_NAME="plane/$WORK_ITEM"

if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  die "本地分支已存在：$BRANCH_NAME"
fi

if git ls-remote --exit-code --heads "$REMOTE" "$BRANCH_NAME" >/dev/null 2>&1; then
  die "远程分支已存在：$REMOTE/$BRANCH_NAME"
fi

echo "获取Plane工作项信息..."
WORK_ITEM_TITLE=$(fetch_plane_work_item_title "$WORK_ITEM")

echo "创建分支 $BRANCH_NAME..."
git switch -c "$BRANCH_NAME"

echo "创建空提交..."
git commit --allow-empty -m "$WORK_ITEM_TITLE"

echo "推送分支..."
git push -u "$REMOTE" "$BRANCH_NAME"

echo "创建草稿 PR..."
gh pr create --draft --fill

echo
echo "完成。"
