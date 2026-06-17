{% set blockchain = 'ethereum' %}

{{
    config(
        alias = 'cowswap_amm_ethereum_trades',
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['blockchain', 'tx_hash', 'evt_index'],
        partition_by = ['block_month'],
        incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.block_time')]
    )
}}

{{ balancer_cowswap_amm_trades(blockchain) }}
