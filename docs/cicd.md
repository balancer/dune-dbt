# CI/CD

Continuous integration and deployment via GitHub Actions.

## GitHub-Hosted Runners

This template uses **GitHub-hosted runners** (`ubuntu-latest`) to execute CI/CD workflows.

GitHub provides and manages these runners - no infrastructure setup required on your end.

## Pull Request Workflow (CI)

**Trigger:** Every pull request
**File:** `.github/workflows/dbt_ci.yml`

### What It Does

1. Runs on every pull request affecting dbt project paths (or manual dispatch)
2. Installs dependencies and dbt packages
3. Compiles project and compares against main manifest
4. Runs modified models with `--full-refresh`
5. Tests modified models
6. Runs modified incremental models (incremental run)
7. Tests modified incremental models again

### PR Schema Isolation

Each PR gets its own isolated schema:

```
{team}__tmp_pr{number}
```

Example: `dune__tmp_pr123`

This is set via `DEV_SCHEMA_SUFFIX=pr{number}` environment variable.

### How to Pass CI

✅ **Keep branch updated:**

```bash
git fetch origin
git merge origin/main
git push
```

✅ **Test locally before pushing:**

```bash
uv run dbt run --select modified_model --full-refresh
uv run dbt test --select modified_model
```

✅ **Fix failing tests** - Don't skip tests or disable checks

### Cost Control Policy

The Dune integration CI runs on matching PR changes, so monitor credit usage:

- Keep the quality workflow (`dbt_quality.yml`) as a zero-credit static validation baseline
- Use `state:modified` in CI (already configured) to limit heavy runs to changed models
- Use path filters to avoid triggering on irrelevant repository changes

## Production Workflow

**Trigger:** Manual (schedule disabled by default)
**File:** `.github/workflows/dbt_prod.yml`
**Branch:** `main` only

⚠️ **Note:** The hourly schedule is **disabled by default** in the template. Teams must uncomment the schedule in the workflow file when ready to enable automatic hourly runs.

### What It Does

1. Downloads previous manifest (if exists)
2. **If state exists**: Runs modified models with `--full-refresh` and tests
3. Runs all models (handles incremental logic automatically)
4. Tests all models
5. Uploads manifest for next run
6. Sends email notification on failure

### State Comparison

The workflow saves `manifest.json` after each run and downloads it next time to detect changes.

- Modified models get full refresh
- Unchanged incremental models run incrementally
- Manifest expires after 90 days

### Target Configuration

Production runs use `DBT_TARGET=prod`:

- Writes to `{team}` schemas (production)
- No suffix applied

## GitHub Setup Required

### Secrets (Settings → Secrets and Variables → Actions → Secrets)

```
DUNE_API_KEY=your_api_key
```

### Variables (Settings → Secrets and Variables → Actions → Variables)

```
DUNE_TEAM_NAME=your_team_name
```

Optional - defaults to `'dune'` if not set.

## Quality Workflow (No Dune Credits)

**Trigger:** Every pull request affecting dbt project files  
**File:** `.github/workflows/dbt_quality.yml`

This workflow does not require `DUNE_API_KEY` and runs only static project checks:

1. `uv sync --locked`
2. `uv run dbt deps`
3. `uv run dbt parse --no-partial-parse`

Use this as the mandatory baseline check for every PR.

## Email Notifications

To receive failure alerts:

1. **Enable notifications:**
   Profile → Settings → Notifications → Actions → "Notify me for failed workflows only"

2. **Verify email address** in GitHub settings

3. **Watch repository:**
   Click "Watch" button (any level works, even "Participating and @mentions")

## Workflow Triggers

### Pull Request Workflow

Runs when:

- PR opened, synchronized, reopened, or marked ready for review
- Changes to: `models/`, `macros/`, `tests/`, `dbt_project.yml`, `profiles.yml`, `packages.yml`, workflow file

## Branch Protection (Required Checks)

To block merges unless CI passes:

1. Go to GitHub → Repository Settings → Branches
2. Edit the protection rule for `main`
3. Enable **Require status checks to pass before merging**
4. Mark these checks as required:
   - `parse` (from `dbt quality`)
   - `dbt-ci` (from `dbt CI`)

### Production Workflow

Runs when:

- Hourly (cron: `'0 * * * *'`) - **disabled by default, must be uncommented**
- Manual trigger via GitHub Actions UI

## Troubleshooting CI Failures

### Branch Not Up-to-Date

```bash
git fetch origin
git merge origin/main
git push
```

### Test Failures

Check test output in GitHub Actions logs:

```
dbt test output → specific test name → error message
```

Query the model in Dune to investigate.

### Main Manifest Missing in PR CI

PR Dune CI depends on `prod-manifest-latest` uploaded by deploy workflow.

If CI fails with missing manifest:

1. Go to Actions → `dbt deploy`
2. Run workflow on `main`
3. Wait for completion (artifact upload)
4. Re-run PR check

### Connection Errors

- Verify `DUNE_API_KEY` secret is set correctly
- Check Dune API status

### Timeout

Workflows timeout after 30 minutes. If hitting this:

- Optimize query performance
- Add date filters during development
- Consider breaking large models into smaller pieces

## Manual Production Run

Go to Actions tab → "dbt prod orchestration" → "Run workflow"

Use this for:

- Testing deployment changes
- Forcing a full refresh
- Running outside normal schedule

## See Also

- [Development Workflow](development-workflow.md) - Local development process
- [Testing](testing.md) - Test requirements
- [Troubleshooting](troubleshooting.md) - Common issues
