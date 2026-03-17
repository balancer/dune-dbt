{% set blockchain = 'arbitrum' %}

{{
    config(
        alias = 'balancer_v3_arbitrum_bpt_supply',
        materialized = 'table',

    )
}}

{{ 
    balancer_v3_compatible_bpt_supply_macro(
        blockchain = blockchain,
        version = '3',        
        project_decoded_as = 'balancer_v3',
        pool_labels_model = 'balancer_v3_pools_arbitrum',
        transfers_spell = ref('balancer_v3_arbitrum_transfers_bpt')
    )
}}