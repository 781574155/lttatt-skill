#!/usr/bin/env bash
# Add all organization members into a specified GitHub Team (gh CLI only)
# Windows/Git-Bash friendly: avoid leading slash in gh api endpoints
#
# Usage:
#   ./add_all_org_members_to_team.sh -o ORG -t TEAM_SLUG [--role member|maintainer] [--dry-run] [--concurrency N]
#
# Example:
#   ./add_all_org_members_to_team.sh -o gtja -t team-7 --dry-run
set -euo pipefail

ORG=""
TEAM_SLUG=""
ROLE="member"
DRY_RUN=0
CONCURRENCY=4
RETRY=3
SLEEP_BETWEEN=0.2

print_usage() {
  cat <<EOF
Usage: $0 -o ORG -t TEAM_SLUG [--role member|maintainer] [--dry-run] [--concurrency N]
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--org) ORG="$2"; shift 2;;
    -t|--team|--team-slug) TEAM_SLUG="$2"; shift 2;;
    --role) ROLE="$2"; shift 2;;
    --dry-run) DRY_RUN=1; shift;;
    --concurrency) CONCURRENCY="$2"; shift 2;;
    -h|--help) print_usage; exit 0;;
    *) echo "Unknown arg: $1"; print_usage; exit 1;;
  esac
done

if [[ -z "$ORG" || -z "$TEAM_SLUG" ]]; then
  echo "Error: org and team-slug are required."
  print_usage
  exit 1
fi

if [[ "$ROLE" != "member" && "$ROLE" != "maintainer" ]]; then
  echo "Error: --role must be 'member' or 'maintainer'"
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not found. Install from https://github.com/cli/cli" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh is not authenticated. Run 'gh auth login' first." >&2
  exit 1
fi

# Fetch org members (login names), using gh pagination
# NOTE: endpoint does NOT start with a leading slash to avoid path rewriting on Windows/MSYS
get_org_members() {
  gh api --paginate "orgs/${ORG}/members" --jq '.[].login'
}

# Add a single member via gh API with retries; endpoint has no leading slash
add_member() {
  local user="$1"
  local role="$2"
  local attempt=0

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY-RUN] gh api --method PUT orgs/${ORG}/teams/${TEAM_SLUG}/memberships/${user} -f role=${role}"
    return 0
  fi

  while (( attempt < RETRY )); do
    if gh api --method PUT "orgs/${ORG}/teams/${TEAM_SLUG}/memberships/${user}" -f role="${role}" >/dev/null 2>&1; then
      echo "OK: ${user}"
      return 0
    else
      ((attempt++))
      echo "WARN: failed to add ${user} (attempt ${attempt}), retrying..." >&2
      sleep $((attempt * 1))
    fi
  done

  echo "ERROR: giving up on ${user}" >&2
  return 1
}

export -f add_member
export ORG TEAM_SLUG DRY_RUN RETRY SLEEP_BETWEEN

echo "Start: org=${ORG}, team=${TEAM_SLUG}, role=${ROLE}, dry-run=${DRY_RUN}, concurrency=${CONCURRENCY}"

members=$(get_org_members) || { echo "Failed to fetch members."; exit 1; }

if [[ -z "$members" ]]; then
  echo "No members found in org ${ORG}."
  exit 0
fi

count=$(echo "$members" | wc -l | tr -d ' ')
echo "Found ${count} members. Adding to team..."

# If xargs or bash -lc behave oddly on your shell, you can set CONCURRENCY=1 to run sequentially.
echo "$members" | xargs -n1 -P "$CONCURRENCY" -I {} bash -lc 'add_member "{}" "'"${ROLE}"'" && sleep '"${SLEEP_BETWEEN}"

echo "Done."
