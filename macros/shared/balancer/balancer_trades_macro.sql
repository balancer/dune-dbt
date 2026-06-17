{% macro balancer_trades_dev_time_predicate(column) %}
{%- if is_incremental() -%}
{{ incremental_predicate(column) }}
{%- elif target.name == 'dev' -%}
{{ column }} >= date_trunc('day', now() - interval '{{ var('DBT_ENV_DEV_LIMIT_DAYS', 3) }}' day)
{%- endif -%}
{% endmacro %}

{% macro balancer_compatible_v1_trades(
    blockchain = '',
    project = '',
    version = '',
    project_decoded_as = 'balancer_v1',
    BPool_evt_LOG_SWAP = 'BPool_evt_LOG_SWAP',
    BPool_call_setSwapFee = 'BPool_call_setSwapFee'
) %}

WITH

swap_fees AS (
    SELECT * FROM (
        SELECT
            swaps.contract_address,
            swaps.evt_tx_hash,
            swaps.evt_block_time,
            swaps.evt_index,
            swaps.evt_block_number,
            fees.swapFee,
            ROW_NUMBER() OVER (PARTITION BY swaps.contract_address, evt_tx_hash, evt_index ORDER BY call_block_number DESC) AS rn
        FROM {{ source(project_decoded_as ~ '_' ~ blockchain, BPool_evt_LOG_SWAP) }} swaps
        LEFT JOIN {{ source(project_decoded_as ~ '_' ~ blockchain, BPool_call_setSwapFee) }} fees
            ON fees.contract_address = swaps.contract_address
            AND fees.call_block_number < swaps.evt_block_number
        {% if is_incremental() %}
        WHERE {{ incremental_predicate('swaps.evt_block_time') }}
        {% endif %}
    ) t
    WHERE t.rn = 1
),

dexs AS (
    SELECT
        CAST(NULL AS VARBINARY) AS taker,
        CAST(NULL AS VARBINARY) AS maker,
        tokenOut AS token_bought_address,
        tokenAmountOut AS token_bought_amount_raw,
        tokenIn AS token_sold_address,
        tokenAmountIn AS token_sold_amount_raw,
        swaps.contract_address AS project_contract_address,
        (swapFee / 1e18) AS swap_fee_percentage,
        swaps.evt_block_number AS block_number,
        swaps.evt_block_time AS block_time,
        swaps.evt_tx_hash AS tx_hash,
        swaps.evt_index
    FROM {{ source(project_decoded_as ~ '_' ~ blockchain, BPool_evt_LOG_SWAP) }} swaps
    LEFT JOIN swap_fees fees
        ON fees.evt_tx_hash = swaps.evt_tx_hash
        AND fees.evt_block_number = swaps.evt_block_number
        AND fees.contract_address = swaps.contract_address
        AND fees.evt_index = swaps.evt_index
    {% if is_incremental() %}
    WHERE {{ incremental_predicate('swaps.evt_block_time') }}
    {% endif %}
)

SELECT
    '{{ blockchain }}' AS blockchain,
    '{{ project }}' AS project,
    '{{ version }}' AS version,
    CAST(date_trunc('month', dexs.block_time) AS date) AS block_month,
    CAST(date_trunc('day', dexs.block_time) AS date) AS block_date,
    dexs.block_time,
    dexs.block_number,
    dexs.token_bought_amount_raw,
    dexs.token_sold_amount_raw,
    dexs.token_bought_address,
    dexs.token_sold_address,
    dexs.taker,
    dexs.maker,
    dexs.project_contract_address,
    dexs.tx_hash,
    dexs.evt_index,
    CAST(NULL AS varbinary) AS pool_id,
    CAST(dexs.swap_fee_percentage AS double) AS swap_fee
FROM dexs

{% endmacro %}

