use foodie_fi;

--                                                                              A. Customer Journey
-- Based off the 8 sample customers provided in the sample from the subscriptions table, write a brief description about each customer’s onboarding journey.
select customer_id, s.plan_id, plan_name, price, start_date
from subscriptions s join plans p on s.plan_id = p.plan_id
where customer_id in (select customer_id from  (select distinct customer_id 
                                                from subscriptions 
                                                order by customer_id asc
                                                limit 8) as sub);

-- Customer 1 signed up to 7-day free trial on 01/08/2020. 
-- After that time, he/she didn't cancel the subsciption, so the system automatically upgraded it to basic monthly plan on 08/08/2020.

-- Customer 2 signed up to 7-day free trial on 20/09/2020. 
-- After that time, he/she upgraded to pro annual plan on 27/09/2020.

-- Customer 3 signed up to 7-day free trial on 13/01/2020. 
-- After that time, he/she didn't cancel the subsciption, so the system automatically upgraded it to basic monthly plan on 20/01/2020.

-- Customer 4 signed up to 7-day free trial on 17/01/2020. 
-- After that time, he/she didn't cancelled the subsciption, so the system automatically upgraded it to basic monthly plan on 24/01/2020. 
-- He/she continued using that plan for about 3 months till 21/04/2020 when he/she cancelled the subscription.

-- Customer 5 signed up to 7-day free trial on 03/08/2020. 
-- After that time, he/she didn't cancel the subsciption, so the system automatically upgraded it basic monthly plan on 10/08/2020.

-- Customer 6 signed up to 7-day free trial on 23/12/2020. 
-- After that time, he/she didn't cancelled the subsciption, so the system automatically upgraded it to basic monthly plan on 30/12/2020. 
-- He/she continued using that plan for about 3 months till 26/02/2021 when he/she cancelled the subscription.

-- Customer 7 signed up to 7-day free trial on 05/02/2020. 
-- After that time, he/she didn't cancelled the subsciption, so the system automatically upgraded it to basic monthly plan on 12/02/2020. 
-- After 3 months using that plan, he/she upgraded to pro annual plan on 22/05/2020.

-- Customer 8 signed up to 7-day free trial on 11/06/2020. 
-- After that time, he/she didn't cancelled the subsciption, so the system automatically upgraded it to basic monthly plan on 18/06/2020. 
-- After 1.5 months using that plan, he/she upgraded to pro annual plan on 03/08/2020.

--                                                                          B. Data Analysis Questions
-- 1. How many customers has Foodie-Fi ever had?
select count(distinct customer_id) as count_customers
from subscriptions;

-- 2. What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
select month(start_date) as Month, count(*) as distribution_values
from subscriptions
where plan_id = '0'
group by month(start_date)
order by Month;

-- 3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
select plan_name, count(plan_name) as counts
from plans p join subscriptions s on p.plan_id = s.plan_id
where year(start_date) > 2020
group by plan_name;

-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
select count(distinct customer_id) as count,
       round(count(distinct customer_id) / (select count(distinct customer_id) from subscriptions) * 100, 1) as percentage
from subscriptions
where plan_id = '4'
group by plan_id;

-- 5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
with cte_plan as (select customer_id, group_concat(distinct plan_id) as plan
                  from subscriptions
                  group by customer_id)
select  count(*), 
        round((count(*) / (select count(distinct customer_id) from subscriptions) * 100), 0) as percentage
from cte_plan
where plan like '%0,4%';

-- 6. What is the number and percentage of customer plans after their initial free trial?
with cte_next_plan as (select customer_id, p.plan_id, LEAD(p.plan_name) OVER(PARTITION BY customer_id ORDER BY p.plan_id) AS next_plan
                       from subscriptions s JOIN plans p ON s.plan_id = p.plan_id
                       where customer_id in (select customer_id from subscriptions where plan_id = '0'))
select  next_plan, 
        count(c.plan_id) as count_plan,
        round((count(c.plan_id) / (select count(distinct customer_id) from subscriptions) * 100), 1) as percentage
from cte_next_plan c join plans p on c.plan_id = p.plan_id
where c.plan_id = '0' and next_plan is not NULL
group by next_plan;

-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
-- 8. How many customers have upgraded to an annual plan in 2020?
-- 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
-- 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
-- 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?

--                                                                          C. Challenge Payment Question
-- The Foodie-Fi team wants you to create a new payments table for the year 2020 that includes amounts paid by each customer in the subscriptions table with the following requirements:
--      monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
--      upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
--      upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
--      once a customer churns they will no longer make payments

--                                                                          D. Outside The Box Questions
-- 1. How would you calculate the rate of growth for Foodie-Fi?
-- 2. What key metrics would you recommend Foodie-Fi management to track over time to assess performance of their overall business?
-- 3. What are some key customer journeys or experiences that you would analyse further to improve customer retention?
-- 4. If the Foodie-Fi team were to create an exit survey shown to customers who wish to cancel their subscription, what questions would you include in the survey?
-- 5. What business levers could the Foodie-Fi team use to reduce the customer churn rate? How would you validate the effectiveness of your ideas?
