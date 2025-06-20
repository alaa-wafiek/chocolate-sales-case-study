SELECT TOP (1000) [Sales_Person]
      ,[Country]
      ,[Product]
      ,[Date]
      ,[Amount]
      ,[Boxes_Shipped]
  FROM [ChocolateSalesDB].[dbo].[Chocolate Sales]



-- Data Cleaning
UPDATE dbo.[Chocolate Sales]
SET Amount = REPLACE(Amount, '$', '');

-- Convert to proper numeric type 
ALTER TABLE dbo.[Chocolate Sales]
ALTER COLUMN Amount FLOAT;


ALTER TABLE dbo.[Chocolate Sales]
ADD CleanedDate DATE;

UPDATE dbo.[Chocolate Sales]
SET CleanedDate = TRY_CAST(Date AS DATE);

ALTER TABLE dbo.[Chocolate Sales]
DROP COLUMN Date;

EXEC sp_rename 'dbo.[Chocolate Sales].CleanedDate', 'Date', 'COLUMN';

SELECT TOP (1000) [Sales_Person]
      ,[Country]
      ,[Product]
      ,[Amount]
      ,[Boxes_Shipped]
  FROM [ChocolateSalesDB].[dbo].[Chocolate Sales]


-- Check rows with missing data
SELECT * FROM dbo.[Chocolate Sales]
WHERE Sales_Person IS NULL 
   OR Country IS NULL 
   OR Product IS NULL 
   OR Amount IS NULL 
   OR Boxes_Shipped IS NULL;


-- Look for exact duplicate rows
SELECT Sales_Person, Country, Product, Date, Amount, Boxes_Shipped,
       COUNT(*) AS Occurrences
FROM dbo.[Chocolate Sales]
GROUP BY Sales_Person, Country, Product, Date, Amount, Boxes_Shipped
HAVING COUNT(*) > 1;


--EXEC sp_help 'dbo.[Chocolate Sales]';


SELECT TOP (1000) [Sales_Person]
      ,[Country]
      ,[Product]
      ,[Amount]
      ,[Boxes_Shipped]
  FROM [ChocolateSalesDB].[dbo].[Chocolate Sales]







--1 Top 5 Products by Total Revenue
SELECT TOP 5 Product, SUM(Amount) AS TotalRevenue
FROM dbo.[Chocolate Sales]
GROUP BY Product
ORDER BY TotalRevenue DESC;

--2 Monthly Sales Trend (Revenue and Boxes Shipped)
SELECT 
  FORMAT(Date, 'yyyy-MM') AS Month,
  SUM(Amount) AS TotalRevenue,
  SUM(Boxes_Shipped) AS TotalBoxes
FROM dbo.[Chocolate Sales]
GROUP BY FORMAT(Date, 'yyyy-MM')
ORDER BY Month;

--3 Salesperson Efficiency (Revenue per Box)
SELECT 
  Sales_Person,
  SUM(Amount) AS TotalRevenue,
  SUM(Boxes_Shipped) AS TotalBoxes,
  CAST(SUM(Amount) * 1.0 / NULLIF(SUM(Boxes_Shipped), 0) AS DECIMAL(10, 2)) AS RevenuePerBox
FROM dbo.[Chocolate Sales]
GROUP BY Sales_Person
ORDER BY RevenuePerBox DESC;


--4 Revenue by Country
SELECT Country, SUM(Amount) AS TotalRevenue
FROM dbo.[Chocolate Sales]
GROUP BY Country
ORDER BY TotalRevenue DESC;


--5 Top 3 Products in Each Country by Revenue
WITH RankedProducts AS (
  SELECT 
    Country,
    Product,
    SUM(Amount) AS TotalRevenue,
    RANK() OVER (PARTITION BY Country ORDER BY SUM(Amount) DESC) AS Rank
  FROM dbo.[Chocolate Sales]
  GROUP BY Country, Product
)
SELECT Country, Product, TotalRevenue
FROM RankedProducts
WHERE Rank <= 3 ;


