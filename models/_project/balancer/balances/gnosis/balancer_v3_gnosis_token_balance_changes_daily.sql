{% set blockchain = 'gnosis' %}

{{
    config(
        alias = 'v3_gnosis_token_balance_changes_daily', 
        materialized = 'table',
    )
}}

{{ 
    balancer_v3_compatible_token_balance_changes_daily_agg_macro(
        blockchain = blockchain,
        version = '3',
        project_decoded_as = 'balancer_v3',
        base_spells_namespace = 'balancer'
    )
}}