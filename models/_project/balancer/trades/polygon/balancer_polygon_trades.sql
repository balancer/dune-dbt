{{ config(
    alias = 'polygon_trades',
    materialized = 'view'
) }}

{{ balancer_trades_union([
    ref('balancer_v2_polygon_trades')
]) }}