--6 Highest Revenue per Box by Product
SELECT top 3
  Product,
  SUM(Amount) AS TotalRevenue,
  SUM(Boxes_Shipped) AS TotalBoxes,
  CAST(SUM(Amount) * 1.0 / NULLIF(SUM(Boxes_Shipped), 0) AS DECIMAL(10, 2)) AS RevenuePerBox
FROM dbo.[Chocolate Sales]
GROUP BY Product
ORDER BY RevenuePerBox DESC;


--7 Salespersons with Fewest Boxes in Last Month
WITH LastMonth AS (
  SELECT FORMAT(MAX(Date), 'yyyy-MM') AS LatestMonth FROM dbo.[Chocolate Sales]
)
SELECT top 3
  Sales_Person,
  SUM(Boxes_Shipped) AS TotalBoxes
FROM dbo.[Chocolate Sales]
WHERE FORMAT(Date, 'yyyy-MM') = (SELECT LatestMonth FROM LastMonth)
GROUP BY Sales_Person
ORDER BY TotalBoxes ASC;


--8 Growth in Revenue by Country Over Last 2 Months
WITH MonthlyRevenue AS (
  SELECT 
    Country,
    FORMAT(Date, 'yyyy-MM') AS SalesMonth,
    SUM(Amount) AS TotalRevenue
  FROM dbo.[Chocolate Sales]
  GROUP BY Country, FORMAT(Date, 'yyyy-MM')
),
RankedMonths AS (
  SELECT *,
         DENSE_RANK() OVER (ORDER BY SalesMonth DESC) AS MonthRank
  FROM MonthlyRevenue
),
LastTwoMonths AS (
  SELECT * FROM RankedMonths WHERE MonthRank <= 2
),
Pivoted AS (
  SELECT 
    curr.Country,
    prev.TotalRevenue AS PrevMonthRevenue,
    curr.TotalRevenue AS CurrMonthRevenue
  FROM LastTwoMonths curr
  JOIN LastTwoMonths prev 
    ON curr.Country = prev.Country AND curr.MonthRank = 1 AND prev.MonthRank = 2
)
SELECT 
  Country,
  CurrMonthRevenue - PrevMonthRevenue AS RevenueGrowth
FROM Pivoted
WHERE CurrMonthRevenue > PrevMonthRevenue;



--9 % Revenue from Top 3 Salespersons
WITH RevenuePerSalesPerson AS (
  SELECT Sales_Person, SUM(Amount) AS TotalRevenue
  FROM dbo.[Chocolate Sales]
  GROUP BY Sales_Person
),
Top3 AS (
  SELECT TOP 3 TotalRevenue FROM RevenuePerSalesPerson ORDER BY TotalRevenue DESC
),
Total AS (
  SELECT SUM(Amount) AS TotalRevenue FROM dbo.[Chocolate Sales]
)
SELECT 
  CAST(SUM(t.TotalRevenue) * 100.0 / (SELECT TotalRevenue FROM Total) AS DECIMAL(5,2)) AS Top3SharePercent
FROM Top3 t;


--10 Correlation Between Boxes Shipped and Revenue
SELECT 
  (
    COUNT(*) * SUM(CAST(Boxes_Shipped AS FLOAT) * CAST(Amount AS FLOAT)) 
    - SUM(CAST(Boxes_Shipped AS FLOAT)) * SUM(CAST(Amount AS FLOAT))
  ) /
  SQRT(
    (COUNT(*) * SUM(CAST(Boxes_Shipped AS FLOAT) * CAST(Boxes_Shipped AS FLOAT)) - POWER(SUM(CAST(Boxes_Shipped AS FLOAT)), 2)) *
    (COUNT(*) * SUM(CAST(Amount AS FLOAT) * CAST(Amount AS FLOAT)) - POWER(SUM(CAST(Amount AS FLOAT)), 2))
  ) AS Correlation
FROM dbo.[Chocolate Sales];

--11 Top Salesperson for Each Product
WITH ProductSales AS (
    SELECT 
        Product,
        Sales_Person,
        SUM(Amount) AS TotalSales,
        ROW_NUMBER() OVER (PARTITION BY Product ORDER BY SUM(Amount) DESC) AS Rank
    FROM dbo.[Chocolate Sales]
    GROUP BY Product, Sales_Person
)
SELECT Product, Sales_Person, TotalSales
FROM ProductSales
WHERE Rank = 1
ORDER BY Product;

