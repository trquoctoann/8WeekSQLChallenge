use pizza_runner;

																	-- Cleaning Data
create table customer_orders_cleaned as
select order_id, customer_id, pizza_id, 
    case
		when exclusions like '' or exclusions like 'null' then null
		else exclusions
    end as exclusions,
    case
		when extras like '' or extras like 'null' then null
		else extras
    end as extras,
	order_time
from customer_orders;

create table runner_orders_cleaned as
select order_id, runner_id,  
    case
		when pickup_time like 'null' then null
		else pickup_time
    end as pickup_time,
    case
		when distance like 'null' then null
		when distance like '%km' then trim('km' from distance)
		else distance 
    end as distance,
    case
		when duration like 'null' then null
		when duration like '%mins' then trim('mins' from duration)
		when duration like '%minute' then trim('minute' from duration)
		when duration like '%minutes' then trim('minutes' from duration)
		else duration
    end as duration,
    case
		when cancellation like '' or cancellation like 'null' then null
		else cancellation
    end as cancellation
from runner_orders;

alter table runner_orders_cleaned modify pickup_time timestamp;
alter table runner_orders_cleaned modify distance float;
alter table runner_orders_cleaned modify duration int;
-- 											A. Pizza Metrics
-- 1. How many pizzas were ordered?
select count(*) as pizza_amount 
from customer_orders;

-- 2. How many unique customer orders were made?
select count(distinct order_id) as unique_order 
from customer_orders;

-- 3. How many successful orders were delivered by each runner?
select runner_id, count(*) as successful_times 
from runner_orders_cleaned 
where pickup_time is not null 
group by runner_id;

-- 4. How many of each type of pizza was delivered?
select C.pizza_id, pizza_name, count(C.pizza_id) as amount 
from customer_orders_cleaned as C join runner_orders_cleaned as R on C.order_id = R.order_id 
	                          join pizza_names as P on C.pizza_id = P.pizza_id 
where pickup_time is not null group by C.pizza_id, pizza_name;

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?
select customer_id,
	SUM(CASE WHEN C.pizza_id = 1 THEN 1 ELSE 0 END) AS Meatlovers,
	SUM(CASE WHEN C.pizza_id = 2 THEN 1 ELSE 0 END) AS Vegetarian
from customer_orders_cleaned as C join runner_orders_cleaned as R on C.order_id = R.order_id 
	                          join pizza_names as P on C.pizza_id = P.pizza_id 
group by customer_id
order by customer_id;

-- 6. What was the maximum number of pizzas delivered in a single order?
select max(pizza_count) 
from (select order_id, count(*) as pizza_count 
      from customer_orders_cleaned 
      group by order_id) as C;

-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
select customer_id,
       sum(case
               when exclusions is not null or extras is not null then 1
               else 0
           end) as pizza_changed,
       sum(case
               when exclusions is not null or extras is not null then 0
               else 1
           end) as pizza_not_changed
from runner_orders_cleaned as R join customer_orders_cleaned as C on R.order_id = C.order_id
where pickup_time is not null
group by customer_id
order by customer_id;

-- 8. How many pizzas were delivered that had both exclusions and extras?
select count(pizza_id) as pizza_exclusions_extra
from customer_orders_cleaned as C join runner_orders_cleaned as R on C.order_id = R.order_id 
where pickup_time is not null and exclusions is not null and extras is not null;

-- 9. What was the total volume of pizzas ordered for each hour of the day?
select hour(order_time) as order_time, count(pizza_id) as amount 
from customer_orders_cleaned 
group by hour(order_time) 
order by order_time;

-- 10. What was the volume of orders for each day of the week?
select dayname(order_time) as order_date, count(pizza_id) as amount 
from customer_orders_cleaned 
group by dayname(order_time) 
order by order_date;


-- 																			B. Runner and Customer Experience
-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
select week(registration_date) as week_period, count(*) as runner_amount
from runners 
where registration_date >= '2021-01-01' 
group by week(registration_date);

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
with cte_minutes as 
	(select distinct C.order_id, 
	        order_time, 
	        pickup_time, 
	        timestampdiff(minute, order_time, pickup_time) as minutes, 
	        runner_id 
	from customer_orders_cleaned as C join runner_orders_cleaned as R on C.order_id = R.order_id 
	where pickup_time is not null) 
