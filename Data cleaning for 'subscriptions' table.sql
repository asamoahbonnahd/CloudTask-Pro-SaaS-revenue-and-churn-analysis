SELECT *
FROM subscriptions ;


-- fixing column headers

ALTER TABLE subscriptions RENAME COLUMN `churned` TO `churn_status` ;
ALTER TABLE subscriptions RENAME COLUMN `upgraded` TO `upgrade_status` ;


-- Standardizing customer_id column

UPDATE subscriptions 
SET customer_id = UPPER(customer_id) ;


-- fixing plan column 

UPDATE subscriptions
SET plan = TRIM(REPLACE(plan,'"','')) ;


-- fixing industry column

UPDATE subscriptions
SET industry = TRIM(REPLACE(industry,'"','')) ;


-- fixing inconsistent signup_date format

UPDATE subscriptions
SET signup_date = CASE
        -- YYYY-MM-DD
        WHEN signup_date LIKE '____-__-__' THEN
            DATE_FORMAT(STR_TO_DATE(signup_date, '%Y-%m-%d'), '%m/%d/%Y')

        -- DD-MM-YYYY
        WHEN signup_date LIKE '__-__-____' THEN
            DATE_FORMAT(STR_TO_DATE(signup_date, '%d-%m-%Y'), '%m/%d/%Y')

        -- DD/MM/YYYY
        WHEN signup_date LIKE '__/__/____'
             AND SUBSTRING_INDEX(signup_date, '/', -1) REGEXP '^[0-9]{4}$'
             AND SUBSTRING_INDEX(signup_date, '/', 1) > 12 THEN
            DATE_FORMAT(STR_TO_DATE(signup_date, '%d/%m/%Y'), '%m/%d/%Y')
        ELSE signup_date END ;


-- finding duplicates 

SELECT customer_id, COUNT(*)
FROM subscriptions
GROUP BY customer_id
HAVING COUNT(*) > 1 ;


-- assigning temporary row ids for deduplication

ALTER TABLE subscriptions
ADD row_id SERIAL PRIMARY KEY ;


-- deleting duplicates

SELECT row_id, customer_id, ROW_NUMBER() OVER(PARTITION BY customer_id) AS row_num
FROM subscriptions ;

SELECT *
FROM (SELECT row_id, customer_id, ROW_NUMBER() OVER(PARTITION BY customer_id) AS row_num
        FROM subscriptions) AS dedupe
WHERE row_num > 1 ;

DELETE FROM subscriptions
WHERE row_id IN (SELECT row_id
        FROM (SELECT row_id, customer_id, ROW_NUMBER() OVER(PARTITION BY customer_id) AS row_num
                FROM subscriptions) AS dedupe 
                WHERE row_num > 1) ;


-- dropping the temporary row_id column

ALTER TABLE subscriptions
DROP COLUMN row_id ;