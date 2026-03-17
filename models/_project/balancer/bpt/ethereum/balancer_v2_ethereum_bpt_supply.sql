{% set blockchain = 'ethereum' %}

{{
    config(
        alias = 'balancer_v2_ethereum_bpt_supply',
        materialized = 'table',

    )
}}

{{ 
    balancer_v2_compatible_bpt_supply_macro(
        blockchain = blockchain,
        version = '2',        
        project_decoded_as = 'balancer_v2',
        pool_labels_model = 'balancer_v2_pools_ethereum',
        transfers_spell = ref('balancer_v2_ethereum_transfers_bpt')
    )
}}