{{
    config(
        alias = 'v2_zkevm_pools_fees',
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['block_number', 'tx_hash', 'index'],
        incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.block_time')]
    )
}}

{{ balancer_v2_pools_fees_macro('zkevm', 'balancer_v2_zkevm', '2021-06-17') }}
