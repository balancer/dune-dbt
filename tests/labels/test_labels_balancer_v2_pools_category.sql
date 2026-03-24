-- This test fails if any v2 pool label is emitted with the wrong category.
select
  blockchain,
  address,
  category
from {{ ref('labels_balancer_v2_pools') }}
where category <> 'balancer_v2_pool'
limit 1
