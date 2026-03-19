#!/bin/bash
# Mass Migration Script for hdtradeservices Organization
# Adds PR validation workflows to all repositories

set -e

# Configuration
ORG="hdtradeservices"
WORKFLOW_FILE=".github/workflows/pr-checks.yml"
COMMIT_MESSAGE="feat: add organization-wide PR validation checks"
BRANCH_NAME="add-pr-validation-checks"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Workflow content
WORKFLOW_CONTENT='name: PR Validation Checks

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  pr-validation:
    uses: hdtradeservices/github-actions-shared/.github/workflows/pr-validation.yml@main
    secrets: inherit'

echo -e "${BLUE}🚀 Starting mass migration for hdtradeservices organization${NC}"
echo -e "${BLUE}📝 This script will add PR validation workflows to all repositories${NC}"
echo ""

# Check if gh CLI is installed and authenticated
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed. Please install it first.${NC}"
    echo "Installation: https://cli.github.com/"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ jq is not installed. Please install it first.${NC}"
    echo "Installation: https://jqlang.github.io/jq/"
    exit 1
fi

# Test GitHub CLI authentication
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI is not authenticated. Please run 'gh auth login' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ GitHub CLI is installed and authenticated${NC}"

# Dry run option
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "${YELLOW}🧪 Running in DRY RUN mode - no changes will be made${NC}"
fi

# Get list of repositories
echo -e "${BLUE}📋 Fetching repositories for organization: $ORG${NC}"
REPOS=$(gh api "orgs/$ORG/repos" --paginate --jq '.[].name' | sort)

if [ -z "$REPOS" ]; then
    echo -e "${RED}❌ No repositories found or insufficient permissions${NC}"
    exit 1
fi

REPO_COUNT=$(echo "$REPOS" | wc -l)
echo -e "${GREEN}✅ Found $REPO_COUNT repositories${NC}"
echo ""

# Process repositories
SUCCESSFUL=0
FAILED=0
SKIPPED=0

for repo in $REPOS; do
    echo -e "${BLUE}🔄 Processing: $repo${NC}"
    
    # Skip this shared actions repository to avoid recursion
    if [[ "$repo" == "github-actions-shared" ]]; then
        echo -e "${YELLOW}⏭️  Skipping github-actions-shared (self-reference)${NC}"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    
    # Check if workflow already exists
    if gh api "repos/$ORG/$repo/contents/$WORKFLOW_FILE" --silent 2>/dev/null; then
        echo -e "${YELLOW}⏭️  Workflow already exists, skipping${NC}"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}🧪 Would add PR validation workflow to $repo${NC}"
        SUCCESSFUL=$((SUCCESSFUL + 1))
        continue
    fi
    
    # Check if repository is archived
    REPO_INFO=$(gh api "repos/$ORG/$repo" --jq '{archived: .archived, default_branch: .default_branch}')
    IS_ARCHIVED=$(echo "$REPO_INFO" | jq -r '.archived')
    DEFAULT_BRANCH=$(echo "$REPO_INFO" | jq -r '.default_branch')
    
    if [[ "$IS_ARCHIVED" == "true" ]]; then
        echo -e "${YELLOW}📦 Repository is archived, skipping${NC}"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    
    # Create the workflow file using the correct default branch
    if gh api "repos/$ORG/$repo/contents/$WORKFLOW_FILE" \
        --method PUT \
        --field message="$COMMIT_MESSAGE" \
        --field content="$(echo "$WORKFLOW_CONTENT" | base64)" \
        --field branch="$DEFAULT_BRANCH" \
        --silent 2>/dev/null; then
        echo -e "${GREEN}✅ Successfully added workflow${NC}"
        SUCCESSFUL=$((SUCCESSFUL + 1))
    else
        echo -e "${RED}❌ Failed to add workflow${NC}"
        FAILED=$((FAILED + 1))
    fi
    
    # Small delay to avoid hitting API rate limits
    sleep 1
done

echo ""
echo -e "${BLUE}📊 Migration Summary:${NC}"
echo -e "${GREEN}✅ Successful: $SUCCESSFUL${NC}"
echo -e "${RED}❌ Failed: $FAILED${NC}"
echo -e "${YELLOW}⏭️  Skipped: $SKIPPED${NC}"
echo -e "${BLUE}📋 Total: $REPO_COUNT${NC}"

if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo -e "${YELLOW}🧪 This was a dry run. Run without --dry-run to make actual changes.${NC}"
    exit 0
fi

if [[ $FAILED -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}🎉 Migration completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "1. Update branch protection rules to require new status checks:"
    echo "   - 'Validate Commit Format'"
    echo "   - 'Validate Commit Message Length'"
    echo "   - 'Check for Fixup Commits'"
    echo "2. Remove old webhook-based status checks from branch protection"
    echo "3. Test with a few test PRs to ensure everything works"
    echo "4. Consider decommissioning the old webhook service"
else
    echo ""
    echo -e "${YELLOW}⚠️  Migration completed with some failures. Check the failed repositories manually.${NC}"
fi