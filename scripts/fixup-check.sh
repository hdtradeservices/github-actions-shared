#!/bin/bash
# Fixup Commits Check Script
# Validates that no fixup commits are present in the PR

set -e

# Configuration
BASE_REF="${GITHUB_BASE_REF:-main}"

echo "🔍 Checking for fixup commits..."
echo "Base reference: origin/$BASE_REF"

# Check if base branch exists
if ! git show-ref --verify --quiet refs/remotes/origin/$BASE_REF; then
    echo "⚠️ Base ref origin/$BASE_REF not found, using origin/main"
    BASE_REF="main"
fi

# Check for fixup commits
FIXUP_COMMITS=$(git log --format="%H %s" origin/$BASE_REF..HEAD | grep '^[a-f0-9]\+ fixup!' || true)

if [ -n "$FIXUP_COMMITS" ]; then
    echo "🚫 Found fixup commits in this PR:"
    echo "$FIXUP_COMMITS"
    echo ""
    echo "💡 Please squash fixup commits before merging:"
    echo "   git rebase -i origin/$BASE_REF"
    echo "   or"
    echo "   git reset --soft origin/$BASE_REF && git commit"
    exit 1
fi

echo "✅ No fixup commits found!"
exit 0