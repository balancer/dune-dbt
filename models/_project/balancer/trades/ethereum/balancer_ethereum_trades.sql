{{ config(
    alias = 'ethereum_trades',
    materialized = 'view'
) }}

{{ balancer_trades_union([
    ref('balancer_v1_ethereum_trades'),
    ref('balancer_v2_ethereum_trades'),
    ref('balancer_cowswap_amm_ethereum_trades'),
    ref('balancer_v3_ethereum_trades')
]) }}
