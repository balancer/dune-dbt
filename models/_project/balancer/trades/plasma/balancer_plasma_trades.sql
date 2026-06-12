{{ config(
    alias = 'plasma_trades',
    materialized = 'view'
) }}

{{ balancer_trades_union([
    ref('balancer_v3_plasma_trades')
]) }}
