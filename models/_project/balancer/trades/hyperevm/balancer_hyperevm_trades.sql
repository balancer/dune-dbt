{{ config(
    alias = 'hyperevm_trades',
    materialized = 'view'
) }}

{{ balancer_trades_union([
    ref('balancer_v3_hyperevm_trades')
]) }}
