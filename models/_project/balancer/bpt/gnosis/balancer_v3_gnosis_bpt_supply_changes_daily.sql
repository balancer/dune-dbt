{% set blockchain = 'gnosis' %}

{{
    config(
        alias = 'balancer_v3_gnosis_bpt_supply_changes_daily',
        materialized = 'table'
    )
}}

{{ 
    balancer_v3_compatible_bpt_supply_changes_daily_agg_macro(
        blockchain = blockchain,
        version = '3',
        project_decoded_as = 'balancer_v3',
        base_spells_namespace = 'balancer'
    )
}}
