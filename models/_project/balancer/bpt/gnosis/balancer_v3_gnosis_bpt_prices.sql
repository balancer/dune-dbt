{% set blockchain = 'gnosis' %}

{{
    config(
        alias = 'balancer_v3_gnosis_bpt_prices',        
        materialized = 'table',
    )
}}


{{ 
    balancer_v3_compatible_bpt_prices_macro(
        blockchain = blockchain,
        version = '3',        
        project_decoded_as = 'balancer_v3',
        base_spells_namespace = 'balancer',
        pool_labels_model = 'balancer_v3_pools_gnosis'
    )
}}
