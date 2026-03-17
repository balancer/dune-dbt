{% set blockchain = 'polygon' %}

{{
    config(
        alias = 'balancer_v2_polygon_bpt_supply',
        materialized = 'table',
    )
}}

{{ 
    balancer_v2_compatible_bpt_supply_macro(
        blockchain = blockchain,
        version = '2',        
        project_decoded_as = 'balancer_v2',
        pool_labels_model = 'balancer_v2_pools_polygon',
        transfers_spell = ref('balancer_v2_polygon_transfers_bpt')
    )
}}