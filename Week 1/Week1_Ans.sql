use dannys_diner;

-- 1. What is the total amount each customer spent at the restaurant?
select customer_id, sum(price) 
from menu join sales on menu.product_id = sales.product_id 
group by customer_id;

-- 2. How many days has each customer visited the restaurant?
select customer_id, count(distinct order_date) 
from sales 
group by customer_id;

-- 3. What was the first item from the menu purchased by each customer?
with cte_sales as 
	(select customer_id, min(order_date) as first_order_date 
	from sales group by customer_id)  
select distinct sales.customer_id, order_date, product_name 
from sales join cte_sales on sales.customer_id = cte_sales.customer_id 
	   join menu on menu.product_id = sales.product_id 
where order_date = first_order_date;

select customer_id, order_date, group_concat(distinct product_name) as product_name
from (select customer_id, order_date, product_id, 
	     dense_rank() over(partition by customer_id order by order_date) as ranking 
      from sales) as T join menu on T.product_id = menu.product_id
where ranking = 1 
group by customer_id, order_date;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
select product_name, count(sales.product_id) as order_amount
from sales join menu on menu.product_id = sales.product_id 
group by product_name 
order by count(sales.product_id) desc 
limit 1;

-- 5. Which item was the most popular for each customer?
with cte_sales as 
	(select customer_id, product_name, rank() over(partition by customer_id order by count(product_name)) as ranking 
	from sales join menu on sales.product_id = menu.product_id 
	group by customer_id, product_name) 
select customer_id, 
	group_concat(distinct product_name order by product_name) as product_name 
from cte_sales 
where ranking = 1 
group by customer_id;

-- 6. Which item was purchased first by the customer after they became a member?
select customer_id, join_date, order_date, product_name 
from (select sales.customer_id, join_date, order_date, product_id,
	     dense_rank() over(partition by sales.customer_id order by order_date asc) as ranking 
      from sales left join members on sales.customer_Id =  members.customer_id 
      where members.customer_id is not null and order_date >= join_date) as T join menu on menu.product_id = T.product_id 
where ranking = 1 
order by customer_id;

-- 7. Which item was purchased just before the customer became a member?
select customer_id, join_date, order_date, 
       group_concat(distinct product_name order by product_name) as product_name
from (select sales.customer_id, join_date, order_date, product_id, 
	     dense_rank() over(partition by sales.customer_id order by order_date desc) as ranking 
	from sales left join members on sales.customer_Id =  members.customer_id 
	where members.customer_id is not null and order_date < join_date) as T join menu on menu.product_id = T.product_id 
where ranking = 1 
group by customer_id, join_date, order_date 
order by customer_id;

-- 8. What is the total items and amount spent for each member before they became a member?
select customer_id, count(customer_id) as total_items, 
	concat('$', sum(price)) as total_spent 
from (select sales.customer_id, join_date, order_date, product_id 
	from sales left join members on sales.customer_Id =  members.customer_id
	where members.customer_id is not null and order_date < join_date) as T join menu on T.product_id = menu.product_id 
group by customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
select customer_id, 
	sum(case 
	        when sales.product_id = '1' then price * 20 
	        else price * 10 
	    end) as total_points 
from sales join menu on sales.product_id = menu.product_id 
group by customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
select sales.customer_id,  
	sum(case
	        when order_date between join_date and date_add(join_date, interval 6 day) then price * 20
	        when sales.product_id = '1' then price * 20
	        else price * 10
	    end) as total_points
from sales join menu on sales.product_id = menu.product_id
	   join members on sales.customer_id = members.customer_id 
where month(order_date) = 1 
group by sales.customer_id
order by sales.customer_id;id

-- bonus1. Join All The Things
select sales.customer_id, order_date, product_name, price, 
	(case 
	     when order_date >= join_date then 'Y' 
	     else 'N' 
	 end) as member 
from sales left join members on sales.customer_id = members.customer_id
	   join menu on menu.product_id = sales.product_id;

-- bonus2. Rank All The Things
with cte_all as 
	(select sales.customer_id, order_date, product_name, price, 
	      (case 
	          when order_date >= join_date then 'Y' 
	          else 'N' 
	      end) as member 
	from sales left join members on sales.customer_id = members.customer_id
	           join menu on menu.product_id = sales.product_id)
select *, 
	case 
	    when member = 'N' then null 
	    else dense_rank() over(partition by customer_id, member order by order_date asc) 
	end as ranking 
from cte_all;