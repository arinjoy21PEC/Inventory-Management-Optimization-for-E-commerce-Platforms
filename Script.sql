-- Step 1: Create Database and Use It
CREATE DATABASE db1;
USE db1;

-- Step 2: Select Data (This assumes the dataset is already loaded)
SELECT * FROM inventory_management_dataset;

-- Step 3: Identify Out-of-Stock Occurrences
SELECT Product_ID, Product_Name, COUNT(*) AS Out_of_Stock_Count
FROM inventory_management_dataset
WHERE Stock_Level <= Reorder_Point
GROUP BY Product_ID, Product_Name;

-- Step 4: Analyze Sales Velocity Patterns
-- Identify products with high sales velocity (> 20.50) and low average stock levels (< 260.44)
-- For Sales Velocity
SELECT 
    AVG(Sales_Velocity) AS Avg_Sales_Velocity, 
    STDDEV(Sales_Velocity) AS StdDev_Sales_Velocity 
FROM inventory_management_dataset;

-- For Stock Level
SELECT 
    AVG(Stock_Level) AS Avg_Stock_Level, 
    STDDEV(Stock_Level) AS StdDev_Stock_Level 
FROM inventory_management_dataset;

SELECT Product_ID, Product_Name, AVG(Sales_Velocity) AS Avg_Sales_Velocity, AVG(Stock_Level) AS Avg_Stock_Level
FROM inventory_management_dataset
GROUP BY Product_ID, Product_Name
HAVING AVG(Sales_Velocity) > 20.50 AND AVG(Stock_Level) < 260.44;  -- Thresholds for velocity and stock level

-- Step 5: Calculate Days Between Sales 
WITH SalesWithLag AS (
    SELECT Product_ID, 
           STR_TO_DATE(Sales_Date, '%d-%m-%Y') AS SalesDate, 
           LAG(STR_TO_DATE(Sales_Date, '%d-%m-%Y'), 1) OVER (PARTITION BY Product_ID ORDER BY STR_TO_DATE(Sales_Date, '%d-%m-%Y')) AS Previous_Sale_Date
    FROM inventory_management_dataset
)
SELECT Product_ID, 
       AVG(DATEDIFF(SalesDate, Previous_Sale_Date)) AS Avg_Days_Between_Sales
FROM SalesWithLag
WHERE Previous_Sale_Date IS NOT NULL
GROUP BY Product_ID;

-- Calculate Future Restocking Needs
WITH SalesLag AS (
    SELECT Product_ID, 
           DATEDIFF(STR_TO_DATE(Sales_Date, '%d-%m-%Y'), 
                    LAG(STR_TO_DATE(Sales_Date, '%d-%m-%Y'), 1) OVER (PARTITION BY Product_ID ORDER BY STR_TO_DATE(Sales_Date, '%d-%m-%Y'))) AS Days_Between_Sales,
           Sales_Velocity
    FROM inventory_management_dataset
)
SELECT Product_ID, 
       AVG(Days_Between_Sales) AS Restocking_Cycle,
       AVG(Sales_Velocity) AS Avg_Sales_Velocity,
       AVG(Days_Between_Sales) * AVG(Sales_Velocity) AS Predicted_Future_Need
FROM SalesLag
WHERE Days_Between_Sales IS NOT NULL
GROUP BY Product_ID;

-- Correlation Analysis Between Sales Trends and Inventory Turnover
-- Calculate Monthly Sales Trends
SELECT Product_ID, 
       EXTRACT(YEAR_MONTH FROM STR_TO_DATE(Sales_Date, '%d-%m-%Y')) AS Sales_Month, 
       SUM(Units_Sold) AS Monthly_Sales, 
       AVG(Inventory_Turnover_Rate) AS Avg_Inventory_Turnover
FROM inventory_management_dataset
GROUP BY Product_ID, Sales_Month;

-- Perform Correlation Analysis
WITH SalesTurnoverData AS (
    SELECT Product_ID, 
           EXTRACT(YEAR_MONTH FROM STR_TO_DATE(Sales_Date, '%d-%m-%Y')) AS Sales_Month, 
           SUM(Units_Sold) AS Monthly_Sales, 
           AVG(Inventory_Turnover_Rate) AS Avg_Inventory_Turnover
    FROM inventory_management_dataset
    GROUP BY Product_ID, Sales_Month
)

SELECT 
    (SUM((Monthly_Sales - Avg_Monthly_Sales) * (Avg_Inventory_Turnover - Avg_Turnover)) / (COUNT(*) - 1)) / 
    (STDDEV(Monthly_Sales) * STDDEV(Avg_Inventory_Turnover)) AS Sales_Turnover_Correlation
FROM (
    SELECT Product_ID, 
           Sales_Month, 
           Monthly_Sales, 
           Avg_Inventory_Turnover, 
           (SELECT AVG(Monthly_Sales) FROM SalesTurnoverData) AS Avg_Monthly_Sales, 
           (SELECT AVG(Avg_Inventory_Turnover) FROM SalesTurnoverData) AS Avg_Turnover
    FROM SalesTurnoverData
) AS CorrelationData;


