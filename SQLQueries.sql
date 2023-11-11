use SuperStore
ExEc sp_rename'order','orders';

-------------------------------------------------------------------------------------------------------------------------------
---Create a view that shows the Product name and territory along with the total number of orders reserved on each territory.
Create or alter view vProduct
as
select [Product Name] ,Territory ,count([Order ID]) as [No of Orders] from Products p,Territory t,orders o
where t.TerritoryID=o.TerritoryID
group by p.[Product Name],t.Territory

select *from vProduct
-------------------------------------------------------------------------------------------------------------------------------
-- Create the cursor inside stored procedure that asks for a "segment " 
---and return a new table containing the Sub-Category 
---and number of Sub-Category for each element of the Sub-Category 
----and the total sales of each element.
CREATE OR ALTER PROCEDURE GetSubCategorySales
    @Segment NVARCHAR(255)
AS
BEGIN
    -- Create a temporary table to store the result
    CREATE TABLE #SubCategorySales (
        SubCategory NVARCHAR(255),
        NumElements INT,
        TotalSales MONEY
    );

    -- Declare variables for cursor
    DECLARE @SubCategory NVARCHAR(255);
    DECLARE @NumElements INT;
    DECLARE @TotalSales MONEY;

    -- Declare the cursor
    DECLARE cursorSubCategory CURSOR FOR
    SELECT
        p.[Sub-Category],
        COUNT(DISTINCT p.[Product ID]) AS NumElements,
        SUM(od.[Sales]) AS TotalSales
    FROM [dbo].[Customers] c
    JOIN [dbo].[Order] o ON c.[Customer ID] = o.[Customer ID]
    JOIN [dbo].[OrderDetails] od ON o.[Order ID] = od.[Order ID]
    JOIN [dbo].[Products] p ON od.[Product ID] = p.[Product ID]
    WHERE c.[Segment] = @Segment
    GROUP BY p.[Sub-Category];

    -- Open the cursor
    OPEN cursorSubCategory;

    -- Fetch the first row
    FETCH NEXT FROM cursorSubCategory INTO @SubCategory, @NumElements, @TotalSales;

    -- Loop through the cursor and insert into the temporary table
    WHILE @@FETCH_STATUS = 0
    BEGIN
        INSERT INTO #SubCategorySales (SubCategory, NumElements, TotalSales)
        VALUES (@SubCategory, @NumElements, @TotalSales);

        -- Fetch the next row
        FETCH NEXT FROM cursorSubCategory INTO @SubCategory, @NumElements, @TotalSales;
    END;

    -- Close and deallocate the cursor
    CLOSE cursorSubCategory;
    DEALLOCATE cursorSubCategory;

    -- Select data from the temporary table
    SELECT * FROM #SubCategorySales;

    DROP TABLE #SubCategorySales;
END;

EXEC GetSubCategorySales @Segment = 'Consumer';

----------------------------------------------------------------------------------------------------------------------------
----stored procedure that asks for a "Status" and "Territory," 
---and return a new table containing the "Status," "Territory," 
---and the total number of orders for each status in that territory
	CREATE OR ALTER PROCEDURE GetStatusTerritoryOrdersSummary
    @Status NVARCHAR(255),
    @Territory NVARCHAR(255)
AS
BEGIN
    -- Create a temporary table to store the result data
    CREATE TABLE #TempSummary (
        [Status] NVARCHAR(255),
        [Territory] NVARCHAR(255),
        [TotalOrders] INT
    );

    -- Insert data into the temporary table
    INSERT INTO #TempSummary
    (
        [Status],
        [Territory],
        [TotalOrders]
    )
    SELECT
        s.[Status],
        t.[Territory],
        COUNT(o.[Order ID]) AS [TotalOrders]
    FROM
        [dbo].[Territory] t
    JOIN
        [dbo].[order] o ON t.[TerritoryID] = o.[TerritoryID]
    JOIN
        [dbo].[Status] s ON s.StatusID = o.StatusID
    WHERE
        t.[Territory] = @Territory
        AND s.[Status] = @Status
    GROUP BY
        s.[Status], t.[Territory];

    -- Select data from the temporary table
    SELECT * FROM #TempSummary;

    -- Drop the temporary table when done
    DROP TABLE #TempSummary;
END;
-------
EXEC GetStatusTerritoryOrdersSummary
    @Status = 'Shipped',
    @Territory = 'Northwest';
---------------------------------------------------------------------------------------------------------------------------------
---stored procedure that asks for a "segment " 
---and return a new table containing the Sub-Category 
---and number of Sub-Category for each element of the Sub-Category 
----and the total sales of each element.
CREATE OR ALTER PROCEDURE GetSubCategorySales
    @Segment NVARCHAR(255)
