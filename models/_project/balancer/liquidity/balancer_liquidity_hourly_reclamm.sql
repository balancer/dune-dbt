{{ config(
        schema = 'balancer',
        alias = 'liquidity_hourly_reclamm',
        materialized = 'table'
        , post_hook='{{ hide_spells() }}'
        )
}}

{% set balancer_models = [
ref('balancer_v3_ethereum_liquidity_hourly_reclamm')
, ref('balancer_v3_gnosis_liquidity_hourly_reclamm')
, ref('balancer_v3_arbitrum_liquidity_hourly_reclamm')
, ref('balancer_v3_base_liquidity_hourly_reclamm')
, ref('balancer_v3_avalanche_c_liquidity_hourly_reclamm')
, ref('balancer_v3_hyperevm_liquidity_hourly_reclamm')
, ref('balancer_v3_monad_liquidity_hourly_reclamm')
, ref('balancer_v3_plasma_liquidity_hourly_reclamm')
] %}


SELECT *
FROM (
    {% for liquidity_model in balancer_models %}
    SELECT
    hour,
    pool_id,
    pool_address,
    pool_symbol,
    version,
    blockchain,
    pool_type,
    token_address,
    token_symbol,
    token_balance_raw,
    token_balance,
    protocol_liquidity_usd,
    protocol_liquidity_eth,
    pool_liquidity_usd,
    pool_liquidity_eth
    FROM {{ liquidity_model }}
    {% if not loop.last %}
    UNION ALL
    {% endif %}
    {% endfor %}
)
