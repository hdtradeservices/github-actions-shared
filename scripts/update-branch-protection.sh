#!/bin/bash
# Branch Protection Update Script for hdtradeservices Organization
# Updates branch protection rules to use new GitHub Actions checks instead of webhook checks

set -e

# Configuration
ORG="hdtradeservices"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Status check names
OLD_WEBHOOK_CHECKS=("zentail/ci/commit-format" "zentail/ci/commit-message" "zentail/ci/no-fixups")
NEW_GITHUB_ACTIONS_CHECK="pr-validation / PR Validation Checks"

echo -e "${BLUE}🔄 Starting branch protection update for hdtradeservices organization${NC}"
echo -e "${BLUE}📝 This script will update branch protection rules to use GitHub Actions instead of webhooks${NC}"
echo ""

# Check dependencies
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed. Please install it first.${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ jq is not installed. Please install it first.${NC}"
    exit 1
fi

# Test GitHub CLI authentication
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI is not authenticated. Please run 'gh auth login' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Dependencies verified${NC}"

# Dry run option
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "${YELLOW}🧪 Running in DRY RUN mode - no changes will be made${NC}"
    echo ""
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
UPDATED=0
SKIPPED=0
FAILED=0

for repo in $REPOS; do
    echo -e "${BLUE}🔄 Processing: $repo${NC}"
    
    # Get repository info
    REPO_INFO=$(gh api "repos/$ORG/$repo" --jq '{archived: .archived, default_branch: .default_branch}' 2>/dev/null || echo "{\"archived\": true}")
    IS_ARCHIVED=$(echo "$REPO_INFO" | jq -r '.archived')
    DEFAULT_BRANCH=$(echo "$REPO_INFO" | jq -r '.default_branch // "master"')
    
    if [[ "$IS_ARCHIVED" == "true" ]]; then
        echo -e "${YELLOW}📦 Repository is archived, skipping${NC}"
        SKIPPED=$((SKIPPED + 1))
        echo ""
        continue
    fi
    
    # Check if PR validation workflow exists
    WORKFLOW_EXISTS=false
    if gh api "repos/$ORG/$repo/contents/.github/workflows/pr-checks.yml" --silent 2>/dev/null; then
        WORKFLOW_EXISTS=true
    fi
    
    # Get current branch protection
    PROTECTION_DATA=$(gh api "repos/$ORG/$repo/branches/$DEFAULT_BRANCH/protection" 2>/dev/null || echo "{}")
    
    # Check if protection exists
    if [[ "$PROTECTION_DATA" == *"Branch not protected"* ]] || [[ "$PROTECTION_DATA" == "{}" ]]; then
        if [[ "$WORKFLOW_EXISTS" == "true" ]]; then
            echo -e "${YELLOW}🆕 No branch protection found, creating with GitHub Actions check${NC}"
            
            if [[ "$DRY_RUN" == "true" ]]; then
                echo -e "${YELLOW}🧪 Would create branch protection with: $NEW_GITHUB_ACTIONS_CHECK${NC}"
                UPDATED=$((UPDATED + 1))
            else
                # Create new branch protection with GitHub Actions check
                PROTECTION_CONFIG='{
                    "required_status_checks": {
                        "strict": true,
                        "contexts": ["'$NEW_GITHUB_ACTIONS_CHECK'"]
                    },
                    "enforce_admins": false,
                    "required_pull_request_reviews": null,
                    "restrictions": null
                }'
                
                if gh api "repos/$ORG/$repo/branches/$DEFAULT_BRANCH/protection" \
                    --method PUT \
                    --input - <<< "$PROTECTION_CONFIG" \
                    --silent 2>/dev/null; then
                    echo -e "${GREEN}✅ Created branch protection with GitHub Actions check${NC}"
                    UPDATED=$((UPDATED + 1))
                else
                    echo -e "${RED}❌ Failed to create branch protection${NC}"
                    FAILED=$((FAILED + 1))
                fi
            fi
        else
            echo -e "${YELLOW}⏭️  No protection and no PR workflow, skipping${NC}"
            SKIPPED=$((SKIPPED + 1))
        fi
        echo ""
        continue
    fi
    
    # Parse existing required status checks
    CURRENT_CHECKS=$(echo "$PROTECTION_DATA" | jq -r '.required_status_checks.contexts[]?' 2>/dev/null || echo "")
    echo "📋 Current checks: $(echo "$CURRENT_CHECKS" | tr '\n' ', ' | sed 's/,$//')"
    
    # Filter out old webhook checks and add new check if workflow exists
    NEW_CHECKS=()
    while IFS= read -r check; do
        if [[ -n "$check" ]]; then
            # Skip old webhook checks
            skip_check=false
            for old_check in "${OLD_WEBHOOK_CHECKS[@]}"; do
                if [[ "$check" == "$old_check" ]]; then
                    echo -e "${YELLOW}🗑️  Removing old webhook check: $check${NC}"
                    skip_check=true
                    break
                fi
            done
            
            # Skip if this is already the new check
            if [[ "$check" == "$NEW_GITHUB_ACTIONS_CHECK" ]]; then
                skip_check=false # Keep it
            fi
            
            if [[ "$skip_check" == "false" ]]; then
                NEW_CHECKS+=("$check")
            fi
        fi
    done <<< "$CURRENT_CHECKS"
    
    # Add GitHub Actions check if workflow exists and not already present
    if [[ "$WORKFLOW_EXISTS" == "true" ]]; then
        check_exists=false
        for check in "${NEW_CHECKS[@]}"; do
            if [[ "$check" == "$NEW_GITHUB_ACTIONS_CHECK" ]]; then
                check_exists=true
                break
            fi
        done
        
        if [[ "$check_exists" == "false" ]]; then
            NEW_CHECKS+=("$NEW_GITHUB_ACTIONS_CHECK")
            echo -e "${GREEN}➕ Adding GitHub Actions check: $NEW_GITHUB_ACTIONS_CHECK${NC}"
        else
            echo -e "${GREEN}✅ GitHub Actions check already present${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No PR workflow found, not adding GitHub Actions check${NC}"
    fi
    
    # Create the new contexts array for jq
    CONTEXTS_JSON="["
    for i in "${!NEW_CHECKS[@]}"; do
        if [[ $i -gt 0 ]]; then
            CONTEXTS_JSON+=","
        fi
        CONTEXTS_JSON+="\"${NEW_CHECKS[$i]}\""
    done
    CONTEXTS_JSON+="]"
    
    echo "📋 Updated checks: $(echo "${NEW_CHECKS[@]}" | tr ' ' ', ')"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}🧪 Would update branch protection${NC}"
        UPDATED=$((UPDATED + 1))
    else
        # Update branch protection with new status checks
        UPDATED_PROTECTION=$(echo "$PROTECTION_DATA" | jq ".required_status_checks.contexts = $CONTEXTS_JSON")
        
        if gh api "repos/$ORG/$repo/branches/$DEFAULT_BRANCH/protection" \
            --method PUT \
            --input - <<< "$UPDATED_PROTECTION" \
            --silent 2>/dev/null; then
            echo -e "${GREEN}✅ Updated branch protection${NC}"
            UPDATED=$((UPDATED + 1))
        else
            echo -e "${RED}❌ Failed to update branch protection${NC}"
            FAILED=$((FAILED + 1))
        fi
    fi
    
    echo ""
    
    # Small delay to avoid hitting API rate limits
    sleep 1
done

echo ""
echo -e "${BLUE}📊 Branch Protection Update Summary:${NC}"
echo -e "${GREEN}✅ Updated: $UPDATED${NC}"
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
    echo -e "${GREEN}🎉 Branch protection update completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}📋 Changes Made:${NC}"
    echo "- Removed old webhook-based status checks (zentail/ci/*)"
    echo "- Added GitHub Actions check where PR validation workflow exists"
    echo "- Preserved existing status checks (build, coverage, etc.)"
else
    echo ""
    echo -e "${YELLOW}⚠️  Branch protection update completed with some failures.${NC}"
    echo "Check the failed repositories manually for permissions or configuration issues."
fi