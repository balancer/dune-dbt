{{ config(
    alias = 'avalanche_c_trades',
    materialized = 'view'
) }}

{{ balancer_trades_union([
    ref('balancer_v2_avalanche_c_trades'),
    ref('balancer_v3_avalanche_c_trades')
]) }}
