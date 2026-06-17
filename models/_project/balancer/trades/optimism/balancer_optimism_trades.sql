{{ config(
    alias = 'optimism_trades',
    materialized = 'view'
) }}

{{ balancer_trades_union([
    ref('balancer_v2_optimism_trades')
]) }}
