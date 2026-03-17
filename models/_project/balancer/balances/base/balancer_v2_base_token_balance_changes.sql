{% set blockchain = 'base' %}

{{ config(
        alias = 'balancer_v2_base_token_balance_changes',
        materialized = 'table',
    )
}}

{{ 
    balancer_v2_compatible_token_balance_changes_macro(
        blockchain = blockchain,
        version = '2',
        project_decoded_as = 'balancer_v2',
        base_spells_namespace = 'balancer',
        pool_labels_model = 'balancer_v2_pools_base'
    )
}}