# Balancer Integration in dbt

This document describes the first Balancer integrations added to the Dune dbt project. Balancer is an automated portfolio manager and trading platform; these models provide on-chain analytics for pools, liquidity, balances, and BPT (Balancer Pool Tokens).

## Overview

The integration covers **Balancer V1**, **V2**, and **V3** across multiple blockchains. Models follow the Dune dbt template conventions (alias, schema, materialization) and use shared macros for reusable logic.

## Project Structure

```
models/_project/balancer/
├── balances/          # Token balance changes (ERC20, BPT)
├── bpt/                # BPT supply, transfers, prices
├── liquidity/          # Liquidity by token per pool
├── pools/              # Pool metadata, tokens, weights
└── support/            # Token whitelist, gauges

models/_project/balancer_cowswap_amm/   # Balancer + CoW Swap AMM integration
sources/balancer/                      # Chain-specific source definitions
macros/shared/balancer/                # Shared macros
```

## Model Domains

### Balances
- **`balancer_token_balance_changes`** — Token balance deltas on pools (V2/V3, all chains)
- **`balancer_token_balance_changes_daily`** — Daily aggregated balance changes
- **`balancer_ethereum_balances`** — ERC20 rolling sum balances (V1, Ethereum)

### Liquidity
- **`balancer_liquidity`** — Liquidity by token per pool (USD/ETH), unions V1–V3 + CoW Swap AMM

### Pools
- **`balancer_pools_tokens_weights`** — Pool IDs, token addresses, normalized weights per chain

### BPT (Balancer Pool Tokens)
- **`balancer_bpt_supply`** — BPT supply by day, pool, version
- **`balancer_transfers_bpt`** — BPT transfer events
- **`balancer_bpt_prices`** — BPT pricing for valuation

### Support
- **`balancer_token_whitelist`** — Whitelisted tokens for pricing
- **`balancer_single_recipient_gauges`** — Gauge-to-pool mapping (Ethereum)

## Blockchains

| Chain      | V1 | V2 | V3 |
|-----------|----|----|-----|
| Ethereum  | ✓  | ✓  | ✓   |
| Arbitrum  |    | ✓  | ✓   |
| Base      |    | ✓  | ✓   |
| Gnosis    |    | ✓  | ✓   |
| Optimism  |    | ✓  | ✓   |
| Polygon   |    | ✓  | ✓   |
| Avalanche C |  | ✓  |     |
| zkEVM     |    | ✓  |     |

## Sources

Sources are defined per chain under `sources/balancer/{chain}/`:
- **Ethereum**: V1 (BFactory, BPool), V2 (Vault, factories, LBP), V3 (Vault, factories), veBAL, GaugeController
- **Other chains**: V2/V3 Vault events, factory calls, pool creation events

All sources use the Dune `delta_prod` database by default.

## Shared Macros

- `balancer_bpt_prices_macro` — BPT price calculation
- `balancer_liquidity_macro` — Liquidity aggregation
- `balancer_transfers_bpt_macro` — BPT transfer parsing
- `balancer_token_balance_changes_daily_agg_macro` — Daily balance aggregation

## Running Balancer Models

```bash
# Run all Balancer models
uv run dbt run --select balancer

# Run a specific domain
uv run dbt run --select balancer_liquidity+
uv run dbt run --select balancer_token_balance_changes+

# Run tests
uv run dbt test --select balancer
```

## Querying on Dune

Models are exposed under the `balancer` schema. Use the `dune` catalog prefix:

```sql
SELECT * FROM dune.{team_name}.balancer_liquidity LIMIT 10;
SELECT * FROM dune.{team_name}.balancer_pools_tokens_weights LIMIT 10;
```

Replace `{team_name}` with your `DUNE_TEAM_NAME` (or `dune__tmp_` for dev).
