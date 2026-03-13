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
| access denied (prod) | No prod write permission | Contact Dune/org admin for prod access |

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
