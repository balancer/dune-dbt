{{
    config(
        alias = 'v2_gnosis_pools_fees',
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['block_number', 'tx_hash', 'index'],
        incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.block_time')]
    )
}}

{{ balancer_v2_pools_fees_macro('gnosis', 'balancer_v2_gnosis', '2022-11-01') }}
