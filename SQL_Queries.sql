-- Total revenue by loyalty status
WITH cte_rev AS (
    SELECT 
        c.Loyalty_Status AS Loyalty_Status,
        SUM(s.Quantity_Sold * p.Cost) AS Revenue
    FROM sales_fact_table AS s
    JOIN product_dimension AS p ON s.Product_ID = p.Product_ID
    JOIN customer_dimension AS c ON c.Customer_ID = s.Customer_ID 
    GROUP BY c.Loyalty_Status
)
SELECT 
    Loyalty_Status,
    Revenue,
    (Revenue * 100.0 / MAX(Revenue) OVER()) AS Pct
FROM cte_rev
ORDER BY Revenue DESC;

  
  
  
  
  
-- % male and female by revenue 
WITH cte_revenue AS (
    SELECT 
        c.Gender AS Gender,
        SUM(s.Quantity_Sold * p.Cost) AS Revenue
    FROM sales_fact_table AS s
    JOIN product_dimension AS p ON s.Product_ID = p.Product_ID
    JOIN customer_dimension AS c ON c.Customer_ID = s.Customer_ID
    GROUP BY c.Gender
)
SELECT 
    Gender,
    Revenue,
    (Revenue * 100 / SUM(Revenue) OVER()) AS pct
FROM cte_revenue;






-- Revenue by cost_ segment    (without using over() )
WITH cte_cost AS (
    SELECT 
        CASE 
            WHEN p.Cost > 150 THEN 'Very Costly'
            WHEN p.Cost > 100 THEN 'High Cost'
            WHEN p.Cost > 50 THEN 'Average Cost'
            ELSE 'Inexpensive'
        END AS Cost_Segment,
        s.Quantity_Sold * p.Cost AS Revenue
    FROM sales_fact_table AS s
    JOIN product_dimension AS p ON s.Product_ID = p.Product_ID
),
total_revenue AS (
    SELECT SUM(Revenue) AS TotalRevenue
    FROM cte_cost
)
SELECT 
    Cost_Segment,
    SUM(Revenue) AS SegmentRevenue,
    (SUM(Revenue) / (SELECT TotalRevenue FROM total_revenue)) * 100 AS RevenuePct
FROM cte_cost 
GROUP BY Cost_Segment
ORDER BY SegmentRevenue DESC;






-- Revenue by age_group
SELECT 
    Age_group,
    SUM(Revenue) AS Total_Revenue
FROM (
    SELECT 
        CASE 
            WHEN c.Age > 50 THEN 'old_age'
            WHEN c.Age > 30 THEN 'middle_age'
            ELSE 'young'
        END AS Age_group,
        s.Quantity_Sold * p.Cost AS Revenue
    FROM sales_fact_table AS s
    JOIN product_dimension AS p ON s.Product_ID = p.Product_ID
    JOIN customer_dimension AS c ON c.Customer_ID = s.Customer_ID
) AS AgeRevenue
GROUP BY Age_group;





-- Top 5 customers by revenue (purchase amount)
WITH cte_customers AS (
    SELECT 
        c.Customer_Name,
        SUM(s.Quantity_Sold * p.Cost) AS Revenue
    FROM sales_fact_table AS s
    JOIN product_dimension AS p ON s.Product_ID = p.Product_ID
    JOIN customer_dimension AS c ON c.Customer_ID = s.Customer_ID
    GROUP BY c.Customer_Name
),
ranked_customers AS (
    SELECT 
        Customer_Name,
        Revenue,
        RANK() OVER (ORDER BY Revenue DESC) AS Rnk
    FROM cte_customers
)
SELECT 
    Customer_Name,
    Revenue,
    Rnk
FROM ranked_customers
WHERE Rnk <= 5;




-- changing DOB to date and adding age
ALTER TABLE customer_dimension
ADD COLUMN DOB_converted DATE;

SET SQL_SAFE_UPDATES = 0;

UPDATE customer_dimension
SET DOB_converted = STR_TO_DATE(DOB, '%d-%b-%y');

SET SQL_SAFE_UPDATES = 1;

ALTER TABLE customer_dimension
ADD COLUMN Age INT;

SET SQL_SAFE_UPDATES = 0;
UPDATE customer_dimension
SET Age = TIMESTAMPDIFF(YEAR, DOB_converted, CURDATE())
WHERE Customer_ID  IS NOT NULL;
SET SQL_SAFE_UPDATES = 1;



-- changing sales_Date into date				
UPDATE sales_fact_table
SET Date = STR_TO_DATE(Date, '%m/%d/%Y')
where Product_ID is not null;

