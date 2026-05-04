{% macro
    balancer_v3_reclamm_hourly_liquidity_macro(
        blockchain,
        version,
        project_decoded_as,
        base_spells_namespace,
        pool_labels_model,
        start_hour
    )
%}

WITH pool_labels AS (
        SELECT
            address AS pool_id,
            name AS pool_symbol,
            pool_type
        FROM {{ source('labels', pool_labels_model) }}
        WHERE blockchain = '{{ blockchain }}'
        AND source = 'query'
        AND model_name = '{{ pool_labels_model }}'
    ),

    token_data AS (
        SELECT
            pool,
            ARRAY_AGG(FROM_HEX(json_extract_scalar(token, '$.token')) ORDER BY token_index) AS tokens
        FROM (
            SELECT
                pool,
                tokenConfig,
                SEQUENCE(1, CARDINALITY(tokenConfig)) AS token_index_array
            FROM {{ source(project_decoded_as + '_' + blockchain, 'Vault_evt_PoolRegistered') }}
        ) AS pool_data
        CROSS JOIN UNNEST(tokenConfig, token_index_array) AS t(token, token_index)
        GROUP BY 1
    ),

    prices_hourly AS (
        SELECT
            date_trunc('hour', timestamp) AS hour,
            contract_address AS token,
            decimals,
            approx_percentile(price, 0.5) AS price
        FROM {{ source('prices', 'hour') }}
        WHERE blockchain = '{{ blockchain }}'
        GROUP BY 1, 2, 3
    ),

    prices_hourly_with_next AS (
        SELECT
            hour,
            token,
            decimals,
            price,
            LEAD(hour, 1, date_trunc('hour', now() + interval '1' hour)) OVER (
                PARTITION BY token
                ORDER BY hour
            ) AS next_hour
        FROM prices_hourly
    ),

    bpt_prices AS (
        SELECT
            CAST(day AS timestamp) AS hour,
            contract_address AS token,
            decimals,
            bpt_price,
            LEAD(CAST(day AS timestamp), 1, date_trunc('hour', now() + interval '1' hour)) OVER (
                PARTITION BY contract_address
                ORDER BY day
            ) AS next_hour
        FROM {{ ref(base_spells_namespace + '_bpt_prices') }}
        WHERE blockchain = '{{ blockchain }}'
        AND version = '{{ version }}'
    ),

    eth_prices AS (
        SELECT
            date_trunc('hour', minute) AS hour,
            avg(price) AS eth_price
        FROM {{ source('prices', 'usd') }}
        WHERE blockchain = 'ethereum'
        AND contract_address = 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2
        GROUP BY 1
    ),

    erc4626_prices AS (
        SELECT
            date_trunc('hour', minute) AS hour,
            wrapped_token AS token,
            decimals,
            approx_percentile(median_price, 0.5) AS price,
            LEAD(date_trunc('hour', minute), 1, date_trunc('hour', now() + interval '1' hour)) OVER (
                PARTITION BY wrapped_token
                ORDER BY date_trunc('hour', minute)
            ) AS next_hour
        FROM {{ source('balancer_v3', 'erc4626_token_prices') }}
        WHERE blockchain = '{{ blockchain }}'
        GROUP BY 1, 2, 3
    ),

    global_fees AS (
        SELECT
            evt_block_time,
            swapFeePercentage / 1e18 AS global_swap_fee,
            ROW_NUMBER() OVER (ORDER BY evt_block_time DESC) AS rn
        FROM {{ source(project_decoded_as + '_' + blockchain, 'ProtocolFeeController_evt_GlobalProtocolSwapFeePercentageChanged') }}
    ),

    pool_creator_fees AS (
        SELECT
            evt_block_time,
            pool,
            poolCreatorSwapFeePercentage / 1e18 AS pool_creator_swap_fee,
            ROW_NUMBER() OVER (PARTITION BY pool ORDER BY evt_block_time DESC) AS rn
        FROM {{ source(project_decoded_as + '_' + blockchain, 'ProtocolFeeController_evt_PoolCreatorSwapFeePercentageChanged') }}
    ),

    swaps_changes AS (
        SELECT
            hour,
            pool_id,
            token,
            SUM(COALESCE(delta, INT256 '0')) AS delta
        FROM (
                SELECT
                    date_trunc('hour', swap.evt_block_time) AS hour,
                    swap.pool AS pool_id,
                    swap.tokenIn AS token,
                    CAST(swap.amountIn AS INT256)
                        - (CAST(swap.swapFeeAmount AS INT256) * (g.global_swap_fee + COALESCE(pc.pool_creator_swap_fee, 0))) AS delta
                FROM {{ source(project_decoded_as + '_' + blockchain, 'Vault_evt_Swap') }} swap
                CROSS JOIN global_fees g
                LEFT JOIN pool_creator_fees pc ON swap.pool = pc.pool
                    AND pc.rn = 1
                WHERE g.rn = 1

                UNION ALL

                SELECT
                    date_trunc('hour', evt_block_time) AS hour,
                    pool AS pool_id,
                    tokenOut AS token,
                    -CAST(amountOut AS INT256) AS delta
                FROM {{ source(project_decoded_as + '_' + blockchain, 'Vault_evt_Swap') }}
            ) swaps
        GROUP BY 1, 2, 3
    ),

    balance_changes AS (
        SELECT
            evt_block_time,
            pool_id,
            category,
            deltas,
            swapFeeAmountsRaw
        FROM (
                SELECT
                    evt_block_time,
                    pool AS pool_id,
                    'add' AS category,
                    amountsAddedRaw AS deltas,
                    swapFeeAmountsRaw
                FROM {{ source(project_decoded_as + '_' + blockchain, 'Vault_evt_LiquidityAdded') }}

                UNION ALL

                SELECT
                    evt_block_time,
                    pool AS pool_id,
                    'remove' AS category,
                    amountsRemovedRaw AS deltas,
                    swapFeeAmountsRaw
                FROM {{ source(project_decoded_as + '_' + blockchain, 'Vault_evt_LiquidityRemoved') }}
            ) adds_and_removes
    ),

    zipped_balance_changes AS (
        SELECT
            date_trunc('hour', evt_block_time) AS hour,
            pool_id,
            t.tokens,
            CASE
                WHEN b.category = 'add' THEN d.deltas
                WHEN b.category = 'remove' THEN -d.deltas
            END AS deltas,
            p.swapFeeAmountsRaw
        FROM balance_changes b
        JOIN token_data td ON b.pool_id = td.pool
        CROSS JOIN UNNEST(td.tokens) WITH ORDINALITY AS t(tokens, i)
        CROSS JOIN UNNEST(b.deltas) WITH ORDINALITY AS d(deltas, i)
        CROSS JOIN UNNEST(b.swapFeeAmountsRaw) WITH ORDINALITY AS p(swapFeeAmountsRaw, i)
        WHERE t.i = d.i
        AND d.i = p.i
    ),

    balances_changes AS (
        SELECT
            hour,
            pool_id,
            tokens AS token,
            deltas - CAST(swapFeeAmountsRaw AS INT256) AS delta
        FROM zipped_balance_changes
    ),

    hourly_delta_balance AS (
        SELECT
            hour,
            pool_id,
            token,
            SUM(COALESCE(amount, INT256 '0')) AS amount
        FROM (
                SELECT
                    hour,
                    pool_id,
                    token,
                    SUM(COALESCE(delta, INT256 '0')) AS amount
                FROM balances_changes
                GROUP BY 1, 2, 3

                UNION ALL

                SELECT
                    hour,
                    pool_id,
                    token,
                    delta AS amount
                FROM swaps_changes
            ) balance
        GROUP BY 1, 2, 3
    ),

    cumulative_balance AS (
        SELECT
            hour,
            pool_id,
            token,
            LEAD(hour, 1, date_trunc('hour', now() + interval '1' hour)) OVER (
                PARTITION BY token, pool_id
                ORDER BY hour
            ) AS next_hour,
            SUM(amount) OVER (
                PARTITION BY pool_id, token
                ORDER BY hour
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS cumulative_amount
        FROM hourly_delta_balance
    ),

    calendar AS (
        SELECT hour_sequence AS hour
        FROM UNNEST(
            sequence(
                CAST('{{ start_hour }}' AS timestamp),
                date_trunc('hour', now()),
                interval '1' hour
            )
        ) AS t(hour_sequence)
    ),

    cumulative_usd_balance AS (
        SELECT
            c.hour,
            '{{ blockchain }}' AS blockchain,
            b.pool_id,
            b.token,
            symbol AS token_symbol,
            cumulative_amount AS token_balance_raw,
            cumulative_amount / POWER(10, COALESCE(t.decimals, p1.decimals, p3.decimals, p4.decimals)) AS token_balance,
            cumulative_amount / POWER(10, COALESCE(t.decimals, p1.decimals, p3.decimals, p4.decimals))
                * COALESCE(p1.price, p4.price, 0) AS protocol_liquidity_usd,
            cumulative_amount / POWER(10, COALESCE(t.decimals, p1.decimals, p3.decimals, p4.decimals))
                * COALESCE(p1.price, p3.bpt_price, p4.price, 0) AS pool_liquidity_usd
        FROM calendar c
        LEFT JOIN cumulative_balance b ON b.hour <= c.hour
            AND c.hour < b.next_hour
        LEFT JOIN {{ source('tokens', 'erc20') }} t ON t.contract_address = b.token
            AND blockchain = '{{ blockchain }}'
        LEFT JOIN prices_hourly_with_next p1 ON p1.hour <= c.hour
            AND c.hour < p1.next_hour
            AND p1.token = b.token
        LEFT JOIN bpt_prices p3 ON p3.hour <= c.hour
            AND c.hour < p3.next_hour
            AND p3.token = b.token
        LEFT JOIN erc4626_prices p4 ON p4.hour <= c.hour
            AND c.hour < p4.next_hour
            AND p4.token = b.token
        WHERE b.token != BYTEARRAY_SUBSTRING(b.pool_id, 1, 20)
    )

SELECT
    c.hour,
    c.pool_id,
    BYTEARRAY_SUBSTRING(c.pool_id, 1, 20) AS pool_address,
    p.pool_symbol,
    '{{ version }}' AS version,
    '{{ blockchain }}' AS blockchain,
    p.pool_type,
    c.token AS token_address,
    c.token_symbol,
    c.token_balance_raw,
    c.token_balance,
    c.protocol_liquidity_usd,
    c.protocol_liquidity_usd / e.eth_price AS protocol_liquidity_eth,
    c.pool_liquidity_usd,
    c.pool_liquidity_usd / e.eth_price AS pool_liquidity_eth
FROM cumulative_usd_balance c
LEFT JOIN eth_prices e ON e.hour = c.hour
LEFT JOIN pool_labels p ON p.pool_id = BYTEARRAY_SUBSTRING(c.pool_id, 1, 20)
WHERE p.pool_type = 'reclamm'

{% endmacro %}
