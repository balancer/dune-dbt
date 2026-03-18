{% set blockchain = 'base' %}

{{
    config(
        alias = 'balancer_v3_base_erc4626_token_mapping',
        materialized = 'table'
    )
}}

WITH vault_mappings AS (
    SELECT DISTINCT
        evt_tx_hash,
        wrappedToken AS vault_address,
        amountUnderlying
    FROM {{ source('balancer_v3_' ~ blockchain, 'Vault_evt_LiquidityAddedToBuffer') }} b
    WHERE b.amountUnderlying > 0
),

underlying_tokens AS (
    SELECT DISTINCT
        vm.vault_address,
        t.contract_address AS underlying_address,
        vm.evt_tx_hash
    FROM vault_mappings vm
    JOIN {{ source('erc20_' ~ blockchain, 'evt_Transfer') }} t
      ON t.evt_tx_hash = vm.evt_tx_hash
     AND t.contract_address != vm.vault_address
     AND t.value = vm.amountUnderlying
     AND t.to = 0xba1333333333a1ba1108e8412f11850a5c319ba9
)

SELECT DISTINCT
    '{{ blockchain }}' AS blockchain,
    ut.vault_address AS erc4626_token,
    COALESCE(vault_token.name, 'Unknown Vault') AS erc4626_token_name,
    COALESCE(vault_token.symbol, 'Unknown') AS erc4626_token_symbol,
    ut.underlying_address AS underlying_token,
    COALESCE(underlying_token.symbol, 'Unknown') AS underlying_token_symbol,
    vault_token.decimals AS decimals
FROM underlying_tokens ut
LEFT JOIN {{ source('tokens', 'erc20') }} vault_token
  ON vault_token.contract_address = ut.vault_address
 AND vault_token.blockchain = '{{ blockchain }}'
LEFT JOIN {{ source('tokens', 'erc20') }} underlying_token
  ON underlying_token.contract_address = ut.underlying_address
 AND underlying_token.blockchain = '{{ blockchain }}'
