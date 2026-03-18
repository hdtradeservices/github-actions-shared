# HDTradeServices Shared GitHub Actions

This repository contains organization-wide GitHub Actions workflows for PR validation and automation. It replaces the existing webhook service with native GitHub Actions.

## 🎯 Purpose

This repository provides reusable workflows that enforce code quality standards across all repositories in the hdtradeservices organization:

- **Commit Format Validation**: Ensures commits follow conventional commit format
- **Commit Length Validation**: Enforces maximum commit message length
- **Fixup Commits Detection**: Prevents fixup commits from being merged

## 🚀 Quick Start

### For Repository Owners

Add this workflow file to your repository at `.github/workflows/pr-checks.yml`:

```yaml
name: PR Validation Checks
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  pr-validation:
    uses: hdtradeservices/github-actions-shared/.github/workflows/pr-validation.yml@main
    secrets: inherit
```

### For Organization Administrators

Use the provided migration script to add workflows to all repositories at once:

```bash
# Download and run the migration script
curl -L https://raw.githubusercontent.com/hdtradeservices/github-actions-shared/main/scripts/migrate-all-repos.sh | bash
```

## 📋 Validation Rules

### Commit Format Check
Validates that commit messages follow conventional commit format:

**Valid examples:**
- `feat: add new user authentication`
- `fix: resolve login bug`
- `docs: update API documentation`
- `feat(auth): add OAuth2 support`

**Pattern:** `^(feat|fix|docs|style|refactor|test|chore)(\([^\)]+\))?:`

### Commit Length Check
Ensures commit messages are not too long for better readability:

- **Default limit:** 72 characters
- **Configurable** per repository if needed

### Fixup Commits Check
Prevents fixup commits from being merged:

- Detects commits starting with `fixup!`
- Helps maintain clean commit history
- Encourages proper commit squashing

## ⚙️ Configuration

### Basic Usage (Recommended)
```yaml
jobs:
  pr-validation:
    uses: hdtradeservices/github-actions-shared/.github/workflows/pr-validation.yml@main
    secrets: inherit
```

### Advanced Configuration
```yaml
jobs:
  pr-validation:
    uses: hdtradeservices/github-actions-shared/.github/workflows/pr-validation.yml@main
    with:
      commit-format-regex: '^(feat|fix|docs|style|refactor|test|chore)(\([^\)]+\))?:'
      max-commit-length: 72
      skip-fixup-check: false
      skip-format-check: false
      skip-length-check: false
    secrets: inherit
```

### Input Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `commit-format-regex` | string | `^(feat\|fix\|docs\|style\|refactor\|test\|chore)(\([^\)]+\))?:` | Regex for commit format validation |
| `max-commit-length` | number | `72` | Maximum commit message length |
| `skip-fixup-check` | boolean | `false` | Skip fixup commits validation |
| `skip-format-check` | boolean | `false` | Skip commit format validation |
| `skip-length-check` | boolean | `false` | Skip commit length validation |

## 🛠️ Migration from Webhook Service

This repository replaces the existing webhook-based PR validation service. The migration provides:

### Benefits
- ✅ **No Infrastructure**: Eliminates webhook service hosting costs
- ✅ **Native Integration**: Better GitHub UI integration
- ✅ **Faster Feedback**: Typically faster than external webhooks
- ✅ **Easier Maintenance**: Updates via pull requests
- ✅ **Better Visibility**: Integrated status checks in PR interface

### Migration Steps

1. **Add workflow to repository** (see Quick Start above)
2. **Update branch protection rules** to require the new status checks:
   - `Validate Commit Format`
   - `Validate Commit Message Length`
   - `Check for Fixup Commits`
3. **Remove old webhook-based status checks** from branch protection
4. **Test with a few PRs** to ensure everything works correctly

### Status Check Names
The new GitHub Actions create these status checks:
- `Validate Commit Format`
- `Validate Commit Message Length` 
- `Check for Fixup Commits`
- `Validation Summary`

Update your branch protection rules to require these instead of the old webhook-based checks.

## 🧪 Testing

### Running Scripts Locally
You can test the validation scripts locally:

```bash
# Test commit format
export GITHUB_BASE_REF=main
export COMMIT_FORMAT_REGEX="^(feat|fix|docs|style|refactor|test|chore)(\([^\)]+\))?:"
./scripts/commit-format-check.sh

# Test commit length
export MAX_COMMIT_LENGTH=72
./scripts/commit-length-check.sh

# Test fixup commits
./scripts/fixup-check.sh
```

### Test Repository
Create a test branch with various commit types to verify the workflows:

```bash
# Create test commits
git commit --allow-empty -m "feat: valid commit message"
git commit --allow-empty -m "invalid commit message format"
git commit --allow-empty -m "feat: this is a very long commit message that exceeds the 72 character limit and should fail validation"
git commit --allow-empty -m "fixup! fix something"
```

## 🔧 Development

### Repository Structure
```
.
├── .github/workflows/
│   └── pr-validation.yml          # Main reusable workflow
├── scripts/
│   ├── commit-format-check.sh     # Commit format validation
│   ├── commit-length-check.sh     # Commit length validation
│   ├── fixup-check.sh             # Fixup commits detection
│   └── migrate-all-repos.sh       # Mass migration script
└── README.md                      # This file
```

### Making Changes
1. Create a feature branch
2. Make your changes
3. Test with a pilot repository
4. Create a pull request
5. After merge, update version tags if needed

### Versioning
- Use `@main` for latest stable version
- Use `@v1.0.0` for specific version pinning
- Major versions get new branches (v1, v2, etc.)

## 🚨 Troubleshooting

### Common Issues

**Workflow not running:**
- Ensure the calling repository has GitHub Actions enabled
- Check that the workflow file is in `.github/workflows/` directory
- Verify the `uses` path is correct

**Base branch not found:**
- The workflow automatically falls back to `main` if base branch is missing
- Ensure your repository has a `main` branch or adjust the base reference

**Permission denied:**
- Add `secrets: inherit` to the calling workflow
- Ensure the repository has proper permissions for GitHub Actions

**Status checks not appearing in PR:**
- Verify the workflow file syntax is valid
- Check GitHub Actions tab for error messages
- Ensure the workflow triggers on pull request events

### Getting Help

1. Check the Actions tab in your repository for detailed logs
2. Review the [GitHub Actions documentation](https://docs.github.com/en/actions)
3. Open an issue in this repository for workflow-related problems
4. Contact the platform team for organization-level configuration

## 📚 Additional Resources

- [GitHub Actions Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [GitHub Branch Protection Rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches)

---

## 🏷️ Version History

- **v1.0.0**: Initial release with commit validation workflows
- **v1.1.0**: Added configuration options and improved error messages
- **v1.2.0**: Enhanced validation scripts and migration tools

Migrated from webhook service to native GitHub Actions on March 2026.