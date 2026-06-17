{{ config(
    alias = 'base_trades',
    materialized = 'view'
) }}

{{ balancer_trades_union([
    ref('balancer_v2_base_trades'),
    ref('balancer_v3_base_trades')
]) }}
