{% set blockchain = 'arbitrum' %}

{{ config(
        alias = 'balancer_v3_arbitrum_token_balance_changes',
        materialized = 'table',
    )
}}

{{ 
    balancer_v3_compatible_token_balance_changes_macro(
        blockchain = blockchain,
        version = '3',
        project_decoded_as = 'balancer_v3',
        base_spells_namespace = 'balancer',
        pool_labels_model = 'balancer_v3_pools_arbitrum'
    )
}}