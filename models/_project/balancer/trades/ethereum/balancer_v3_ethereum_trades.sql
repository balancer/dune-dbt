{{
    config(
        alias = 'v3_ethereum_trades',
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['blockchain', 'tx_hash', 'evt_index'],
        partition_by = ['block_month'],
        incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.block_time')]
    )
}}

{{ balancer_v3_enriched_trades('ethereum') }}
