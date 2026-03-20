{{
    config(
        alias = 'v3_hyperevm_pools_fees',
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['block_number', 'tx_hash', 'index'],
        incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.block_time')]
    )
}}

{{ balancer_v3_pools_fees_macro('hyperevm', 'balancer_v3_hyperevm') }}