ALTER TABLE sales_fact_table
MODIFY COLUMN Date DATE;







-- top 5 customers in festival season
WITH cte_festive AS (
    SELECT 
        c.Customer_Name,
        SUM(s.Quantity_Sold * p.Cost) AS Revenue
    FROM sales_fact_table AS s
    JOIN product_dimension AS p ON s.Product_ID = p.Product_ID
    JOIN customer_dimension AS c ON c.Customer_ID = s.Customer_ID
    WHERE MONTH(s.Date) IN (10, 11, 12)
    GROUP BY c.Customer_Name
),
ranked_cus AS (
    SELECT 
        Customer_Name,
        Revenue,
        RANK() OVER (ORDER BY Revenue DESC) AS rnk
    FROM cte_festive
)
SELECT 
    Customer_Name,
    Revenue
FROM ranked_cus
WHERE rnk <= 5;





    -- Revenue by cities
SELECT 
	l.City,
	SUM(s.Quantity_Sold * p.Cost) AS Revenue
FROM sales_fact_table AS s
JOIN product_dimension AS p ON s.Product_ID = p.Product_ID
JOIN location_dimension AS l ON l.Location_ID= s.Location_ID
GROUP BY l.City
ORDER BY Revenue DESC;








-- Revenue by month and brand (validating trend with last month (DEC))
SELECT 
	Brand,
	SUM(s.Quantity_Sold * p.Cost) AS Revenue
FROM sales_fact_table AS s
JOIN product_dimension AS p ON s.Product_ID = p.Product_ID
WHERE MONTH(s.Date)=12
GROUP BY p.Brand 
ORDER BY Revenue DESC;





-- Revenue by Chocolate Type
SELECT 
    p.Chocolate_Type AS Product,
    SUM(s.Quantity_Sold * p.Cost) AS Revenue
FROM sales_fact_table AS s
JOIN product_dimension AS p ON s.Product_ID = p.Product_ID
GROUP BY p.Chocolate_Type;
    
    
    
    
    
-- pct of reveunue from festival seasons 
SELECT 
    FestivalSeasonRevenue,
    TotalRevenue,
    (FestivalSeasonRevenue / NULLIF(TotalRevenue, 0)) * 100 AS Percentage
FROM (
    SELECT 
        SUM(CASE WHEN MONTH(s.Date) IN (10, 11, 12) THEN s.Quantity_Sold * p.Cost ELSE 0 END) AS FestivalSeasonRevenue,
        SUM(s.Quantity_Sold * p.Cost) AS TotalRevenue
    FROM sales_fact_table AS s
    JOIN product_dimension AS p ON s.Product_ID = p.Product_ID
) AS RevenueData;





-- Revenue by Quarter 
SELECT 
	QUARTER(s.Date) as Qtr,
	SUM(s.Quantity_Sold * p.Cost) AS Revenue
FROM sales_fact_table AS s
JOIN product_dimension AS p ON s.Product_ID = p.Product_ID
GROUP BY QUARTER(s.Date)
ORDER BY Qtr;




-- MoM change in Revenue
WITH cte_prev_month AS (
    SELECT 
        MONTH(s.Date) AS Month,
        SUM(s.Quantity_Sold * p.Cost) AS Revenue
    FROM sales_fact_table AS s
    JOIN product_dimension AS p ON s.Product_ID = p.Product_ID
    GROUP BY MONTH(s.Date)
    ORDER BY MONTH(s.Date)
),
prev_rev AS (
    SELECT 
        Month,
        Revenue,
        LAG(Revenue, 1) OVER (ORDER BY Month) AS Prev_Revenue
    FROM cte_prev_month
)
SELECT 
    Month,
    ((Revenue - Prev_Revenue) / NULLIF(Prev_Revenue, 0)) * 100 AS Pct_Change
FROM prev_rev;




-- Revenue in Weekday by chocolate type 
WITH RevenueData AS (
    SELECT 
        DAYNAME(s.Date) AS Day,
        DAYOFWEEK(s.Date) AS DayNumber,
        p.Chocolate_Type,
        SUM(s.Quantity_Sold * p.Cost) AS Revenue
    FROM sales_fact_table AS s
    JOIN product_dimension AS p ON s.Product_ID = p.Product_ID
    GROUP BY DAYNAME(s.Date), DAYOFWEEK(s.Date), p.Chocolate_Type
)
SELECT 
    Day,
    Chocolate_Type,
    Revenue
FROM RevenueData
ORDER BY DayNumber, Revenue DESC;



