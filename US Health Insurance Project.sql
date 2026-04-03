use us_health_insurance;
											-- Create Main Table
CREATE TABLE insurance_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    age INT,
    sex VARCHAR(10),
    bmi DECIMAL(5,2),
    children INT,
    smoker VARCHAR(10),
    region VARCHAR(50),
    charges DECIMAL(10,2)
);

select * from insurance_data;

												-- Data Cleaning
-- Check for duplicates
select *, COUNT(*)
FROM insurance_data
GROUP BY id, age, sex, bmi, children, smoker, region, charges
HAVING COUNT(*) > 1;

set sql_safe_updates=0;

-- Delete duplicates
DELETE FROM insurance_data
WHERE id NOT IN (
    select * FROM (
        select MIN(id)
        FROM insurance_data
        GROUP BY id, age, sex, bmi, children, smoker, region, charges
    ) t
);

-- check nulls
select * FROM insurance_data
WHERE age IS NULL 
   OR bmi IS NULL 
   OR charges IS NULL;
   
-- Validate ranges
select MIN(age), MAX(age) FROM insurance_data;
select MIN(bmi), MAX(bmi) FROM insurance_data;
select MIN(charges), MAX(charges) FROM insurance_data;   


											-- Feature Engineering
create view insurance_features as
select *,
    case 
        when age between 18 and 30 then '18-30'
        when age between 31 and 45 then '31-45'
        when age between 46 and 60 then '46-60'
        else '60+'
    end as age_group,

    case 
        when bmi < 18.5 then 'Underweight'
        when bmi between 18.5 and 24.9 then 'Normal'
        when bmi between 25 and 29.9 then 'Overweight'
        else 'Obese'
    end as bmi_category,

    case 
        when smoker = 'yes' and bmi >= 30 and age >= 40 then 'High Risk'
        when smoker = 'yes' OR bmi >= 30 then 'Medium Risk'
        else 'Low Risk'
    end as risk_category
FROM insurance_data;
select * from insurance_features;

select * from insurance_data;
										-- RISK SEGMENTATION ANALYSIS

-- Classify customers into risk categories using multiple factors.
SELECT *,
CASE 
    WHEN smoker = 'yes' AND bmi > 30 AND age > 45 THEN 'Very High Risk'
    WHEN smoker = 'yes' OR bmi > 30 THEN 'High Risk'
    WHEN age BETWEEN 30 AND 45 THEN 'Medium Risk'
    ELSE 'Low Risk'
END AS risk_category
FROM insurance_data;
                           
--  How many customers fall into each risk category? (Risk distribution) 
WITH risk_data AS (
    SELECT *,
    CASE 
        WHEN smoker='yes' AND bmi>=30 AND age>=40 THEN 'High Risk'
        WHEN smoker='yes' OR bmi>=30 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_category
    FROM insurance_data
)
SELECT risk_category, COUNT(*) as no_of_customers FROM risk_data GROUP BY risk_category;

-- How are customers distributed across cost segments? (Cost segmentation)
SELECT *,
CASE 
    WHEN charges <10000 THEN 'Low'
    WHEN charges BETWEEN 10000 AND 30000 THEN 'Medium'
    ELSE 'High'
END AS cost_segment
FROM insurance_data;



									-- PREMIUM DRIVER ANALYSIS
                                    
-- Does smoking significantly increase charges?
SELECT smoker, AVG(charges) as smoker_premium FROM insurance_data GROUP BY smoker;

-- How does BMI affect cost?
SELECT bmi_category, AVG(charges) as premium_by_bmi
FROM insurance_features
GROUP BY bmi_category;

-- Does age influence insurance charges?
SELECT age_group, AVG(charges) as premium_by_age
FROM insurance_features
GROUP BY age_group;

-- Does sex influence insurance charges?
SELECT sex, AVG(charges) as premium_by_sex
FROM insurance_data
GROUP BY sex;

-- Are there regional differences?
SELECT region, AVG(charges) as premium_by_region
FROM insurance_data
GROUP BY region;



										-- CUSTOMER PROFILING
                                        
-- Which combination of factors leads to highest charges? / (Most expensive profile)
WITH feature_data AS (
    SELECT *,
    CASE 
        WHEN age BETWEEN 18 AND 30 THEN '18-30'
        WHEN age BETWEEN 31 AND 45 THEN '31-45'
        WHEN age BETWEEN 46 AND 60 THEN '46-60'
        ELSE '60+'
    END AS age_group,
    CASE 
        WHEN bmi <18.5 THEN 'Underweight'
        WHEN bmi BETWEEN 18.5 AND 24.9 THEN 'Normal'
        WHEN bmi BETWEEN 25 AND 29.9 THEN 'Overweight'
        ELSE 'Obese'
    END AS bmi_category
    FROM insurance_data
)
SELECT age_group, bmi_category, smoker, AVG(charges)
FROM feature_data
GROUP BY age_group, bmi_category, smoker
ORDER BY AVG(charges) DESC
LIMIT 1;

