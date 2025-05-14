#!/bin/zsh

# Script to force push multiple repositories to GitHub
# Helps manage batch updates across multiple related repositories
# Usage: ./batch-force-push-to-github.sh [path/to/root/directory] [--no-backup]

# Set defaults
ROOT_DIR=${1:-$(pwd)}
BACKUP_FLAG=""
if [[ "$2" == "--no-backup" ]]; then
  BACKUP_FLAG="--skip-backup"
fi

echo "🚀 Batch Force Push to GitHub 🚀"
echo "=================================="
echo ""
echo "This script will force push all git repositories in:"
echo "📁 $ROOT_DIR"
echo ""

# Confirmation
echo "⚠️  WARNING: This will force push ALL repositories found in the directory."
echo "    Force pushing overwrites remote history and cannot be undone."
read "confirm?Are you absolutely sure you want to proceed? (yes/no): "

if [[ "$confirm" != "yes" ]]; then
  echo "❌ Batch force push aborted."
  exit 1
fi

# Find all git repositories in the specified directory
echo "🔍 Finding git repositories..."
REPOS=()
while IFS= read -r repo; do
  REPOS+=("$repo")
done < <(find "$ROOT_DIR" -name ".git" -type d -prune | sed 's/\/.git$//')

REPO_COUNT=${#REPOS[@]}

if [[ $REPO_COUNT -eq 0 ]]; then
  echo "❌ No git repositories found in $ROOT_DIR"
  exit 1
fi

echo "✅ Found $REPO_COUNT repositories to process."
echo ""

# Process each repository
SUCCESS_COUNT=0
FAILED_REPOS=()
SKIPPED_REPOS=()

for repo in "${REPOS[@]}"; do
  REPO_NAME=$(basename "$repo")
  echo "⬆️  Processing: $REPO_NAME"
  echo "    Path: $repo"
  
  # Enter repository
  pushd "$repo" > /dev/null
  
  # Check if there are any changes to push
  if ! git rev-parse --abbrev-ref @{upstream} &>/dev/null; then
    echo "    ⚠️  No upstream branch set. Skipping."
    SKIPPED_REPOS+=("$REPO_NAME (no upstream)")
    popd > /dev/null
    continue
  fi
  
  # Check if there are any commits to push
  git fetch origin
  AHEAD=$(git rev-list --count @{upstream}..HEAD)
  BEHIND=$(git rev-list --count HEAD..@{upstream})
  
  if [[ $AHEAD -eq 0 && $BEHIND -eq 0 ]]; then
    echo "    ✅ Already in sync with remote. Skipping."
    SKIPPED_REPOS+=("$REPO_NAME (in sync)")
    popd > /dev/null
    continue
  fi
  
  # Execute the force push
  CURRENT_BRANCH=$(git branch --show-current)
  echo "    🔄 Force pushing branch '$CURRENT_BRANCH'..."
  
  # Use our existing force push script
  $(dirname "$0")/force-push-to-remote.sh origin $BACKUP_FLAG
  
  # Check result
  if [[ $? -eq 0 ]]; then
    echo "    ✅ Force push successful."
    SUCCESS_COUNT=$((SUCCESS_COUNT+1))
  else
    echo "    ❌ Force push failed."
    FAILED_REPOS+=("$REPO_NAME")
  fi
  
  # Return to original directory
  popd > /dev/null
  echo ""
done

# Summary
echo "📊 Batch Force Push Summary:"
echo "=============================="
echo "✅ Successfully processed: $SUCCESS_COUNT/$REPO_COUNT repositories"

if [[ ${#SKIPPED_REPOS[@]} -gt 0 ]]; then
  echo "⏩ Skipped repositories: ${#SKIPPED_REPOS[@]}"
  for repo in "${SKIPPED_REPOS[@]}"; do
    echo "   - $repo"
  done
fi

if [[ ${#FAILED_REPOS[@]} -gt 0 ]]; then
  echo "❌ Failed repositories: ${#FAILED_REPOS[@]}"
  for repo in "${FAILED_REPOS[@]}"; do
    echo "   - $repo"
  done
  echo ""
  echo "Please check error messages above or process these repositories individually."
fi

echo ""
echo "✨ Batch operation completed!"