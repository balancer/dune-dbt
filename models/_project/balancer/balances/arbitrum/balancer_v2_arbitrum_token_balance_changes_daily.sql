{% set blockchain = 'arbitrum' %}

{{
    config(
        alias = 'v2_arbitrum_token_balance_changes_daily', 
        materialized = 'table',
    )
}}

{{ 
    balancer_v2_compatible_token_balance_changes_daily_agg_macro(
        blockchain = blockchain,
        version = '2',
        project_decoded_as = 'balancer_v2',
        base_spells_namespace = 'balancer'
    )
}}