-- Which customers pay more than their regional average?
SELECT *
FROM insurance_data i
WHERE charges > (
    SELECT AVG(charges)
    FROM insurance_data
    WHERE region = i.region
)
group by id
order by charges;

										-- ANOMALY DETECTION
-- Find customers whose charges are more than 2x the average. (outliers = avg_charge*2)
SELECT id, age, sex, bmi, smoker, charges
FROM insurance_data
WHERE charges > (SELECT AVG(charges) * 2 FROM insurance_data);

-- Are there smokers paying unusually low charges?
SELECT id, smoker, charges
FROM insurance_data
WHERE smoker='yes'
AND charges < (
    SELECT AVG(charges)
    FROM insurance_data
    WHERE smoker='yes'
);

										-- ADVANCED ANALYTICS
                                        
-- How do customers rank within regions based on insurance charges?
SELECT *,
RANK() OVER (PARTITION BY region ORDER BY charges DESC) AS rank_in_region
FROM insurance_data;

-- Which age group contributes the most to total insurance charges?
WITH age_groups AS (
    SELECT 
	CASE 
		WHEN age BETWEEN 18 AND 30 THEN '18-30'
            WHEN age BETWEEN 31 AND 45 THEN '31-45'
            WHEN age BETWEEN 46 AND 60 THEN '46-60'
            ELSE '60+'
        END AS age_group,
        charges
    FROM insurance_data
)
SELECT 
    age_group,
    SUM(charges) AS total_charges,
    ROUND(SUM(charges) * 100 / SUM(SUM(charges)) OVER (), 2) AS contribution_percent
FROM age_groups
GROUP BY age_group
ORDER BY contribution_percent DESC;

-- What is the percentage increase in average charges for smokers compared to non-smokers?
WITH avg_cost AS (
    SELECT smoker, AVG(charges) AS avg_charge
    FROM insurance_data
    GROUP BY smoker
)
SELECT 
    ROUND(
        (MAX(CASE WHEN smoker = 'yes' THEN avg_charge END) -
         MAX(CASE WHEN smoker = 'no' THEN avg_charge END)) 
        / MAX(CASE WHEN smoker = 'no' THEN avg_charge END) * 100, 
    2) AS percent_increase
FROM avg_cost;

-- Who are the top 10% high-paying customers?
SELECT *
FROM (
    SELECT *,
           NTILE(10) OVER (ORDER BY charges DESC) AS percentile
    FROM insurance_data
) t
WHERE percentile = 1;

-- How do charges accumulate with age?
SELECT age,
       SUM(charges) AS total,
       SUM(SUM(charges)) OVER (ORDER BY age) AS running_total
FROM insurance_data
GROUP BY age;

-- Track cumulative charges within each region.
SELECT 
    region,
    age,
    charges,
    SUM(charges) OVER (
        PARTITION BY region 
        ORDER BY age
    ) AS cumulative_charges
FROM insurance_data;

-- Which customers pay charges that are above average?
SELECT id, charges 
FROM insurance_data
WHERE charges > (SELECT AVG(charges) FROM insurance_data);

-- Find customers whose charges are above the average of their group (smoker/non-smoker).
SELECT id, smoker, charges
FROM (
    SELECT *,
           AVG(charges) OVER (PARTITION BY smoker) AS group_avg
    FROM insurance_data
) t
WHERE charges > group_avg;

-- Who has the highest charges per region?
SELECT id, sex, region, charges FROM insurance_data i
WHERE charges = (
    SELECT MAX(charges)
    FROM insurance_data
    WHERE region = i.region
);
-- Which regions exceed overall averages?
SELECT region, SUM(charges) as total_avg_charges
FROM insurance_data
GROUP BY region
HAVING SUM(charges) > (
    SELECT AVG(total_charges)
    FROM (
        SELECT SUM(charges) AS total_charges
        FROM insurance_data
        GROUP BY region
    ) t
);


								-- BUSINESS SIMULATION & INSIGHTS
-- What will be the charges if smoker premiums are reduced 10% ?
SELECT *,
CASE 
    WHEN smoker='yes' THEN charges*0.9
    ELSE charges
END 
as adjusted_price
FROM insurance_data;


-- Which segment is most profitable?
SELECT smoker,
       AVG(charges) AS avg_charges,
       VARIANCE(charges) AS variance
FROM insurance_data
GROUP BY smoker;

-- How do cohorts behave? (cohort comparison)
SELECT age_group, smoker, AVG(charges)
FROM insurance_features
GROUP BY age_group, smoker;