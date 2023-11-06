--1.Số lượng đơn hàng và số lượng khách hàng mỗi tháng
select format_date('%Y-%m', created_at) as month_year
,count(user_id) as total_user
,count(order_id) as total_order
from bigquery-public-data.thelook_ecommerce.orders
where date(created_at) between '2019-01-01' and '2022-04-30'
group by 1
order by 1
--Nxet: Số lượng khách hàng và đơn hàng đều tăng dần theo thời gian từ 24 đơn vị vào đầu năm 2019 đến xấp xỉ 2400 đơn vị ở t4/2022

--2. Giá trị đơn hàng trung bình (AOV) và số lượng khách hàng mỗi tháng
select format_date('%Y-%m', created_at) as month_year
,count(distinct user_id) as distinct_users
,round(avg(sale_price),2) as average_order_value
from bigquery-public-data.thelook_ecommerce.order_items 
where date(created_at) between '2019-01-01' and '2022-04-30'
group by 1
order by 1
--Nxet: Số lượng người dùng khác nhau có xu hướng tăng dần theo thời gian từ 24 đến gần 2400 người. Còn giá trị đơn hàng trung bình không thay đổi nhiều theo tgian, dao động từ 50-70.

--3. Nhóm khách hàng theo độ tuổi
with young as (
select first_name,last_name,gender,age,
"youngest" as tag
from bigquery-public-data.thelook_ecommerce.users
where age = (
select min(age) 
from bigquery-public-data.thelook_ecommerce.users
where date(created_at) between '2019-01-01' and '2022-04-30'
)
),

old as (
select first_name,last_name,gender,age,
"oldest" as tag
from
bigquery-public-data.thelook_ecommerce.users
where age = ( 
select max(age) 
from bigquery-public-data.thelook_ecommerce.users
where date(created_at) between '2019-01-01' and '2022-04-30'
)
)

,cte as(
select * from young
union all
select * from old
)

select sum (case when tag = 'youngest' and gender = 'F' then 1 else 0 end) as youngF
,sum (case when tag = 'youngest' and gender = 'M' then 1 else 0 end) as youngM
,sum (case when tag = 'oldest' and gender = 'M' then 1 else 0 end) as oldM
,sum (case when tag = 'oldest' and gender = 'F' then 1 else 0 end) as oldF
from cte
--Nxet: Đối với cả nam lẫn nữ, KH trẻ nhất là 12 tuổi và lớn nhất là 70 tuổi. Nữ có 609 khách trẻ tuổi nhất,trong khi nam chỉ có 567 người 12 tuổi. Tương tự, nữ có 569 người ở độ tuổi 70, còn nam ít hơn với 567 người.

--4.Top 5 sản phẩm mỗi tháng.
with cte as (
select format_date('%Y-%m', o.created_at) as month_year
,product_id
,name as product_name
,sum(retail_price) as sale
,sum(cost) as cost
,sum(retail_price-cost) as profit
from bigquery-public-data.thelook_ecommerce.order_items as o
inner join bigquery-public-data.thelook_ecommerce.products as p
on p.id = o.product_id 
where date(created_at) between '2019-01-01' and '2022-04-30'
group by 1,2,3)

,cte2 as(
select *,
dense_rank() over (partition by month_year order by profit desc) as rank_per_month
from cte
)

select *
from cte2
where rank_per_month <=5
order by month_year,rank_per_month

--5.Doanh thu tính đến thời điểm hiện tại trên mỗi danh mục
select date(created_at) as dates
,p.category as product_categories
,sum(sale_price) as revenue
from bigquery-public-data.thelook_ecommerce.order_items as o
inner join bigquery-public-data.thelook_ecommerce.products as p
on p.id = o.product_id 
where date(created_at) > date_sub("2022-04-15", interval 3 month) 
group by 1,2
order by 1


