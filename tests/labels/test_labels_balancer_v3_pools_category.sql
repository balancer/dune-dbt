-- This test fails if any v3 pool label is emitted with the wrong category.
select
  blockchain,
  address,
  category
from {{ ref('labels_balancer_v3_pools') }}
where category <> 'balancer_v3_pool'
limit 1
