# Balancer V3 Spell Gap Mapping (Wave 1)

## Source to Target
- Hourly source: `/Users/gustavotorres/Desktop/Projects/balancer/spellbook/dbt_subprojects/hourly_spellbook/models/_project/balancer`
- Dex source: `/Users/gustavotorres/Desktop/Projects/balancer/spellbook/dbt_subprojects/dex/models/_projects/balancer`
- Hourly target: `/Users/gustavotorres/Desktop/Projects/balancer/dune-dbt/models/_project/balancer`
- Dex target: `/Users/gustavotorres/Desktop/Projects/balancer/dune-dbt/models/_projects/balancer`

## Implemented in Wave 1
- Shared macros: `balancer_lbps_macro`, `balancer_pool_token_supply_changes_macro`, `balancer_pool_token_supply_changes_daily_agg_macro`, `balancer_protocol_fee_macro`
- BPT V3 supply changes: `arbitrum`, `base`, `ethereum`, `gnosis` + global V3-only aggregators
- ERC4626 V3 mapping/prices: `arbitrum`, `base`, `ethereum`, `gnosis` + global V3-only aggregators
- LBP V3: `arbitrum`, `base`, `ethereum`, `gnosis` + global aggregator
- Protocol fee V3: `arbitrum`, `base`, `ethereum`, `gnosis` + global V3-only aggregator

## Deferred
- Dex V3 Balancer models (`pools_fees`, `trades`) until dex foundation is imported in this repo.
- New-chain backlog (`hyperevm`, `monad`, `sonic`, `avalanche_c v3`) remains out of Wave 1.
