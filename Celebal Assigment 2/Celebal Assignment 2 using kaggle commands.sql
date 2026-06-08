-- 1. Load dataset into a SQL database
CREATE DATABASE superstore_database;
USE superstore_database;
CREATE TABLE superstore (
    Row_ID INTEGER,
    Order_ID TEXT,
    Order_Date TEXT,
    Ship_Date TEXT,
    Ship_Mode TEXT,
    Customer_ID TEXT,
    Customer_Name TEXT,
    Segment TEXT,
    Country TEXT,
    City TEXT,
    State TEXT,
    Postal_Code INTEGER,
    Region TEXT,
    Product_ID TEXT,
    Category TEXT,
    Sub_Category TEXT,
    Product_Name TEXT,
    Sales REAL,
    Quantity INTEGER,
    Discount REAL,
    Profit REAL
);
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Sample - Superstore.csv'
INTO TABLE superstore
CHARACTER SET latin1
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    Row_ID,
    Order_ID,
    @Order_Date,
    @Ship_Date,
    Ship_Mode,
    Customer_ID,
    Customer_Name,
    Segment,
    Country,
    City,
    State,
    Postal_Code,
    Region,
    Product_ID,
    Category,
    Sub_Category,
    Product_Name,
    Sales,
    Quantity,
    Discount,
    Profit
)
SET
    Order_Date = STR_TO_DATE(@Order_Date,'%m/%d/%Y'),
    Ship_Date = STR_TO_DATE(@Ship_Date,'%m/%d/%Y');

-- 2. Explore table (schema, sample data). 
-- no of rows in table
SELECT COUNT(*) FROM superstore;

--  table schema 
DESCRIBE superstore;

-- The first 3 customer orders with profit information
SELECT Order_ID , Customer_ID, Customer_Name , Country , Profit  FROM superstore
LIMIT 3;

-- 3.Apply WHERE filters (region, category, date, sales)
-- The customer orders in year 2016
SELECT * FROM superstore 
WHERE Order_Date between '2016-01-01' and '2017-01-01';

-- Ther customer orders with first class shipment mode
SELECT Order_ID , Order_Date , Ship_Mode FROM superstore
WHERE Ship_Mode = 'First Class';


-- no of orders and sales in each Category 
SELECT Category, count(*) as no_of_orders , SUM(sales) as Sales 
FROM superstore 
GROUP BY Category ;

-- Aggregate functions on sales
SELECT
    Category,
    SUM(Sales) AS Total_Sales,
    AVG(Sales) AS Avg_Sales,
    MAX(Sales) AS Highest_Sale,
    MIN(Sales) AS Lowest_Sale
FROM superstore
GROUP BY Category;

-- count of unique customers in each region
SELECT
    Region,
    COUNT(DISTINCT Customer_ID) AS Unique_Customers
FROM superstore
GROUP BY Region;

--  total profit in each segment
SELECT
    Segment,
    ROUND(SUM(Profit),2) AS Total_Profit
FROM superstore
GROUP BY Segment
ORDER BY Total_Profit DESC;

-- 5.Sort and limit results (top products, top categories)
-- top 3 product names and their revenue
SELECT
    Product_Name,
    ROUND(SUM(Sales),2) AS Revenue
FROM superstore
GROUP BY Product_Name
ORDER BY Revenue DESC
LIMIT 3;

--  Each categories with total profit 
SELECT
    Category,
    ROUND(SUM(Profit),2) AS Total_Profit
FROM superstore
GROUP BY Category
ORDER BY Total_Profit DESC
LIMIT 5;

-- 6.Solve use cases (monthly trends, top customers, duplicates).
-- revenue in each month 
SELECT
    MONTHNAME(Order_Date) AS Month,
    ROUND(SUM(Sales),2) AS Revenue
FROM superstore
GROUP BY Month
ORDER BY Revenue DESC;

-- no of unique orders of each customer
SELECT
    Customer_Name,
    COUNT(DISTINCT Order_ID) AS Orders_Count
FROM superstore
GROUP BY Customer_Name
ORDER BY Orders_Count DESC
LIMIT 10;

-- Top 10 Customers Generating Highest Profit
SELECT
    Customer_Name,
    ROUND(SUM(Profit),2) AS Total_Profit
FROM superstore
GROUP BY Customer_Name
ORDER BY Total_Profit DESC
LIMIT 10;

-- Cities With High Sales But Low Profit
SELECT
    City,
    ROUND(SUM(Sales),2) AS Revenue,
    ROUND(SUM(Profit),2) AS Profit
FROM superstore
GROUP BY City
HAVING SUM(Sales) > 10000
   AND SUM(Profit) < 1000
ORDER BY Revenue DESC;

-- 7.Validate results (row counts, data quality). 

-- total number of rows
SELECT COUNT(*) AS Rows_count
FROM superstore;

-- orders with negative sales 
SELECT *
FROM superstore
WHERE Sales < 0;

-- total rows count, unique rows count , duplicate rows count
SELECT
    COUNT(*) AS Total_Rows,
    COUNT(DISTINCT Row_ID) AS Unique_Rows,
    COUNT(*) - COUNT(DISTINCT Row_ID) AS Duplicate_Rows
FROM superstore;
