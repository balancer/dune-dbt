{% macro balancer_v3_pools_fees_macro(blockchain, source_namespace) %}

    SELECT
        '{{ blockchain }}' AS blockchain
        , '3' AS version
        , bytearray_substring(pool, 1, 20) AS pool_address
        , pool AS pool_id
        , evt_tx_hash AS tx_hash
        , evt_index AS tx_index
        , evt_index AS index
        , evt_block_time AS block_time
        , evt_block_number AS block_number
        , swapFeePercentage AS swap_fee_percentage
    FROM {{ source(source_namespace, 'Vault_evt_SwapFeePercentageChanged') }}
    {% if is_incremental() %}
    WHERE {{ incremental_predicate('evt_block_time') }}
    {% endif %}

{% endmacro %}
