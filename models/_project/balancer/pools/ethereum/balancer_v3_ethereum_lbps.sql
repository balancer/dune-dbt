{% set blockchain = 'ethereum' %}

{{
    config(
        alias = 'balancer_v3_ethereum_lbps',
        materialized = 'table'
    )
}}

{{ 
    balancer_v3_compatible_lbps_macro(
        blockchain = blockchain,
        project_decoded_as = 'balancer_v3'
    )
}}
