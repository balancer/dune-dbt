{{ config(
    alias = 'balancer_bpt_supply_changes_daily'
    , post_hook='{{ hide_spells() }}'
    )
}}

{% set balancer_models = [
    ref('balancer_v3_ethereum_bpt_supply_changes_daily'),
    ref('balancer_v3_gnosis_bpt_supply_changes_daily'),
    ref('balancer_v3_arbitrum_bpt_supply_changes_daily'),
    ref('balancer_v3_base_bpt_supply_changes_daily')
] %}

SELECT *
FROM (
    {% for model in balancer_models %}
    SELECT
        block_date
      , blockchain
      , pool_type
      , pool_symbol
      , version
      , token_address
      , daily_delta
    FROM {{ model }}
    {% if not loop.last %}
    UNION ALL
    {% endif %}
    {% endfor %}
)