select runner_id, avg(minutes) as avg_minutes
from cte_minutes 
group by runner_id;

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
with cte_minutes as
	(select C.order_id, 
	        order_time, pickup_time, 
	        timestampdiff(minute, order_time, pickup_time) as minutes, 
	        count(C.order_id) as number_pizza 
	from customer_orders_cleaned as C join runner_orders_cleaned as R on C.order_id = R.order_id  
	where pickup_time is not null 
	group by C.order_id, order_time, pickup_time, minutes)  
select number_pizza, avg(minutes) 
from cte_minutes 
group by number_pizza;

-- 4. What was the average distance travelled for each customer?
select customer_id, round(avg(distance), 1) as avg_distance 
from customer_orders_cleaned as C join runner_orders_cleaned as R on C.order_id = R.order_id
group by customer_id;

-- 5. What was the difference between the longest and shortest delivery times for all orders?
select max(duration) - min(duration) as difference 
from runner_orders_cleaned;

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
select runner_id, C.order_id, distance, duration, 
	round(distance/(duration/60), 1) as avg_speed, 
	count(C.order_id) as pizza_number 
from runner_orders_cleaned as R join customer_orders_cleaned as C on R.order_id = C.order_id 
where pickup_time is not null
group by runner_id, C.order_id, distance, duration, avg_speed
order by runner_id;

-- 7. What is the successful delivery percentage for each runner?
select runner_id, 
	sum(case when pickup_time is not null then 1 else 0 end) as success, 
	sum(case when pickup_time is not null then 0 else 1 end) as cancel, 
	round(sum(case when pickup_time is not null then 1 else 0 end) / count(order_id), 2) as percentage 
from runner_orders_cleaned 
group by runner_id;


-- 																		C. Ingredient Optimisation
-- 1. What are the standard ingredients for each pizza?
SELECT 
  pr.pizza_id,
  TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(pr.toppings, ',', numbers.n), ',', -1)) AS topping_id,
  pt.topping_name
FROM
  (SELECT 1 n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8) numbers
  JOIN pizza_recipes pr ON CHAR_LENGTH(pr.toppings) - CHAR_LENGTH(REPLACE(pr.toppings, ',', '')) >= numbers.n - 1
  JOIN pizza_toppings pt ON TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(pr.toppings, ',', numbers.n), ',', -1)) = pt.topping_id
ORDER BY pizza_id;

select * from pizza_recipes;

SELECT 
  SUBSTRING_INDEX(SUBSTRING_INDEX('1,2,3,4,5', ',', n), ',', -1) as number
FROM 
  (SELECT 1 as n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5) numbers
WHERE 
  n <=  LENGTH('1,2,3,4,5') - LENGTH(REPLACE('1,2,3,4,5', ',', '')) + 1;

-- 2. What was the most commonly added extra?
select * from customer_orders_cleaned;
show tables;
select * from pizza_names;
-- 3. What was the most common exclusion?
-- 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
-- 	  Meat Lovers
-- 	  Meat Lovers - Exclude Beef
-- 	  Meat Lovers - Extra Bacon
-- 	  Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
-- 5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
-- 	For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"
-- 6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

-- 																		D. Pricing and Ratings
-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?


-- 2. What if there was an additional $1 charge for any pizza extras?
-- 	Add cheese is $1 extra
-- 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.
-- 4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
-- 	customer_id
-- 	order_id
-- 	runner_id
-- 	rating
-- 	order_time
-- 	pickup_time
-- 	Time between order and pickup
-- 	Delivery duration
-- 	Average speed
-- 	Total number of pizzas
-- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?

-- bonus. If Danny wants to expand his range of pizzas - how would this impact the existing data design? Write an INSERT statement to demonstrate what would happen if a new Supreme pizza with all the toppings was added to the Pizza Runner menu?

