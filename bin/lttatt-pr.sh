#!/usr/bin/env bash
set -euo pipefail

BASE_BRANCH="master"
REMOTE="origin"

echo "Checking required tools..."
command -v git >/dev/null || { echo "Missing git"; exit 1; }
command -v gh >/dev/null || { echo "Missing GitHub CLI: gh"; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Not inside a git repository."
  exit 1
}

echo "Checking remote..."
git remote get-url "$REMOTE" >/dev/null || {
  echo "Remote '$REMOTE' not found."
  exit 1
}

echo "Checking current branch..."
CURRENT_BRANCH=$(git branch --show-current)

if [[ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]]; then
  echo "Current branch is '$CURRENT_BRANCH', but expected '$BASE_BRANCH'."
  echo "Please switch to '$BASE_BRANCH' first:"
  echo "  git switch $BASE_BRANCH"
  exit 1
fi

echo "Checking working tree changes..."
if git diff --quiet && git diff --cached --quiet; then
  echo "No local changes to commit."
  exit 0
fi

echo
echo "Current status:"
git status --short

echo
read -rp "Enter branch name, e.g. feature/update-login-flow: " BRANCH_NAME

if [[ ! "$BRANCH_NAME" =~ ^[a-z]+/[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "Invalid branch name. Use format: feature/xxx-yyy, fix/xxx-yyy, or chore/xxx-yyy"
  exit 1
fi

if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  echo "Local branch already exists: $BRANCH_NAME"
  exit 1
fi

echo
read -rp "Enter commit message: " COMMIT_MESSAGE

if [[ -z "$COMMIT_MESSAGE" ]]; then
  echo "Commit message cannot be empty."
  exit 1
fi

PR_TITLE="$COMMIT_MESSAGE"

echo
echo "Stashing current changes safely..."
STASH_MSG="auto-stash-before-$BRANCH_NAME-$(date +%Y%m%d%H%M%S)"
git stash push --include-untracked -m "$STASH_MSG"

echo "Fetching latest remote code..."
git fetch "$REMOTE"

echo "Creating new branch from latest $REMOTE/$BASE_BRANCH..."
git switch -c "$BRANCH_NAME" "$REMOTE/$BASE_BRANCH"

echo "Restoring your changes onto the new branch..."
if ! git stash pop; then
  echo
  echo "Conflict or error while applying your changes."
  echo "Please resolve these files manually:"
  git status --short
  echo
  echo "Your stash may still exist. Check with:"
  echo "  git stash list"
  exit 1
fi

echo
echo "Checking status after restoring changes..."
git status --short

echo
echo "Staging all related changes..."
git add -A

if git diff --cached --quiet; then
  echo "No staged changes after applying stash."
  exit 1
fi

echo "Committing..."
git commit -m "$COMMIT_MESSAGE"

echo "Pushing branch..."
git push -u "$REMOTE" "$BRANCH_NAME"

echo "Creating draft pull request..."
gh pr create --draft --fill

echo
echo "Done."

