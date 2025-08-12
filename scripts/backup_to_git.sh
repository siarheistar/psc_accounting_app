#!/usr/bin/env bash
set -euo pipefail

# Backup all local changes to the current branch with a timestamped commit message.
# Usage:
#   scripts/backup_to_git.sh                # auto message
#   scripts/backup_to_git.sh -m "Your msg"  # custom message

msg=""
while getopts ":m:" opt; do
  case $opt in
    m) msg="$OPTARG" ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 2 ;;
  esac
done

if ! command -v git >/dev/null 2>&1; then
  echo "git not found in PATH" >&2
  exit 1
fi

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "${repo_root}" ]]; then
  echo "Not inside a git repository" >&2
  exit 1
fi

cd "${repo_root}"

branch=$(git rev-parse --abbrev-ref HEAD)
remote="origin"

# Construct default message with timestamp if not provided
if [[ -z "${msg}" ]]; then
  timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
  msg="Backup: ${timestamp}"
fi

echo "Repo: ${repo_root}"
echo "Branch: ${branch}"
echo "Remote: ${remote}"

# Show short status and proceed
git status --short

# Stage all changes (including new/removed files)
git add -A

# Commit if there is anything to commit
if git diff --cached --quiet; then
  echo "No staged changes to commit. Pushing latest HEAD..."
else
  git commit -m "${msg}"
fi

# Ensure upstream exists
if ! git rev-parse --symbolic-full-name --abbrev-ref "@{u}" >/dev/null 2>&1; then
  echo "Setting upstream to ${remote}/${branch}"
  git push -u "${remote}" "${branch}"
else
  git push "${remote}" "${branch}"
fi

echo "✅ Backup complete."