--12 Most Sold Product by Quantity in Last Month
SELECT TOP 1 Product, SUM(Amount) AS TotalQuantity
FROM dbo.[Chocolate Sales]
WHERE FORMAT([Date], 'yyyy-MM') = (
    SELECT MAX(FORMAT([Date], 'yyyy-MM')) FROM dbo.[Chocolate Sales]
)
GROUP BY Product
ORDER BY TotalQuantity DESC;

--13 Average Revenue per Box Shipped for Each Product
SELECT Product,
       SUM(Amount) AS TotalRevenue,
       SUM(CAST(Boxes_Shipped AS FLOAT)) AS TotalBoxes,
       ROUND(SUM(Amount) * 1.0 / NULLIF(SUM(CAST(Boxes_Shipped AS FLOAT)), 0), 2) AS RevenuePerBox
FROM dbo.[Chocolate Sales]
GROUP BY Product
ORDER BY RevenuePerBox DESC;

--14. Products Sold by Only One Salesperson
SELECT Product, COUNT(DISTINCT Sales_Person) AS SalespersonCount
FROM dbo.[Chocolate Sales]
GROUP BY Product
HAVING COUNT(DISTINCT Sales_Person) = 1;

--15 Salespeople with Revenue Above Average
WITH SalespersonRevenue AS (
    SELECT Sales_Person, SUM(Amount) AS TotalRevenue
    FROM dbo.[Chocolate Sales]
    GROUP BY Sales_Person
)
SELECT *
FROM SalespersonRevenue
WHERE TotalRevenue > (
    SELECT AVG(TotalRevenue) FROM SalespersonRevenue
);
--16 Total Revenue per Country for Each Month
SELECT Country, FORMAT([Date], 'yyyy-MM') AS Month, SUM(Amount) AS MonthlyRevenue
FROM dbo.[Chocolate Sales]
GROUP BY Country, FORMAT([Date], 'yyyy-MM')
ORDER BY Country, Month;
 
--17 Which countries have underperforming sales?
SELECT TOP 3 Country, SUM(Amount) AS TotalRevenue
FROM dbo.[Chocolate Sales]
GROUP BY Country
ORDER BY TotalRevenue ASC;

--18 Where are we growing recently?
WITH Last2Months AS (
  SELECT DISTINCT TOP 2 FORMAT([Date], 'yyyy-MM') AS Month
  FROM dbo.[Chocolate Sales]
  ORDER BY Month DESC
),
MonthNames AS (
  SELECT 
    MIN(Month) AS PrevMonth,
    MAX(Month) AS CurrMonth
  FROM Last2Months
),
RevenueData AS (
  SELECT 
    Country,
    FORMAT([Date], 'yyyy-MM') AS Month,
    SUM(Amount) AS TotalRevenue
  FROM dbo.[Chocolate Sales]
  WHERE FORMAT([Date], 'yyyy-MM') IN (SELECT Month FROM Last2Months)
  GROUP BY Country, FORMAT([Date], 'yyyy-MM')
),
Pivoted AS (
  SELECT 
    r.Country,
    m.PrevMonth,
    m.CurrMonth,
    MAX(CASE WHEN r.Month = m.PrevMonth THEN r.TotalRevenue END) AS PrevMonthRevenue,
    MAX(CASE WHEN r.Month = m.CurrMonth THEN r.TotalRevenue END) AS CurrMonthRevenue
  FROM RevenueData r
  CROSS JOIN MonthNames m
  GROUP BY r.Country, m.PrevMonth, m.CurrMonth
)
SELECT Country, 
       PrevMonthRevenue, 
       CurrMonthRevenue,
       CurrMonthRevenue - PrevMonthRevenue AS RevenueGrowth
FROM Pivoted
WHERE CurrMonthRevenue > PrevMonthRevenue
ORDER BY RevenueGrowth DESC;
