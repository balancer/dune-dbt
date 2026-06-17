{{ config(
    alias = 'gnosis_trades',
    materialized = 'view'
) }}

{{ balancer_trades_union([
    ref('balancer_v2_gnosis_trades'),
    ref('balancer_v3_gnosis_trades')
]) }}
