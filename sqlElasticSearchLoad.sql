Use AdventureWorks2017
GO
DROP PROCEDURE IF EXISTS dbo.sqlElasticSearchLoad;
GO
CREATE PROCEDURE dbo.sqlElasticSearchLoad
AS
SET NOCOUNT ON
--python script to 
DECLARE @pscript  as NVARCHAR(MAX)
DECLARE @sqlQuery as NVARCHAR(MAX)

SET @pscript = N'
from elasticsearch import helpers
from elasticsearch import Elasticsearch
import calendar as cl
from datetime import datetime
from dateutil.parser import parse

es = Elasticsearch([{''host'':''localhost'',''port'':9200}])

dfInput = InputDataSet
dfInput["OrderDate"] = dfInput["OrderDate"].apply(lambda x :parse(x).date())

columns = list(dfInput.columns)

def filterKeys(document):
    return {key: document[key] for key in columns}

def doc_generator(df):
    df_iter = df.iterrows()
    for i, document in df_iter:
        yield {
                "_index" : "adventures",
                "_type"  : "lineitem",
                "_source": filterKeys(document)
                }
  
helpers.bulk(es,doc_generator(dfInput), chunk_size=1000, request_timeout=200)

print(''Data successfully pushed to ElasticSearch'')
'
--OutputDataSet=dfInput
--Define the sql query to extract the data
SET @sqlQuery = N'

	select cast(s.LineTotal as float) LineTotal, cast(h.OrderDate as char(12)) OrderDate ,p.ProductID,p.Name ProductName,h.Status,Month(OrderDate) OrderMonth,Format(orderdate,''MMM'') OrderMonths ,Year(OrderDate) OrderYear,
	  s.OrderQty,cast(s.UnitPrice as float)UnitPrice,cast(s.UnitPriceDiscount as float)UnitPriceDiscount,ps.Name ProductSubCategoryName,pc.Name ProductCategoryName,
	  CONCAT (sp.FirstName,'' ,'', sp.LastName) SalesPersonName
	from Sales.SalesOrderDetail s 
	Inner join Sales.SalesOrderHeader h on s.SalesOrderID=h.SalesOrderID
	Left join Production.Product p on p.ProductID = s.ProductID
	left join Production.ProductSubcategory ps on p.ProductSubcategoryID=ps.ProductSubcategoryID
	left join Production.ProductCategory pc on pc.ProductCategoryID=ps.ProductCategoryID
	left join Person.Person sp on sp.BusinessEntityID = h.SalesPersonID
'

-- run sql query using pythpn

EXEC sp_execute_external_script 
@language = N'Python',
@script   = @pscript,
@input_data_1 = @sqlQuery


