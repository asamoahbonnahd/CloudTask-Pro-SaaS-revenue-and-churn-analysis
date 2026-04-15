SELECT *
FROM subscriptions  ;

SELECT *
FROM monthly_revenue ;

-- What is the overall churn rate

SELECT ROUND(SUM(CASE WHEN churn_status = 'yes' THEN 1 ELSE 0 END) /COUNT(*) * 100.0, 2) AS churn_rate_pct
FROM subscriptions ;


-- how has the monthly churn rate trended over the past 4 years?

SELECT LEFT(month_, 4) AS year_, ROUND(AVG(monthly_churn_rate_pct), 2) AS monthly_churn_rate_over_the_years
FROM monthly_revenue
GROUP BY year_ ;


-- Which subscription plan (Starter, Professional, Business, Enterprise) has the highest churn rate?

SELECT plan, churn_status, CASE WHEN churn_status = 'yes' THEN 1 ELSE 0 END
FROM subscriptions ;

SELECT plan, ROUND(AVG(CASE WHEN churn_status = 'yes' THEN 1 ELSE 0 END) * 100, 2) AS churn_rate_in_thier_plan
FROM subscriptions
GROUP BY plan
ORDER BY churn_rate_in_thier_plan DESC ;


-- Does billing cycle (monthly vs. annual) significantly impact retention?

SELECT billing_cycle, ROUND(AVG(CASE WHEN churn_status = 'yes' THEN 1 ELSE 0 END) * 100, 2) AS churn_rate_pct
FROM subscriptions
GROUP BY billing_cycle;


-- What's the churn Rate in Acquisition Channels

SELECT acquisition_channel, ROUND(AVG(CASE WHEN churn_status = 'Yes' THEN 1 ELSE 0 END) * 100, 2) AS churn_rate_pct
FROM subscriptions
GROUP BY acquisition_channel
ORDER BY churn_rate_pct DESC;


--  What's the churn rate in Company Sizes

SELECT company_size, ROUND(AVG(CASE WHEN churn_status = 'Yes' THEN 1 ELSE 0 END) * 100, 2) AS churn_rate_pct
FROM subscriptions
GROUP BY company_size
ORDER BY churn_rate_pct DESC;


-- What are the top 3 reasons customers churn 

SELECT churn_reason, COUNT(churn_reason)
FROM subscriptions
WHERE churn_reason <> ''
GROUP BY churn_reason
ORDER BY COUNT(churn_reason) DESC
LIMIT 3 ;


-- do these reasons differ by plan type and company size?

SELECT plan, churn_reason, COUNT(churn_reason) AS reason_count
FROM subscriptions
WHERE churn_reason <> ''
GROUP BY plan, churn_reason
ORDER BY plan, reason_count DESC ;

SELECT company_size, churn_reason, COUNT(churn_reason) AS reason_count 
FROM subscriptions
WHERE churn_reason <> ''
GROUP BY company_size, churn_reason
ORDER BY company_size, reason_count DESC ;


-- Calculate the average Customer Lifetime Value (CLV) by plan

-- avg monthly recuring revenue

SELECT plan, ROUND(AVG(monthly_revenue), 2) AS avg_mrr
FROM subscriptions
GROUP BY plan  ;


-- avg_lifespand_in_months

SELECT plan, ROUND(AVG(DATEDIFF(churn_date, signup_date)/30.0), 2) AS avg_lifespand_months
FROM subscriptions
WHERE churn_status = 'Yes'
GROUP BY plan ;


-- multiplying avg_mmr by avg_lifespand_months to find Customer Lifetime Value (CLV) per plan

SELECT m.plan, avg_mrr, avg_lifespand_months, ROUND(avg_mrr * avg_lifespand_months, 2) AS clv
FROM (SELECT plan, ROUND(AVG(DATEDIFF(churn_date, signup_date)/30.0), 2) AS avg_lifespand_months
        FROM subscriptions
        WHERE churn_status = 'Yes'
        GROUP BY plan) AS m

JOIN (SELECT plan, ROUND(AVG(monthly_revenue), 2) AS avg_mrr
    FROM subscriptions
    GROUP BY plan) AS l
