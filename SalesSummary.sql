/************************************************************************
	Title: Sales Metric Calculation By Year, Sales Channel and Postal Code
	Author: Aakash Patel
	Created Date: 05/14/2013
*************************************************************************/
	

USE [AdventureWorks2008R2]

--Placeholder Definition
DECLARE @TransactionAmtPlaceHolder INT = 0
DECLARE @RevenuePlaceHolder INT = 0
DECLARE @DistinctBuyerPlaceHolder INT = 0
DECLARE @InternetSalesChannel VARCHAR(55) = 'Internet'
DECLARE @ResellerSalesChannel VARCHAR(55) = 'Reseller'



--Delete Temp Tables
IF  EXISTS (SELECT * FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(N'tempdb..#tblSummary') AND type in (N'U'))
DROP TABLE #tblSummary

IF  EXISTS (SELECT * FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(N'tempdb..#tblSalesDim') AND type in (N'U'))
DROP TABLE #tblSalesDim

IF  EXISTS (SELECT * FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(N'tempdb..#tblTransaction') AND type in (N'U'))
DROP TABLE #tblTransaction

/** Metric Calculation ******************************************/
--Internet Sales Channel
SELECT PostalCode
	,CASE WHEN OnlineOrderFlag = 1 THEN @InternetSalesChannel ELSE @ResellerSalesChannel END SalesChannel
	,YEAR(O.OrderDate) [Year] 
	,SUM(SubTotal)/COUNT(SalesOrderID) AvgTransactionAmt
	,SUM(SubTotal+Freight) TotalRevenue 
	,COUNT(DISTINCT CustomerID) DistinctBuyers 
INTO #tblTransaction
FROM Sales.SalesOrderHeader O
	INNER JOIN Person.Address A
	ON O.BillToAddressID = A.AddressID
	INNER JOIN Person.StateProvince S
	ON S.StateProvinceID = A.StateProvinceID
WHERE S.CountryRegionCode = 'US'
GROUP BY A.PostalCode, YEAR(O.OrderDate), OnlineOrderFlag



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



--Final Summary Table
SELECT P.PostalCode
	,P.[Year]
	,P.[SalesChannel]
	,ISNULL(T.AvgTransactionAmt,@TransactionAmtPlaceHolder) AvgTransactionAmt
	,ISNULL(T.TotalRevenue,@RevenuePlaceHolder) TotalRevenue
	,ISNULL(T.DistinctBuyers,@DistinctBuyerPlaceHolder) DistinctBuyers
INTO #tblSummary
FROM #tblSalesDim P
LEFT OUTER JOIN #tblTransaction T
	ON P.PostalCode = T.PostalCode AND P.[Year] = T.[Year] AND P.SalesChannel = T.SalesChannel
ORDER BY P.[Year], P.PostalCode, P.SalesChannel


--Select Data
SELECT * FROM #tblSummary