AS
BEGIN
    -- Create a temporary table to store the result
    CREATE TABLE #SubCategorySales (
        SubCategory NVARCHAR(255),
        NumElements INT,
        TotalSales MONEY
    );
    -- Insert data into the temporary table
    INSERT INTO #SubCategorySales (SubCategory, NumElements, TotalSales)
    SELECT
        p.[Sub-Category],
        COUNT(DISTINCT p.[Product ID]) AS NumElements,
        SUM(od.[Sales]) AS TotalSales
    FROM [dbo].[Customers] c
    JOIN [dbo].[order] o ON c.[Customer ID] = o.[Customer ID]
    JOIN [dbo].[OrderDetails] od ON o.[Order ID] = od.[Order ID]
    JOIN [dbo].[Products] p ON od.[Product ID] = p.[Product ID]
    WHERE c.[Segment] = @Segment
    GROUP BY p.[Sub-Category];
    -- Select data from the temporary table
    SELECT * FROM #SubCategorySales;
    -- Clean up the temporary table
    DROP TABLE #SubCategorySales;
END;
------
EXEC GetSubCategorySales @Segment = 'Consumer';
---------------------------------------------------------------------------------------------------------------------------
---stored procedure that asks for a "Product Name " 
---return table of total sales  and the largest territory according to total sales 
---and the percentage of its sales in relation to the total sales of the product Name. 
---If you do not enter Product Name, 
---it will display the Product Name in order according to sales in each territory

CREATE OR ALTER PROCEDURE GetProductSalesSummary
    @ProductName NVARCHAR(255) = NULL
AS
BEGIN
    -- Create a temporary table to store the result
    CREATE TABLE #ProductSalesSummary (
        [Product Name] NVARCHAR(255),
        [Territory] NVARCHAR(255),
        [TotalSales] MONEY
    );

    -- Insert data into the temporary table
    INSERT INTO #ProductSalesSummary ([Product Name], [Territory], [TotalSales])
    SELECT
        p.[Product Name],
        t.[Territory],
        SUM(od.[Sales]) AS [TotalSales]
    FROM
        [dbo].[OrderDetails] od
    JOIN
        [dbo].[Products] p ON od.[Product ID] = p.[Product ID]
    JOIN
        [dbo].[order] o ON od.[Order ID] = o.[Order ID]
    JOIN
        [dbo].[Territory] t ON o.[TerritoryID] = t.[TerritoryID]
    WHERE
        @ProductName IS NULL OR p.[Product Name] = @ProductName
    GROUP BY
        p.[Product Name], t.[Territory];

    -- Calculate the largest territory and its percentage of sales
    WITH LargestTerritoryCTE AS (
        SELECT
            [Product Name],
            [Territory],
            [TotalSales],
            ROW_NUMBER() OVER (PARTITION BY [Product Name] ORDER BY [TotalSales] DESC) AS RowNum
        FROM #ProductSalesSummary
    )

    SELECT
        L.[Product Name],
        L.[Territory] AS [Largest Territory],
        L.[TotalSales],
        ROUND((L.[TotalSales] / T.[TotalSales] * 100), 2) AS [PercentageOfSales]
    FROM LargestTerritoryCTE L
    JOIN (SELECT [Product Name], SUM([TotalSales]) AS [TotalSales] FROM #ProductSalesSummary GROUP BY [Product Name]) T
    ON L.[Product Name] = T.[Product Name]
    WHERE L.RowNum = 1;

    -- Clean up the temporary table
    DROP TABLE #ProductSalesSummary;
END;
EXEC GetProductSalesSummary  @ProductName = 'Tuff Stuff Recycled Round Ring Binders'

---------------------------------------------------------------------------------------------------------------------------------
---Find Top discount in each products

with cte 
as (
	  SELECT [Product Name],Sales,Quantity , max(discount ) as High_Discount
      FROM Products p , OrderDetails o where o.[Product ID] = p.[Product ID]
	  group by [Product Name],Sales,Quantity
      )

select * from cte
--------------------------------------------------------------------------------------------------------------------------------
---create a cursor that displays the customer name and his order date and the shipping date.

declare c cursor
for 
select  [Customer Name], o.[Ship Date] , o.[Order Date]
from orders o , Customers c
where o.[Customer ID] = c.[Customer ID]
order by [Order Date] 
for read only
declare @FUll_Name varchar(50),@Shipping_date Date , @order_date date
open c
fetch c into @FUll_Name ,@Shipping_date,@order_date
while @@FETCH_STATUS = 0
begin
select  @FUll_Name as FULL_Name ,@Shipping_date as SHIPPING_Date,@order_date as ORDER_Date
fetch c into @FUll_Name ,@Shipping_date,@order_date
end
close c

deallocate c
----------------------------------------------------------------------------------------------------------------------------

