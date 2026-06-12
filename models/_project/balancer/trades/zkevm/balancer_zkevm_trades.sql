{{ config(
    alias = 'zkevm_trades',
    materialized = 'view'
) }}

{{ balancer_trades_union([
    ref('balancer_v2_zkevm_trades')
]) }}
