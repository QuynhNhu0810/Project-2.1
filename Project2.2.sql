--Create metric--
create view bigquery-public-data.thelook_ecommerce.vw_ecommerce_analyst as
with cte as(
select 
 format_date('%Y-%m', o.created_at) as Month
,format_date('%Y', o.created_at) as Year
,p.category as Product_category
,sum(sale_price) as TPV
,count(oi.order_id) as TPO
,sum(cost) as Total_cost
from bigquery-public-data.thelook_ecommerce.orders as o
inner join bigquery-public-data.thelook_ecommerce.order_items as oi
on o.order_id = oi.order_id
inner join bigquery-public-data.thelook_ecommerce.products as p
on p.id = oi.product_id 
group by 1,2,3
order by 1,2)

,cte2 as(
select *
,lag(TPV) over(partition by Month order by Month) as next_rev
,lag(TPO) over(partition by Month order by Month) as next_order
,TPV-TPO as Total_profit
from cte
)

 select Month,Year,Product_category,TPV,TPO,Total_cost,Total_profit
,concat(round((next_rev - TPV)/TPV*100.0,2),"%") as Revenue_growth
,concat(round((next_order - TPO)/TPO*100.0,2),"%") as Order_growth
,round(Total_profit/Total_cost,2) as Profit_to_cost_ratio 
from cte2
  

--Retention cohort analysis--
WITH cte AS (
  SELECT
    order_id,
    user_id,
    created_at
  FROM (
    SELECT
      order_id,
      user_id,
      created_at,
      ROW_NUMBER() OVER (PARTITION BY order_id, user_id ORDER BY created_at) AS dup_order
    FROM
      bigquery-public-data.thelook_ecommerce.orders
    WHERE
      user_id IS NOT NULL
  )
  WHERE
    dup_order = 1
)

,cus_index as(
select
  user_id, 
  format_date('%Y-%m', first_purchase_date) as cohort_date,
	created_at,
	(extract(year from created_at)-extract(year from first_purchase_date))*12
	+(extract(month from created_at)-extract(month from first_purchase_date))+1 as index
FROM(
	SELECT user_id,
  MIN(created_at) over(PARTITION BY user_id) as first_purchase_date,
created_at
from cte
) a)
  
,analysis as(
select 
cohort_date,
index,
count(distinct user_id) as cnt
from cus_index
where index between 1 and 4
group by cohort_date, index
order by 1)

select *,
concat(round((cnt / FIRST_VALUE(cnt) OVER (PARTITION BY cohort_date ORDER BY index)),2) * 100.0,"%") AS retention_rate 
from analysis
