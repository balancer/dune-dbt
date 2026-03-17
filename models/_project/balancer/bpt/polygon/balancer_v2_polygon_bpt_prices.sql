{% set blockchain = 'polygon' %}

{{
    config(
        alias = 'balancer_v2_polygon_bpt_prices',        
        materialized = 'table',
    )
}}


{{ 
    balancer_v2_compatible_bpt_prices_macro(
        blockchain = blockchain,
        version = '2',        
        project_decoded_as = 'balancer_v2',
        base_spells_namespace = 'balancer',
        pool_labels_model = 'balancer_v2_pools_polygon'
    )
}}
