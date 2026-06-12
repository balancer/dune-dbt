{{
    config(
        alias = 'v3_plasma_base_trades',
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['tx_hash', 'evt_index'],
        incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.block_time')]
    )
}}

{{
    balancer_compatible_v3_trades(
        blockchain = 'plasma',
        project = 'balancer',
        version = '3'
    )
}}
