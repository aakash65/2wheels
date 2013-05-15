/************************************************************************
	Title: Popular Product Category By Year, Sales Channel and Postal Code
	Author: Aakash Patel
	Created Date: 05/14/2013
*************************************************************************/

USE [AdventureWorks2008R2]

--Placeholder Definition
DECLARE @ProductCategoryPlaceHolder VARCHAR(50) = 'NA'
DECLARE @InternetSalesChannel VARCHAR(55) = 'Internet'
DECLARE @ResellerSalesChannel VARCHAR(55) = 'Reseller'



--Delete Temp Tables
IF  EXISTS (SELECT * FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(N'tempdb..#tblProductCategorySummary') AND type in (N'U'))
DROP TABLE #tblProductCategorySummary

IF  EXISTS (SELECT * FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(N'tempdb..#tblSalesDim') AND type in (N'U'))
DROP TABLE #tblSalesDim

IF  EXISTS (SELECT * FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(N'tempdb..#tblCategory') AND type in (N'U'))
DROP TABLE #tblCategory


/** Popular Product Category ******************************************/
--Internet Sales Channel
SELECT Z.PostalCode
	,SalesChannel
	,Z.[Year]
	,PC.Name PopularProductCategory 
INTO #tblCategory
FROM 
(
	SELECT A.PostalCode
			,CASE WHEN O.OnlineOrderFlag = 1 THEN @InternetSalesChannel ELSE @ResellerSalesChannel END SalesChannel
			,YEAR(O.OrderDate) [Year]
			,PC.ProductCategoryID
			,SUM(OD.OrderQty) ProductSold
			,RANK() OVER(Partition BY A.PostalCode, YEAR(O.OrderDate), O.OnlineOrderFlag ORDER BY SUM(OD.OrderQty) DESC) Rnk
	FROM Sales.SalesOrderHeader O
		INNER JOIN Sales.SalesOrderDetail OD
			ON O.SalesOrderID = OD.SalesOrderID
		INNER JOIN Production.Product P
			ON OD.ProductID = P.ProductID
		INNER JOIN Production.ProductSubcategory PS
			ON P.ProductSubcategoryID = PS.ProductSubcategoryID
		INNER JOIN Production.ProductCategory PC
			ON PS.ProductCategoryID = PC.ProductCategoryID 
		INNER JOIN Person.Address A
			ON O.BillToAddressID = A.AddressID
		INNER JOIN Person.StateProvince S
			ON S.StateProvinceID = A.StateProvinceID
	WHERE S.CountryRegionCode = 'US'
	GROUP BY A.PostalCode, PC.ProductCategoryID, YEAR(O.OrderDate), O.OnlineOrderFlag
) Z
INNER JOIN Production.ProductCategory PC
	ON PC.ProductCategoryID = Z.ProductCategoryID
WHERE Z.Rnk = 1
ORDER BY Z.[Year], Z.PostalCode, Z.SalesChannel



/** Dimension Set  ******************************************************************/
SELECT DISTINCT A.PostalCode
	,SalesChannel
	,O.Year
INTO #tblSalesDim
FROM Person.Address A
	INNER JOIN Person.StateProvince S
		ON S.StateProvinceID = A.StateProvinceID
	CROSS JOIN (SELECT DISTINCT YEAR(OrderDate) [Year] FROM Sales.SalesOrderHeader) O 
	CROSS JOIN (SELECT @InternetSalesChannel SalesChannel UNION SELECT @ResellerSalesChannel) SC
WHERE S.CountryRegionCode = 'US'
ORDER BY Year,PostalCode


--ProductCategory Summary
SELECT P.PostalCode
	,P.[Year]
	,P.SalesChannel
	,ISNULL(C.PopularProductCategory,@ProductCategoryPlaceHolder) PopularProductCategory
INTO #tblProductCategorySummary
FROM #tblSalesDim P
LEFT OUTER JOIN #tblCategory C
	ON P.PostalCode = C.PostalCode AND P.[Year] = C.[Year] AND P.SalesChannel = C.SalesChannel
ORDER BY P.[Year], P.PostalCode, P.SalesChannel


--Select Data
SELECT * FROM #tblProductCategorySummary