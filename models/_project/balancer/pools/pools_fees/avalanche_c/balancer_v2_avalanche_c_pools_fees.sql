{{
    config(
        alias = 'v2_avalanche_c_pools_fees',
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['block_number', 'tx_hash', 'index'],
        incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.block_time')]
    )
}}

{{ balancer_v2_pools_fees_macro('avalanche_c', 'balancer_v2_avalanche_c', '2023-02-17') }}
