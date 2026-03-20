{% set blockchain = 'base' %}

{{
    config(
        alias = 'v3_base_lbps',
        materialized = 'table'
    )
}}

{{ 
    balancer_v3_compatible_lbps_macro(
        blockchain = blockchain,
        project_decoded_as = 'balancer_v3'
    )
}}