ON m.plan = l.plan 
order by clv desc ;


--  Compare this to the Customer Acquisition Cost (CAC). Which plans are the most and least profitable?

SELECT ROUND(AVG(customer_acquisition_cost), 2) AS avg_customer_acquisition_cost
FROM monthly_revenue ;

SELECT m.plan, ROUND(avg_mrr * avg_lifespand_months, 2) AS clv, ROUND(ROUND(avg_mrr * avg_lifespand_months, 2)/200.04, 2)
	AS CLV_CAC_Ratio
FROM (SELECT plan, ROUND(AVG(DATEDIFF(churn_date, signup_date)/30.0), 2) AS avg_lifespand_months
        FROM subscriptions
        WHERE churn_status = 'Yes'
        GROUP BY plan) AS m
JOIN (SELECT plan, ROUND(AVG(monthly_revenue), 2) AS avg_mrr
    FROM subscriptions
    GROUP BY plan) AS l
ON m.plan = l.plan 
ORDER BY CLV_CAC_Ratio desc ;


-- Calculate net revenue retention by months (new MRR minus churned MRR)

SELECT month_,
    ROUND(new_customers * avg_revenue_per_customer, 2) AS new_mrr,
    ROUND(churned_customers * avg_revenue_per_customer, 2) AS churned_mrr,
    ROUND((new_customers * avg_revenue_per_customer) - (churned_customers * avg_revenue_per_customer), 2) AS net_revenue_retention
FROM monthly_revenue
ORDER BY month_ ;


-- Identify months with unusual spikes or dips

SELECT month_,
    ROUND(new_customers * avg_revenue_per_customer, 2) AS new_mrr,
    ROUND(churned_customers * avg_revenue_per_customer, 2) AS churned_mrr,
    ROUND((new_customers * avg_revenue_per_customer) - (churned_customers * avg_revenue_per_customer), 2) AS net_revenue_retention,
    ROUND(total_mrr - LAG(total_mrr) OVER (ORDER BY month_), 2) AS mrr_change
FROM monthly_revenue
ORDER BY month_ ;


-- Feature Usage vs Churn rate

SELECT CASE 
        WHEN feature_usage_pct < 20 THEN '0–19%'
        WHEN feature_usage_pct < 40 THEN '20–39%'
        WHEN feature_usage_pct < 60 THEN '40–59%'
        WHEN feature_usage_pct < 80 THEN '60–79%'
        ELSE '80–100%' END AS usage_bucket, 
     ROUND(AVG(CASE WHEN churn_status = 'Yes' THEN 1 ELSE 0 END * 100), 2) AS churn_rate_pct , COUNT(*) AS customers
FROM subscriptions
GROUP BY usage_bucket
ORDER BY usage_bucket;


-- Net Promoter Score (NPS) vs Churn rate

SELECT CASE 
        WHEN nps_score <= 6 THEN 'Detractor (0–6)'
        WHEN nps_score BETWEEN 7 AND 8 THEN 'Passive (7–8)'
        ELSE 'Promoter (9–10)' END AS nps_group,
        ROUND(AVG(CASE WHEN churn_status = 'yes' THEN 1 ELSE 0 END) * 100, 2) AS curn_rate_pct, COUNT(*)
FROM subscriptions
GROUP BY nps_group ;


-- Feature Usage + NPS Combined 

SELECT CASE 
        WHEN feature_usage_pct < 40 THEN 'Low Usage'
        WHEN feature_usage_pct < 70 THEN 'Medium Usage'
        ELSE 'High Usage'
    END AS usage_group,
    CASE 
        WHEN nps_score <= 6 THEN 'Detractor'
        WHEN nps_score BETWEEN 7 AND 8 THEN 'Passive'
        ELSE 'Promoter'
    END AS nps_group,
    ROUND(AVG(CASE WHEN churn_status = 'Yes' THEN 1 ELSE 0 END) * 100, 2) AS churn_rate_pct,
    COUNT(*) AS customers
FROM subscriptions
GROUP BY usage_group, nps_group
ORDER BY churn_rate_pct DESC ;