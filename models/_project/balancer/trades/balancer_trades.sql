{{ config(
    alias = 'trades',
    materialized = 'view',
    post_hook='{{ hide_spells() }}'
) }}

{{ balancer_trades_union([
    ref('balancer_ethereum_trades'),
    ref('balancer_arbitrum_trades'),
    ref('balancer_avalanche_c_trades'),
    ref('balancer_base_trades'),
    ref('balancer_gnosis_trades'),
    ref('balancer_optimism_trades'),
    ref('balancer_polygon_trades'),
    ref('balancer_zkevm_trades'),
    ref('balancer_monad_trades'),
    ref('balancer_hyperevm_trades'),
    ref('balancer_plasma_trades')
]) }}
