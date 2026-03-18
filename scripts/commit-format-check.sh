#!/bin/bash
# Commit Format Validation Script
# Validates that commit messages follow conventional commit format

set -e

# Configuration
DEFAULT_REGEX="^(feat|fix|docs|style|refactor|test|chore)(\([^\)]+\))?:"
COMMIT_FORMAT_REGEX="${COMMIT_FORMAT_REGEX:-$DEFAULT_REGEX}"
BASE_REF="${GITHUB_BASE_REF:-main}"

echo "🔍 Checking commit message format..."
echo "Expected pattern: $COMMIT_FORMAT_REGEX"
echo "Base reference: origin/$BASE_REF"

# Check if base branch exists
if ! git show-ref --verify --quiet refs/remotes/origin/$BASE_REF; then
    echo "⚠️ Base ref origin/$BASE_REF not found, using origin/main"
    BASE_REF="main"
fi

INVALID_COMMITS=""
COMMIT_COUNT=0
EXIT_CODE=0

# Process each commit
while IFS=' ' read -r hash message; do
    if [ -n "$hash" ]; then
        COMMIT_COUNT=$((COMMIT_COUNT + 1))
        if ! echo "$message" | grep -qE "$COMMIT_FORMAT_REGEX"; then
            echo "❌ Invalid format: $hash - $message"
            INVALID_COMMITS="$INVALID_COMMITS\n$hash: $message"
            EXIT_CODE=1
        else
            echo "✅ Valid format: $hash - $message"
        fi
    fi
done < <(git log --format="%H %s" origin/$BASE_REF..HEAD)

if [ $EXIT_CODE -eq 1 ]; then
    echo ""
    echo "🚫 Found commits with invalid format:"
    echo -e "$INVALID_COMMITS"
    echo ""
    echo "💡 Commit messages should follow conventional commit format:"
    echo "   feat: add new feature"
    echo "   fix: resolve bug in component"
    echo "   docs: update README"
    echo "   style: fix formatting"
    echo "   refactor: improve code structure"
    echo "   test: add unit tests"
    echo "   chore: update dependencies"
    echo ""
    echo "   Optional scope: feat(auth): add login endpoint"
else
    echo "✅ All $COMMIT_COUNT commit messages follow the expected format!"
fi

exit $EXIT_CODE