{{ config(
    alias = 'monad_trades',
    materialized = 'view'
) }}

{{ balancer_trades_union([
    ref('balancer_v3_monad_trades')
]) }}
