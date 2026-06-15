CREATE DATABASE assignment3;
USE assignment3;
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
CREATE TABLE customers (
    Customer_ID VARCHAR(30) PRIMARY KEY,
    Customer_Name VARCHAR(100),
    Segment VARCHAR(50),
    Country VARCHAR(50),
    City VARCHAR(50),
    State VARCHAR(50),
    Region VARCHAR(50)
);

CREATE TABLE products (
    Product_ID VARCHAR(30) PRIMARY KEY,
    Product_Name VARCHAR(255),
    Category VARCHAR(50),
    Sub_Category VARCHAR(50)
);

CREATE TABLE orders (
    Row_ID INT PRIMARY KEY,
    Order_ID VARCHAR(30),
    Order_Date DATE,
    Ship_Date DATE,
    Ship_Mode VARCHAR(50),
    Customer_ID VARCHAR(30),
    Product_ID VARCHAR(30),
    Sales DECIMAL(10,2),
    Quantity INT,
    Discount DECIMAL(5,2),
    Profit DECIMAL(10,2)
);
INSERT INTO customers
SELECT DISTINCT
    Customer_ID,
    Customer_Name,
    Segment,
    Country,
    City,
    State,
    Region
FROM superstore;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    Customer_ID VARCHAR(30),
    Customer_Name VARCHAR(100),
    Segment VARCHAR(50),
    Country VARCHAR(50),
    City VARCHAR(50),
    State VARCHAR(50),
    Region VARCHAR(50)
);

INSERT INTO customers
SELECT DISTINCT
    Customer_ID,
    Customer_Name,
    Segment,
    Country,
    City,
    State,
    Region
FROM superstore;

DROP TABLE IF EXISTS products;

CREATE TABLE products (
    Product_ID VARCHAR(30),
    Product_Name VARCHAR(255),
    Category VARCHAR(50),
    Sub_Category VARCHAR(50)
);
INSERT INTO products
SELECT DISTINCT
    Product_ID,
    Product_Name,
    Category,
    Sub_Category
FROM superstore;
DROP TABLE IF EXISTS orders;

CREATE TABLE orders (
    Row_ID INT,
    Order_ID VARCHAR(30),
    Order_Date DATE,
    Ship_Date DATE,
    Ship_Mode VARCHAR(50),
    Customer_ID VARCHAR(30),
    Product_ID VARCHAR(30),
    Sales DECIMAL(10,2),
    Quantity INT,
    Discount DECIMAL(5,2),
    Profit DECIMAL(10,2)
);
INSERT INTO orders
SELECT DISTINCT
    Row_ID,
    Order_ID,
    Order_Date,
    Ship_Date,
    Ship_Mode,
    Customer_ID,
    Product_ID,
    Sales,
    Quantity,
    Discount,
    Profit
FROM superstore;
SELECT
    Customer_ID,
    SUM(Sales) AS Total_Sales
FROM orders
GROUP BY Customer_ID
HAVING SUM(Sales) >
(
    SELECT AVG(CustomerSales)
    FROM
    (
        SELECT SUM(Sales) AS CustomerSales
        FROM orders
        GROUP BY Customer_ID
    ) x
);
SELECT Customer_ID
FROM orders
GROUP BY Customer_ID
HAVING MAX(Sales) > 1000;

WITH customer_sales AS
(
    SELECT
        Customer_ID,
        SUM(Sales) AS Total_Sales
    FROM orders
    GROUP BY Customer_ID
)
SELECT *
FROM customer_sales
ORDER BY Total_Sales DESC;

WITH customer_sales AS
(
    SELECT
        Customer_ID,
        SUM(Sales) AS Total_Sales
    FROM orders
    GROUP BY Customer_ID
)
SELECT
    Customer_ID,
    Total_Sales,
    RANK() OVER (ORDER BY Total_Sales DESC) AS Sales_Rank
FROM customer_sales;

WITH product_sales AS
(
    SELECT
        Product_ID,
        SUM(Sales) AS Total_Sales
    FROM orders
    GROUP BY Product_ID
)
SELECT
    Product_ID,
    Total_Sales,
    RANK() OVER (ORDER BY Total_Sales DESC) AS Product_Rank
FROM product_sales;

WITH customer_sales AS
(
    SELECT
        Customer_ID,
        SUM(Sales) AS Total_Sales
    FROM orders
    GROUP BY Customer_ID
)
SELECT
    Customer_ID,
    Total_Sales,
    ROW_NUMBER() OVER (ORDER BY Total_Sales DESC) AS row_num,
    RANK() OVER (ORDER BY Total_Sales DESC) AS sales_rank
FROM customer_sales;

WITH customer_sales AS
(
    SELECT
        Customer_ID,
        SUM(Sales) AS Total_Sales
    FROM orders
    GROUP BY Customer_ID
)
SELECT
    Customer_ID,
    Total_Sales
FROM customer_sales
ORDER BY Total_Sales DESC
LIMIT 10;

WITH customer_sales AS
(
    SELECT
        Customer_ID,
        SUM(Sales) AS Total_Sales
    FROM orders
    GROUP BY Customer_ID
)
SELECT
    Customer_ID,
    Total_Sales
FROM customer_sales
ORDER BY Total_Sales ASC
LIMIT 10;

SELECT
    Customer_ID,
    COUNT(DISTINCT Order_ID) AS Order_Count
FROM orders
GROUP BY Customer_ID
HAVING COUNT(DISTINCT Order_ID) = 1;


WITH customer_sales AS
(
    SELECT
        Customer_ID,
        SUM(Sales) AS Total_Sales
    FROM orders
    GROUP BY Customer_ID
)
SELECT *
FROM customer_sales
WHERE Total_Sales >
(
    SELECT AVG(Total_Sales)
    FROM customer_sales
)
ORDER BY Total_Sales DESC;