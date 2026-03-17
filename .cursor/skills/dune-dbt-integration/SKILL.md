---
name: dune-dbt-integration
description: Troubleshoot and configure Dune + dbt integration. Use when setting up profiles.yml, fixing 401/access denied errors, running dbt against Dune, or querying dbt models in the Dune UI.
alwaysApply: false
---

# Dune dbt Integration

Key learnings for integrating dbt with Dune's Trino connector.

## profiles.yml — Authentication

**Dune uses LDAP, not JWT.** The official template differs from some docs:

```yaml
# ✅ Correct (from dune-dbt-template)
method: ldap
user: dune          # Fixed — do not change
password: "{{ env_var('DUNE_API_KEY') }}"
catalog: dune       # Fixed — do not change
host: trino.api.dune.com
port: 443
http_scheme: https
cert: true
session_properties:
  transformations: true
```

**Do not use:** `method: jwt`, `jwt_token`, or `user: "{{ env_var('DUNE_TEAM_NAME') }}"`.

## Environment Variables

- **dbt does not auto-load `.env`** — run `source .env` before `uv run dbt run`.
- Required: `DUNE_API_KEY`, `DUNE_TEAM_NAME`.
- Optional: `DEV_SCHEMA_SUFFIX` for personal dev schemas.
- Optional: `DUNE_SKIP_VIEW_PROPERTIES=true` — skips `hide_spells()` and `expose_spells()` post-hooks in prod when API key lacks `alter_view_properties` permission.

## Model Config — Dune Restrictions

- **Remove `file_format = 'delta'`** — Dune catalog does not support this property. Causes: `table property 'format' does not exist`.
- **Never set `format` or `file_format`** in model configs.

## incremental_predicate Macro

Models using `incremental_predicate()` require these vars in `dbt_project.yml`:

```yaml
vars:
  DBT_ENV_INCREMENTAL_TIME_UNIT: 'day'
  DBT_ENV_INCREMENTAL_TIME: '1'
```

Otherwise: `Required var 'DBT_ENV_INCREMENTAL_TIME_UNIT' not found`.

## Schema Naming

| Target | Schema pattern | Example |
|--------|----------------|---------|
| dev | `{team}__tmp___{custom}` | `balancer__tmp___balancer_v2_ethereum` |
| prod | `{team}__{custom}` or `{team}` | `balancer__balancer_v2_ethereum` |

Note: dev uses **three underscores** between `tmp` and the custom schema.

## Querying in Dune UI

Always use the `dune.` catalog prefix:

```sql
-- Dev
select * from dune.balancer__tmp___balancer_v2_ethereum.bpt_supply limit 100;

-- Prod
select * from dune.balancer.bpt_supply limit 100;
```

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| 401 Invalid authentication | Wrong auth method or API key | Use LDAP, `user: dune`, `password: DUNE_API_KEY` |
| Env var not provided | .env not loaded | Run `source .env` before dbt |
| table property 'format' does not exist | file_format in model | Remove `file_format = 'delta'` |
| DBT_ENV_INCREMENTAL_TIME_UNIT not found | incremental_predicate macro | Add vars to dbt_project.yml |
| access denied (prod) | See "Access Denied (Prod)" section below | |
| Cannot execute procedure dune._internal.alter_view_properties | API key lacks permission for view metadata | Set `DUNE_SKIP_VIEW_PROPERTIES=true` in .env |

## Access Denied (Prod) — Support Recommendation

When support says: *"make sure in your profiles.yml your api key has permissions in your prod target"*, they refer to:

### 1. API key context

- **API key must be from the team account**, not personal.
- If dev works, the key is team-level — this is not the issue.
- Prod writes to `{team_name}`; personal keys only have access to `{user}__tmp_*`.

### 2. DUNE_TEAM_NAME exact match

- Prod schema (`{{ env_var('DUNE_TEAM_NAME') }}`) must be **exactly** the team handle on Dune.
- Docs: *"Verify you're using the correct team namespace"* (Supported SQL Operations).
- Case-sensitive; no spaces or extra characters.

**Check:** In the Dune UI, what is the exact team handle? Compare with `DUNE_TEAM_NAME` in `.env`.

### 3. Data Transformations enabled

- Docs: *"Dune Enterprise account with Data Transformations enabled"* (prerequisite).
- *"Verify you're using the correct team namespace and have Data Transformations enabled."* (troubleshooting).

**Check:** Does the team's Enterprise plan have Data Transformations enabled?

### 4. profiles.yml — same key for dev and prod

- Dev and prod use the same `DUNE_API_KEY` (correct).
- Only difference is schema: dev → `{team}__tmp_*`, prod → `{team}`.
- `transformations: true` in both (required for writes).

### Checklist for access denied in prod

1. [ ] API key created under **team** context (if dev works, this is done)
2. [ ] `DUNE_TEAM_NAME` = exact team handle on Dune
3. [ ] Data Transformations enabled on team's Enterprise plan
4. [ ] `transformations: true` in session_properties (dev and prod)
5. [ ] Contact Dune support if all above pass — prod schema may require explicit provisioning

## Deploy Targets

```bash
# Dev (default)
uv run dbt run

# Prod
uv run dbt run --target prod
```

Prod may require additional permissions; dev typically works with a valid org API key.

## Verify API Key

```bash
curl -X POST -H "X-DUNE-API-KEY: $DUNE_API_KEY" "https://api.dune.com/api/v1/usage"
```

Success = JSON with `credits_used`, `billing_periods`. Use **POST**, not GET.

## Prerequisites

- Dune Enterprise account with **Data Transformations** enabled.
- API key from the **team/org** (not personal) for team schemas.
