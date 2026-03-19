{% set blockchain = 'base' %}

{{
    config(
        alias = 'v3_base_protocol_fee',
        materialized = 'table'
    )
}}

{{ 
    balancer_v3_compatible_protocol_fee_macro(
        blockchain = blockchain,
        version = '3',
        project_decoded_as = 'balancer_v3',
        base_spells_namespace = 'balancer',
        pool_labels_model = 'balancer_v3_pools_base'
    )
}}
