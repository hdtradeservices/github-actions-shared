#!/bin/bash
# Commit Length Validation Script
# Validates that commit messages are not too long

set -e

# Configuration
DEFAULT_MAX_LENGTH=72
MAX_COMMIT_LENGTH="${MAX_COMMIT_LENGTH:-$DEFAULT_MAX_LENGTH}"
BASE_REF="${GITHUB_BASE_REF:-main}"

echo "🔍 Checking commit message length (max: $MAX_COMMIT_LENGTH characters)..."
echo "Base reference: origin/$BASE_REF"

# Check if base branch exists
if ! git show-ref --verify --quiet refs/remotes/origin/$BASE_REF; then
    echo "⚠️ Base ref origin/$BASE_REF not found, using origin/main"
    BASE_REF="main"
fi

LONG_COMMITS=""
COMMIT_COUNT=0
EXIT_CODE=0

# Process each commit
while IFS=' ' read -r hash message; do
    if [ -n "$hash" ]; then
        COMMIT_COUNT=$((COMMIT_COUNT + 1))
        MESSAGE_LENGTH=${#message}
        if [ $MESSAGE_LENGTH -gt $MAX_COMMIT_LENGTH ]; then
            echo "❌ Too long ($MESSAGE_LENGTH chars): $hash - $message"
            LONG_COMMITS="$LONG_COMMITS\n$hash: $message ($MESSAGE_LENGTH chars)"
            EXIT_CODE=1
        else
            echo "✅ Good length ($MESSAGE_LENGTH chars): $hash - $message"
        fi
    fi
done < <(git log --format="%H %s" origin/$BASE_REF..HEAD)

if [ $EXIT_CODE -eq 1 ]; then
    echo ""
    echo "🚫 Found commits with messages too long:"
    echo -e "$LONG_COMMITS"
    echo ""
    echo "💡 Keep commit messages under $MAX_COMMIT_LENGTH characters for better readability."
else
    echo "✅ All $COMMIT_COUNT commit messages are within the length limit!"
fi

exit $EXIT_CODE