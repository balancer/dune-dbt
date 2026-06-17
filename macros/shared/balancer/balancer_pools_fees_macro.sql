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

{% macro balancer_v2_pools_fees_macro(blockchain, source_namespace, project_start_date) %}

    {% set event_signature = '0xa9ba3ffe0b6c366b81232caab38605a0699ad5398d6cce76f91ee809e322dafc' %}

    WITH registered_pools AS (
        SELECT DISTINCT
            poolAddress AS pool_address
        FROM {{ source(source_namespace, 'Vault_evt_PoolRegistered') }}
    )

    SELECT
        '{{ blockchain }}' AS blockchain
        , '2' AS version
        , logs.contract_address AS pool_address
        , CAST(NULL AS VARBINARY) AS pool_id
        , logs.tx_hash AS tx_hash
        , logs.tx_index AS tx_index
        , logs.index AS index
        , logs.block_time AS block_time
        , logs.block_number AS block_number
        , CAST(bytearray_to_uint256(bytearray_ltrim(logs.data)) AS DOUBLE) AS swap_fee_percentage
    FROM {{ source(blockchain, 'logs') }} AS logs
    INNER JOIN registered_pools
        ON registered_pools.pool_address = logs.contract_address
    WHERE logs.topic0 = {{ event_signature }}
    {% if not is_incremental() %}
        AND logs.block_time >= TIMESTAMP '{{ project_start_date }}'
    {% endif %}
    {% if is_incremental() %}
        AND {{ incremental_predicate('logs.block_time') }}
    {% endif %}

{% endmacro %}
