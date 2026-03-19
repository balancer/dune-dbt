{{ config(
    alias = 'v3_pools_fees'
    , materialized = 'view'
    , post_hook='{{ hide_spells() }}'
    )
}}

{% set balancer_models = [
    ref('balancer_v3_ethereum_pools_fees'),
    ref('balancer_v3_gnosis_pools_fees'),
    ref('balancer_v3_arbitrum_pools_fees'),
    ref('balancer_v3_base_pools_fees'),
    ref('balancer_v3_avalanche_c_pools_fees'),
    ref('balancer_v3_hyperevm_pools_fees'),
    ref('balancer_v3_monad_pools_fees')
] %}

SELECT *
FROM (
    {% for model in balancer_models %}
    SELECT
        blockchain
      , version
      , pool_address
      , pool_id
      , tx_hash
      , tx_index
      , index
      , block_time
      , block_number
      , swap_fee_percentage
    FROM {{ model }}
    {% if not loop.last %}
    UNION ALL
    {% endif %}
    {% endfor %}
)