{# ######################################################################### #}

{% macro balancer_compatible_v2_trades(
    blockchain = '',
    project = '',
    version = '',
    project_decoded_as = 'balancer_v2',
    Vault_evt_Swap = 'Vault_evt_Swap',
    pools_fees = 'pools_fees'
) %}

WITH

swap_fees AS (
    SELECT * FROM (
        SELECT
            swaps.poolId,
            swaps.evt_tx_hash,
            swaps.evt_index,
            swaps.evt_block_number,
            bytearray_substring(swaps.poolId, 1, 20) AS contract_address,
            fees.swap_fee_percentage,
            ROW_NUMBER() OVER (PARTITION BY poolId, evt_tx_hash, evt_index ORDER BY block_number DESC, index DESC) AS rn
        FROM {{ source(project_decoded_as ~ '_' ~ blockchain, Vault_evt_Swap) }} swaps
        LEFT JOIN {{ ref(project_decoded_as ~ '_' ~ blockchain ~ '_' ~ pools_fees) }} fees
            ON fees.pool_address = bytearray_substring(swaps.poolId, 1, 20)
            AND ARRAY[fees.block_number] || ARRAY[fees.index] < ARRAY[swaps.evt_block_number] || ARRAY[swaps.evt_index]
        {% if is_incremental() or target.name == 'dev' %}
        WHERE {{ balancer_trades_dev_time_predicate('swaps.evt_block_time') }}
        {% endif %}
    ) t
    WHERE t.rn = 1
),

pool_labels AS (
    SELECT
        blockchain,
        address AS pool_address,
        name AS pool_symbol,
        pool_type
    FROM {{ ref('labels_balancer_v2_pools') }}
),

dexs AS (
    SELECT
        swap.evt_block_number AS block_number,
        swap.evt_block_time AS block_time,
        CAST(NULL AS VARBINARY) AS taker,
        CAST(NULL AS VARBINARY) AS maker,
        swap.amountOut AS token_bought_amount_raw,
        swap.amountIn AS token_sold_amount_raw,
        swap.tokenOut AS token_bought_address,
        swap.tokenIn AS token_sold_address,
        swap_fees.contract_address AS project_contract_address,
        swap.poolId AS pool_id,
        l.pool_symbol,
        l.pool_type,
        swap_fees.swap_fee_percentage / POWER(10, 18) AS swap_fee,
        swap.evt_tx_hash AS tx_hash,
        swap.evt_index
    FROM swap_fees
    INNER JOIN {{ source(project_decoded_as ~ '_' ~ blockchain, Vault_evt_Swap) }} swap
        ON swap.evt_block_number = swap_fees.evt_block_number
        AND swap.evt_tx_hash = swap_fees.evt_tx_hash
        AND swap.evt_index = swap_fees.evt_index
    LEFT JOIN pool_labels l
        ON l.blockchain = '{{ blockchain }}'
        AND l.pool_address = swap_fees.contract_address
    WHERE swap.tokenIn <> swap_fees.contract_address
        AND swap.tokenOut <> swap_fees.contract_address
    {% if is_incremental() or target.name == 'dev' %}
        AND {{ balancer_trades_dev_time_predicate('swap.evt_block_time') }}
    {% endif %}
)

SELECT
    '{{ blockchain }}' AS blockchain,
    '{{ project }}' AS project,
    '{{ version }}' AS version,
    CAST(date_trunc('month', dexs.block_time) AS date) AS block_month,
    CAST(date_trunc('day', dexs.block_time) AS date) AS block_date,
    dexs.block_time,
    dexs.block_number,
    dexs.token_bought_amount_raw,
    dexs.token_sold_amount_raw,
    dexs.token_bought_address,
    dexs.token_sold_address,
    dexs.taker,
    dexs.maker,
    dexs.project_contract_address,
    dexs.tx_hash,
    dexs.evt_index,
    dexs.pool_id,
    dexs.swap_fee,
    dexs.pool_symbol,
    dexs.pool_type
FROM dexs
/* hardcoded filter for inflated volumes on whitehat effort to recover funds */
WHERE CAST(date_trunc('day', dexs.block_time) AS date) != date '2025-11-12'

{% endmacro %}

{# ######################################################################### #}

{% macro balancer_compatible_v3_trades(
    blockchain = '',
    project = '',
    version = '',
    project_decoded_as = 'balancer_v3',
    Vault_evt_Swap = 'Vault_evt_Swap',
    Vault_evt_Wrap = 'Vault_evt_Wrap',
    Vault_evt_Unwrap = 'Vault_evt_Unwrap'
) %}

WITH

pool_labels AS (
    SELECT
        blockchain,
        address AS pool_address,
        name AS pool_symbol,
        pool_type
    FROM {{ ref('labels_balancer_v3_pools') }}
),

swaps_filtered AS (
    SELECT
        swap.*
    FROM {{ source(project_decoded_as ~ '_' ~ blockchain, Vault_evt_Swap) }} swap
    WHERE swap.tokenIn <> swap.pool
        AND swap.tokenOut <> swap.pool
    {% if is_incremental() or target.name == 'dev' %}
        AND {{ balancer_trades_dev_time_predicate('swap.evt_block_time') }}
    {% endif %}
),

{# Buffer swaps move underlying through Wrap/Unwrap; match nearest Wrap/Unwrap by evt_index with one-to-one mutual-nearest assignment. #}
wrap_candidates AS (
    SELECT
        s.evt_tx_hash,
        s.evt_index AS swap_evt_index,
        w.evt_index AS wrap_evt_index,
        w.depositedUnderlying,
        ROW_NUMBER() OVER (
            PARTITION BY s.evt_tx_hash, s.evt_index
            ORDER BY ABS(CAST(w.evt_index AS bigint) - CAST(s.evt_index AS bigint)), w.evt_index ASC
        ) AS rn_swap,
        ROW_NUMBER() OVER (
            PARTITION BY w.evt_tx_hash, w.evt_index
            ORDER BY ABS(CAST(w.evt_index AS bigint) - CAST(s.evt_index AS bigint)), s.evt_index ASC
        ) AS rn_event
    FROM swaps_filtered s
    INNER JOIN {{ source(project_decoded_as ~ '_' ~ blockchain, Vault_evt_Wrap) }} w
        ON w.evt_tx_hash = s.evt_tx_hash
        AND w.mintedShares = s.amountIn
        AND w.wrappedToken = s.tokenIn
    {% if is_incremental() or target.name == 'dev' %}
        AND {{ balancer_trades_dev_time_predicate('w.evt_block_time') }}
    {% endif %}
),

wrap_for_swap AS (
    SELECT
        evt_tx_hash,
        swap_evt_index,
        depositedUnderlying
    FROM wrap_candidates
    WHERE rn_swap = 1
        AND rn_event = 1
),

unwrap_candidates AS (
    SELECT
        s.evt_tx_hash,
        s.evt_index AS swap_evt_index,
        u.evt_index AS unwrap_evt_index,
        u.withdrawnUnderlying,
        ROW_NUMBER() OVER (
            PARTITION BY s.evt_tx_hash, s.evt_index
            ORDER BY ABS(CAST(u.evt_index AS bigint) - CAST(s.evt_index AS bigint)), u.evt_index ASC
        ) AS rn_swap,
        ROW_NUMBER() OVER (
            PARTITION BY u.evt_tx_hash, u.evt_index
            ORDER BY ABS(CAST(u.evt_index AS bigint) - CAST(s.evt_index AS bigint)), s.evt_index ASC
        ) AS rn_event
    FROM swaps_filtered s
    INNER JOIN {{ source(project_decoded_as ~ '_' ~ blockchain, Vault_evt_Unwrap) }} u
        ON u.evt_tx_hash = s.evt_tx_hash
        AND u.burnedShares = s.amountOut
        AND u.wrappedToken = s.tokenOut
    {% if is_incremental() or target.name == 'dev' %}
        AND {{ balancer_trades_dev_time_predicate('u.evt_block_time') }}
    {% endif %}
),

unwrap_for_swap AS (
    SELECT
        evt_tx_hash,
        swap_evt_index,
        withdrawnUnderlying
    FROM unwrap_candidates
    WHERE rn_swap = 1
        AND rn_event = 1
),

dexs AS (
    SELECT
        swap.evt_block_number AS block_number,
        swap.evt_block_time AS block_time,
        CAST(NULL AS VARBINARY) AS taker,
        CAST(NULL AS VARBINARY) AS maker,
        COALESCE(unwrap_for_swap.withdrawnUnderlying, swap.amountOut) AS token_bought_amount_raw,
        COALESCE(wrap_for_swap.depositedUnderlying, swap.amountIn) AS token_sold_amount_raw,
        swap.tokenOut AS token_bought_address,
        swap.tokenIn AS token_sold_address,
        swap.pool AS project_contract_address,
        swap.pool AS pool_id,
        l.pool_symbol,
        l.pool_type,
        swap.SwapFeePercentage / POWER(10, 18) AS swap_fee,
        swap.evt_tx_hash AS tx_hash,
        swap.evt_index
    FROM swaps_filtered swap
    LEFT JOIN wrap_for_swap
        ON wrap_for_swap.evt_tx_hash = swap.evt_tx_hash
        AND wrap_for_swap.swap_evt_index = swap.evt_index
    LEFT JOIN unwrap_for_swap
        ON unwrap_for_swap.evt_tx_hash = swap.evt_tx_hash
        AND unwrap_for_swap.swap_evt_index = swap.evt_index
    LEFT JOIN pool_labels l
        ON l.blockchain = '{{ blockchain }}'
        AND l.pool_address = swap.pool
)

SELECT
    '{{ blockchain }}' AS blockchain,
    '{{ project }}' AS project,
    '{{ version }}' AS version,
    CAST(date_trunc('month', dexs.block_time) AS date) AS block_month,
    CAST(date_trunc('day', dexs.block_time) AS date) AS block_date,
    dexs.block_time,
    dexs.block_number,
    dexs.token_bought_amount_raw,
    dexs.token_sold_amount_raw,
    dexs.token_bought_address,
    dexs.token_sold_address,
    dexs.taker,
    dexs.maker,
    dexs.project_contract_address,
    dexs.tx_hash,
    dexs.evt_index,
    dexs.pool_id,
    dexs.swap_fee,
    dexs.pool_symbol,
    dexs.pool_type
FROM dexs

{% endmacro %}

{# ######################################################################### #}

{% macro balancer_v2_enriched_trades(blockchain) %}

WITH
dexs_base AS (
    SELECT
        tx_hash,
        evt_index,
        pool_id,
        swap_fee,
        pool_symbol,
        pool_type
    FROM {{ ref('balancer_v2_' ~ blockchain ~ '_base_trades') }}
),

dexs AS (
    SELECT
        dexs.blockchain,
        dexs.project,
        dexs.version,
        dexs.block_month,
        dexs.block_date,
        dexs.block_time,
        dexs.block_number,
        dexs.token_bought_symbol,
        dexs.token_sold_symbol,
        dexs.token_pair,
        dexs.token_bought_amount,
        dexs.token_sold_amount,
        dexs.token_bought_amount_raw,
        dexs.token_sold_amount_raw,
        dexs.amount_usd,
        dexs.token_bought_address,
        dexs.token_sold_address,
        dexs.taker,
        dexs.maker,
        dexs.project_contract_address,
        dexs.tx_hash,
        dexs.tx_from,
        dexs.tx_to,
        dexs.evt_index,
        dexs_base.pool_id,
        dexs_base.swap_fee,
        dexs_base.pool_symbol,
        dexs_base.pool_type
    FROM {{ source('dex', 'trades') }} dexs
    INNER JOIN dexs_base
        ON dexs.tx_hash = dexs_base.tx_hash
        AND dexs.evt_index = dexs_base.evt_index
    WHERE dexs.blockchain = '{{ blockchain }}'
        AND dexs.project = 'balancer'
        AND dexs.version = '2'
    {% if is_incremental() or target.name == 'dev' %}
        AND {{ balancer_trades_dev_time_predicate('dexs.block_time') }}
    {% endif %}
),

bpa AS (
    SELECT
        dexs.block_number,
        dexs.tx_hash,
        dexs.evt_index,
        bpt_prices.contract_address,
        dexs.block_time,
        MAX(bpt_prices.day) AS bpa_max_block_date
    FROM dexs
    LEFT JOIN {{ ref('balancer_bpt_prices') }} bpt_prices
        ON bpt_prices.contract_address = dexs.token_bought_address
        AND bpt_prices.blockchain = '{{ blockchain }}'
        AND bpt_prices.version = '2'
        AND bpt_prices.day <= DATE_TRUNC('day', dexs.block_time)
    GROUP BY 1, 2, 3, 4, 5
),

bpb AS (
    SELECT
        dexs.block_number,
        dexs.tx_hash,
        dexs.evt_index,
        bpt_prices.contract_address,
        dexs.block_time,
        MAX(bpt_prices.day) AS bpb_max_block_date
    FROM dexs
    LEFT JOIN {{ ref('balancer_bpt_prices') }} bpt_prices
        ON bpt_prices.contract_address = dexs.token_sold_address
        AND bpt_prices.blockchain = '{{ blockchain }}'
        AND bpt_prices.version = '2'
        AND bpt_prices.day <= DATE_TRUNC('day', dexs.block_time)
    GROUP BY 1, 2, 3, 4, 5
)

SELECT
    dexs.blockchain,
    dexs.project,
    dexs.version,
    dexs.block_date,
    dexs.block_number,
    dexs.block_month,
    dexs.block_time,
    dexs.token_bought_symbol,
    dexs.token_sold_symbol,
    dexs.token_pair,
    dexs.token_bought_amount,
    dexs.token_sold_amount,
    dexs.token_bought_amount_raw,
    dexs.token_sold_amount_raw,
    COALESCE(
        dexs.amount_usd,
        dexs.token_bought_amount_raw / POWER(10, COALESCE(erc20a.decimals, 18)) * bpa_bpt_prices.bpt_price,
        dexs.token_sold_amount_raw / POWER(10, COALESCE(erc20b.decimals, 18)) * bpb_bpt_prices.bpt_price
    ) AS amount_usd,
    dexs.token_bought_address,
    dexs.token_sold_address,
    dexs.taker,
    dexs.maker,
    dexs.project_contract_address,
    dexs.pool_id,
    dexs.swap_fee,
    dexs.pool_symbol,
    dexs.pool_type,
    dexs.tx_hash,
    dexs.tx_from,
    dexs.tx_to,
    dexs.evt_index
FROM dexs
LEFT JOIN {{ source('tokens', 'erc20') }} erc20a
    ON erc20a.contract_address = dexs.token_bought_address
    AND erc20a.blockchain = dexs.blockchain
LEFT JOIN {{ source('tokens', 'erc20') }} erc20b
    ON erc20b.contract_address = dexs.token_sold_address
    AND erc20b.blockchain = dexs.blockchain
INNER JOIN bpa
    ON bpa.block_number = dexs.block_number
    AND bpa.tx_hash = dexs.tx_hash
    AND bpa.evt_index = dexs.evt_index
LEFT JOIN {{ ref('balancer_bpt_prices') }} bpa_bpt_prices
    ON bpa_bpt_prices.contract_address = bpa.contract_address
    AND bpa_bpt_prices.blockchain = '{{ blockchain }}'
    AND bpa_bpt_prices.version = '2'
    AND bpa_bpt_prices.day = bpa.bpa_max_block_date
INNER JOIN bpb
    ON bpb.block_number = dexs.block_number
    AND bpb.tx_hash = dexs.tx_hash
    AND bpb.evt_index = dexs.evt_index
LEFT JOIN {{ ref('balancer_bpt_prices') }} bpb_bpt_prices
    ON bpb_bpt_prices.contract_address = bpb.contract_address
    AND bpb_bpt_prices.blockchain = '{{ blockchain }}'
    AND bpb_bpt_prices.version = '2'
    AND bpb_bpt_prices.day = bpb.bpb_max_block_date

{% endmacro %}

{# ######################################################################### #}

{% macro balancer_v3_enriched_trades(blockchain) %}

WITH
dexs_base AS (
    SELECT
        tx_hash,
        evt_index,
        pool_id,
        swap_fee,
        pool_symbol,
        pool_type
    FROM {{ ref('balancer_v3_' ~ blockchain ~ '_base_trades') }}
),

dexs AS (
    SELECT
        dexs.blockchain,
        dexs.project,
        dexs.version,
        dexs.block_month,
        dexs.block_date,
        dexs.block_time,
        dexs.block_number,
        dexs.token_bought_symbol,
        dexs.token_sold_symbol,
        dexs.token_pair,
        dexs.token_bought_amount,
        dexs.token_sold_amount,
        dexs.token_bought_amount_raw,
        dexs.token_sold_amount_raw,
        dexs.amount_usd,
        dexs.token_bought_address,
        dexs.token_sold_address,
        dexs.taker,
        dexs.maker,
        dexs.project_contract_address,
        dexs.tx_hash,
        dexs.tx_from,
        dexs.tx_to,
        dexs.evt_index,
        dexs_base.pool_id,
        dexs_base.swap_fee,
        dexs_base.pool_symbol,
        dexs_base.pool_type
    FROM {{ source('dex', 'trades') }} dexs
    INNER JOIN dexs_base
        ON dexs.tx_hash = dexs_base.tx_hash
        AND dexs.evt_index = dexs_base.evt_index
    WHERE dexs.blockchain = '{{ blockchain }}'
        AND dexs.project = 'balancer'
        AND dexs.version = '3'
    {% if is_incremental() or target.name == 'dev' %}
        AND {{ balancer_trades_dev_time_predicate('dexs.block_time') }}
    {% endif %}
),

bpa AS (
    SELECT
        dexs.block_number,
        dexs.tx_hash,
        dexs.evt_index,
        bpt_prices.contract_address,
        dexs.block_time,
        MAX(bpt_prices.day) AS bpa_max_block_date
    FROM dexs
    LEFT JOIN {{ ref('balancer_bpt_prices') }} bpt_prices
        ON bpt_prices.contract_address = dexs.token_bought_address
        AND bpt_prices.blockchain = '{{ blockchain }}'
        AND bpt_prices.version = '3'
        AND bpt_prices.day <= DATE_TRUNC('day', dexs.block_time)
    GROUP BY 1, 2, 3, 4, 5
),

bpb AS (
    SELECT
        dexs.block_number,
        dexs.tx_hash,
        dexs.evt_index,
        bpt_prices.contract_address,
        dexs.block_time,
        MAX(bpt_prices.day) AS bpb_max_block_date
    FROM dexs
    LEFT JOIN {{ ref('balancer_bpt_prices') }} bpt_prices
        ON bpt_prices.contract_address = dexs.token_sold_address
        AND bpt_prices.blockchain = '{{ blockchain }}'
        AND bpt_prices.version = '3'
        AND bpt_prices.day <= DATE_TRUNC('day', dexs.block_time)
    GROUP BY 1, 2, 3, 4, 5
)

SELECT
    dexs.blockchain,
    dexs.project,
    dexs.version,
    dexs.block_date,
    dexs.block_number,
    dexs.block_month,
    dexs.block_time,
    dexs.token_bought_symbol,
    dexs.token_sold_symbol,
    dexs.token_pair,
    dexs.token_bought_amount,
    dexs.token_sold_amount,
    dexs.token_bought_amount_raw,
    dexs.token_sold_amount_raw,
    COALESCE(
        dexs.amount_usd,
        dexs.token_bought_amount_raw / POWER(10, COALESCE(erc20a.decimals, erc4626a.decimals, 18)) * COALESCE(bpa_bpt_prices.bpt_price, erc4626a.median_price),
        dexs.token_sold_amount_raw / POWER(10, COALESCE(erc20b.decimals, erc4626b.decimals, 18)) * COALESCE(bpb_bpt_prices.bpt_price, erc4626b.median_price)
    ) AS amount_usd,
    dexs.token_bought_address,
    dexs.token_sold_address,
    dexs.taker,
    dexs.maker,
    dexs.project_contract_address,
    dexs.pool_id,
    dexs.swap_fee,
    dexs.pool_symbol,
    dexs.pool_type,
    dexs.tx_hash,
    dexs.tx_from,
    dexs.tx_to,
    dexs.evt_index
FROM dexs
LEFT JOIN {{ source('tokens', 'erc20') }} erc20a
    ON erc20a.contract_address = dexs.token_bought_address
    AND erc20a.blockchain = dexs.blockchain
LEFT JOIN {{ source('tokens', 'erc20') }} erc20b
    ON erc20b.contract_address = dexs.token_sold_address
    AND erc20b.blockchain = dexs.blockchain
INNER JOIN bpa
    ON bpa.block_number = dexs.block_number
    AND bpa.tx_hash = dexs.tx_hash
    AND bpa.evt_index = dexs.evt_index
LEFT JOIN {{ ref('balancer_bpt_prices') }} bpa_bpt_prices
    ON bpa_bpt_prices.contract_address = bpa.contract_address
    AND bpa_bpt_prices.blockchain = '{{ blockchain }}'
    AND bpa_bpt_prices.version = '3'
    AND bpa_bpt_prices.day = bpa.bpa_max_block_date
INNER JOIN bpb
    ON bpb.block_number = dexs.block_number
    AND bpb.tx_hash = dexs.tx_hash
    AND bpb.evt_index = dexs.evt_index
LEFT JOIN {{ ref('balancer_bpt_prices') }} bpb_bpt_prices
    ON bpb_bpt_prices.contract_address = bpb.contract_address
    AND bpb_bpt_prices.blockchain = '{{ blockchain }}'
    AND bpb_bpt_prices.version = '3'
    AND bpb_bpt_prices.day = bpb.bpb_max_block_date
LEFT JOIN {{ ref('balancer_v3_erc4626_token_prices') }} erc4626a
    ON erc4626a.wrapped_token = dexs.token_bought_address
    AND erc4626a.blockchain = '{{ blockchain }}'
    AND erc4626a.minute <= dexs.block_time
    AND dexs.block_time < erc4626a.next_change
LEFT JOIN {{ ref('balancer_v3_erc4626_token_prices') }} erc4626b
    ON erc4626b.wrapped_token = dexs.token_sold_address
    AND erc4626b.blockchain = '{{ blockchain }}'
    AND erc4626b.minute <= dexs.block_time
    AND dexs.block_time < erc4626b.next_change

{% endmacro %}

{# ######################################################################### #}

{% macro balancer_v1_enriched_trades(
    blockchain = 'ethereum',
    project_start_date = '2020-03-13'
) %}

WITH

swap_fees AS (
    SELECT * FROM (
        SELECT
            swaps.contract_address,
            swaps.evt_tx_hash,
            swaps.evt_block_time,
            swaps.evt_index,
            swaps.evt_block_number,
            fees.swapFee,
            ROW_NUMBER() OVER (PARTITION BY swaps.contract_address, evt_tx_hash, evt_index ORDER BY call_block_number DESC) AS row_num
        FROM {{ source('balancer_v1_' ~ blockchain, 'BPool_evt_LOG_SWAP') }} swaps
        LEFT JOIN {{ source('balancer_v1_' ~ blockchain, 'BPool_call_setSwapFee') }} fees
            ON fees.contract_address = swaps.contract_address
            AND fees.call_block_number < swaps.evt_block_number
        {% if is_incremental() or target.name == 'dev' %}
        WHERE {{ balancer_trades_dev_time_predicate('swaps.evt_block_time') }}
        {% endif %}
    ) t
    WHERE t.row_num = 1
),

pool_labels AS (
    SELECT
        address,
        name
    FROM {{ ref('labels_balancer_v1_pools_ethereum') }}
),

v1 AS (
    SELECT
        tokenOut AS token_bought_address,
        tokenAmountOut AS token_bought_amount_raw,
        tokenIn AS token_sold_address,
        tokenAmountIn AS token_sold_amount_raw,
        swaps.contract_address AS project_contract_address,
        l.name AS pool_symbol,
        (swapFee / 1e18) AS swap_fee_percentage,
        swaps.evt_block_time,
        swaps.evt_tx_hash,
        swaps.evt_index,
        swaps.evt_block_number
    FROM {{ source('balancer_v1_' ~ blockchain, 'BPool_evt_LOG_SWAP') }} swaps
    LEFT JOIN swap_fees fees
        ON fees.evt_tx_hash = swaps.evt_tx_hash
        AND fees.evt_block_number = swaps.evt_block_number
        AND fees.contract_address = swaps.contract_address
        AND fees.evt_index = swaps.evt_index
    LEFT JOIN pool_labels l
        ON l.address = swaps.contract_address
    WHERE 1 = 1
    {% if is_incremental() or target.name == 'dev' %}
        AND {{ balancer_trades_dev_time_predicate('swaps.evt_block_time') }}
    {% elif not is_incremental() %}
        AND swaps.evt_block_time >= TIMESTAMP '{{ project_start_date }}'
    {% endif %}
),

prices AS (
    SELECT *
    FROM {{ source('prices', 'usd') }}
    WHERE blockchain = '{{ blockchain }}'
    {% if is_incremental() or target.name == 'dev' %}
        AND {{ balancer_trades_dev_time_predicate('minute') }}
    {% elif not is_incremental() %}
        AND minute >= TIMESTAMP '{{ project_start_date }}'
    {% endif %}
)

SELECT
    '{{ blockchain }}' AS blockchain,
    'balancer' AS project,
    '1' AS version,
    CAST(date_trunc('day', evt_block_time) AS date) AS block_date,
    CAST(date_trunc('month', evt_block_time) AS date) AS block_month,
    evt_block_time AS block_time,
    trades.evt_block_number AS block_number,
    erc20a.symbol AS token_bought_symbol,
    erc20b.symbol AS token_sold_symbol,
    CASE
        WHEN lower(erc20a.symbol) > lower(erc20b.symbol) THEN concat(erc20b.symbol, '-', erc20a.symbol)
        ELSE concat(erc20a.symbol, '-', erc20b.symbol)
    END AS token_pair,
    token_bought_amount_raw / power(10, erc20a.decimals) AS token_bought_amount,
    token_sold_amount_raw / power(10, erc20b.decimals) AS token_sold_amount,
    CAST(token_bought_amount_raw AS UINT256) AS token_bought_amount_raw,
    CAST(token_sold_amount_raw AS UINT256) AS token_sold_amount_raw,
    coalesce(
        (token_bought_amount_raw / power(10, p_bought.decimals)) * p_bought.price,
        (token_sold_amount_raw / power(10, p_sold.decimals)) * p_sold.price
    ) AS amount_usd,
    token_bought_address,
    token_sold_address,
    tx."from" AS taker,
    CAST(NULL AS VARBINARY) AS maker,
    project_contract_address,
    CAST(NULL AS VARBINARY) AS pool_id,
    pool_symbol,
    'v1' AS pool_type,
    CAST(trades.swap_fee_percentage AS DOUBLE) AS swap_fee,
    evt_tx_hash AS tx_hash,
    tx."from" AS tx_from,
    tx.to AS tx_to,
    CAST(evt_index AS BIGINT) AS evt_index
FROM v1 trades
INNER JOIN {{ source(blockchain, 'transactions') }} tx
    ON trades.evt_tx_hash = tx.hash
    {% if is_incremental() or target.name == 'dev' %}
    AND {{ balancer_trades_dev_time_predicate('tx.block_time') }}
    {% elif not is_incremental() %}
    AND tx.block_time >= TIMESTAMP '{{ project_start_date }}'
    {% endif %}
LEFT JOIN {{ source('tokens', 'erc20') }} erc20a
    ON trades.token_bought_address = erc20a.contract_address
    AND erc20a.blockchain = '{{ blockchain }}'
LEFT JOIN {{ source('tokens', 'erc20') }} erc20b
    ON trades.token_sold_address = erc20b.contract_address
    AND erc20b.blockchain = '{{ blockchain }}'
LEFT JOIN prices p_bought
    ON p_bought.minute = date_trunc('minute', trades.evt_block_time)
    AND p_bought.contract_address = trades.token_bought_address
LEFT JOIN prices p_sold
    ON p_sold.minute = date_trunc('minute', trades.evt_block_time)
    AND p_sold.contract_address = trades.token_sold_address

{% endmacro %}

{# ######################################################################### #}

{% macro balancer_cowswap_amm_trades(blockchain = 'ethereum') %}

SELECT
    '{{ blockchain }}' AS blockchain,
    'balancer' AS project,
    '1' AS version,
    CAST(date_trunc('month', trade.evt_block_time) AS date) AS block_month,
    CAST(date_trunc('day', trade.evt_block_time) AS date) AS block_date,
    trade.evt_block_time AS block_time,
    trade.evt_block_number AS block_number,
    tb.symbol AS token_bought_symbol,
    ts.symbol AS token_sold_symbol,
    concat(ts.symbol, '-', tb.symbol) AS token_pair,
    (trade.buyAmount / power(10, COALESCE(pb.decimals, tb.decimals))) AS token_bought_amount,
    ((trade.sellAmount - trade.feeAmount) / power(10, COALESCE(ps.decimals, ts.decimals))) AS token_sold_amount,
    trade.buyAmount AS token_bought_amount_raw,
    trade.sellAmount AS token_sold_amount_raw,
    coalesce(
        trade.buyAmount / power(10, COALESCE(pb.decimals, tb.decimals)) * pb.price,
        trade.sellAmount / power(10, COALESCE(ps.decimals, ts.decimals)) * ps.price
    ) AS amount_usd,
    trade.buyToken AS token_bought_address,
    trade.sellToken AS token_sold_address,
    CAST(NULL AS VARBINARY) AS taker,
    CAST(NULL AS VARBINARY) AS maker,
    pool.bPool AS pool_id,
    (trade.feeAmount / power(10, ts.decimals)) AS swap_fee,
    pool.bPool AS project_contract_address,
    p.name AS pool_symbol,
    'balancer_cowswap_amm' AS pool_type,
    trade.evt_tx_hash AS tx_hash,
    settlement.solver AS tx_from,
    trade.contract_address AS tx_to,
    trade.evt_index AS evt_index
FROM {{ source('gnosis_protocol_v2_' ~ blockchain, 'GPv2Settlement_evt_Trade') }} trade
INNER JOIN {{ source('b_cow_amm_' ~ blockchain, 'BCoWFactory_evt_LOG_NEW_POOL') }} pool
    ON trade.owner = pool.bPool
LEFT JOIN {{ source('prices', 'usd') }} AS ps
    ON trade.sellToken = ps.contract_address
    AND ps.minute = date_trunc('minute', trade.evt_block_time)
    AND ps.blockchain = '{{ blockchain }}'
    {% if is_incremental() %}
    AND {{ incremental_predicate('ps.minute') }}
    {% endif %}
LEFT JOIN {{ source('prices', 'usd') }} AS pb
    ON pb.contract_address = trade.buyToken
    AND pb.minute = date_trunc('minute', trade.evt_block_time)
    AND pb.blockchain = '{{ blockchain }}'
    {% if is_incremental() %}
    AND {{ incremental_predicate('pb.minute') }}
    {% endif %}
LEFT JOIN {{ source('tokens', 'erc20') }} AS ts
    ON trade.sellToken = ts.contract_address
    AND ts.blockchain = '{{ blockchain }}'
LEFT JOIN {{ source('tokens', 'erc20') }} AS tb
    ON trade.buyToken = tb.contract_address
    AND tb.blockchain = '{{ blockchain }}'
LEFT JOIN {{ source('gnosis_protocol_v2_' ~ blockchain, 'GPv2Settlement_evt_Settlement') }} AS settlement
    ON trade.evt_tx_hash = settlement.evt_tx_hash
LEFT JOIN (
    SELECT
        address,
        name
    FROM {{ source('labels', 'balancer_cowswap_amm_pools') }}
    WHERE blockchain = '{{ blockchain }}'
) p
    ON p.address = trade.owner
{% if is_incremental() or target.name == 'dev' %}
WHERE {{ balancer_trades_dev_time_predicate('trade.evt_block_time') }}
{% endif %}

{% endmacro %}

{# ######################################################################### #}

{% macro balancer_trades_union(trade_models) %}

SELECT *
FROM (
    {% for model in trade_models %}
    SELECT
        blockchain,
        project,
        version,
        block_month,
        block_date,
        block_time,
        block_number,
        token_bought_symbol,
        token_sold_symbol,
        token_pair,
        token_bought_amount,
        token_sold_amount,
        token_bought_amount_raw,
        token_sold_amount_raw,
        amount_usd,
        token_bought_address,
        token_sold_address,
        taker,
        maker,
        pool_id,
        swap_fee,
        project_contract_address,
        pool_symbol,
        pool_type,
        tx_hash,
        tx_from,
        tx_to,
        evt_index
    FROM {{ model }}
    {% if not loop.last %}
    UNION ALL
    {% endif %}
    {% endfor %}
)

{% endmacro %}
