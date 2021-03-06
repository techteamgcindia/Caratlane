USE [SymphonyCL]
GO
/****** Object:  StoredProcedure [dbo].[AfterCreate]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[AfterCreate] 
	@objectType sysname,
	@objectName sysname
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	IF OBJECT_ID(@objectName) IS NOT NULL
		PRINT '<<< CREATED ' + @objectType + ' ' + @objectName + ' >>>'
	ELSE
		PRINT '<<< FAILED CREATING ' + @objectType + ' ' + @objectName + ' >>>'

END
GO
/****** Object:  StoredProcedure [dbo].[AssortmentReplenishmentReport]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
/******************************************/
/***** End Create Utility Procedures ******/
/******************************************/

/******************************************/
/******** Diagnostic Procedures ***********/
/******************************************/


CREATE PROCEDURE [dbo].[AssortmentReplenishmentReport] 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	CREATE TABLE #LocationCatalogSkusEx(
		[id] [int] NOT NULL,
		[skuID] [int] NOT NULL,
		[categoryID] [int] NOT NULL,
		[categoryName] [nvarchar](100) NOT NULL,
		[stockLocationID] [int] NOT NULL,
		[stockLocationName] [nvarchar] (100) NOT NULL,
		[originStockLocationID] [int] NOT NULL,
		[replenishmentTypeID] [tinyint] NOT NULL,
		[maxPipeline] [decimal](18, 5) NOT NULL,
		[normLevel] [decimal](18, 5) NOT NULL,
		[minimumReplenishment] [decimal] NULL,
		[lastBatchReplenishment] [decimal] (18, 5) NULL,
		[replenishmentMultiplications] [decimal] NULL,

	 CONSTRAINT [PK_LocationCatalogSkusEx] PRIMARY KEY CLUSTERED 
	(
		[stockLocationID] ASC,
		[categoryID] ASC,
		[skuID] ASC
	)ON [PRIMARY]
	);

	CREATE INDEX [IX_LocationCatalogSkusEx] ON #LocationCatalogSkusEx (id) ON [PRIMARY]

	INSERT INTO #LocationCatalogSkusEx
		SELECT 
			   [LCS].[id]
			  ,[LCS].[skuID]
			  ,[CS].[categoryID]
			  ,[C].[categoryName]
			  ,[LCS].[stockLocationID]
			  ,[SL].[stockLocationName]
			  ,[LCS].[originStockLocationID]
			  ,[LCS].[replenishmentTypeID]
			  ,[LCS].[maxPipeline]
			  ,[LC].[normLevel]
			  ,[LCS].[minimumReplenishment]
			  ,[LCS].[lastBatchReplenishment]
			  ,[LCS].[replenishmentMultiplications]
		FROM [dbo].[Symphony_LocationCatalogSkus] LCS
		INNER JOIN [dbo].[Symphony_CatalogSkus] CS
			ON CS.skuID = LCS.skuID
		INNER JOIN [dbo].[Symphony_LocationCategories] LC
			ON LC.categoryID = CS.categoryID
			AND LC.stockLocationID = LCS.stockLocationID
		INNER JOIN [dbo].[Symphony_Categories] C
			ON C.categoryID = CS.categoryID
		INNER JOIN [dbo].[Symphony_StockLocations] SL
			ON SL.stockLocationID = LCS.stockLocationID

	--SELECT * FROM #LocationCatalogSkusEx
	PRINT 'Table LocationCatalogSkusEx Created'

	CREATE TABLE #AssortmentReplenishmentRecommendationsEx(
		[id] [int] NOT NULL,
		[parentID] [int] NULL,
		[categoryID] [int] NULL,
		[originalSkuID] [int] NULL,
		[originalStockLocationID] [int] NULL,
		[originalLocationCatalogID] [int] NOT NULL,
		[originalInventoryNeeded] [decimal](18, 5) NOT NULL,
		[originalDaysAtStockLocation] [int] NOT NULL,
		[skuID] [int] NULL,
		[stockLocationID] [int] NULL,
		[locationCatalogID] [int] NOT NULL,
		[inventoryNeeded] [decimal](18, 5) NOT NULL,
		[inventoryInPipeline] [decimal](18, 5) NOT NULL,
		[replenishmentTypeID] [tinyint] NOT NULL,
		[replenishmentModeID] [tinyint] NOT NULL,
	 CONSTRAINT [PK_AssortmentReplenishmentRecommendationsEx] PRIMARY KEY CLUSTERED 
	(
		[id] ASC
	)
	);


	INSERT INTO #AssortmentReplenishmentRecommendationsEx
	SELECT 
		 [ARR].[id]
		,[ARR].[parentID]
		,CASE
			WHEN [OLCS].[categoryID] > 0 THEN [OLCS].[categoryID]
			ELSE [LCS].[categoryID]
		 END AS [categoryID]
		,[OLCS].[skuID] AS [originalSkuID] 
		,[OLCS].[stockLocationID] AS [originalStockLocationID]
		,[ARR].[originalLocationCatalogID]
		,[ARR].[originalInventoryNeeded]
		,[ARR].[originalDaysAtStockLocation]
		,[LCS].[skuID]
		,[LCS].[stockLocationID]
		,[ARR].[locationCatalogID]
		,[ARR].[inventoryNeeded]
		,[ARR].[inventoryInPipeline]
		,ISNULL([LCS].[replenishmentTypeID],255)
		,[ARR].[replenishmentModeID]
	FROM [dbo].[Symphony_AssortmentReplenishmentRecommendations] ARR
	LEFT JOIN #LocationCatalogSkusEx LCS
		ON LCS.[id] = ARR.[locationCatalogID]
	LEFT JOIN #LocationCatalogSkusEx OLCS
		ON OLCS.[id] = ARR.[originalLocationCatalogID]

	PRINT 'Table AssortmentReplenishmentRecommendationsEx Created'
	--SELECT * FROM #AssortmentReplenishmentRecommendationsEx
	
	DECLARE @InventoryNeededSummaries AS TABLE(
		 [id] [int] IDENTITY(1,1)
		,[skuID] [int]
		,[categoryID] [int]
		,[stockLocationID] [int]
		,[inventoryNeeded] [decimal](18,5)
		,[recommendedInventory] [decimal](18,5)
)	
	
	INSERT INTO @InventoryNeededSummaries
		SELECT 
			 TMP.skuID
			,TMP.categoryID
			,TMP.stockLocationID
			,SLS.inventoryNeeded
			,TMP.recommendedInventory
		FROM (
			SELECT 
				 skuID
				,categoryID
				,stockLocationID
				,SUM(inventoryNeeded) AS [recommendedInventory]
			FROM #AssortmentReplenishmentRecommendationsEx 
			WHERE locationCatalogID > 0 AND inventoryNeeded > 0
			GROUP BY stockLocationID,categoryID,skuID) TMP
		LEFT JOIN Symphony_StockLocationSkus SLS
			ON SLS.stockLocationID = TMP.stockLocationID
			AND SLS.skuID = TMP.skuID


	PRINT 'Table InventoryNeededSummaries Created'

	DECLARE @npiThreshold int
	SELECT @npiThreshold = CAST([flag_value] AS [int]) FROM [dbo].[Symphony_Globals] WHERE [flag_name] = N'elapsedTimeThreshold.NPI'

	DECLARE @mtrThreshold int
	SELECT @mtrThreshold = CAST([flag_value] AS [int]) FROM [dbo].[Symphony_Globals] WHERE [flag_name] = N'elapsedTimeThreshold.MTR'
	
	DECLARE @RecommendationCountsByType AS TABLE(
		 [id] [int] IDENTITY(1,1)
		,[skuID] [int]
		,[categoryID] [int]
		,[stockLocationID] [int]
		,[npiCount] [decimal](18,5)
		,[mtrCount] [decimal](18,5)
		,[mtarCount] [decimal](18,5)
		,[inactiveCount] [decimal](18,5)
		,[inventoryNeeded] [decimal](18,5)
	)

	INSERT INTO @RecommendationCountsByType
		SELECT 
			 ARR.[skuID]
			,ARR.[categoryID]
			,ARR.[stockLocationID]
			,CASE WHEN [replenishmentTypeID] = 0 AND [originalDaysAtStockLocation] < @npiThreshold THEN ISNULL(ARR.[inventoryNeeded],0) ELSE 0 END
			,CASE WHEN [replenishmentTypeID] = 1 AND (([originalDaysAtStockLocation] > 0 AND [originalDaysAtStockLocation] < @mtrThreshold) OR ([originalDaysAtStockLocation] = 0 AND INS.inventoryNeeded = INS.recommendedInventory)) THEN ISNULL(ARR.[inventoryNeeded],0)  ELSE 0 END
			,CASE WHEN [replenishmentTypeID] = 2  THEN ISNULL(ARR.[inventoryNeeded],0) ELSE 0 END
			,CASE WHEN [replenishmentTypeID] = 3  THEN ISNULL(ARR.[inventoryNeeded],0) ELSE 0 END	
			,ARR.[inventoryNeeded]
		FROM #AssortmentReplenishmentRecommendationsEx ARR
		INNER JOIN @InventoryNeededSummaries INS
			ON INS.skuID = ARR.skuID
			AND INS.stockLocationID = ARR.stockLocationID
		WHERE ARR.[inventoryNeeded] > 0

	DECLARE @Results AS TABLE(
		 [stockLocationName] [nvarchar](100)
		,[categoryName] [nvarchar](100)
		,[DELTA][decimal](18,5)
		,[normLevel][decimal](18,5)
		,[allowance][decimal](18,5)
		,[totalPipeLine][decimal](18,5)
		,[pipeLine][decimal](18,5)
		,[orderedInventory][decimal](18,5)
		,[recommendedInventory][decimal](18,5)
		,[npiCount] [decimal](18,5)
		,[mtrCount] [decimal](18,5)
		,[stockLocationID] [int]
		,[categoryID] [int]
	)


	INSERT INTO @Results
	 SELECT DISTINCT
		 LCS.stockLocationName
		,LCS.categoryName
		,TMP.pipeLine + ISNULL(TMP.recommendedInventory,0) + ISNULL(TMP.orderedInventory,0) - LCS.normLevel AS [DELTA]
		,LCS.normLevel
		,TMP.Allowance
		,TMP.pipeLine + ISNULL(TMP.recommendedInventory,0) + ISNULL(TMP.orderedInventory,0) AS [totalPipeLine]
		,TMP.pipeLine
		,TMP.orderedInventory
		,TMP.recommendedInventory
		,TMP.npiCount
		,TMP.mtrCount
		,LCS.stockLocationID
		,LCS.categoryID
	 FROM (

				SELECT 
					 SLS.stockLocationID
					,SLS.categoryID  
					,SLS.pipeLine
					,SLS.Allowance
					,ART.orderedInventory
					,ARR.recommendedInventory
					,ARR.npiCount
					,ARR.mtrCount
					,ARR.mtarCount
					,ARR.inactiveCount
				FROM (
					SELECT --Sum of pipeline per category
						 LCS.stockLocationID
						,LCS.categoryID  
						,LCS.normLevel
						,SUM(LCS.maxPipeline) AS [Allowance]
						,SUM(SLS.inventoryAtSite + SLS.inventoryAtTransit + SLS.inventoryAtProduction) AS [pipeLine]
					FROM #LocationCatalogSkusEx LCS
					LEFT JOIN Symphony_StockLocationSkus SLS
						ON SLS.skuID = LCS.skuID
						AND SLS.stockLocationID = LCS.stockLocationID
					GROUP BY
						 LCS.stockLocationID
						,LCS.categoryID  
						,LCS.normLevel
					) SLS
				LEFT JOIN (
					SELECT 
						 stockLocationID
						,categoryID
						,SUM(npiCount) AS [npiCount]
						,SUM(mtrCount) AS [mtrCount]
						,SUM(mtarCount) AS [mtarCount]
						,SUM(inactiveCount) AS [inactiveCount]
						,SUM(inventoryNeeded) AS [recommendedInventory]
					FROM @RecommendationCountsByType
					GROUP BY stockLocationID, categoryID) ARR
					
					--SELECT --Sum of Recommendations per sl category
					--	 LCS.stockLocationID
					--	,LCS.categoryID  
					--	,SUM(ARR.inventoryNeeded) AS [recommendedInventory]
					--FROM #AssortmentReplenishmentRecommendationsEx ARR
					--INNER JOIN #LocationCatalogSkusEx LCS
					--	ON LCS.id = ARR.locationCatalogID
					--WHERE ARR.inventoryNeeded > 0
					--GROUP BY LCS.stockLocationID,LCS.categoryID) ARR
					
				ON ARR.stockLocationID = SLS.stockLocationID
				AND ARR.categoryID = SLS.categoryID
				LEFT JOIN (
					SELECT --Sum of pending orders per sl category
						 LCS.stockLocationID
						,LCS.categoryID  
						,SUM(ART.quantity) AS [orderedInventory]
					FROM Symphony_AssortmentReplenishmentTracking ART
					INNER JOIN #LocationCatalogSkusEx LCS
						ON LCS.skuID = ART.skuID
						AND LCS.stockLocationID = ART.stockLocationID
					GROUP BY LCS.stockLocationID,LCS.categoryID) ART
				ON ART.stockLocationID = SLS.stockLocationID
				AND ART.categoryID = SLS.categoryID
		) TMP
		
	INNER JOIN #LocationCatalogSkusEx LCS
	ON LCS.categoryID = TMP.categoryID
	AND LCS.stockLocationID = TMP.stockLocationID
	
	PRINT 'Table Results Created'

	SELECT 
		 [stockLocationName]
		,[categoryName]
		,[DELTA]
		,[normLevel]
		,[allowance]
		,[totalPipeLine]
		,[pipeLine]
		,[orderedInventory]
		,[recommendedInventory]
		,[npiCount]
		,[mtrCount]
		,[stockLocationID]
		,[categoryID]
	FROM @Results
	WHERE [DELTA] < 0
	AND [normLevel] <= [allowance]
	ORDER BY [stockLocationName], [categoryName]

	SELECT 
		 [stockLocationName]
		,[categoryName]
		,[DELTA]
		,[normLevel]
		,[allowance]
		,[totalPipeLine]
		,[pipeLine]
		,[orderedInventory]
		,[recommendedInventory]
		,[npiCount]
		,[mtrCount]
		,[stockLocationID]
		,[categoryID]
	FROM @Results
	WHERE [DELTA] > 0
	AND ISNULL([recommendedInventory],0) <> ([npiCount] + [mtrCount])
	ORDER BY [stockLocationName], [categoryName]

	SELECT 
		 [stockLocationName]
		,[categoryName]
		,[DELTA]
		,[normLevel]
		,[allowance]
		,[totalPipeLine]
		,[pipeLine]
		,[orderedInventory]
		,[recommendedInventory]
		,[npiCount]
		,[mtrCount]
		,[stockLocationID]
		,[categoryID]
	FROM @Results
	
	END
GO
/****** Object:  StoredProcedure [dbo].[BeforeCreate]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[BeforeCreate] 
	-- Add the parameters for the stored procedure here
	@objectType sysname,
	@objectName sysname
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF OBJECT_ID(@objectName) IS NOT NULL
	BEGIN
		EXEC ('DROP ' + @objectType + ' ' + @objectName)
		IF OBJECT_ID(@objectName) IS NOT NULL
			PRINT '<<< FAILED DROPPING ' + @objectType + ' ' + @objectName + ' >>>'
		ELSE
			PRINT '<<< DROPPED ' + @objectType + ' ' + @objectName + ' >>>'
	END

END
GO
/****** Object:  StoredProcedure [dbo].[Client_SP_AG_alignment_Pre_Post]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Client_SP_AG_alignment_Pre_Post]
AS
BEGIN
drop table clinet_table_AG_alignment_post_LnR

select * into clinet_table_AG_alignment_post_LnR  from

(

SELECT sl.stockLocationName as [Stock Location]
       ,sl.stockLocationDescription as [SL Description]
       ,slpi1.slItemName as [City]
	  ,slpi2.slItemName as [Region]
	  ,slpi3.slItemName as [State]
	  ,slpi6.slItemName as [Store Group]
	  ,ag.name as [Assortment Group] 
	  ,ag.description as [AG Description]
	  ,dg.name as [Display Group]
	  ,varietyTarget [Variety Target]
	  ,spaceTarget [Space Target]
	   ,case when gapMode=0 then 'Variety' else 'Space' end [Gap Mode]
	    ,validFamiliesNum+(notValidFamiliesNum - notValidFamiliesOverThresholdNum)+notValidFamiliesOverThresholdNum as [SKU Families]
	  ,validFamiliesNum as [Valid SKU Families]
	  ,(notValidFamiliesNum - notValidFamiliesOverThresholdNum) [Newly Invalid Families]
       ,[notValidFamiliesOverThresholdNum] [Expired Invalid Families]
	   ,case when agBP=-1 then '0' else agbp end as [AG Penetration]
	        ,case when varietyGap<0 then 0 else varietyGap end [Variety Gap]
           ,case when spaceGap<0 then 0 else spaceGap end [Sapce Gap]
		,agh.totalSpace [Total Space]
		,a.buffer [Total Buffer]
		,a.site [Total Stock at Site]
		,a.transit [Total stock at Transit]
		,aa.site as [Valid_Site]
		,aa.transit [Valid Transit]
		,aaa.site [Expired_Site]
		,aaa.transit [Expired_Transit]
	   	 ,cast(getdate() as date) as [Date]
  FROM [SymphonyCL].[dbo].[Symphony_LocationAssortmentGroups] agh
  left join Symphony_AssortmentGroups ag on ag.id=agh.assortmentGroupID
  left join Symphony_StockLocations sl on sl.stockLocationID=agh.stockLocationID
  left join Symphony_RetailAgDgConnection agdg on agdg.assortmentGroupID=ag.id
  left join Symphony_DisplayGroups dg on dg.id=agdg.displayGroupID
  left join Symphony_StockLocationPropertyItems slpi1 on slpi1.slItemID=sl.slPropertyID1
 left join Symphony_StockLocationPropertyItems slpi2 on slpi2.slItemID=sl.slPropertyID2
left join Symphony_StockLocationPropertyItems slpi3 on slpi3.slItemID=sl.slPropertyID3
left join Symphony_StockLocationPropertyItems slpi4 on slpi4.slItemID=sl.slPropertyID4
left join Symphony_StockLocationPropertyItems slpi5 on slpi5.slItemID=sl.slPropertyID5
left join Symphony_StockLocationPropertyItems slpi6 on slpi6.slItemID=sl.slPropertyID6
left join Symphony_StockLocationPropertyItems slpi7 on slpi7.slItemID=sl.slPropertyID7
left join (SELECT sl.stockLocationName
        ,ag.name ag_name
     ,sum(bufferSize) as buffer
	 ,sum(inventoryAtSite) as site
	 ,sum(inventoryAtTransit) transit
  FROM [Symphony_StockLocationSkus] sls
    join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  join Symphony_SkuFamilies sf on sf.id=ms.familyID
  join Symphony_StockLocations sl on sl.stockLocationID=sls.stockLocationID
  join Symphony_RetailFamilyAgConnection rfac on rfac.familyID=sf.id
  join Symphony_AssortmentGroups ag on ag.id=rfac.assortmentGroupID
  join Symphony_SKUs s on s.skuID=sls.skuID
  where sls.isDeleted=0 and sl.isDeleted=0
  group by sl.stockLocationName,ag.name)a on a.stockLocationName=sl.stockLocationName and a.ag_name=ag.name

  left join (SELECT sl.stockLocationName
        ,ag.name ag_name
     ,sum(bufferSize) as buffer
	 ,sum(inventoryAtSite) as site
	 ,sum(inventoryAtTransit) transit
  FROM [Symphony_StockLocationSkus] sls
    join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  join Symphony_SkuFamilies sf on sf.id=ms.familyID
  join Symphony_StockLocations sl on sl.stockLocationID=sls.stockLocationID
  join Symphony_RetailFamilyAgConnection rfac on rfac.familyID=sf.id
  join Symphony_AssortmentGroups ag on ag.id=rfac.assortmentGroupID
  join Symphony_SKUs s on s.skuID=sls.skuID
  join Symphony_FamilyValidationResults fvr on fvr.familyID=ms.familyID and fvr.stockLocationID=sls.stockLocationID
  where sls.isDeleted=0 and sl.isDeleted=0 and fvr.isValid=1
  group by sl.stockLocationName,ag.name)aa on aa.stockLocationName=sl.stockLocationName and aa.ag_name=ag.name


    left join (SELECT sl.stockLocationName
        ,ag.name ag_name
     ,sum(bufferSize) as buffer
	 ,sum(inventoryAtSite) as site
	 ,sum(inventoryAtTransit) transit
  FROM [Symphony_StockLocationSkus] sls
    join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  join Symphony_SkuFamilies sf on sf.id=ms.familyID
  join Symphony_StockLocations sl on sl.stockLocationID=sls.stockLocationID
  join Symphony_RetailFamilyAgConnection rfac on rfac.familyID=sf.id
  join Symphony_AssortmentGroups ag on ag.id=rfac.assortmentGroupID
  join Symphony_SKUs s on s.skuID=sls.skuID
  join Symphony_FamilyValidationResults fvr on fvr.familyID=ms.familyID and fvr.stockLocationID=sls.stockLocationID
  where sls.isDeleted=0 and sl.isDeleted=0 and fvr.isValid=0 and fvr.isInvalidOverThreshold=1
  group by sl.stockLocationName,ag.name)aaa on aaa.stockLocationName=sl.stockLocationName and aaa.ag_name=ag.name


where sl.isDeleted=0 --and ag.name='W_ANNABELLE_ TOP' and sl.stockLocationName='P033'
)#erf




--

select pre_l.[stock location], 
       pre_l.[Assortment Group],
	   pre_l.[Display Group],
	   pre_l.[Variety Target],
	   pre_l.[Space Target],
	   pre_l.[Gap Mode],
	   pre_l.[Valid SKU Families] as [Pre_Valid SKU Families],
	   pre_l.[Newly Invalid Families] as [Pre_Newly Invalid Families],
	  

	   pre_l.[Total Buffer] as [Pre_Total Buffer],
	   pre_l.[Total Stock at Site] as [Pre_Total Stock at Site],
       pre_l.[Total Stock at Transit] as [Pre_Total Stock at Transit],
	   pre_l.[Variety Gap] as [Pre_Variety Gap],


	   post_l.[Valid SKU Families] as [Post_Valid SKU Families],
	   post_l.[Newly Invalid Families] as [Post_Newly Invalid Families],
	   post_l.[Total Buffer] as [post_Total Buffer],
	   post_l.[Total Stock at Site] as [post_Total Stock at Site],
       post_l.[Total Stock at Transit] as [post_Total Stock at Transit],
	   post_l.[Variety Gap] as [post_Variety Gap]
	   

   --	  cast (case when pre_l.[Variety Target]>0 then ((isnull (pre_l.[Valid SKU Families],0)  + isnull(pre_l.[Newly Invalid Families],0) ) / (pre_l.[Variety Target])) else 0 
	  
	--  end as decimal(10,2)) as Pre_Align
	  -- (post_l.[Valid SKU Families]  + post_l.[Newly Invalid Families] ) / nullif (pre_l.[Variety Target],0) as Post_Align


from clinet_table_AG_alignment_pre_LnR pre_L
left join clinet_table_AG_alignment_post_LnR Post_L on Post_L.[Stock Location]=pre_l.[Stock Location] and post_l.[Assortment Group]=pre_l.[Assortment Group]

end
GO
/****** Object:  StoredProcedure [dbo].[Client_SP_ALIGNMENT]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Client_SP_ALIGNMENT]
AS
BEGIN


drop table client_temp_todaysallocation2summary

  select * into client_temp_todaysallocation2summary from
   (
	select distinct 
	a.SL, ag.name as AG ,avg( lg.VT ) as VT,sum(Repl_Qty) as Repl_Qty
	
	from client_temp_todaysallocation1 a
	
	left join Symphony_SkuFamilies f on f.name=a.SKU
	left  join [dbo].[Symphony_RetailFamilyAgConnection] rfac on  rfac.familyid=f.id
	left  join [dbo].[Symphony_AssortmentGroups] ag on ag.id=rfac.assortmentgroupid
	left JOIN 
	(select sl.stockLocationName as SL,ag.name as AG ,lag.varietyTarget as VT from
	Symphony_LocationAssortmentGroups LAG 
	join Symphony_StockLocations sl on lag.stockLocationID=sl.stockLocationID
	left join [dbo].[Symphony_AssortmentGroups] ag on ag.id=LAG.assortmentgroupid) lg on lg.SL=a.SL and lg.AG=ag.name
    group by a.sl,ag.name
	)#ty




drop table client_tempp_todaypreLnRstatatus

select * into client_tempp_todaypreLnRstatatus from
(
select distinct a.SL, ag.name as AG ,avg( lg.VT ) as VT,sum(a.INV_Site) as site, sum(a.Inv_Transit) as tra_Qty
from Client_STATUS_TEMP a
left join Symphony_SkuFamilies f on f.name=a.SKU
	left  join [dbo].[Symphony_RetailFamilyAgConnection] rfac on  rfac.familyid=f.id
	left  join [dbo].[Symphony_AssortmentGroups] ag on ag.id=rfac.assortmentgroupid
	left JOIN 
	(select sl.stockLocationName as SL,ag.name as AG ,lag.varietyTarget as VT from
	Symphony_LocationAssortmentGroups LAG 
	join Symphony_StockLocations sl on lag.stockLocationID=sl.stockLocationID
	left join [dbo].[Symphony_AssortmentGroups] ag on ag.id=LAG.assortmentgroupid) lg on lg.SL=a.SL and lg.AG=ag.name
    group by a.sl,ag.name
	)#rtg


drop table client_tempp_Alignmentreport1

select * into client_tempp_Alignmentreport1 from
(

	select distinct sl,ag from client_tempp_todaypreLnRstatatus
	
	union
	select distinct sl,ag from client_temp_todaysallocation2summary
	)#fgv

	--select * from   client_tempp_Alignmentreport1

	
drop table client_tempp_Alignmentreport2

select * into client_tempp_Alignmentreport2 from
(

	select distinct al.SL,al.AG
	,case when ta.VT is null then ts.VT else ta.VT end as [Varity Target]
	,isnull (ts.site,0) as [Inv at Site Qty]
	,isnull (ts.tra_Qty,0) as [Inv at Transit Qty]
	,isnull (ta.Repl_Qty,0) as [Today's Allocated Qty]
	,isnull(ts.site,0)+isnull (ts.tra_Qty,0)+isnull (ta.Repl_Qty,0) as Total_stk
	
	from   client_tempp_Alignmentreport1 al
	left join client_temp_todaysallocation2summary ta on ta.sl=al.sl and ta.AG=al.AG
	left join  client_tempp_todaypreLnRstatatus ts on ts.sl=al.sl and ts.AG=al.AG
  )#ed	
	

	select distinct al.SL,al.AG
	, [Varity Target]

	,[Inv at Site Qty]
	, [Inv at Transit Qty]
	, [Today's Allocated Qty]
	,case when [Varity Target] is null then null else
	Total_stk/
	 nullif( [Varity Target],0) end as [Alignment]
	from   client_tempp_Alignmentreport2 al
	where al.ag is not null

end
GO
/****** Object:  StoredProcedure [dbo].[Client_SP_CITY_LEVEL_SALESESTIMATION]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Client_SP_CITY_LEVEL_SALESESTIMATION]
AS
BEGIN


SELECT  distinct  
   slpi.slItemName as City
 --    ,a.[familyID]
 --     ,s.stockLocationName
	  ,f.name  as Family
	   -- ,a.[stockLocationID]
     --,[assortmentGroupID]
	 ,ag.name  as   AG
      --,[propertyItemID]
      ,[salesEstimation]
      --,[decile]
  FROM [SymphonyCL].[dbo].[FamilySalesRankingByProperty] a
  join Symphony_StockLocations s on s.stockLocationID=a.stockLocationID
  join  Symphony_SkuFamilies f  on f.id=a.familyID
 join [dbo].[Symphony_StockLocationPropertyItems] slpi on slpi.slItemID=s.slPropertyID1
 left join Symphony_RetailFamilyAgConnection RFAC on RFAC.familyID=a.familyID
 join [dbo].[Symphony_AssortmentGroups] ag on ag.id=rfac.assortmentgroupid

 END
GO
/****** Object:  StoredProcedure [dbo].[Client_SP_MIS_REPORT]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Client_SP_MIS_REPORT]
AS
BEGIN


select SL.stockLocationName, SLS.locationSkuName as SKU,
     slpi1.slItemName as City,
	slpi2.slItemName as Region,
SKUPI1.skuItemName [category],
SKUPI2.skuItemName [Sub category],
SKUPI3.skuItemName [collection],
SKUPI4.skuItemName [Occasion],
SKUPI3.skuItemName [Theme],
SKUPI3.skuItemName [Gender],
sls.custom_txt3 [Store_MTR Type],
sls.custom_txt4 [Global_MTR Type],
sls.unitPrice [MRP],
SLS.InventoryAtTransit, SLS.inventoryAtSite, SLS.bufferSize, 
Case WHEN SLS.siteColor =0 THEN 'Cyan' 
     WHEN SLS.SiteColor =1 then 'Green' 
WHEN SLS.SiteColor =2 then 'Yellow' 
WHEN SLS.SiteColor =3 then 'Red' 
WHEN SLS.SiteColor =4 then 'Black'  
END [SiteColor],
Case WHEN SLS.TransitColor =0 THEN 'Cyan' 
     WHEN SLS.TransitColor =1 then 'Green' 
WHEN SLS.TransitColor =2 then 'Yellow' 
WHEN SLS.TransitColor =3 then 'Red' 
WHEN SLS.TransitColor =4 then 'Black'  
END [TransitColor],

RCONS.LastWeeksConsumption, RCONS.SiteStockoutDaysLastWeek, MCONS.Last30DaysConsumption, MCONS.SiteStockoutDaysLast30Days,
TMCONS.Last60DaysConsumption, TMCONS.SiteStockoutDaysLast60Days,
HMCONS.Last90DaysConsumption, HMCONS.SiteStockoutDaysLast90Days,
isnull(wavd.AvailableDaysLastWeek,0) as AvailableDaysLastWeek,
isnull(mavd.AvailableLast30Days,0) as AvailableLast30Days,
isnull(tmavd.AvailableLast60Days,0) as AvailableLast60Days,
isnull(Hmavd.AvailableLast90Days,0) as AvailableLast90Days,
OSL.StockLocationName [OriginWH],isnull(awh1.WHnewsiteStock,0) as [WH site Stock]
,isnull(ceiling(awh.LastWeekAverageWHsiteStock),0) as LastWeekAverageWHsiteStock,
FINW.firstInwarddate, datediff(day, FINW.firstInwarddate, getdate()+1) [DaysSinceFirstInward]
from Symphony_StockLocationSkus SLS
join Symphony_StockLocations SL on SL.stockLocationID = SLS.stockLocationID
Left JOIN Symphony_SkusPropertyItems SKUPI1 ON SLS.skuPropertyID1 = SKUPI1.skuItemID
Left JOIN Symphony_SkusPropertyItems SKUPI2 ON SLS.skuPropertyID2 = SKUPI2.skuItemID
Left JOIN Symphony_SkusPropertyItems SKUPI3 ON SLS.skuPropertyID3 = SKUPI3.skuItemID
Left JOIN Symphony_SkusPropertyItems SKUPI4 ON SLS.skuPropertyID4 = SKUPI4.skuItemID
Left JOIN Symphony_SkusPropertyItems SKUPI6 ON SLS.skuPropertyID6 = SKUPI6.skuItemID
left join Symphony_StockLocationPropertyItems slpi1 on slpi1.slItemID=sl.slPropertyID1
left join Symphony_StockLocationPropertyItems slpi2 on slpi2.slItemID=sl.slPropertyID2
Left join Symphony_Stocklocations OSL on OSL.stockLocationID = SLS.originStockLocation 

join (select stocklocationID, skuID, min(updatedate) [firstInwarddate] from Symphony_StockLocationSkuhistory 
where totalIn>0 OR InventoryAtSite>0 OR Consumption>0
group by stocklocationID, skuID) FINW on FINW.stocklocationID = SLS.stocklocationID and  FINW.skuID = SLS.skuID


left join (select SLSH.stockLocationID, SLSH.skuID, 
Sum ( Case when (totalIn>0 OR InventoryAtSite>0 OR Consumption>0) then 1 else 0 End ) [AvailableDaysLastWeek]
from Symphony_stocklocationskuhistory SLSH
where updateDate >= convert(date,GETDATE()-7)
group by SLSH.stockLocationID, SLSH.skuID ) WAVD on WAVD.stockLocationID = SLS.stockLocationID and WAVD.skuID = SLS.skuID

left join (select SLSH.stockLocationID, SLSH.skuID, 
Sum ( Case when (totalIn>0 OR InventoryAtSite>0 OR Consumption>0) then 1 else 0 End ) [AvailableLast30Days]
from Symphony_stocklocationskuhistory SLSH
where updateDate >= convert(date,GETDATE()-30)
group by SLSH.stockLocationID, SLSH.skuID ) MAVD on MAVD.stockLocationID = SLS.stockLocationID and MAVD.skuID = SLS.skuID

left join (select SLSH.stockLocationID, SLSH.skuID, 
Sum ( Case when (totalIn>0 OR InventoryAtSite>0 OR Consumption>0) then 1 else 0 End ) [AvailableLast60Days]
from Symphony_stocklocationskuhistory SLSH
where updateDate >=  convert(date,GETDATE()-60)
group by SLSH.stockLocationID, SLSH.skuID ) TMAVD on TMAVD.stockLocationID = SLS.stockLocationID and TMAVD.skuID = SLS.skuID

left join (select SLSH.stockLocationID, SLSH.skuID, 
Sum ( Case when (totalIn>0 OR InventoryAtSite>0 OR Consumption>0) then 1 else 0 End ) [AvailableLast90Days]
from Symphony_stocklocationskuhistory SLSH
where updateDate >=  convert(date,GETDATE()-90)
group by SLSH.stockLocationID, SLSH.skuID ) HMAVD on HMAVD.stockLocationID = SLS.stockLocationID and HMAVD.skuID = SLS.skuID



left join (select SLSH.stockLocationID, SLSH.skuID, avg(SLSH.inventoryAtSite) [LastWeekAverageWHsiteStock]
from Symphony_stocklocationskuhistory SLSH
where updateDate >=  convert(date,GETDATE()-7) 
group by SLSH.stockLocationID, SLSH.skuID ) AWH on AWH.stockLocationID = OSL.stockLocationID and AWH.skuID = SLS.skuID

left join (select distinct SLSH.stockLocationID, SLSH.skuID,SLSH.inventoryAtSite [WHnewsiteStock]
from Symphony_StockLocationSkus SLSh
) AWH1 on AWH1.stockLocationID = OSL.stockLocationID and AWH1.skuID = sls.skuID

left join (select SLSH.stockLocationID, SLSH.skuID, SUM(SLSH.consumption) [LastWeeksConsumption],
Sum ( Case when SLSH.InventoryAtSite > 0 or totalIn>0 OR InventoryAtSite>0 OR Consumption>0 then 0 else 1 End ) [SiteStockoutDaysLastWeek]
from Symphony_stocklocationskuhistory SLSH
join (select stocklocationID, skuID, min(updatedate) [firstInwarddate] from Symphony_StockLocationSkuhistory 
where totalIn>0 OR InventoryAtSite>0 OR Consumption>0
group by stocklocationID, skuID) FINW on FINW.stocklocationID = SLSH.stocklocationID and  FINW.skuID = SLSH.skuID
where updateDate >= convert(date,GETDATE()-7) and updatedate > convert(date,finw.firstInwarddate)
group by SLSH.stockLocationID, SLSH.skuID ) RCONS on RCONS.stockLocationID = SLS.stockLocationID and RCONS.skuID = SLS.skuID

left join (select SLSH.stockLocationID, SLSH.skuID, SUM(SLSH.consumption) [Last30DaysConsumption],
Sum ( Case when SLSH.InventoryAtSite > 0 or totalIn>0 OR InventoryAtSite>0 OR Consumption>0 then 0 else 1 End ) [SiteStockoutDaysLast30Days]
from Symphony_stocklocationskuhistory SLSH
join (select stocklocationID, skuID, min(updatedate) [firstInwarddate] from Symphony_StockLocationSkuhistory 
where totalIn>0 OR InventoryAtSite>0 OR Consumption>0
group by stocklocationID, skuID) FINW on FINW.stocklocationID = SLSH.stocklocationID and  FINW.skuID = SLSH.skuID
where updateDate >= convert(date,GETDATE()-30) and updatedate > convert(date,finw.firstInwarddate)
group by SLSH.stockLocationID, SLSH.skuID ) MCONS on MCONS.stockLocationID = SLS.stockLocationID and MCONS.skuID = SLS.skuID

left join (select SLSH.stockLocationID, SLSH.skuID, SUM(SLSH.consumption) [Last60DaysConsumption],
Sum ( Case when SLSH.InventoryAtSite > 0 or totalIn>0 OR InventoryAtSite>0 OR Consumption>0 then 0 else 1 End ) [SiteStockoutDaysLast60Days]
from Symphony_stocklocationskuhistory SLSH
join (select stocklocationID, skuID, min(updatedate) [firstInwarddate] from Symphony_StockLocationSkuhistory 
where totalIn>0 OR InventoryAtSite>0 OR Consumption>0
group by stocklocationID, skuID) FINW on FINW.stocklocationID = SLSH.stocklocationID and  FINW.skuID = SLSH.skuID
where updateDate >= convert(date,GETDATE()-60) and updatedate > convert(date,finw.firstInwarddate)
group by SLSH.stockLocationID, SLSH.skuID ) TMCONS on TMCONS.stockLocationID = SLS.stockLocationID and TMCONS.skuID = SLS.skuID


left join (select SLSH.stockLocationID, SLSH.skuID, SUM(SLSH.consumption) [Last90DaysConsumption],
Sum ( Case when SLSH.InventoryAtSite > 0 or totalIn>0 OR InventoryAtSite>0 OR Consumption>0 then 0 else 1 End ) [SiteStockoutDaysLast90Days]
from Symphony_stocklocationskuhistory SLSH
join (select stocklocationID, skuID, min(updatedate) [firstInwarddate] from Symphony_StockLocationSkuhistory 
where totalIn>0 OR InventoryAtSite>0 OR Consumption>0
group by stocklocationID, skuID) FINW on FINW.stocklocationID = SLSH.stocklocationID and  FINW.skuID = SLSH.skuID
where updateDate >= convert(date,GETDATE()-90) and updatedate > convert(date,finw.firstInwarddate)
group by SLSH.stockLocationID, SLSH.skuID ) HMCONS on HMCONS.stockLocationID = SLS.stockLocationID and HMCONS.skuID = SLS.skuID


where SLS.isDeleted = 0 and sl.stockLocationType=3 and OSL.Stocklocationname in ('CL-FC-MUM-WICEL') 

end
GO
/****** Object:  StoredProcedure [dbo].[Client_SP_MTSSKU_UPDATE]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Client_SP_MTSSKU_UPDATE]
AS
BEGIN

update sls
set sls.custom_num2 = osls.inventoryAtSite 
FROM [dbo].[Symphony_StockLocationSkus] sls
JOIN [dbo].[Symphony_StockLocationSkus] osls on sls.originStockLocation=osls.stockLocationID AND SLS.locationSkuName=OSLS.locationSkuName
where sls.isdeleted = 0 and osls.isdeleted = 0 


 update sls set sls.unitPrice=ms.unitPrice
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where sls.unitPrice<>ms.unitPrice
  and sls.isDeleted=0

  update sls set sls.TVC=ms.tvc
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where sls.TVC<>ms.tvc
  and sls.isDeleted=0 

  update sls set sls.Throughput=ms.throughput
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where sls.Throughput<>ms.throughput
  and sls.isDeleted=0 


  update sls set sls.skuPropertyID1=ms.skuPropertyID1
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.skuPropertyID1<>ms.skuPropertyID1 or sls.skuPropertyID1 is null)
  and sls.isDeleted=0


  update sls set sls.skuPropertyID2=ms.skuPropertyID2
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.skuPropertyID2<>ms.skuPropertyID2 or sls.skuPropertyID2 is null)
  and sls.isDeleted=0

  update sls set sls.skuPropertyID3=ms.skuPropertyID3
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.skuPropertyID3<>ms.skuPropertyID3 or sls.skuPropertyID3 is null)
  and sls.isDeleted=0

  update sls set sls.skuPropertyID4=ms.skuPropertyID4
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.skuPropertyID4<>ms.skuPropertyID4 or sls.skuPropertyID4 is null)
  and sls.isDeleted=0

  update sls set sls.skuPropertyID5=ms.skuPropertyID5
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.skuPropertyID5<>ms.skuPropertyID5 or sls.skuPropertyID5 is null)
  and sls.isDeleted=0

  update sls set sls.skuPropertyID6=ms.skuPropertyID6
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.skuPropertyID6<>ms.skuPropertyID6 or sls.skuPropertyID6 is null)
  and sls.isDeleted=0

  update sls set sls.skuPropertyID7=ms.skuPropertyID7
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.skuPropertyID7<>ms.skuPropertyID7 or sls.skuPropertyID7 is null)
  and sls.isDeleted=0

  update sls set sls.custom_txt1=ms.custom_txt1
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_txt1<>ms.custom_txt1 or sls.custom_txt1 is null)
  and sls.isDeleted=0

  update sls set sls.custom_txt2=ms.custom_txt2
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_txt2<>ms.custom_txt2 or sls.custom_txt2 is null)
  and sls.isDeleted=0

  update sls set sls.custom_txt3=ms.custom_txt3
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_txt3<>ms.custom_txt3 or sls.custom_txt3 is null)
  and sls.isDeleted=0

  update sls set sls.custom_txt4=ms.custom_txt4
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_txt4<>ms.custom_txt4 or sls.custom_txt4 is null)
  and sls.isDeleted=0

  update sls set sls.custom_txt5=ms.custom_txt5
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_txt5<>ms.custom_txt5 or sls.custom_txt5 is null)
  and sls.isDeleted=0

  update sls set sls.custom_txt6=ms.custom_txt6
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_txt6<>ms.custom_txt6 or sls.custom_txt6 is null)
  and sls.isDeleted=0

  update sls set sls.custom_txt7=ms.custom_txt7
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_txt7<>ms.custom_txt7 or sls.custom_txt7 is null)
  and sls.isDeleted=0

  update sls set sls.custom_txt8=ms.custom_txt8
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_txt8<>ms.custom_txt8 or sls.custom_txt8 is null)
  and sls.isDeleted=0

  update sls set sls.custom_txt9=ms.custom_txt9
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_txt9<>ms.custom_txt9 or sls.custom_txt9 is null)
  and sls.isDeleted=0

  update sls set sls.custom_txt10=ms.custom_txt10
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_txt10<>ms.custom_txt10 or sls.custom_txt10 is null)
  and sls.isDeleted=0


  update sls set sls.custom_num1=ms.custom_num1
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_num1<>ms.custom_num1 or sls.custom_num1 is null)
  and sls.isDeleted=0

  update sls set sls.custom_num2=ms.custom_num2
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_num2<>ms.custom_num2 or sls.custom_num2 is null)
  and sls.isDeleted=0

  update sls set sls.custom_num3=ms.custom_num3
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_num3<>ms.custom_num3 or sls.custom_num3 is null)
  and sls.isDeleted=0

  update sls set sls.custom_num4=ms.custom_num4
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_num4<>ms.custom_num4 or sls.custom_num4 is null)
  and sls.isDeleted=0

  update sls set sls.custom_num5=ms.custom_num5
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_num5<>ms.custom_num5 or sls.custom_num5 is null)
  and sls.isDeleted=0

  
  update sls set sls.custom_num7=ms.custom_num7
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_num7<>ms.custom_num7 or sls.custom_num7 is null)
  and sls.isDeleted=0

  
  update sls set sls.custom_num8=ms.custom_num8
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_num8<>ms.custom_num8 or sls.custom_num8 is null)
  and sls.isDeleted=0
  
  
  update sls set sls.custom_num9=ms.custom_num9
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_num9<>ms.custom_num9 or sls.custom_num9 is null)
  and sls.isDeleted=0

  
  update sls set sls.custom_num10=ms.custom_num10
  from Symphony_StockLocationSkus sls 
  join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  where (sls.custom_num10<>ms.custom_num10 or sls.custom_num10 is null)
  and sls.isDeleted=0

  /*update sls set sls.replenishmentTime=sl.slCustom_num2
  from Symphony_StockLocationSkus sls 
  join Symphony_StockLocations sl on sl.stockLocationID=sls.stockLocationID
  where (sls.replenishmentTime<>sl.slCustom_num2 or sls.replenishmentTime is null) and  sl.stockLocationType=3 and
  sl.slCustom_num2 is not null and sls.isDeleted=0*/
  

 /* update sls set sls.originStockLocation=sl.defaultOriginID
  from Symphony_StockLocationSkus sls 
  join Symphony_StockLocations sl on sl.stockLocationID=sls.stockLocationID
  where sls.originStockLocation is null and  sl.stockLocationType=3 and sls.isDeleted=0
  and sl.stockLocationName not in ('CL-FC-BNG-KOR','CL-FC-DEL-GK')*/

  
  update sls set autoReplenishment=1
  from Symphony_StockLocationSkus sls where autoReplenishment=0 
  
  
update sls set inventoryAtTransit=0
from Symphony_StockLocationSkus sls
where inventoryAtTransit<0

update sls set inventoryAtTransit=0
from Symphony_StockLocationSkuHistory sls
where inventoryAtTransit<0

end
GO
/****** Object:  StoredProcedure [dbo].[Client_SP_OUTPUT]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Client_SP_OUTPUT]
AS
BEGIN


drop table numb_99
CREATE TABLE numb_99
( i INT NOT NULL
, PRIMARY KEY (i)
) ;

INSERT INTO numb_99 (i)
VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13),(14),(15),(16),(17),(18),(19),(20),(21),(22),(23),(24),(25),(26),(27),(28),(29),(30),(31),(32),(33),(34),(35),(36),(37),(38),(39),(40),(41),(42),(43),(44),(45),(46),(47),(48),(49),(50),(51),(52),(53),(54),(55),(56),(57),(58),(59),(60),(61),(62),(63),(64),(65),(66),(67),(68),(69),(70),(71),(72),(73),(74),(75),(76),(77),(78),(79),(80),(81),(82),(83),(84),(85),(86),(87),(88),(89),(90),(91),(92),(93),(94),(95),(96),(97),(98),(99),(100),(101),(102),(103),(104),(105),(106),(107),(108),(109),(110),(111),(112),(113),(114),(115),(116),(117),(118),(119),(120),(121),(122),(123),(124),(125),(126),(127),(128),(129),(130),(131),(132),(133),(134),(135),(136),(137),(138),(139),(140),(141),(142),(143),(144),(145),(146),(147),(148),(149),(150),(151),(152),(153),(154),(155),(156),(157),(158),(159),(160),(161),(162),(163),(164),(165),(166),(167),(168),(169),(170),(171),(172),(173),(174),(175),(176),(177),(178),(179),(180),(181),(182),(183),(184),(185),(186),(187),(188),(189),(190),(191),(192),(193),(194),(195),(196),(197),(198),(199),(200),(201),(202),(203),(204),(205),(206),(207),(208),(209),(210),(211),(212),(213),(214),(215),(216),(217),(218),(219),(220),(221),(222),(223),(224),(225),(226),(227),(228),(229),(230),(231),(232),(233),(234),(235),(236),(237),(238),(239),(240),(241),(242),(243),(244),(245),(246),(247),(248),(249),(250),(251),(252),(253),(254),(255),(256),(257),(258),(259),(260),(261),(262),(263),(264),(265),(266),(267),(268),(269),(270),(271),(272),(273),(274),(275),(276),(277),(278),(279),(280),(281),(282),(283),(284),(285),(286),(287),(288),(289),(290),(291),(292),(293),(294),(295),(296),(297),(298),(299),(300),(301),(302),(303),(304),(305),(306),(307),(308),(309),(310),(311),(312),(313),(314),(315),(316),(317),(318),(319),(320),(321),(322),(323),(324),(325),(326),(327),(328),(329),(330),(331),(332),(333),(334),(335),(336),(337),(338),(339),(340),(341),(342),(343),(344),(345),(346),(347),(348),(349),(350),(351),(352),(353),(354),(355),(356),(357),(358),(359),(360),(361),(362),(363),(364),(365),(366),(367),(368),(369),(370),(371),(372),(373),(374),(375),(376),(377),(378),(379),(380),(381),(382),(383),(384),(385),(386),(387),(388),(389),(390),(391),(392),(393),(394),(395),(396),(397),(398),(399),(400),(401),(402),(403),(404),(405),(406),(407),(408),(409),(410),(411),(412),(413),(414),(415),(416),(417),(418),(419),(420),(421),(422),(423),(424),(425),(426),(427),(428),(429),(430),(431),(432),(433),(434),(435),(436),(437),(438),(439),(440),(441),(442),(443),(444),(445),(446),(447),(448),(449),(450),(451),(452),(453),(454),(455),(456),(457),(458),(459),(460),(461),(462),(463),(464),(465),(466),(467),(468),(469),(470),(471),(472),(473),(474),(475),(476),(477),(478),(479),(480),(481),(482),(483),(484),(485),(486),(487),(488),(489),(490),(491),(492),(493),(494),(495),(496),(497),(498),(499),(500),(501),(502),(503),(504),(505),(506),(507),(508),(509),(510),(511),(512),(513),(514),(515),(516),(517),(518),(519),(520),(521),(522),(523),(524),(525),(526),(527),(528),(529),(530),(531),(532),(533),(534),(535),(536),(537),(538),(539),(540),(541),(542),(543),(544),(545),(546),(547),(548),(549),(550),(551),(552),(553),(554),(555),(556),(557),(558),(559),(560),(561),(562),(563),(564),(565),(566),(567),(568),(569),(570),(571),(572),(573),(574),(575),(576),(577),(578),(579),(580),(581),(582),(583),(584),(585),(586),(587),(588),(589),(590),(591),(592),(593),(594),(595),(596),(597),(598),(599),(600),(601),(602),(603),(604),(605),(606),(607),(608),(609),(610),(611),(612),(613),(614),(615),(616),(617),(618),(619),(620),(621),(622),(623),(624),(625),(626),(627),(628),(629),(630),(631),(632),(633),(634),(635),(636),(637),(638),(639),(640),(641),(642),(643),(644),(645),(646),(647),(648),(649),(650),(651),(652),(653),(654),(655),(656),(657),(658),(659),(660),(661),(662),(663),(664),(665),(666),(667),(668),(669),(670),(671),(672),(673),(674),(675),(676),(677),(678),(679),(680),(681),(682),(683),(684),(685),(686),(687),(688),(689),(690),(691),(692),(693),(694),(695),(696),(697),(698),(699),(700),(701),(702),(703),(704),(705),(706),(707),(708),(709),(710),(711),(712),(713),(714),(715),(716),(717),(718),(719),(720),(721),(722),(723),(724),(725),(726),(727),(728),(729),(730),(731),(732),(733),(734),(735),(736),(737),(738),(739),(740),(741),(742),(743),(744),(745),(746),(747),(748),(749),(750),(751),(752),(753),(754),(755),(756),(757),(758),(759),(760),(761),(762),(763),(764),(765),(766),(767),(768),(769),(770),(771),(772),(773),(774),(775),(776),(777),(778),(779),(780),(781),(782),(783),(784),(785),(786),(787),(788),(789),(790),(791),(792),(793),(794),(795),(796),(797),(798),(799),(800),(801),(802),(803),(804),(805),(806),(807),(808),(809),(810),(811),(812),(813),(814),(815),(816),(817),(818),(819),(820),(821),(822),(823),(824),(825),(826),(827),(828),(829),(830),(831),(832),(833),(834),(835),(836),(837),(838),(839),(840),(841),(842),(843),(844),(845),(846),(847),(848),(849),(850),(851),(852),(853),(854),(855),(856),(857),(858),(859),(860),(861),(862),(863),(864),(865),(866),(867),(868),(869),(870),(871),(872),(873),(874),(875),(876),(877),(878),(879),(880),(881),(882),(883),(884),(885),(886),(887),(888),(889),(890),(891),(892),(893),(894),(895),(896),(897),(898),(899),(900),(901),(902),(903),(904),(905),(906),(907),(908),(909),(910),(911),(912),(913),(914),(915),(916),(917),(918),(919),(920),(921),(922),(923),(924),(925),(926),(927),(928),(929),(930),(931),(932),(933),(934),(935),(936),(937),(938),(939),(940),(941),(942),(943),(944),(945),(946),(947),(948),(949),(950),(951),(952),(953),(954),(955),(956),(957),(958),(959),(960),(961),(962),(963),(964),(965),(966),(967),(968),(969),(970),(971),(972),(973),(974),(975),(976),(977),(978),(979),(980),(981),(982),(983),(984),(985),(986),(987),(988),(989),(990),(991),(992),(993),(994),(995),(996),(997),(998),
(999);


drop table Client_Replenishment_temp

SELECT * into Client_Replenishment_temp from (select 
    
        sl.stockLocationName as SL
       ,sk.skuName as SKU
      ,[replenishmentQuantity] as Repl_Qty
      ,sl1.stockLocationName as Origin_SL
	  --,sk.skuname + '|' + cast(ROW_NUMBER() OVER(PARTITION BY sk.skuname ORDER BY sk.skuname)as nvarchar(100)) AS aas
	  ,'Replenishment-MTR' as Recommendation_Type
	  ,0 as [Priority]

  FROM [SymphonyCL].[dbo].[Symphony_ReplenishmentDistributionLog] RL
  join Symphony_StockLocations sl on sl.stockLocationID=rl.stockLocationID
  join Symphony_StockLocations sl1 on sl1.stockLocationID=rl.originStockLocation
  join Symphony_SKUs sk on sk.skuID=rl.skuID
  where sl.stockLocationType=3 and rl.originStockLocation is not null and rl.bufferSize>0 and sl.isDeleted=0 and
  sl.stockLocationName not in 
  ('CL-FC-BNG-KOR','CL-FC-DEL-GK','CL-FC-CHN-PGR','CL-FC-BLR-BTM','CL-FC-DEL-MYP2','CL-FC-HYD-Jubilee','CL-FC-KOL-VKR''CL-FC-PUN-MNG PETH')


  union

  
  select 
    
        sl.stockLocationName as SL
       ,sk.skuName as SKU
      ,[replenishmentQuantity] as Repl_Qty
      ,sl1.stockLocationName as Origin_SL
	  --,sk.skuname + '|' + cast(ROW_NUMBER() OVER(PARTITION BY sk.skuname ORDER BY sk.skuname)as nvarchar(100)) AS aas
	  ,'MicroFC_Replenishment' as Recommendation_Type
	  ,0 as [Priority]

  FROM [SymphonyCL].[dbo].[Symphony_ReplenishmentDistributionLog] RL
  join Symphony_StockLocations sl on sl.stockLocationID=rl.stockLocationID
  join Symphony_StockLocations sl1 on sl1.stockLocationID=rl.originStockLocation
  join Symphony_SKUs sk on sk.skuID=rl.skuID
  where sl.stockLocationType=3 and rl.originStockLocation is not null and rl.bufferSize>0 and sl.isDeleted=0 and
  sl.stockLocationName  in 
  ('CL-FC-BNG-KOR','CL-FC-DEL-GK','CL-FC-CHN-PGR','CL-FC-BLR-BTM','CL-FC-DEL-MYP2','CL-FC-HYD-Jubilee','CL-FC-KOL-VKR''CL-FC-PUN-MNG PETH')




union

SELECT slo.stockLocationName as [SL]
       ,s.skuName as [SK]
       ,rar.totalNPI as [Repl_Qty]
       ,slo1.stockLocationName as [Origin SL]
	   --,s.skuname + '|' + cast(ROW_NUMBER() OVER(PARTITION BY s.skuname ORDER BY s.skuname)as nvarchar(100)) AS aas
	   ,'Refreshment-MTAR' as Recommendation_Type
	   ,slo.allocationPriority as [Priority]
           
  FROM [SymphonyCL].[dbo].[Symphony_RetailAllocationRequest] rar 
  INNER JOIN [SymphonyCL].[dbo].[Symphony_MasterSkus] MS ON rar.familyID = MS.familyID
  INNER JOIN [SymphonyCL].[dbo].[Symphony_SKUs] S ON S.skuID = MS.skuID
  INNER JOIN [SymphonyCL].[dbo].[Symphony_StockLocations] SLO ON SLO.stockLocationID = rar.destinationID
  INNER JOIN [SymphonyCL].[dbo].[Symphony_StockLocations] SLO1 ON SLO1.stockLocationID = rar.originID
  --join Symphony_LocationFamilyAttributes lfa on lfa.familyID=ms.familyID and lfa.stockLocationID=rar.destinationID 
  --join Symphony_NPISets npi on npi.id=lfa.npiSetID
  --join (select distinct npiSetID,familyMemberID, npiQuantity from Symphony_NPISetMembers) m on m.npiSetID=npi.id and m.familyMemberID=ms.familyMemberID
  --join Symphony_SkuFamilies sf on sf.id=rar.familyID
  join Symphony_RetailFamilyAgConnection rfac on rfac.familyID=rar.familyID
  join Symphony_AssortmentGroup ag on ag.assortmentGroupID=rfac.assortmentGroupID
  join Symphony_LocationAssortmentGroups lag on lag.stockLocationID=rar.destinationID and lag.assortmentGroupID=ag.assortmentGroupID
  left join Symphony_RetailAgDgConnection agdg on agdg.assortmentGroupID=ag.assortmentGroupID
  left join Symphony_DisplayGroup dg on dg.displayGroupID=agdg.displayGroupID
  where bySystem=1  )#c  -- and m.npiQuantity>0 --and sentToReplenishment=1 and requestStatus=1





  drop table Client_Replenishment

  SELECT * into Client_Replenishment from (select 
    
        SL
       ,SKU
      ,Repl_Qty
      ,Origin_SL
	  ,sku + '|'  + Origin_SL+ cast(ROW_NUMBER() OVER(PARTITION BY sku,origin_sl ORDER BY sku,Recommendation_Type desc,priority desc)as nvarchar(100)) AS aas
	  ,Recommendation_Type
	  ,Priority

  FROM Client_Replenishment_temp t
  JOIN   numb_99  ON numb_99.i <= t."Repl_Qty"
  )#d

  --select * from Client_Replenishment
  --select * from Client_Replenishment_temp





  drop table Client_STATUS_TEMP_33

create table Client_STATUS_TEMP_33
(SL nvarchar(100),
SKU nvarchar(100),
Barcode nvarchar(100),
Barcode_days int,
Qty int,
Year nvarchar(10),
Month nvarchar(10),
Day nvarchar(10),
)



drop table allfilenames
drop table bulkact

CREATE TABLE ALLFILENAMES(WHICHPATH VARCHAR(255),WHICHFILE varchar(255))
CREATE TABLE BULKACT(RAWDATA VARCHAR (8000))
declare @filename varchar(255),
        @path     varchar(255),
        @sql      varchar(8000),
        @cmd      varchar(1000)



SET @path = 'D:\SymphonyData\CustomReports\Output_Script\'
SET @cmd = 'dir ' + @path + '*.csv /b'
INSERT INTO  ALLFILENAMES(WHICHFILE)
EXEC Master..xp_cmdShell @cmd
UPDATE ALLFILENAMES SET WHICHPATH = @path where WHICHPATH is null

--cursor loop
    declare c1 cursor for SELECT WHICHPATH,WHICHFILE FROM ALLFILENAMES where WHICHFILE like 'WH_Barcode_stock%.csv%'
    open c1
    fetch next from c1 into @path,@filename
    While @@fetch_status <> -1
      begin
      --bulk insert won't take a variable name, so make a sql and execute it instead:
       set @sql = 'BULK INSERT Client_STATUS_TEMP_33 FROM ''' + @path + @filename + ''' '
           + '     WITH ( 
                   FIELDTERMINATOR = '','', 
                   ROWTERMINATOR = ''\n'', 
                   FIRSTROW = 3 
                ) '
    print @sql
    exec (@sql)

      fetch next from c1 into @path,@filename
      end
    close c1
    deallocate c1
/*
BULK INSERT Client_STATUS_TEMP_33
FROM 'D:\SymphonyData\CustomReports\Output_Script\WH_Barcode_stock.csv'
WITH
(
FIRSTROW = 2, --ignores first row (header row)
FIELDTERMINATOR = ',',
ROWTERMINATOR = '\n'
)

--select * from Client_STATUS_TEMP_33
*/


drop table Client_STATUS_TEMP_1

select SKU + '|' +  SL + cast(ROW_NUMBER() OVER(PARTITION BY sku,sl ORDER BY sku,barcode_days desc )as nvarchar(100)) AS aas,*
into Client_STATUS_TEMP_1 from 
Client_STATUS_TEMP_33 where YEAR=datepart(year,getdate()) and month=datepart(MONTH,getdate()) and day=datepart(DAY,getdate())

--select * from Client_STATUS_TEMP_1 

drop table Repl_output_revised_post_2nd_LnR

select r.SL,r.SKU,s.Barcode,case when r.Repl_Qty>1 then 1 else r.Repl_Qty end as Repl_Qty ,r.Origin_SL,Recommendation_Type
into Repl_output_revised_post_2nd_LnR
from Client_Replenishment r
join Client_STATUS_TEMP_1 s on s.aas=r.aas


/*
select r.SL,r.SKU,s.Barcode,case when r.Repl_Qty>1 then 1 else r.Repl_Qty end as Repl_Qty ,r.Origin_SL,Recommendation_Type

from Client_Replenishment r
join Client_STATUS_TEMP_1 s on s.aas=r.aas
--where (r.Recommendation_Type like 'Ref%' or r.Recommendation_Type like 'Rep%') */


end

GO
/****** Object:  StoredProcedure [dbo].[Client_SP_OUTPUT_MTAR]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Client_SP_OUTPUT_MTAR]
AS
BEGIN

drop table numb_99
CREATE TABLE numb_99
( i INT NOT NULL
, PRIMARY KEY (i)
) ;

INSERT INTO numb_99 (i)
VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13),(14),(15),(16),(17),(18),(19),(20),(21),(22),(23),(24),(25),(26),(27),(28),(29),(30),(31),(32),(33),(34),(35),(36),(37),(38),(39),(40),(41),(42),(43),(44),(45),(46),(47),(48),(49),(50),(51),(52),(53),(54),(55),(56),(57),(58),(59),(60),(61),(62),(63),(64),(65),(66),(67),(68),(69),(70),(71),(72),(73),(74),(75),(76),(77),(78),(79),(80),(81),(82),(83),(84),(85),(86),(87),(88),(89),(90),(91),(92),(93),(94),(95),(96),(97),(98),(99),(100),(101),(102),(103),(104),(105),(106),(107),(108),(109),(110),(111),(112),(113),(114),(115),(116),(117),(118),(119),(120),(121),(122),(123),(124),(125),(126),(127),(128),(129),(130),(131),(132),(133),(134),(135),(136),(137),(138),(139),(140),(141),(142),(143),(144),(145),(146),(147),(148),(149),(150),(151),(152),(153),(154),(155),(156),(157),(158),(159),(160),(161),(162),(163),(164),(165),(166),(167),(168),(169),(170),(171),(172),(173),(174),(175),(176),(177),(178),(179),(180),(181),(182),(183),(184),(185),(186),(187),(188),(189),(190),(191),(192),(193),(194),(195),(196),(197),(198),(199),(200),(201),(202),(203),(204),(205),(206),(207),(208),(209),(210),(211),(212),(213),(214),(215),(216),(217),(218),(219),(220),(221),(222),(223),(224),(225),(226),(227),(228),(229),(230),(231),(232),(233),(234),(235),(236),(237),(238),(239),(240),(241),(242),(243),(244),(245),(246),(247),(248),(249),(250),(251),(252),(253),(254),(255),(256),(257),(258),(259),(260),(261),(262),(263),(264),(265),(266),(267),(268),(269),(270),(271),(272),(273),(274),(275),(276),(277),(278),(279),(280),(281),(282),(283),(284),(285),(286),(287),(288),(289),(290),(291),(292),(293),(294),(295),(296),(297),(298),(299),(300),(301),(302),(303),(304),(305),(306),(307),(308),(309),(310),(311),(312),(313),(314),(315),(316),(317),(318),(319),(320),(321),(322),(323),(324),(325),(326),(327),(328),(329),(330),(331),(332),(333),(334),(335),(336),(337),(338),(339),(340),(341),(342),(343),(344),(345),(346),(347),(348),(349),(350),(351),(352),(353),(354),(355),(356),(357),(358),(359),(360),(361),(362),(363),(364),(365),(366),(367),(368),(369),(370),(371),(372),(373),(374),(375),(376),(377),(378),(379),(380),(381),(382),(383),(384),(385),(386),(387),(388),(389),(390),(391),(392),(393),(394),(395),(396),(397),(398),(399),(400),(401),(402),(403),(404),(405),(406),(407),(408),(409),(410),(411),(412),(413),(414),(415),(416),(417),(418),(419),(420),(421),(422),(423),(424),(425),(426),(427),(428),(429),(430),(431),(432),(433),(434),(435),(436),(437),(438),(439),(440),(441),(442),(443),(444),(445),(446),(447),(448),(449),(450),(451),(452),(453),(454),(455),(456),(457),(458),(459),(460),(461),(462),(463),(464),(465),(466),(467),(468),(469),(470),(471),(472),(473),(474),(475),(476),(477),(478),(479),(480),(481),(482),(483),(484),(485),(486),(487),(488),(489),(490),(491),(492),(493),(494),(495),(496),(497),(498),(499),(500),(501),(502),(503),(504),(505),(506),(507),(508),(509),(510),(511),(512),(513),(514),(515),(516),(517),(518),(519),(520),(521),(522),(523),(524),(525),(526),(527),(528),(529),(530),(531),(532),(533),(534),(535),(536),(537),(538),(539),(540),(541),(542),(543),(544),(545),(546),(547),(548),(549),(550),(551),(552),(553),(554),(555),(556),(557),(558),(559),(560),(561),(562),(563),(564),(565),(566),(567),(568),(569),(570),(571),(572),(573),(574),(575),(576),(577),(578),(579),(580),(581),(582),(583),(584),(585),(586),(587),(588),(589),(590),(591),(592),(593),(594),(595),(596),(597),(598),(599),(600),(601),(602),(603),(604),(605),(606),(607),(608),(609),(610),(611),(612),(613),(614),(615),(616),(617),(618),(619),(620),(621),(622),(623),(624),(625),(626),(627),(628),(629),(630),(631),(632),(633),(634),(635),(636),(637),(638),(639),(640),(641),(642),(643),(644),(645),(646),(647),(648),(649),(650),(651),(652),(653),(654),(655),(656),(657),(658),(659),(660),(661),(662),(663),(664),(665),(666),(667),(668),(669),(670),(671),(672),(673),(674),(675),(676),(677),(678),(679),(680),(681),(682),(683),(684),(685),(686),(687),(688),(689),(690),(691),(692),(693),(694),(695),(696),(697),(698),(699),(700),(701),(702),(703),(704),(705),(706),(707),(708),(709),(710),(711),(712),(713),(714),(715),(716),(717),(718),(719),(720),(721),(722),(723),(724),(725),(726),(727),(728),(729),(730),(731),(732),(733),(734),(735),(736),(737),(738),(739),(740),(741),(742),(743),(744),(745),(746),(747),(748),(749),(750),(751),(752),(753),(754),(755),(756),(757),(758),(759),(760),(761),(762),(763),(764),(765),(766),(767),(768),(769),(770),(771),(772),(773),(774),(775),(776),(777),(778),(779),(780),(781),(782),(783),(784),(785),(786),(787),(788),(789),(790),(791),(792),(793),(794),(795),(796),(797),(798),(799),(800),(801),(802),(803),(804),(805),(806),(807),(808),(809),(810),(811),(812),(813),(814),(815),(816),(817),(818),(819),(820),(821),(822),(823),(824),(825),(826),(827),(828),(829),(830),(831),(832),(833),(834),(835),(836),(837),(838),(839),(840),(841),(842),(843),(844),(845),(846),(847),(848),(849),(850),(851),(852),(853),(854),(855),(856),(857),(858),(859),(860),(861),(862),(863),(864),(865),(866),(867),(868),(869),(870),(871),(872),(873),(874),(875),(876),(877),(878),(879),(880),(881),(882),(883),(884),(885),(886),(887),(888),(889),(890),(891),(892),(893),(894),(895),(896),(897),(898),(899),(900),(901),(902),(903),(904),(905),(906),(907),(908),(909),(910),(911),(912),(913),(914),(915),(916),(917),(918),(919),(920),(921),(922),(923),(924),(925),(926),(927),(928),(929),(930),(931),(932),(933),(934),(935),(936),(937),(938),(939),(940),(941),(942),(943),(944),(945),(946),(947),(948),(949),(950),(951),(952),(953),(954),(955),(956),(957),(958),(959),(960),(961),(962),(963),(964),(965),(966),(967),(968),(969),(970),(971),(972),(973),(974),(975),(976),(977),(978),(979),(980),(981),(982),(983),(984),(985),(986),(987),(988),(989),(990),(991),(992),(993),(994),(995),(996),(997),(998),
(999);


drop table Client_Replenishment_temp

SELECT * into Client_Replenishment_temp from (select 
    
        sl.stockLocationName as SL
       ,sk.skuName as SKU
      ,[replenishmentQuantity] as Repl_Qty
      ,sl1.stockLocationName as Origin_SL
	  --,sk.skuname + '|' + cast(ROW_NUMBER() OVER(PARTITION BY sk.skuname ORDER BY sk.skuname)as nvarchar(100)) AS aas
	  ,'Replenishment-MTR' as Recommendation_Type
	  ,0 as [Priority]

  FROM [SymphonyCL].[dbo].[Symphony_ReplenishmentDistributionLog] RL
  join Symphony_StockLocations sl on sl.stockLocationID=rl.stockLocationID
  join Symphony_StockLocations sl1 on sl1.stockLocationID=rl.originStockLocation
  join Symphony_SKUs sk on sk.skuID=rl.skuID
  where sl.stockLocationType=3 and rl.originStockLocation is not null and rl.bufferSize>0 and sl.isDeleted=0 and
  sl.stockLocationName not in 
  ('CL-FC-BNG-KOR','CL-FC-DEL-GK','CL-FC-CHN-PGR','CL-FC-BLR-BTM','CL-FC-DEL-MYP2','CL-FC-HYD-Jubilee','CL-FC-KOL-VKR''CL-FC-PUN-MNG PETH')


  union

  
  select 
    
        sl.stockLocationName as SL
       ,sk.skuName as SKU
      ,[replenishmentQuantity] as Repl_Qty
      ,sl1.stockLocationName as Origin_SL
	  --,sk.skuname + '|' + cast(ROW_NUMBER() OVER(PARTITION BY sk.skuname ORDER BY sk.skuname)as nvarchar(100)) AS aas
	  ,'MicroFC_Replenishment' as Recommendation_Type
	  ,0 as [Priority]

  FROM [SymphonyCL].[dbo].[Symphony_ReplenishmentDistributionLog] RL
  join Symphony_StockLocations sl on sl.stockLocationID=rl.stockLocationID
  join Symphony_StockLocations sl1 on sl1.stockLocationID=rl.originStockLocation
  join Symphony_SKUs sk on sk.skuID=rl.skuID
  where sl.stockLocationType=3 and rl.originStockLocation is not null and rl.bufferSize>0 and sl.isDeleted=0 and
  sl.stockLocationName  in 
  ('CL-FC-BNG-KOR','CL-FC-DEL-GK','CL-FC-CHN-PGR','CL-FC-BLR-BTM','CL-FC-DEL-MYP2','CL-FC-HYD-Jubilee','CL-FC-KOL-VKR''CL-FC-PUN-MNG PETH')




union

SELECT slo.stockLocationName as [SL]
       ,s.skuName as [SK]
       ,rar.totalNPI as [Repl_Qty]
       ,slo1.stockLocationName as [Origin SL]
	   --,s.skuname + '|' + cast(ROW_NUMBER() OVER(PARTITION BY s.skuname ORDER BY s.skuname)as nvarchar(100)) AS aas
	   ,'Refreshment-MTAR' as Recommendation_Type
	   ,slo.allocationPriority as [Priority]
           
  FROM [SymphonyCL].[dbo].[Symphony_RetailAllocationRequest] rar 
  INNER JOIN [SymphonyCL].[dbo].[Symphony_MasterSkus] MS ON rar.familyID = MS.familyID
  INNER JOIN [SymphonyCL].[dbo].[Symphony_SKUs] S ON S.skuID = MS.skuID
  INNER JOIN [SymphonyCL].[dbo].[Symphony_StockLocations] SLO ON SLO.stockLocationID = rar.destinationID
  INNER JOIN [SymphonyCL].[dbo].[Symphony_StockLocations] SLO1 ON SLO1.stockLocationID = rar.originID
  --join Symphony_LocationFamilyAttributes lfa on lfa.familyID=ms.familyID and lfa.stockLocationID=rar.destinationID 
  --join Symphony_NPISets npi on npi.id=lfa.npiSetID
  --join (select distinct npiSetID,familyMemberID, npiQuantity from Symphony_NPISetMembers) m on m.npiSetID=npi.id and m.familyMemberID=ms.familyMemberID
  --join Symphony_SkuFamilies sf on sf.id=rar.familyID
  join Symphony_RetailFamilyAgConnection rfac on rfac.familyID=rar.familyID
  join Symphony_AssortmentGroup ag on ag.assortmentGroupID=rfac.assortmentGroupID
  join Symphony_LocationAssortmentGroups lag on lag.stockLocationID=rar.destinationID and lag.assortmentGroupID=ag.assortmentGroupID
  left join Symphony_RetailAgDgConnection agdg on agdg.assortmentGroupID=ag.assortmentGroupID
  left join Symphony_DisplayGroup dg on dg.displayGroupID=agdg.displayGroupID
  where bySystem=1  )#c  -- and m.npiQuantity>0 --and sentToReplenishment=1 and requestStatus=1





  drop table Client_Replenishment

  SELECT * into Client_Replenishment from (select 
    
        SL
       ,SKU
      ,Repl_Qty
      ,Origin_SL
	  ,sku + '|'  + Origin_SL+ cast(ROW_NUMBER() OVER(PARTITION BY sku,origin_sl ORDER BY sku,Recommendation_Type desc,priority desc)as nvarchar(100)) AS aas
	  ,Recommendation_Type
	  ,Priority

  FROM Client_Replenishment_temp t
  JOIN   numb_99  ON numb_99.i <= t."Repl_Qty"
  )#d

  --select * from Client_Replenishment
  --select * from Client_Replenishment_temp





  drop table Client_STATUS_TEMP_33

create table Client_STATUS_TEMP_33
(SL nvarchar(100),
SKU nvarchar(100),
Barcode nvarchar(100),
Barcode_days int,
Qty int,
Year nvarchar(10),
Month nvarchar(10),
Day nvarchar(10),
)



drop table allfilenames
drop table bulkact

CREATE TABLE ALLFILENAMES(WHICHPATH VARCHAR(255),WHICHFILE varchar(255))
CREATE TABLE BULKACT(RAWDATA VARCHAR (8000))
declare @filename varchar(255),
        @path     varchar(255),
        @sql      varchar(8000),
        @cmd      varchar(1000)



SET @path = 'D:\SymphonyData\CustomReports\Output_Script\'
SET @cmd = 'dir ' + @path + '*.csv /b'
INSERT INTO  ALLFILENAMES(WHICHFILE)
EXEC Master..xp_cmdShell @cmd
UPDATE ALLFILENAMES SET WHICHPATH = @path where WHICHPATH is null

--cursor loop
    declare c1 cursor for SELECT WHICHPATH,WHICHFILE FROM ALLFILENAMES where WHICHFILE like 'WH_Barcode_stock%.csv%'
    open c1
    fetch next from c1 into @path,@filename
    While @@fetch_status <> -1
      begin
      --bulk insert won't take a variable name, so make a sql and execute it instead:
       set @sql = 'BULK INSERT Client_STATUS_TEMP_33 FROM ''' + @path + @filename + ''' '
           + '     WITH ( 
                   FIELDTERMINATOR = '','', 
                   ROWTERMINATOR = ''\n'', 
                   FIRSTROW = 2 
                ) '
    print @sql
    exec (@sql)

      fetch next from c1 into @path,@filename
      end
    close c1
    deallocate c1
/*
BULK INSERT Client_STATUS_TEMP_33
FROM 'D:\SymphonyData\CustomReports\Output_Script\WH_Barcode_stock.csv'
WITH
(
FIRSTROW = 2, --ignores first row (header row)
FIELDTERMINATOR = ',',
ROWTERMINATOR = '\n'
)

--select * from Client_STATUS_TEMP_33
*/




drop table Client_STATUS_TEMP_1

select SKU + '|' +  SL + cast(ROW_NUMBER() OVER(PARTITION BY sku,sl ORDER BY sku,barcode_days desc )as nvarchar(100)) AS aas,*
into Client_STATUS_TEMP_1 from 
Client_STATUS_TEMP_33 where YEAR=datepart(year,getdate()) and month=datepart(MONTH,getdate()) and day=datepart(DAY,getdate())

--select * from Client_STATUS_TEMP_1 

drop table Repl_output_revised_post_1st_LnR

select r.SL,r.SKU,s.Barcode,case when r.Repl_Qty>1 then 1 else r.Repl_Qty end as Repl_Qty ,r.Origin_SL,Recommendation_Type
into Repl_output_revised_post_1st_LnR
from Client_Replenishment r
join Client_STATUS_TEMP_1 s on s.aas=r.aas




/*select r.SL,r.SKU,s.Barcode,case when r.Repl_Qty>1 then 1 else r.Repl_Qty end as Repl_Qty ,r.Origin_SL,Recommendation_Type

from Client_Replenishment r
join Client_STATUS_TEMP_1 s on s.aas=r.aas
--where (r.Recommendation_Type like 'Ref%' or r.Recommendation_Type like 'Rep%')*/

end

GO
/****** Object:  StoredProcedure [dbo].[Client_SP_Sale_Data]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Client_SP_Sale_Data]
AS
BEGIN

SELECT sl.stockLocationName  
       ,s.skuName SKU
	   ,spi1.slItemName as [City]
	   ,spi2.slItemName as [Region]
	   ,spi3.slItemName as [Store Category]
	   ,spi4.slItemName as [Store Level]
	   ,s1.skuItemName as [Category]
	   ,s2.skuItemName as [Sub Category]
	   ,s3.skuItemName as [Collection]

	   ,sls.custom_txt3  as [Store MTR]
	   ,sls.custom_txt4  as [Global MTR]
	   ,CONVERT(date,slsh.updateDate-1) as date
           ,sum (slsh.consumption) AS consumption
  FROM [Symphony_StockLocationSkuHistory] slsh
  join Symphony_StockLocations sl on sl.stockLocationID=slsh.stockLocationID
    join Symphony_SKUs s on s.skuID=slsh.skuID
	left JOIN Symphony_StockLocationSkus SLS on slsh.skuID=SLS.skuID and slsh.stockLocationID=sls.stockLocationID 
	left join Symphony_StockLocationPropertyItems spi1 on spi1.slItemID=sl.slPropertyID1
	left join Symphony_StockLocationPropertyItems spi2 on spi2.slItemID=sl.slPropertyID2
	left join Symphony_StockLocationPropertyItems spi3 on spi3.slItemID=sl.slPropertyID3
	left join Symphony_StockLocationPropertyItems spi4 on spi4.slItemID=sl.slPropertyID4

	left join Symphony_SKUsPropertyItems s1 on s1.skuItemID=sls.skuPropertyID1
	left join Symphony_SKUsPropertyItems s2 on s2.skuItemID=sls.skuPropertyID2
	left join Symphony_SKUsPropertyItems s3 on s3.skuItemID=sls.skuPropertyID3

	where  SL.stockLocationType=3 and slsh.consumption>0 and sl.isDeleted=0
	group by sl.stockLocationName,s.skuName,slsh.updateDate,sls.custom_txt3,sls.custom_txt4,spi1.slItemName,spi2.slItemName
	,spi3.slItemName,spi4.slItemName,s1.skuItemName,s2.skuItemName,s3.skuItemName
  order by slsh.updateDate

  end
GO
/****** Object:  StoredProcedure [dbo].[Client_SP_STATUS_RESET]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Client_SP_STATUS_RESET]
AS
BEGIN



drop table Client_STATUS_TEMP

create table Client_STATUS_TEMP
(SL nvarchar(100),
SKU nvarchar(100),
INV_Site int,
Inv_Transit int,
Year nvarchar(10),
Month nvarchar(10),
Day nvarchar(10),

)




drop table allfilenames
drop table bulkact

CREATE TABLE ALLFILENAMES(WHICHPATH VARCHAR(255),WHICHFILE varchar(255))
CREATE TABLE BULKACT(RAWDATA VARCHAR (8000))
declare @filename varchar(255),
        @path     varchar(255),
        @sql      varchar(8000),
        @cmd      varchar(1000)



SET @path = 'D:\SymphonyData\InputFolder\'
SET @cmd = 'dir ' + @path + '*.csv /b'
INSERT INTO  ALLFILENAMES(WHICHFILE)
EXEC Master..xp_cmdShell @cmd
UPDATE ALLFILENAMES SET WHICHPATH = @path where WHICHPATH is null

--cursor loop
    declare c1 cursor for SELECT WHICHPATH,WHICHFILE FROM ALLFILENAMES where WHICHFILE like 'STATUS%.csv%'
    open c1
    fetch next from c1 into @path,@filename
    While @@fetch_status <> -1
      begin
      --bulk insert won't take a variable name, so make a sql and execute it instead:
       set @sql = 'BULK INSERT Client_STATUS_TEMP FROM ''' + @path + @filename + ''' '
           + '     WITH ( 
                   FIELDTERMINATOR = '','', 
                   ROWTERMINATOR = ''\n'', 
                   FIRSTROW = 2 
                ) '
    print @sql
    exec (@sql)

      fetch next from c1 into @path,@filename
      end
    close c1
    deallocate c1

	--select * from Client_STATUS_TEMP

	
	update sls set inventoryAtTransit=0,inventoryAtSite=0

 from Symphony_StockLocationSkus sls
join Symphony_StockLocations sl on sl.stockLocationID=sls.stockLocationID 
where sl.stockLocationName + '|' + sls.locationSkuName not in (select SL  + '|' + SKU from Client_Status_Temp)
 and inventoryAtSite+inventoryAtTransit>0  --and sl.stockLocationName  in (select distinct SL from Client_Status_Temp) 



 ---- Pre LnR prcess ----

 update sls set sls.originStockLocation=null
  from Symphony_StockLocationSkus sls 
  join Symphony_StockLocations sl on sl.stockLocationID=sls.stockLocationID
  where sls.originStockLocation is not null 
  and sl.stockLocationName in ('CL-FC-MUM-WICEL')


  
update sls set sls.defaultOriginID = c.DO_copy
  from Symphony_StockLocationS sls 
  left join (select sl.stockLocationID as aa,slpi.slItemName,sl2.stockLocationID as DO_copy from Symphony_StockLocationS sl
	        left join Symphony_StockLocationPropertyItems slpi
			 on slpi.slItemID=sl.slPropertyID7
			 left join Symphony_StockLocationS sl2 on sl2.stockLocationName=slpi.slItemName) C on c.aa=sls.stockLocationID
   where sls.slPropertyID7 is not null and sls.stockLocationName not in ('CL-FC-MUM-WICEL')  and sls.isDeleted=0


   update sls set sls.originStockLocation=sl.defaultOriginID
  from Symphony_StockLocationSkus sls 
  join Symphony_StockLocations sl on sl.stockLocationID=sls.stockLocationID
  where sls.isDeleted=0 and sl.isDeleted=0 and 
  ( sls.originStockLocation is null or sls.originStockLocation<>sl.defaultOriginID)
  and sl.stockLocationName not in ('CL-FC-MUM-WICEL')


  ---for 1st LnR make the OSL as null for Regonal FC's
   update sls set sls.originStockLocation=null
  from Symphony_StockLocationSkus sls 
  join Symphony_StockLocations sl on sl.stockLocationID=sls.stockLocationID
  where sls.isDeleted=0 and sl.isDeleted=0   
  and sl.stockLocationName in 
  ('CL-FC-BNG-KOR','CL-FC-DEL-GK','CL-FC-CHN-PGR','CL-FC-BLR-BTM','CL-FC-DEL-MYP2','CL-FC-HYD-Jubilee','CL-FC-KOL-VKR''CL-FC-PUN-MNG PETH')

  
  update sl set sl.export = 0
  from Symphony_CustomReports sl
  where name in  ('MTS_Update') 








end
GO
/****** Object:  StoredProcedure [dbo].[Client_SP_STATUS_RESET_2]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Client_SP_STATUS_RESET_2]


AS
BEGIN


Declare @cmd2 varchar(1000);
set @cmd2 = 'sqlcmd -S "localhost" -U "sa" -P "Supp!y_99$" -d "SymphonyCL" -Q "set nocount on; select * from Client_STATUS_TEMP_33 where Barcode not  in (select Barcode from Repl_output_revised_post_1st_LnR);" -o "D:\SymphonyData\CustomReports\Output_Script\WH_Barcode_stock_for_2nd_LnR%date:~-4,4%%date:~-10,2%%date:~-7,2%.csv" -s"," -W'
exec master.dbo.xp_cmdshell @cmd2


drop table Client_STATUS_TEMP_S1

select * into Client_STATUS_TEMP_S1 from (
select s.sl,s.SKU,cast (case when (s.INV_Site-isnull(oa.Reple_Qty,0))<0 then 0 else (s.INV_Site-isnull(oa.Reple_Qty,0)) end as decimal(10,0)) as Inv_Site,Inv_Transit,s.Year,s.Month,s.Day from Client_STATUS_TEMP s
left join ( 
select origin_sl,sku,sum(Repl_qty) as Reple_Qty from  Repl_output_revised_post_1st_LnR group by origin_sl,sku
) oa on oa.origin_sl=s.sl and oa.sku=s.sku)#s1

--select * from Client_STATUS_TEMP_S2

drop table Client_STATUS_TEMP_S2

select * into Client_STATUS_TEMP_S2 from
(

select s1.sl,s1.SKU,s1.Inv_Site, cast (s1.Inv_Transit+isnull(oa1.Reple_Qty,0) as decimal(10,0)) as Inv_Transit,s1.Year,s1.Month,s1.Day from Client_STATUS_TEMP_S1 s1
left join ( 
select sl,sku,sum(Repl_qty) as Reple_Qty from  Repl_output_revised_post_1st_LnR group by sl,sku
) oa1 on oa1.sl=s1.sl and oa1.sku=s1.sku

union


select vx.sl,vx.sku,0 as inv_sitee,cast(sum(vx.repl_qty) as decimal(10,0)) as Inv_transitt 
,DATEPART(year,getdate()) as [year],
DATEPART(MONTH,getdate()) as [Month], 
DATEPART(DAY,getdate()) as [Day]
from Repl_output_revised_post_1st_LnR vx where
vx.sl+vx.sku not in (select hb.sl+hb.sku from Client_STATUS_TEMP_S1 hb) group by vx.sl,vx.sku
)#cxv






Declare @cmd3 varchar(1000);
set @cmd3 = 'sqlcmd -S "localhost" -U "sa" -P "Supp!y_99$" -d "SymphonyCL" -Q "set nocount on; select * from Client_STATUS_TEMP_S2;" -o "D:\SymphonyData\InputFolder\STATUS_for_2nd_LnR_%date:~-4,4%%date:~-10,2%%date:~-7,2%.csv" -s"," -W'
exec master.dbo.xp_cmdshell @cmd3


drop table clinet_table_AG_alignment_pre_LnR

select * into clinet_table_AG_alignment_pre_LnR  from

(

SELECT sl.stockLocationName as [Stock Location]
       ,sl.stockLocationDescription as [SL Description]
       ,slpi1.slItemName as [City]
	  ,slpi2.slItemName as [Region]
	  ,slpi3.slItemName as [State]
	  ,slpi6.slItemName as [Store Group]
	  ,ag.name as [Assortment Group] 
	  ,ag.description as [AG Description]
	  ,dg.name as [Display Group]
	  ,varietyTarget [Variety Target]
	  ,spaceTarget [Space Target]
	   ,case when gapMode=0 then 'Variety' else 'Space' end [Gap Mode]
	    ,validFamiliesNum+(notValidFamiliesNum - notValidFamiliesOverThresholdNum)+notValidFamiliesOverThresholdNum as [SKU Families]
	  ,validFamiliesNum as [Valid SKU Families]
	  ,(notValidFamiliesNum - notValidFamiliesOverThresholdNum) [Newly Invalid Families]
       ,[notValidFamiliesOverThresholdNum] [Expired Invalid Families]
	   ,case when agBP=-1 then '0' else agbp end as [AG Penetration]
	        ,case when varietyGap<0 then 0 else varietyGap end [Variety Gap]
           ,case when spaceGap<0 then 0 else spaceGap end [Sapce Gap]
		,agh.totalSpace [Total Space]
		,a.buffer [Total Buffer]
		,a.site [Total Stock at Site]
		,a.transit [Total stock at Transit]
		,aa.site as [Valid_Site]
		,aa.transit [Valid Transit]
		,aaa.site [Expired_Site]
		,aaa.transit [Expired_Transit]
	   	 ,cast(getdate() as date) as [Date]
  FROM [SymphonyCL].[dbo].[Symphony_LocationAssortmentGroups] agh
  left join Symphony_AssortmentGroups ag on ag.id=agh.assortmentGroupID
  left join Symphony_StockLocations sl on sl.stockLocationID=agh.stockLocationID
  left join Symphony_RetailAgDgConnection agdg on agdg.assortmentGroupID=ag.id
  left join Symphony_DisplayGroups dg on dg.id=agdg.displayGroupID
  left join Symphony_StockLocationPropertyItems slpi1 on slpi1.slItemID=sl.slPropertyID1
 left join Symphony_StockLocationPropertyItems slpi2 on slpi2.slItemID=sl.slPropertyID2
left join Symphony_StockLocationPropertyItems slpi3 on slpi3.slItemID=sl.slPropertyID3
left join Symphony_StockLocationPropertyItems slpi4 on slpi4.slItemID=sl.slPropertyID4
left join Symphony_StockLocationPropertyItems slpi5 on slpi5.slItemID=sl.slPropertyID5
left join Symphony_StockLocationPropertyItems slpi6 on slpi6.slItemID=sl.slPropertyID6
left join Symphony_StockLocationPropertyItems slpi7 on slpi7.slItemID=sl.slPropertyID7
left join (SELECT sl.stockLocationName
        ,ag.name ag_name
     ,sum(bufferSize) as buffer
	 ,sum(inventoryAtSite) as site
	 ,sum(inventoryAtTransit) transit
  FROM [Symphony_StockLocationSkus] sls
    join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  join Symphony_SkuFamilies sf on sf.id=ms.familyID
  join Symphony_StockLocations sl on sl.stockLocationID=sls.stockLocationID
  join Symphony_RetailFamilyAgConnection rfac on rfac.familyID=sf.id
  join Symphony_AssortmentGroups ag on ag.id=rfac.assortmentGroupID
  join Symphony_SKUs s on s.skuID=sls.skuID
  where sls.isDeleted=0 and sl.isDeleted=0
  group by sl.stockLocationName,ag.name)a on a.stockLocationName=sl.stockLocationName and a.ag_name=ag.name

  left join (SELECT sl.stockLocationName
        ,ag.name ag_name
     ,sum(bufferSize) as buffer
	 ,sum(inventoryAtSite) as site
	 ,sum(inventoryAtTransit) transit
  FROM [Symphony_StockLocationSkus] sls
    join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  join Symphony_SkuFamilies sf on sf.id=ms.familyID
  join Symphony_StockLocations sl on sl.stockLocationID=sls.stockLocationID
  join Symphony_RetailFamilyAgConnection rfac on rfac.familyID=sf.id
  join Symphony_AssortmentGroups ag on ag.id=rfac.assortmentGroupID
  join Symphony_SKUs s on s.skuID=sls.skuID
  join Symphony_FamilyValidationResults fvr on fvr.familyID=ms.familyID and fvr.stockLocationID=sls.stockLocationID
  where sls.isDeleted=0 and sl.isDeleted=0 and fvr.isValid=1
  group by sl.stockLocationName,ag.name)aa on aa.stockLocationName=sl.stockLocationName and aa.ag_name=ag.name


    left join (SELECT sl.stockLocationName
        ,ag.name ag_name
     ,sum(bufferSize) as buffer
	 ,sum(inventoryAtSite) as site
	 ,sum(inventoryAtTransit) transit
  FROM [Symphony_StockLocationSkus] sls
    join Symphony_MasterSkus ms on ms.skuID=sls.skuID
  join Symphony_SkuFamilies sf on sf.id=ms.familyID
  join Symphony_StockLocations sl on sl.stockLocationID=sls.stockLocationID
  join Symphony_RetailFamilyAgConnection rfac on rfac.familyID=sf.id
  join Symphony_AssortmentGroups ag on ag.id=rfac.assortmentGroupID
  join Symphony_SKUs s on s.skuID=sls.skuID
  join Symphony_FamilyValidationResults fvr on fvr.familyID=ms.familyID and fvr.stockLocationID=sls.stockLocationID
  where sls.isDeleted=0 and sl.isDeleted=0 and fvr.isValid=0 and fvr.isInvalidOverThreshold=1
  group by sl.stockLocationName,ag.name)aaa on aaa.stockLocationName=sl.stockLocationName and aaa.ag_name=ag.name


where sl.isDeleted=0 --and ag.name='W_ANNABELLE_ TOP' and sl.stockLocationName='P033'
)#agfv





--- for 2nd LnR, set OSL as PrentFC for all the stores --

  update sls set sls.originStockLocation=0
  from Symphony_StockLocationSkus sls 
  join Symphony_StockLocations sl on sl.stockLocationID=sls.stockLocationID
  where sls.isDeleted=0 and sl.isDeleted=0
  and sl.stockLocationName not in ('CL-FC-MUM-WICEL')

  --- for 2nd LnR, set Defaut Orgin as PrentFC for all the stores --

  update sl set sl.defaultOriginID = 0 
  from Symphony_StockLocationS sl
  where sl.isDeleted=0 and sl.stockLocationName not in ('CL-FC-MUM-WICEL') 









end
GO
/****** Object:  StoredProcedure [dbo].[Client_SP_STATUS_RESET_3]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Client_SP_STATUS_RESET_3]
AS
BEGIN



drop table Client_STATUS_TEMP_S3

select * into Client_STATUS_TEMP_S3 from (
select s.sl,s.SKU,cast (case when (s.INV_Site-isnull(oa.Reple_Qty,0))<0 then 0 else (s.INV_Site-isnull(oa.Reple_Qty,0)) end as decimal(10,0)) as Inv_Site,Inv_Transit,s.Year,s.Month,s.Day from Client_STATUS_TEMP_s2 s
left join ( 
select origin_sl,sku,sum(Repl_qty) as Reple_Qty from  Repl_output_revised_post_2nd_LnR group by origin_sl,sku
) oa on oa.origin_sl=s.sl and oa.sku=s.sku)#s1



drop table Client_STATUS_TEMP_S4

select * into Client_STATUS_TEMP_S4 from
(

select s1.sl,s1.SKU,s1.Inv_Site, cast (s1.Inv_Transit+isnull(oa1.Reple_Qty,0) as decimal(10,0)) as Inv_Transit,s1.Year,s1.Month,s1.Day from Client_STATUS_TEMP_S3 s1
left join ( 
select sl,sku,sum(Repl_qty) as Reple_Qty from  Repl_output_revised_post_2nd_LnR group by sl,sku
) oa1 on oa1.sl=s1.sl and oa1.sku=s1.sku

union


select vx.sl,vx.sku,0 as inv_sitee,cast(sum(vx.repl_qty) as decimal(10,0)) as Inv_transitt 
,DATEPART(year,getdate()) as [year],
DATEPART(MONTH,getdate()) as [Month], 
DATEPART(DAY,getdate()) as [Day]
from Repl_output_revised_post_2nd_LnR vx where
vx.sl+vx.sku not in (select hb.sl+hb.sku from Client_STATUS_TEMP_S3 hb) group by vx.sl,vx.sku
)#cxv



Declare @cmd3 varchar(1000);
set @cmd3 = 'sqlcmd -S "localhost" -U "sa" -P "Supp!y_99$" -d "SymphonyCL" -Q "set nocount on; select * from Client_STATUS_TEMP_S4;" -o "D:\SymphonyData\InputFolder\STATUS_for_3rd_LnR_%date:~-4,4%%date:~-10,2%%date:~-7,2%.csv" -s"," -W'
exec master.dbo.xp_cmdshell @cmd3


update sl set sl.export = 1
  from Symphony_CustomReports sl
  where name in  ('MTS_Update') 



end
GO
/****** Object:  StoredProcedure [dbo].[Client_SP_WH_Order]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Client_SP_WH_Order]
AS
BEGIN


SELECT sl.stockLocationName as [Stock Location]
         ,ss.skuName as SKU
         ,cast(sls.bufferSize as decimal(20,0)) as [Buffer Size]
         ,isnull(a.g,0) as FE_Gap
		 ,sls.inventoryAtSite as WH_Site_Qty
		 ,sls.inventoryAtTransit as WH_Transit_Qty
         ,sls.inventoryatsite+sls.inventoryattransit+sls.inventoryatproduction as WH_Total_Pipe_Qty
		 ,isnull((sls.bufferSize+a.g)-(sls.inventoryatsite+sls.inventoryattransit+sls.inventoryatproduction),0) as Total_gap_Qty
		 ,'' as [Origin Stock Location]
		
		 ,case when siteColor=0 then 'Cyan' 
       when siteColor=1 then 'Green' 
	when siteColor=2 then 'yellow' 	
   	when siteColor=3 then 'Red' 	
	when siteColor=4 then 'Black' end	[Site_BP Color]

		
		 ,case when productionColor=0 then 'Cyan' 
       when productionColor=1 then 'Green' 
	when productionColor=2 then 'yellow' 	
   	when productionColor=3 then 'Red' 	
	when productionColor=4 then 'Black' end	[Pipe_BP Color]
	,convert(varchar,GETDATE(),103) as [Date]
			 FROM [SymphonyCL].[dbo].[Symphony_StockLocationSkus] sls
  join Symphony_StockLocations sl on sls.stockLocationID=sl.stockLocationID
 /*join Symphony_StockLocations sl1
on sls.originStockLocation=sl1.stockLocationID*/
join Symphony_SKUs ss on sls.skuid=ss.skuID
join Symphony_SKUsPropertyItems spi1 on spi1.skuItemID=sls.skuPropertyID1
left join 
(SELECT sl1.stockLocationName as [Stock Location]
         ,ss.skuName as SKU
		 ,sum(sls.replenishmentQuantity) as [Replenishment Quantity]
		 ,sum(sls.inventoryNeeded) as inveneed
		 ,ISNULL(sum(sls.inventoryNeeded-sls.replenishmentQuantity),0) as g
		 ,sum(cast(sls.bufferSize as decimal(20,0))) as [Buffer Size]
		 FROM [SymphonyCL].[dbo].[Symphony_StockLocationSkus] sls
  join Symphony_StockLocations sl
on sls.stockLocationID=sl.stockLocationID
 join Symphony_StockLocations sl1
on sls.originStockLocation=sl1.stockLocationID
join Symphony_SKUs ss
on sls.skuid=ss.skuID
where /*sls.inventoryNeeded-sls.replenishmentQuantity>0 and */ sl.stockLocationType=3
group by sl1.stockLocationName,ss.skuName)a on a.[Stock Location]=sl.stockLocationName and a.SKU=ss.skuName 
where sls.bufferSize>0 and sl.stockLocationName IN ('CL-FC-MUM-WICEL')  and spi1.skuItemName is not null
and 
isnull((sls.bufferSize+a.g)-(sls.inventoryatsite+sls.inventoryattransit+sls.inventoryatproduction),0)>0

end
GO
/****** Object:  StoredProcedure [dbo].[CreateAfterChangeTriggers]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[CreateAfterChangeTriggers]
	@tableName sysname = NULL
	-- Add the parameters for the stored procedure here
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	--Get trigger/table name pairs
	DECLARE @PARAMETERS AS TABLE([ID] [int] IDENTITY (0,1),[tableName] [nvarchar](100), [triggerName] [nvarchar](150))
	
	INSERT INTO @PARAMETERS
		SELECT [tableName], [triggerName] 
		FROM [dbo].[Symphony_DataChanged]
		WHERE [type] = 0
		AND [tableName] LIKE ISNULL(@tableName, '%')
		
	DECLARE
		 @COUNT int
		,@INDEX int
		,@TABLE_NAME NVARCHAR(100)
		,@TRIGGER_NAME NVARCHAR(150)
		
	SELECT @COUNT = COUNT(1), @INDEX = 0 FROM @PARAMETERS;
	
	WHILE @INDEX < @COUNT
	BEGIN
	
		SELECT @TABLE_NAME = [tableName], @TRIGGER_NAME = [triggerName] 
		FROM @PARAMETERS
		WHERE [ID] = @INDEX
		
		EXECUTE('IF  EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N''[dbo].[' + @TRIGGER_NAME + ']''))
						DROP TRIGGER [dbo].[' + @TRIGGER_NAME + ']'
				) 

					
		EXECUTE('CREATE TRIGGER [dbo].[' + @TRIGGER_NAME + '] ON [dbo].[' + @TABLE_NAME +']
					   AFTER INSERT,DELETE,UPDATE
					AS
					BEGIN
						UPDATE [dbo].[Symphony_DataChanged]
						SET [lastDataChange] = GETDATE()
						WHERE [tableName] = ''' + @TABLE_NAME + ''';
					END'
				)
												
		SET @INDEX = @INDEX + 1;
		
	END
	
END
GO
/****** Object:  StoredProcedure [dbo].[CreateAfterInsertDeleteTriggers]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[CreateAfterInsertDeleteTriggers]
	-- Add the parameters for the stored procedure here
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--Get trigger/table name pairs
	DECLARE @PARAMETERS AS TABLE([ID] [int] IDENTITY (0,1),[tableName] [nvarchar](100), [triggerName] [nvarchar](150))
	
	INSERT INTO @PARAMETERS
		SELECT [tableName], [triggerName] 
		FROM [dbo].[Symphony_DataChanged]
		WHERE [type] = 1;
		
	DECLARE
		 @COUNT int
		,@INDEX int
		,@TABLE_NAME NVARCHAR(100)
		,@TRIGGER_NAME NVARCHAR(150)
		
	SELECT @COUNT = COUNT(1), @INDEX = 0 FROM @PARAMETERS;
	
	WHILE @INDEX < @COUNT
	BEGIN
	
		SELECT @TABLE_NAME = [tableName], @TRIGGER_NAME = [triggerName] 
		FROM @PARAMETERS
		WHERE [ID] = @INDEX
		
		EXECUTE('IF  EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N''[dbo].[' + @TRIGGER_NAME + ']''))
					DROP TRIGGER [dbo].[' + @TRIGGER_NAME + ']'
				)
					
		EXECUTE('CREATE TRIGGER [dbo].[' + @TRIGGER_NAME + '] ON [dbo].[' + @TABLE_NAME +']
					   AFTER INSERT,DELETE
					AS
					BEGIN
						UPDATE [dbo].[Symphony_DataChanged]
						SET [lastDataChange] = GETDATE()
						WHERE [tableName] = ''' + @TABLE_NAME + ''';
					END' 
				)
										
		SET @INDEX = @INDEX + 1;
		
	END
END
GO
/****** Object:  StoredProcedure [dbo].[CreateCustomChangeTriggers]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[CreateCustomChangeTriggers]
	-- Add the parameters for the stored procedure here
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	EXECUTE (
		'IF  EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N''[dbo].[AfterUpdate_StockLocationSkus]''))
			DROP TRIGGER [dbo].[AfterUpdate_StockLocationSkus]'
	)
					
	EXECUTE (
		'CREATE TRIGGER [dbo].[AfterUpdate_StockLocationSkus] 
		   ON  [dbo].[Symphony_StockLocationSkus] 
		   AFTER UPDATE
		AS 
		BEGIN
			IF UPDATE([isDeleted])	BEGIN
			
				DECLARE @isChanged bit = 0
				
				SELECT TOP 1
					@isChanged = CONVERT(bit, 1)
				FROM deleted 
				INNER JOIN inserted 
					ON inserted.skuID =deleted.skuID
					AND inserted.stockLocationID = deleted.stockLocationID
					AND inserted.[isDeleted] <> deleted.[isDeleted]
				
				IF @isChanged = 1
					UPDATE [dbo].[Symphony_DataChanged]
					SET [lastDataChange] = GETDATE()
					WHERE [tableName] = ''Symphony_StockLocationSkus''
					OR [tableName] = ''Symphony_SKUs'';
				
			END
			ELSE IF UPDATE([originStockLocation])
			BEGIN
				UPDATE [dbo].[Symphony_DataChanged]
				SET [lastDataChange] = GETDATE()
				WHERE [tableName] = ''Symphony_StockLocationSkus'' AND [type] = 2;
			END
		END'
	)

	EXECUTE (
		'IF  EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N''[dbo].[AfterUpdate_MTOSkus]''))
			DROP TRIGGER [dbo].[AfterUpdate_MTOSkus]'
	)
					
	EXECUTE (
		'CREATE TRIGGER [dbo].[AfterUpdate_MTOSkus] 
		   ON  [dbo].[Symphony_MTOSkus] 
		   AFTER UPDATE
		AS 
		BEGIN
			IF UPDATE([isDeleted])
			BEGIN
				UPDATE [dbo].[Symphony_DataChanged]
				SET [lastDataChange] = GETDATE()
				WHERE [tableName] = ''Symphony_MTOSkus''
				OR [tableName] = ''Symphony_MTOSkus'';
			END
		END'
	)

END
GO
/****** Object:  StoredProcedure [dbo].[CreateInputQuarantineTable]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[CreateInputQuarantineTable]
	-- Add the parameters for the stored procedure here
	@inputTableName sysname
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    DECLARE @identityColumnName sysname;
    DECLARE @quarantineTableName sysname;
	SELECT @quarantineTableName = N'[dbo].[' +  OBJECT_NAME(OBJECT_ID(@inputTableName)) + N'Quarantine]';
	--SELECT @quarantineTableName = OBJECT_NAME(OBJECT_ID(@inputTableName)) + N'Quarantine';
	EXEC [dbo].[BeforeCreate] 'TABLE', @quarantineTableName
	
	EXEC ('SELECT TOP(0) * INTO ' + @quarantineTableName + ' FROM ' + @inputTableName)

	SELECT
		@identityColumnName = ISNULL( COL.[name],N'')
	FROM sys.columns COL
	INNER JOIN sys.tables TBL
		ON TBL.[object_id] = COL.[object_id]
	WHERE COL.[is_identity] = 1
		AND TBL.[object_id] = OBJECT_ID(@quarantineTableName,'TABLE')

	IF LEN(@identityColumnName) > 0
		EXEC ('ALTER TABLE ' + @quarantineTableName + ' DROP COLUMN ' + @identityColumnName)

	EXEC ('ALTER TABLE ' + @quarantineTableName + ' ADD id bigint IDENTITY')
	EXEC ('ALTER TABLE ' + @quarantineTableName + ' ADD [type] nvarchar(50)')
	EXEC ('ALTER TABLE ' + @quarantineTableName + ' ADD loadingDate datetime')
	EXEC ('ALTER TABLE ' + @quarantineTableName + ' ADD quarantineReason nvarchar(500)')
	EXEC ('ALTER TABLE ' + @quarantineTableName + ' ADD actualLineContent nvarchar(1000)')
	
	EXEC [dbo].[AfterCreate] 'TABLE', @quarantineTableName

END
GO
/****** Object:  StoredProcedure [dbo].[DropDefaultConstraint]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[DropDefaultConstraint] 
	-- Add the parameters for the stored procedure here
	@tableName sysname, 
	@columnName sysname
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @constraintName sysname;
	
	SELECT
		@constraintName = DC.name
	FROM sys.default_constraints DC
	INNER JOIN sys.tables T
		ON DC.parent_object_id = T.object_id
	INNER JOIN sys.columns C
		ON C.object_id = T.object_id
		AND DC.parent_column_id = C.column_id
	WHERE T.name = REPLACE(REPLACE(@tableName,'[',''),']','') 
		AND C.name = REPLACE(REPLACE(@columnName,'[',''),']','')
		

	IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(@constraintName) AND type = 'D')
	BEGIN
		EXEC ('ALTER TABLE ' + @tableName + ' DROP CONSTRAINT ' + @constraintName)
	END
END
GO
/****** Object:  StoredProcedure [dbo].[DropDefaultConstraints]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[DropDefaultConstraints] 
	@tableName sysname
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @cmd nvarchar(max);
	
	SELECT
		@cmd = CASE
			WHEN @cmd IS NULL THEN 'ALTER TABLE ' + @tableName + ' DROP CONSTRAINT ' + DC.name
			ELSE @cmd + CHAR(13) + 'ALTER TABLE ' + @tableName + ' DROP CONSTRAINT ' + DC.name
		END
	FROM sys.default_constraints DC
	INNER JOIN sys.tables T
		ON DC.parent_object_id = T.object_id
	WHERE T.name = REPLACE(REPLACE(@tableName,'[',''),']','');
		
	EXEC (@cmd);
END
GO
/****** Object:  StoredProcedure [dbo].[DropForeignKeyConstraints]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[DropForeignKeyConstraints]
	@tableName sysname
AS
BEGIN

	SET NOCOUNT ON;
	
	DECLARE
		 @charIndex int
		,@cmd nvarchar(max);

	SELECT 
		 @charIndex = CHARINDEX('.', REVERSE(@tableName), 1)
		,@tableName = CASE 
			WHEN @charIndex > 0 THEN  LTRIM(RTRIM(REPLACE(REPLACE(RIGHT(@tableName, @charIndex - 1),'[',''),']','')))
			ELSE LTRIM(RTRIM(REPLACE(REPLACE(@tableName,'[',''),']','')))
			END

	SELECT 
		@cmd = CASE	
			WHEN @cmd IS NULL THEN 'ALTER TABLE ' + @tableName + ' DROP CONSTRAINT ' + FK.name 
			ELSE @cmd + CHAR(13) +  'ALTER TABLE ' + @tableName + ' DROP CONSTRAINT ' + FK.name 
			END
	FROM sys.foreign_keys FK
	INNER JOIN sys.tables TBL
		ON TBL.object_id = FK.parent_object_id
	WHERE TBL.name = @tableName
	
	EXEC (@cmd)
	
END
GO
/****** Object:  StoredProcedure [dbo].[Symphony_CustomReport_Data]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Symphony_CustomReport_Data]
	 @reportID int
	,@skip int = null
	,@take int = null
	,@select nvarchar(max) = null
	,@where nvarchar(max) = null
	,@orderby nvarchar(max) = null
	,@paramValues nvarchar(max) = null
	,@paramDefinitions nvarchar(max) = null
AS
BEGIN
	
	SET NOCOUNT ON;

	--Get the query text
	DECLARE 			 
		 @sql nvarchar(max)
		,@guid nvarchar(36)
		,@queryText nvarchar(max)
		,@procedure nvarchar(max)
		,@pageRange nvarchar(max)
		,@tableDefinition nvarchar(max);

	DECLARE @columnDefinitions TABLE(
			name nvarchar(128)
		,system_Type_Name nvarchar(128)
	)

	SELECT 			 
		 @guid = 'TMP_' + REPLACE( newid(),'-','')
		,@queryText = RTRIM(LTRIM([query])) FROM [dbo].[Symphony_CustomReports] WHERE [id] = @reportID;

	DECLARE @isProcedure bit = CONVERT(bit, CHARINDEX('EXEC', @queryText));

	--Create Tmp table with uniqueId field
	--The uniqueId field is necessary for the grid view
	--Note: The custom report definition should be modified add a mandatory order by clause

	--Get column definitions
	-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	IF @isProcedure = 1 BEGIN
		SELECT @procedure = LTRIM(SUBSTRING(@queryText, CHARINDEX(' ', @queryText), LEN(@queryText)));
		IF (CHARINDEX(' ', @procedure) > 0)
			SELECT @procedure = LEFT(@procedure, CHARINDEX(' ', @procedure) - 1)
		INSERT INTO @columnDefinitions
			SELECT QUOTENAME(name,'[') [name], [system_type_name] FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID(@procedure), null);
	END
	ELSE BEGIN

		INSERT INTO @columnDefinitions
			SELECT QUOTENAME(name,'[') [name], [system_type_name] FROM sys.dm_exec_describe_first_result_set(@queryText,NULL,NULL);
	END
	-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	-- Create tmp table
	-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	SELECT
		@tableDefinition = CASE 
			WHEN @tableDefinition IS NULL THEN 'uniqueId int IDENTITY(1, 1), ' + [name] + ' ' + [system_type_name]
			ELSE @tableDefinition + ', ' + [name] + ' ' + [system_type_name]
		END
	FROM(
		SELECT [name], [system_type_name]
		FROM @columnDefinitions
	) tmp

	SELECT 
			@tableDefinition = @tableDefinition + ', CONSTRAINT PK_' + @guid + ' PRIMARY KEY CLUSTERED  (uniqueId)'
		,@sql = '	CREATE TABLE ' + @guid + '(' + @tableDefinition + ')';

	EXEC (@sql);
	-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	IF @isProcedure = 1 BEGIN
		SELECT @sql = 'INSERT INTO ' + @guid + ' EXEC ' + @procedure;
		EXEC (@sql);

		SELECT @queryText = 'SELECT * FROM ' + @guid + ' ' + + ISNULL(@where, '');
	END
	ELSE BEGIN
		SELECT @sql = 'INSERT  INTO ' + @guid + ' SELECT * FROM (' + @queryText +  ') TMP ' + ISNULL(@where, '') ;

		IF @paramDefinitions IS NOT NULL AND @paramValues IS NOT NULL
			SELECT @sql = 'sp_executesql N''' + REPLACE( @sql,'''','''''') + ''', N''' + @paramDefinitions + ''', ' + @paramValues
		EXEC (@sql);

		SELECT @queryText = 'SELECT * FROM ' + @guid;
	END

	IF @skip + @take IS  NULL
		SELECT @sql = ISNULL(@select, 'SELECT * ') + ' FROM (' + @queryText + ') TMP ' + ISNULL(@orderby, 'ORDER BY uniqueId')
	ELSE
		SELECT @sql = ISNULL(@select, 'SELECT * ') + ' FROM (' + @queryText + ') TMP ' + ISNULL(@orderby, 'ORDER BY uniqueId') + ' OFFSET ' + CONVERT(nvarchar(10), @skip) + ' ROWS FETCH NEXT ' + CONVERT(nvarchar(10), @take) + ' ROWS ONLY';

	IF @isProcedure = 1 AND @paramDefinitions IS NOT NULL AND @paramValues IS NOT NULL
		SELECT @sql = 'sp_executesql N''' +  @sql + ''', N''' + @paramDefinitions + ''',' + @paramValues 

	EXEC (@sql);

	IF OBJECT_ID(@guid) IS NOT NULL BEGIN
		SELECT @sql = 'DROP TABLE ' + @guid;
		EXEC (@sql);
	END

END
GO
/****** Object:  StoredProcedure [dbo].[Symphony_CustomReport_DataTable]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Symphony_CustomReport_DataTable]
	@reportID int
AS
BEGIN
	
	SET NOCOUNT ON;

	--Get the query text
	DECLARE @queryText nvarchar(max);
	SELECT @queryText = RTRIM(LTRIM([query])) FROM [dbo].[Symphony_CustomReports] WHERE [id] = @reportID

	--Differentiate between queries and procedures
	DECLARE 
		 @guid nvarchar(36)
		,@sql nvarchar(max)

	DECLARE @columnDefinitions TABLE(
		 name nvarchar(128)
		,system_Type_Name nvarchar(128)
	)

	SELECT @guid = 'TMP_' + REPLACE( newid(),'-','');

	IF CHARINDEX('EXEC', @queryText) = 1 BEGIN
		DECLARE @procedure nvarchar(max);
		-- LTRIM MAY NOT WORK HERE, USER SHOULD NOT INSERT MORE THAN 1 SPACE BETWEEN EXEC AND THE PROCEDURE NAME
		SELECT @procedure = LTRIM(SUBSTRING(@queryText, CHARINDEX(' ', @queryText), LEN(@queryText)));
		IF (CHARINDEX(' ', @procedure) > 0)
			SELECT @procedure = LEFT(@procedure, CHARINDEX(' ', @procedure) - 1)
		INSERT INTO @columnDefinitions
			SELECT QUOTENAME(name,'[') [name], [system_type_name] FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID(@procedure), null);
	END
	ELSE BEGIN
		INSERT INTO @columnDefinitions
			SELECT QUOTENAME(name,'[') [name], [system_type_name] FROM sys.dm_exec_describe_first_result_set(@queryText,NULL,NULL);
	END

	EXEC (@sql);

	DECLARE 
	 @tableDefinition nvarchar(max)
	,@separator nvarchar(1) = ','
	
	SELECT
		@tableDefinition = CASE 
			WHEN @tableDefinition IS NULL THEN [name] + ' ' + [system_type_name]
			ELSE @tableDefinition + @separator + [name] + ' ' + [system_type_name]
		END
	FROM(
		SELECT [name], [system_type_name]
		FROM @columnDefinitions
	) tmp

	SELECT @sql = '	CREATE TABLE ' + @guid + '(' + @tableDefinition + ')';
	EXEC (@sql);

	SELECT @sql = '	SELECT * FROM ' + @guid;
	EXEC (@sql);

	SELECT @sql = 'DROP TABLE ' + @guid;
	EXEC (@sql);

END
GO
/****** Object:  StoredProcedure [dbo].[Symphony_CustomReport_RowCount]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Symphony_CustomReport_RowCount]
	 @reportID int
	,@where nvarchar(max) = null
	,@paramValues nvarchar(max) = null
	,@paramDefinitions nvarchar(max) = null
AS
BEGIN
	
	SET NOCOUNT ON;

	--Get the query text
	DECLARE 			 
		 @sql nvarchar(max)
		,@queryText nvarchar(max);

	SELECT @queryText = RTRIM(LTRIM([query])) FROM [dbo].[Symphony_CustomReports] WHERE [id] = @reportID

	IF @queryText IS NULL BEGIN
		SELECT 0;
		RETURN 1;
	END

	--Differentiate between queries and procedures
	IF CHARINDEX('EXEC', @queryText) = 1 BEGIN

		DECLARE 
			 @guid nvarchar(36)
			,@procedure nvarchar(max)
			,@tableDefinition nvarchar(max)

		DECLARE @columnDefinitions TABLE(
			 name nvarchar(128)
			,system_Type_Name nvarchar(128)
		)
		-- LTRIM MAY NOT WORK HERE, USER SHOULD NOT INSERT MORE THAN 1 SPACE BETWEEN EXEC AND THE PROCEDURE NAME
		SELECT 
			 @guid = 'TMP_' + REPLACE( newid(),'-','')
			,@procedure = LTRIM(SUBSTRING(@queryText, CHARINDEX(' ', @queryText), LEN(@queryText)));
			IF (CHARINDEX(' ', @procedure) > 0)
				SELECT @procedure = LEFT(@procedure, CHARINDEX(' ', @procedure) - 1)
			INSERT INTO @columnDefinitions
				SELECT QUOTENAME(name,'[') [name], [system_type_name] FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID(@procedure), null);

		SELECT
			@tableDefinition = CASE 
				--WHEN @tableDefinition IS NULL THEN 'uniqueId int IDENTITY(1, 1), ' + [name] + ' ' + [system_type_name]
				WHEN @tableDefinition IS NULL THEN [name] + ' ' + [system_type_name]
				ELSE @tableDefinition + ', ' + [name] + ' ' + [system_type_name]
			END
		FROM(
			SELECT [name], [system_type_name]
			FROM @columnDefinitions
		) tmp

		SELECT 
			 --@tableDefinition = @tableDefinition + ', CONSTRAINT PK_' + @guid + ' PRIMARY KEY CLUSTERED  (uniqueId)'
			 @sql = '	CREATE TABLE ' + @guid + '(' + @tableDefinition + ')';

		EXEC (@sql);

		SELECT @sql = 'INSERT INTO ' + @guid + ' EXEC ' + @procedure;
		EXEC (@sql);

		SELECT @sql = 'SELECT COUNT(1) FROM ' + @guid + ' ' + ISNULL(@where, '');

		IF @paramDefinitions IS NOT NULL AND @paramValues IS NOT NULL
			SELECT @sql = 'sp_executesql N''' + @sql + ''', N''' + @paramDefinitions + ''',' + @paramValues 

		EXEC (@sql);

		SELECT @sql = 'DROP TABLE ' + @guid;
		EXEC (@sql);

	END
	ELSE BEGIN

		SELECT @sql = 'SELECT COUNT(1) FROM (' + @queryText  + ') TMP' + ' ' + ISNULL(@where, '');

		IF @paramDefinitions IS NOT NULL AND @paramValues IS NOT NULL 
			SELECT @sql = 'sp_executesql N''' + REPLACE( @sql,'''','''''') + ''', N''' + @paramDefinitions + ''',' + @paramValues 
	
		EXEC (@sql);
	END
END
GO
/****** Object:  StoredProcedure [dbo].[Symphony_CustomReport_SQLColumns]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Symphony_CustomReport_SQLColumns]
	@reportID int
AS
BEGIN
	
	SET NOCOUNT ON;

	--Get the query text
	DECLARE @queryText nvarchar(max);
	SELECT @queryText = RTRIM(LTRIM([query])) FROM [dbo].[Symphony_CustomReports] WHERE [id] = @reportID

	--Differentiate between queries and procedures
	IF CHARINDEX('EXEC', @queryText) = 1 BEGIN
		DECLARE @procedure nvarchar(max);
		SELECT @procedure = LTRIM(SUBSTRING(@queryText, CHARINDEX(' ', @queryText), LEN(@queryText)))
		SELECT QUOTENAME(name,'[') [name], system_type_name [type] FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID(@procedure), null);
	END
	ELSE BEGIN
		SELECT QUOTENAME(name,'[') [name], system_type_name [type] FROM sys.dm_exec_describe_first_result_set(@queryText,NULL,NULL);
	END

END
GO
/****** Object:  StoredProcedure [dbo].[Symphony_CustomReport_Summary]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Symphony_CustomReport_Summary]
	 @reportID int
	,@operation nvarchar(max) = null
	,@columnName nvarchar(max) = null
	,@where nvarchar(max) = null
	,@paramValues nvarchar(max) = null
	,@paramDefinitions nvarchar(max) = null
AS
BEGIN
	
	SET NOCOUNT ON;

	

	--Get the query text
	DECLARE 			 
		 @sql nvarchar(max)
		,@guid nvarchar(36)
		,@queryText nvarchar(max)
		,@procedure nvarchar(max)
		,@pageRange nvarchar(max)
		,@tableDefinition nvarchar(max);

	DECLARE @columnDefinitions TABLE(
			name nvarchar(128)
		,system_Type_Name nvarchar(128)
	)

	SELECT 			 
		 @guid = 'TMP_' + REPLACE( newid(),'-','')
		,@queryText = RTRIM(LTRIM([query])) FROM [dbo].[Symphony_CustomReports] WHERE [id] = @reportID;

	DECLARE @isProcedure bit = CONVERT(bit, CHARINDEX('EXEC', @queryText));

	--Create Tmp table with uniqueId field
	--The uniqueId field is necessary for the grid view
	--Note: The custom report definition should be modified add a mandatory order by clause

	--Get column definitions
	-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	IF @isProcedure = 1 BEGIN
		SELECT @procedure = LTRIM(SUBSTRING(@queryText, CHARINDEX(' ', @queryText), LEN(@queryText)));
		IF (CHARINDEX(' ', @procedure) > 0)
			SELECT @procedure = LEFT(@procedure, CHARINDEX(' ', @procedure) - 1)
		INSERT INTO @columnDefinitions
			SELECT QUOTENAME(name,'[') [name], [system_type_name] FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID(@procedure), null);
	END
	ELSE BEGIN

		INSERT INTO @columnDefinitions
			SELECT QUOTENAME(name,'[') [name], [system_type_name] FROM sys.dm_exec_describe_first_result_set(@queryText,NULL,NULL);
	END
	-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	-- Create tmp table
	-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	SELECT
		@tableDefinition = CASE 
			WHEN @tableDefinition IS NULL THEN 'uniqueId int IDENTITY(1, 1), ' + [name] + ' ' + [system_type_name]
			ELSE @tableDefinition + ', ' + [name] + ' ' + [system_type_name]
		END
	FROM(
		SELECT [name], [system_type_name]
		FROM @columnDefinitions
	) tmp

	SELECT 
			@tableDefinition = @tableDefinition + ', CONSTRAINT PK_' + @guid + ' PRIMARY KEY CLUSTERED  (uniqueId)'
		,@sql = '	CREATE TABLE ' + @guid + '(' + @tableDefinition + ')';

	EXEC (@sql);
	-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	IF @isProcedure = 1 BEGIN
		SELECT @sql = 'INSERT INTO ' + @guid + ' EXEC ' + @procedure;
		EXEC (@sql);

		SELECT @queryText = 'SELECT * FROM ' + @guid + ' ' + + ISNULL(@where, '');
	END
	ELSE BEGIN
		SELECT @sql = 'INSERT  INTO ' + @guid + ' SELECT * FROM (' + @queryText +  ') TMP ' + ISNULL(@where, '') ;

		IF @paramDefinitions IS NOT NULL AND @paramValues IS NOT NULL
			SELECT @sql = 'sp_executesql N''' + REPLACE( @sql,'''','''''') + ''', N''' + @paramDefinitions + ''', ' + @paramValues
		EXEC (@sql);

		SELECT @queryText = 'SELECT * FROM ' + @guid;
	END
	IF @operation = 'AVG'	BEGIN

		DECLARE @scale int
		DECLARE @cmd nvarchar(max) =
		N'SELECT @scale = CASE WHEN COL.system_type_id IN (48, 52, 56, 127) THEN 2 ELSE NULL END
		FROM sys.columns COL
		INNER JOIN sys.tables TBL
			ON TBL.object_id = COL.object_id
		WHERE TBL.NAME = ''' + @guid + '''
			AND COL.NAME = ''' + @columnName + ''''


		EXEC sp_executesql @cmd
			,N'@scale int OUTPUT'
			,@scale = @scale OUTPUT

		SELECT @columnName = QUOTENAME(@columnName);

		IF @scale IS NULL
			SELECT @sql =  'SELECT ' + @operation + '(' + @columnName + ')' + ' FROM (' + @queryText + ') TMP '
		ELSE
			SELECT @sql =  'SELECT ' + @operation + '(CONVERT(decimal(18, ' + CONVERT(nvarchar(10),@scale) + '),' + @columnName + '))' + ' FROM (' + @queryText + ') TMP '
	END
	ELSE BEGIN
		SELECT @sql =  'SELECT ' + @operation + '(' + @columnName + ')' + ' FROM (' + @queryText + ') TMP '
	END

	IF @isProcedure = 1 AND @paramDefinitions IS NOT NULL AND @paramValues IS NOT NULL
		SELECT @sql = 'sp_executesql N''' +  @sql + ''', N''' + @paramDefinitions + ''',' + @paramValues 

	EXEC (@sql);

	IF OBJECT_ID(@guid) IS NOT NULL BEGIN
		SELECT @sql = 'DROP TABLE ' + @guid;
		EXEC (@sql);
	END

END

GO
/****** Object:  StoredProcedure [dbo].[Symphony_spCopyExistingPurchasingOrders]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/******************************************/
/****** End Diagnostic Procedures *********/
/******************************************/

/******************************************/
/****** IST Compliance Procedures *********/
/******************************************/

/*****  IS EXECUTED BEFORE THE LOAD & RECALCULATE *****/


CREATE PROCEDURE [dbo].[Symphony_spCopyExistingPurchasingOrders]
AS
BEGIN

	TRUNCATE TABLE Symphony_PurchasingOrderPrev
	INSERT INTO [dbo].[Symphony_PurchasingOrderPrev] (
		ID
		,stockLocationID
		,skuID
		,skuDescription
		,quantity
		,orderID
		,clientOrderID
		,supplierID
		,bufferSize
		,isToOrder
		,orderPrice
		,orderDate
		,promisedDueDate
		,bufferPenetration
		,bufferColor
		,inputSuspicion
		,virtualStockLevel
		,bufferDueDate
		,considered
		,newRedBlack
		,calculateDueDate
		,oldBufferColor
		,neededDate
		,isShipped
		,supplierSkuName
		,note
		,needsMatch
		,purchasingPropertyID1
		,purchasingPropertyID2
		,purchasingPropertyID3
		,purchasingPropertyID4
		,purchasingPropertyID5
		,purchasingPropertyID6
		,purchasingPropertyID7
		,isISTOrder
		)
	SELECT ID
		,stockLocationID
		,skuID
		,skuDescription
		,quantity
		,orderID
		,clientOrderID
		,supplierID
		,bufferSize
		,isToOrder
		,orderPrice
		,orderDate
		,promisedDueDate
		,bufferPenetration
		,bufferColor
		,inputSuspicion
		,virtualStockLevel
		,bufferDueDate
		,considered
		,newRedBlack
		,calculateDueDate
		,oldBufferColor
		,neededDate
		,isShipped
		,supplierSkuName
		,note
		,needsMatch
		,purchasingPropertyID1
		,purchasingPropertyID2
		,purchasingPropertyID3
		,purchasingPropertyID4
		,purchasingPropertyID5
		,purchasingPropertyID6
		,purchasingPropertyID7
		,isISTOrder
	FROM [dbo].[Symphony_PurchasingOrder]
END
EXEC [dbo].[AfterCreate] 'PROCEDURE', '[dbo].[Symphony_spCopyExistingPurchasingOrders]'
GO
/****** Object:  StoredProcedure [dbo].[Symphony_spGenerateReducedRules]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[Symphony_spGenerateReducedRules]
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE [dbo].[Symphony_familyTreeReducedRules];
    TRUNCATE TABLE [dbo].[Symphony_familyTreeReducedRulesPrepare];

    INSERT INTO [dbo].[Symphony_familyTreeReducedRules]
       SELECT 
            FAG.[familyID]
           ,FAG.[assortmentGroupID]
           ,AGDG.[displayGroupID]
           ,NULL
       FROM [dbo].[Symphony_SkuFamilies] F
       INNER JOIN [dbo].[Symphony_RetailFamilyAgConnection] FAG
           ON F.[id] = FAG.[familyID]
       LEFT JOIN [dbo].[Symphony_RetailAgDgConnection] AGDG
           ON AGDG.[assortmentGroupID] = FAG.[assortmentGroupID]

    INSERT INTO [dbo].[Symphony_familyTreeReducedRules]
       SELECT 
            FAG.[familyID]
           ,FAG.[assortmentGroupID]
           ,AGDG.[displayGroupID]
           ,MSKU.[familyMemberID]
       FROM [dbo].[Symphony_SkuFamilies] F
       INNER JOIN [dbo].[Symphony_RetailFamilyAgConnection] FAG
           ON F.[id] = FAG.[familyID]
       LEFT JOIN [dbo].[Symphony_RetailAgDgConnection] AGDG
           ON AGDG.[assortmentGroupID] = FAG.[assortmentGroupID]
       INNER JOIN [dbo].[Symphony_MasterSkus] MSKU
           ON MSKU.[familyID] = FAG.[familyID]

   EXECUTE [dbo].[Symphony_spGetReducedRulesCommon]   
   EXECUTE [dbo].[Symphony_spGetReducedRulesSL]   
   EXECUTE [dbo].[Symphony_spGetReducedRulesFamilyMember]   
   EXECUTE [dbo].[Symphony_spGetReducedRulesSLFamilyMember]   
END
GO
/****** Object:  StoredProcedure [dbo].[Symphony_spGetReducedRulesCommon]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

--**********************************************************
-- Get common rules					
--**********************************************************
CREATE PROCEDURE [dbo].[Symphony_spGetReducedRulesCommon]
AS
BEGIN
    SET NOCOUNT ON;

    --**********************************************************
    -- Get common rules					
    --**********************************************************
    INSERT INTO [dbo].[Symphony_familyTreeReducedRulesPrepare]  
    SELECT
          FT.[familyID]
         ,FT.[assortmentGroupID]
         ,-1 [familyMemberID]
         ,-1 [stockLocationID]
         ,MAX([minimumMembersCount])[minimumMembersCount]
         ,MAX([minimumPreferredCount])[minimumPreferredCount]
         ,MAX([minimumInventory])[minimumInventory]
         ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
         ,1
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
         ON FT.[familyID] = VR.[familyID]
         AND FT.[assortmentGroupID] = VR.[assortmentGroupID]
         AND FT.[displayGroupID] = VR.[displayGroupID]
    WHERE
          VR.[familyMemberID] IS NULL
          AND VR.[stockLocationID] IS NULL
    GROUP BY 
		 FT.[familyID]
		,FT.[assortmentGroupID]
    UNION
    SELECT
         FT.[familyID]
        ,FT.[assortmentGroupID]
        ,-1 [familyMemberID]
        ,-1 [stockLocationID]
        ,MAX([minimumMembersCount])[minimumMembersCount]
        ,MAX([minimumPreferredCount])[minimumPreferredCount]
        ,MAX([minimumInventory])[minimumInventory]
        ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
        ,1
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
        ON VR.[familyID] is NULL
        AND FT.[assortmentGroupID] = VR.[assortmentGroupID]
        AND FT.[displayGroupID] = VR.[displayGroupID]
    WHERE
         VR.[familyMemberID] IS NULL
         AND VR.[stockLocationID] IS NULL
    GROUP BY 
		 FT.[familyID]
		,FT.[assortmentGroupID]
    UNION
    SELECT
         FT.[familyID]
        ,FT.[assortmentGroupID]
        ,-1 [familyMemberID]
        ,-1 [stockLocationID]
        ,MAX([minimumMembersCount])[minimumMembersCount]
        ,MAX([minimumPreferredCount])[minimumPreferredCount]
        ,MAX([minimumInventory])[minimumInventory]
        ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
        ,1
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
        ON VR.[familyID] is null
        AND VR.[assortmentGroupID] is null
        AND FT.[displayGroupID] = VR.[displayGroupID]
    WHERE
         VR.[familyMemberID] IS NULL
         AND VR.[stockLocationID] IS NULL
    GROUP BY 
		 FT.[familyID]
		,FT.[assortmentGroupID]
    UNION
    SELECT
         FT.[familyID]
        ,FT.[assortmentGroupID]
        ,-1 [familyMemberID]
        ,-1 [stockLocationID]
        ,MAX([minimumMembersCount])[minimumMembersCount]
        ,MAX([minimumPreferredCount])[minimumPreferredCount]
        ,MAX([minimumInventory])[minimumInventory]
        ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
        ,1
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
        ON FT.[familyID] = VR.[familyID] 
        AND VR.[assortmentGroupID] is null
        AND VR.[displayGroupID]  is null
    WHERE
         VR.[familyMemberID] IS NULL
         AND VR.[stockLocationID] IS NULL
    GROUP BY 
		 FT.[familyID]
		,FT.[assortmentGroupID]
    UNION
    SELECT
         FT.[familyID]
        ,FT.[assortmentGroupID]
        ,-1 [familyMemberID]
        ,-1 [stockLocationID]
        ,MAX([minimumMembersCount])[minimumMembersCount]
        ,MAX([minimumPreferredCount])[minimumPreferredCount]
        ,MAX([minimumInventory])[minimumInventory]
        ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
        ,1
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
        ON FT.[familyID] = VR.[familyID] 
        AND VR.[assortmentGroupID] is null
        AND FT.[displayGroupID] = VR.[displayGroupID]
    WHERE
         VR.[familyMemberID] IS NULL
         AND VR.[stockLocationID] IS NULL
    GROUP BY 
		 FT.[familyID]
		,FT.[assortmentGroupID]
  UNION
    SELECT
           FT.[familyID]
          ,FT.[assortmentGroupID]
          ,-1 [familyMemberID]
          ,-1 [stockLocationID]
          ,MAX([minimumMembersCount])[minimumMembersCount]
          ,MAX([minimumPreferredCount])[minimumPreferredCount]
          ,MAX([minimumInventory])[minimumInventory]
          ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
          ,1
      FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
      INNER JOIN Symphony_familyTreeReducedRules FT  
          ON FT.[familyID] = VR.[familyID] 
          AND FT.[assortmentGroupID] = VR.[assortmentGroupID]
          AND VR.[displayGroupID] IS NULL
      WHERE
           VR.[familyMemberID] IS NULL
           AND VR.[stockLocationID] IS NULL
      GROUP BY 
	  	 FT.[familyID]
	  	,FT.[assortmentGroupID]
    UNION
    SELECT
           FT.[familyID]
          ,FT.[assortmentGroupID]
          ,-1 [familyMemberID]
          ,-1 [stockLocationID]
          ,MAX([minimumMembersCount])[minimumMembersCount]
          ,MAX([minimumPreferredCount])[minimumPreferredCount]
          ,MAX([minimumInventory])[minimumInventory]
          ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
          ,1
      FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
      INNER JOIN Symphony_familyTreeReducedRules FT  
          ON VR.[familyID] is null
          AND FT.[assortmentGroupID] = VR.[assortmentGroupID]
          AND VR.[displayGroupID] IS NULL
      WHERE
           VR.[familyMemberID] IS NULL
           AND VR.[stockLocationID] IS NULL
      GROUP BY 
	  	 FT.[familyID]
	  	,FT.[assortmentGroupID]
    UNION
    SELECT
         FT.[familyID]
        ,FT.[assortmentGroupID]
        ,-1 [familyMemberID]
        ,-1 [stockLocationID]
        ,MAX([minimumMembersCount])[minimumMembersCount]
        ,MAX([minimumPreferredCount])[minimumPreferredCount]
        ,MAX([minimumInventory])[minimumInventory]
        ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
        ,1
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
        ON VR.[familyID] is null
        AND VR.[assortmentGroupID] is null
        AND VR.[displayGroupID]  is null
    WHERE
         VR.[familyMemberID] IS NULL
         AND VR.[stockLocationID] IS NULL
    GROUP BY 
		 FT.[familyID]
		,FT.[assortmentGroupID]
END
GO
/****** Object:  StoredProcedure [dbo].[Symphony_spGetReducedRulesFamilyMember]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

--**********************************************************
--Get familyMember rules
--**********************************************************
CREATE PROCEDURE [dbo].[Symphony_spGetReducedRulesFamilyMember]
AS
BEGIN
    SET NOCOUNT ON;

    --**********************************************************
    --Get familyMember rules
    --**********************************************************
    INSERT INTO [dbo].[Symphony_familyTreeReducedRulesPrepare]  
    SELECT
          FT.[familyID]
         ,FT.[assortmentGroupID]
         ,FT.[familyMemberID]
         ,-1 [stockLocationID]
         ,MAX([minimumMembersCount])[minimumMembersCount]
         ,MAX([minimumPreferredCount])[minimumPreferredCount]
         ,MAX([minimumInventory])[minimumInventory]
         ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
         ,3
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
         ON FT.[familyID] = VR.[familyID]
         AND FT.[assortmentGroupID] = VR.[assortmentGroupID]
         AND FT.[displayGroupID] = VR.[displayGroupID]
	    AND FT.[familyMemberID] = VR.[familyMemberID]
    WHERE
           VR.[stockLocationID] IS NULL
    GROUP BY 
		FT.[familyID]
	     ,FT.[assortmentGroupID]
          ,FT.[familyMemberID]
    UNION
    SELECT
         FT.[familyID]
        ,FT.[assortmentGroupID]
        ,FT.[familyMemberID]
        ,-1 [stockLocationID]
        ,MAX([minimumMembersCount])[minimumMembersCount]
        ,MAX([minimumPreferredCount])[minimumPreferredCount]
        ,MAX([minimumInventory])[minimumInventory]
        ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
        ,3
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
        ON VR.[familyID] is NULL
        AND FT.[assortmentGroupID] = VR.[assortmentGroupID]
        AND FT.[displayGroupID] = VR.[displayGroupID]
	   AND FT.[familyMemberID] = VR.[familyMemberID]
    WHERE
          VR.[stockLocationID] IS NULL
    GROUP BY 
		 FT.[familyID]
	     ,FT.[assortmentGroupID]
          ,FT.[familyMemberID]
    UNION
    SELECT
         FT.[familyID]
        ,FT.[assortmentGroupID]
        ,FT.[familyMemberID]
        ,-1 [stockLocationID]
        ,MAX([minimumMembersCount])[minimumMembersCount]
        ,MAX([minimumPreferredCount])[minimumPreferredCount]
        ,MAX([minimumInventory])[minimumInventory]
        ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
        ,3
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
        ON VR.[familyID] is null
        AND VR.[assortmentGroupID] is null
        AND FT.[displayGroupID] = VR.[displayGroupID]
	      AND FT.[familyMemberID] = VR.[familyMemberID]
    WHERE
          VR.[stockLocationID] IS NULL
    GROUP BY 
		 FT.[familyID]
	     ,FT.[assortmentGroupID]
          ,FT.[familyMemberID]
    UNION
    SELECT
         FT.[familyID]
        ,FT.[assortmentGroupID]
        ,FT.[familyMemberID]
        ,-1 [stockLocationID]
        ,MAX([minimumMembersCount])[minimumMembersCount]
        ,MAX([minimumPreferredCount])[minimumPreferredCount]
        ,MAX([minimumInventory])[minimumInventory]
        ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
        ,3
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
        ON FT.[familyID] = VR.[familyID] 
        AND VR.[assortmentGroupID] is null
        AND VR.[displayGroupID]  is null
	   AND FT.[familyMemberID] = VR.[familyMemberID]
    WHERE
          VR.[stockLocationID] IS NULL
    GROUP BY 
		 FT.[familyID]
	     ,FT.[assortmentGroupID]
          ,FT.[familyMemberID]
    UNION
    SELECT
         FT.[familyID]
        ,FT.[assortmentGroupID]
        ,FT.[familyMemberID]
        ,-1 [stockLocationID]
        ,MAX([minimumMembersCount])[minimumMembersCount]
        ,MAX([minimumPreferredCount])[minimumPreferredCount]
        ,MAX([minimumInventory])[minimumInventory]
        ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
        ,3
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
        ON FT.[familyID] = VR.[familyID] 
        AND VR.[assortmentGroupID] is null
        AND FT.[displayGroupID] = VR.[displayGroupID]
	   AND FT.[familyMemberID] = VR.[familyMemberID]
    WHERE
          VR.[stockLocationID] IS NULL
    GROUP BY 
		 FT.[familyID]
	     ,FT.[assortmentGroupID]
          ,FT.[familyMemberID]
    UNION
    SELECT
           FT.[familyID]
          ,FT.[assortmentGroupID]
          ,FT.[familyMemberID]
          ,-1 [stockLocationID]
          ,MAX([minimumMembersCount])[minimumMembersCount]
          ,MAX([minimumPreferredCount])[minimumPreferredCount]
          ,MAX([minimumInventory])[minimumInventory]
          ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
          ,3
      FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
      INNER JOIN Symphony_familyTreeReducedRules FT  
          ON FT.[familyID] = VR.[familyID] 
          AND FT.[assortmentGroupID] = VR.[assortmentGroupID]
          AND VR.[displayGroupID] IS NULL
	      	AND FT.[familyMemberID] = VR.[familyMemberID]
      WHERE
           VR.[stockLocationID] IS NULL
      GROUP BY 
	  	 FT.[familyID]
	     ,FT.[assortmentGroupID]
          ,FT.[familyMemberID]
    UNION
    SELECT
           FT.[familyID]
          ,FT.[assortmentGroupID]
          ,FT.[familyMemberID]
          ,-1 [stockLocationID]
          ,MAX([minimumMembersCount])[minimumMembersCount]
          ,MAX([minimumPreferredCount])[minimumPreferredCount]
          ,MAX([minimumInventory])[minimumInventory]
          ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
          ,3
      FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
      INNER JOIN Symphony_familyTreeReducedRules FT  
          ON VR.[familyID] IS NULL
          AND FT.[assortmentGroupID] = VR.[assortmentGroupID]
          AND VR.[displayGroupID] IS NULL
	      	AND FT.[familyMemberID] = VR.[familyMemberID]
      WHERE
           VR.[stockLocationID] IS NULL
      GROUP BY 
	  	 FT.[familyID]
	     ,FT.[assortmentGroupID]
          ,FT.[familyMemberID]
    UNION
    SELECT
         FT.[familyID]
        ,FT.[assortmentGroupID]
        ,FT.[familyMemberID]
        ,-1 [stockLocationID]
        ,MAX([minimumMembersCount])[minimumMembersCount]
        ,MAX([minimumPreferredCount])[minimumPreferredCount]
        ,MAX([minimumInventory])[minimumInventory]
        ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
        ,3
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
        ON VR.[familyID] is null
        AND VR.[assortmentGroupID] is null
        AND VR.[displayGroupID]  is null
	   AND FT.[familyMemberID] = VR.[familyMemberID]
    WHERE
         VR.[stockLocationID] IS NULL
    GROUP BY 
		 FT.[familyID]
	     ,FT.[assortmentGroupID]
          ,FT.[familyMemberID]
END
GO
/****** Object:  StoredProcedure [dbo].[Symphony_spGetReducedRulesResults]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

--***************************************************
--********* Reduced rules procedures
--***************************************************
CREATE PROCEDURE [dbo].[Symphony_spGetReducedRulesResults]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  
       [familyID],
       [assortmentGroupID],
       null [familyMemberID],
       null [stockLocationID],
       MAX([minimumMembersCount])[minimumMembersCount],
       MAX([minimumPreferredCount])[minimumPreferredCount],
       MAX([minimumInventory])[minimumInventory],
       MAX([minimumPercentBufferSize])[minimumPercentBufferSize] 
    FROM 
       [dbo].[Symphony_familyTreeReducedRulesPrepare]  
    WHERE
	  [familyMemberID] = -1 AND
	  [stockLocationID] = -1
    GROUP BY 
	  [familyID],
	  [assortmentGroupID]
UNION 
    SELECT
        [familyID]
       ,[assortmentGroupID]
       ,null [familyMemberID]
       ,[stockLocationID]
       ,MAX([minimumMembersCount])[minimumMembersCount]
       ,MAX([minimumPreferredCount])[minimumPreferredCount]
       ,MAX([minimumInventory])[minimumInventory]
       ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
	FROM 
       [dbo].[Symphony_familyTreeReducedRulesPrepare]  
	WHERE
        [familyMemberID] != -1 AND
        [stockLocationID] != -1  
     GROUP BY 
        [familyID]
	  ,[assortmentGroupID]
       ,[stockLocationID]
UNION 
    SELECT
          [familyID]
         ,[assortmentGroupID]
         ,[familyMemberID]
         ,null [stockLocationID]
         ,MAX([minimumMembersCount])[minimumMembersCount]
         ,MAX([minimumPreferredCount])[minimumPreferredCount]
         ,MAX([minimumInventory])[minimumInventory]
         ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
	FROM 
       [dbo].[Symphony_familyTreeReducedRulesPrepare]  
	WHERE
           [stockLocationID] !=-1
     GROUP BY 
		[familyID]
	     ,[assortmentGroupID]
          ,[familyMemberID]
UNION 
    SELECT
          [familyID]
         ,[assortmentGroupID]
         ,[familyMemberID]
         ,[stockLocationID]
         ,MAX([minimumMembersCount])[minimumMembersCount]
         ,MAX([minimumPreferredCount])[minimumPreferredCount]
         ,MAX([minimumInventory])[minimumInventory]
         ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
	FROM 
       [dbo].[Symphony_familyTreeReducedRulesPrepare]  
	WHERE 
        [stockLocationID] !=-1
      GROUP BY
          [familyID]
	    ,[assortmentGroupID]
         ,[familyMemberID]
         ,[stockLocationID]
END 
GO
/****** Object:  StoredProcedure [dbo].[Symphony_spGetReducedRulesSL]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

--**********************************************************
--Get stockLocation specific rules
--**********************************************************
CREATE PROCEDURE [dbo].[Symphony_spGetReducedRulesSL]
AS
BEGIN
    SET NOCOUNT ON;

    --**********************************************************
    --Get stockLocation specific rules
    --**********************************************************
    INSERT INTO [dbo].[Symphony_familyTreeReducedRulesPrepare]  
    SELECT
             FT.[familyID]
            ,FT.[assortmentGroupID]
            ,-1 [familyMemberID]
            ,[stockLocationID]
            ,MAX([minimumMembersCount])[minimumMembersCount]
            ,MAX([minimumPreferredCount])[minimumPreferredCount]
            ,MAX([minimumInventory])[minimumInventory]
            ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
            ,2
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT
            ON FT.[familyID] = VR.[familyID]
            AND FT.[assortmentGroupID] = VR.[assortmentGroupID]
            AND FT.[displayGroupID] = VR.[displayGroupID]
     WHERE
            VR.[familyMemberID] IS NULL
            AND VR.[stockLocationID] IS NOT NULL
     GROUP BY 
             FT.[familyID]
	       ,FT.[assortmentGroupID]
            ,VR.[stockLocationID]
  UNION
	SELECT
             FT.[familyID]
            ,FT.[assortmentGroupID]
            ,-1 [familyMemberID]
            ,[stockLocationID]
            ,MAX([minimumMembersCount])[minimumMembersCount]
            ,MAX([minimumPreferredCount])[minimumPreferredCount]
            ,MAX([minimumInventory])[minimumInventory]
            ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
            ,2
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT
            ON VR.[familyID] is NULL
            AND FT.[assortmentGroupID] = VR.[assortmentGroupID]
            AND FT.[displayGroupID] = VR.[displayGroupID]
     WHERE
            VR.[familyMemberID] IS NULL
            AND VR.[stockLocationID] IS NOT NULL
     GROUP BY 
             FT.[familyID]
	       ,FT.[assortmentGroupID]
            ,VR.[stockLocationID]
  UNION
	SELECT
             FT.[familyID]
            ,FT.[assortmentGroupID]
            ,-1 [familyMemberID]
            ,[stockLocationID]
            ,MAX([minimumMembersCount])[minimumMembersCount]
            ,MAX([minimumPreferredCount])[minimumPreferredCount]
            ,MAX([minimumInventory])[minimumInventory]
            ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
            ,2
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT
            ON VR.[familyID] is null
            AND VR.[assortmentGroupID] is null
            AND FT.[displayGroupID] = VR.[displayGroupID]
     WHERE
            VR.[familyMemberID] IS NULL
            AND VR.[stockLocationID] IS NOT NULL
     GROUP BY 
             FT.[familyID]
	       ,FT.[assortmentGroupID]
            ,VR.[stockLocationID]
  UNION
	SELECT
             FT.[familyID]
            ,FT.[assortmentGroupID]
            ,-1 [familyMemberID]
            ,[stockLocationID]
            ,MAX([minimumMembersCount])[minimumMembersCount]
            ,MAX([minimumPreferredCount])[minimumPreferredCount]
            ,MAX([minimumInventory])[minimumInventory]
            ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
            ,2
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT
            ON FT.[familyID] = VR.[familyID] 
            AND VR.[assortmentGroupID] is null
            AND VR.[displayGroupID]  is null
     WHERE
            VR.[familyMemberID] IS NULL
            AND VR.[stockLocationID] IS NOT NULL
     GROUP BY 
             FT.[familyID]
	       ,FT.[assortmentGroupID]
            ,VR.[stockLocationID]
  UNION
	SELECT
             FT.[familyID]
            ,FT.[assortmentGroupID]
            ,-1 [familyMemberID]
            ,[stockLocationID]
            ,MAX([minimumMembersCount])[minimumMembersCount]
            ,MAX([minimumPreferredCount])[minimumPreferredCount]
            ,MAX([minimumInventory])[minimumInventory]
            ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
            ,2
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT
             ON FT.[familyID] = VR.[familyID] 
             AND VR.[assortmentGroupID] is null
             AND FT.[displayGroupID] = VR.[displayGroupID]
     WHERE
            VR.[familyMemberID] IS NULL
            AND VR.[stockLocationID] IS NOT NULL
     GROUP BY 
             FT.[familyID]
	       ,FT.[assortmentGroupID]
            ,VR.[stockLocationID]
  UNION
	SELECT
             FT.[familyID]
            ,FT.[assortmentGroupID]
            ,-1 [familyMemberID]
            ,[stockLocationID]
            ,MAX([minimumMembersCount])[minimumMembersCount]
            ,MAX([minimumPreferredCount])[minimumPreferredCount]
            ,MAX([minimumInventory])[minimumInventory]
            ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
            ,2
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT
             ON FT.[familyID] = VR.[familyID] 
             AND FT.[assortmentGroupID] = VR.[assortmentGroupID]
             AND VR.[displayGroupID] IS NULL
     WHERE
            VR.[familyMemberID] IS NULL
            AND VR.[stockLocationID] IS NOT NULL
     GROUP BY 
             FT.[familyID]
	       ,FT.[assortmentGroupID]
            ,VR.[stockLocationID]
  UNION
  SELECT
             FT.[familyID]
            ,FT.[assortmentGroupID]
            ,-1 [familyMemberID]
            ,[stockLocationID]
            ,MAX([minimumMembersCount])[minimumMembersCount]
            ,MAX([minimumPreferredCount])[minimumPreferredCount]
            ,MAX([minimumInventory])[minimumInventory]
            ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
            ,2
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT
             ON VR.[familyID] IS NULL
             AND FT.[assortmentGroupID] = VR.[assortmentGroupID]
             AND VR.[displayGroupID] IS NULL
     WHERE
            VR.[familyMemberID] IS NULL
            AND VR.[stockLocationID] IS NOT NULL
     GROUP BY 
             FT.[familyID]
	       ,FT.[assortmentGroupID]
            ,VR.[stockLocationID]
  UNION
	SELECT
             FT.[familyID]
            ,FT.[assortmentGroupID]
            ,-1 [familyMemberID]
            ,[stockLocationID]
            ,MAX([minimumMembersCount])[minimumMembersCount]
            ,MAX([minimumPreferredCount])[minimumPreferredCount]
            ,MAX([minimumInventory])[minimumInventory]
            ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
            ,2
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT
             ON VR.[familyID] is null
             AND VR.[assortmentGroupID] is null
             AND VR.[displayGroupID]  is null
     WHERE
            VR.[familyMemberID] IS NULL
            AND VR.[stockLocationID] IS NOT NULL
     GROUP BY 
             FT.[familyID]
	       ,FT.[assortmentGroupID]
            ,VR.[stockLocationID]
END
GO
/****** Object:  StoredProcedure [dbo].[Symphony_spGetReducedRulesSLFamilyMember]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

--**********************************************************
--Get stockLocation specific familyMember rules
--**********************************************************
CREATE PROCEDURE [dbo].[Symphony_spGetReducedRulesSLFamilyMember]
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [dbo].[Symphony_familyTreeReducedRulesPrepare]  
    SELECT
          FT.[familyID]
         ,FT.[assortmentGroupID]
         ,FT.[familyMemberID]
         ,[stockLocationID]
         ,MAX([minimumMembersCount])[minimumMembersCount]
         ,MAX([minimumPreferredCount])[minimumPreferredCount]
         ,MAX([minimumInventory])[minimumInventory]
         ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
         ,4
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
         ON FT.[familyID] = VR.[familyID]
         AND FT.[assortmentGroupID] = VR.[assortmentGroupID]
         AND FT.[displayGroupID] = VR.[displayGroupID]
	    AND FT.[familyMemberID] = VR.[familyMemberID]
    WHERE 
        VR.[stockLocationID] IS NOT NULL
      GROUP BY
          FT.[familyID]
	    ,FT.[assortmentGroupID]
         ,FT.[familyMemberID]
         ,VR.[stockLocationID]
    UNION
    SELECT
         FT.[familyID]
        ,FT.[assortmentGroupID]
        ,FT.[familyMemberID]
        ,[stockLocationID]
        ,MAX([minimumMembersCount])[minimumMembersCount]
        ,MAX([minimumPreferredCount])[minimumPreferredCount]
        ,MAX([minimumInventory])[minimumInventory]
        ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
        ,4
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
        ON VR.[familyID] is NULL
        AND FT.[assortmentGroupID] = VR.[assortmentGroupID]
        AND FT.[displayGroupID] = VR.[displayGroupID]
	   AND FT.[familyMemberID] = VR.[familyMemberID]
    WHERE 
        VR.[stockLocationID] IS NOT NULL
      GROUP BY
          FT.[familyID]
	    ,FT.[assortmentGroupID]
         ,FT.[familyMemberID]
         ,VR.[stockLocationID]
    UNION
    SELECT
         FT.[familyID]
        ,FT.[assortmentGroupID]
        ,FT.[familyMemberID]
        ,[stockLocationID]
        ,MAX([minimumMembersCount])[minimumMembersCount]
        ,MAX([minimumPreferredCount])[minimumPreferredCount]
        ,MAX([minimumInventory])[minimumInventory]
        ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
        ,4
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
        ON VR.[familyID] is null
        AND VR.[assortmentGroupID] is null
        AND FT.[displayGroupID] = VR.[displayGroupID]
	   AND FT.[familyMemberID] = VR.[familyMemberID]
    WHERE 
        VR.[stockLocationID] IS NOT NULL
      GROUP BY
          FT.[familyID]
	    ,FT.[assortmentGroupID]
         ,FT.[familyMemberID]
         ,VR.[stockLocationID]
    UNION
    SELECT
         FT.[familyID]
        ,FT.[assortmentGroupID]
        ,FT.[familyMemberID]
        ,[stockLocationID]
        ,MAX([minimumMembersCount])[minimumMembersCount]
        ,MAX([minimumPreferredCount])[minimumPreferredCount]
        ,MAX([minimumInventory])[minimumInventory]
        ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
        ,4
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
        ON FT.[familyID] = VR.[familyID] 
        AND VR.[assortmentGroupID] is null
        AND VR.[displayGroupID]  is null
	   AND FT.[familyMemberID] = VR.[familyMemberID]
    WHERE 
        VR.[stockLocationID] IS NOT NULL
      GROUP BY
          FT.[familyID]
	    ,FT.[assortmentGroupID]
         ,FT.[familyMemberID]
         ,VR.[stockLocationID]
    UNION
    SELECT
         FT.[familyID]
        ,FT.[assortmentGroupID]
        ,FT.[familyMemberID]
        ,[stockLocationID]
        ,MAX([minimumMembersCount])[minimumMembersCount]
        ,MAX([minimumPreferredCount])[minimumPreferredCount]
        ,MAX([minimumInventory])[minimumInventory]
        ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
        ,4
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
        ON FT.[familyID] = VR.[familyID] 
        AND VR.[assortmentGroupID] is null
        AND FT.[displayGroupID] = VR.[displayGroupID]
	   AND FT.[familyMemberID] = VR.[familyMemberID]
    WHERE 
        VR.[stockLocationID] IS NOT NULL
      GROUP BY
          FT.[familyID]
	    ,FT.[assortmentGroupID]
         ,FT.[familyMemberID]
         ,VR.[stockLocationID]
  UNION
    SELECT
           FT.[familyID]
          ,FT.[assortmentGroupID]
          ,FT.[familyMemberID]
          ,[stockLocationID]
          ,MAX([minimumMembersCount])[minimumMembersCount]
          ,MAX([minimumPreferredCount])[minimumPreferredCount]
          ,MAX([minimumInventory])[minimumInventory]
          ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
          ,4
      FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
      INNER JOIN Symphony_familyTreeReducedRules FT  
          ON FT.[familyID] = VR.[familyID] 
          AND FT.[assortmentGroupID] = VR.[assortmentGroupID]
          AND VR.[displayGroupID] IS NULL
		AND FT.[familyMemberID] = VR.[familyMemberID]
      WHERE 
        VR.[stockLocationID] IS NOT NULL
      GROUP BY
          FT.[familyID]
	    ,FT.[assortmentGroupID]
         ,FT.[familyMemberID]
         ,VR.[stockLocationID]
    UNION
    SELECT
           FT.[familyID]
          ,FT.[assortmentGroupID]
          ,FT.[familyMemberID]
          ,[stockLocationID]
          ,MAX([minimumMembersCount])[minimumMembersCount]
          ,MAX([minimumPreferredCount])[minimumPreferredCount]
          ,MAX([minimumInventory])[minimumInventory]
          ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
          ,4
      FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
      INNER JOIN Symphony_familyTreeReducedRules FT  
          ON VR.[familyID] IS NULL
          AND FT.[assortmentGroupID] = VR.[assortmentGroupID]
          AND VR.[displayGroupID] IS NULL
		      AND FT.[familyMemberID] = VR.[familyMemberID]
      WHERE 
        VR.[stockLocationID] IS NOT NULL
      GROUP BY
          FT.[familyID]
	    ,FT.[assortmentGroupID]
         ,FT.[familyMemberID]
         ,VR.[stockLocationID]
    UNION
    SELECT
         FT.[familyID]
        ,FT.[assortmentGroupID]
        ,FT.[familyMemberID]
        ,[stockLocationID]
        ,MAX([minimumMembersCount])[minimumMembersCount]
        ,MAX([minimumPreferredCount])[minimumPreferredCount]
        ,MAX([minimumInventory])[minimumInventory]
        ,MAX([minimumPercentBufferSize])[minimumPercentBufferSize]
        ,4
    FROM [dbo].[Symphony_SkuFamiliesValidationRules] VR
    INNER JOIN Symphony_familyTreeReducedRules FT  
        ON VR.[familyID] is null
        AND VR.[assortmentGroupID] is null
        AND VR.[displayGroupID]  is null
	   AND FT.[familyMemberID] = VR.[familyMemberID]
    WHERE 
        VR.[stockLocationID] IS NOT NULL
    GROUP BY
          FT.[familyID]
	    ,FT.[assortmentGroupID]
         ,FT.[familyMemberID]
         ,VR.[stockLocationID]
END
GO
/****** Object:  StoredProcedure [dbo].[Symphony_spHandleISTComplianceHistory]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
/*****  IS EXECUTED AFTER THE LOAD & RECALCULATE *****/
CREATE PROCEDURE [dbo].[Symphony_spHandleISTComplianceHistory]
AS
BEGIN
	INSERT INTO [Symphony_ISTComplianceHistory](
		   [orderID]
		  ,[stockLocationID]
		  ,[supplierID]
		  ,[skuID]
		  ,[quantity]
		  ,[orderPrice]
		  ,[orderDate]
		  ,[promisedDueDate]
		  ,[purchasingPropertyID1]
		  ,[purchasingPropertyID2]
		  ,[purchasingPropertyID3]
		  ,[purchasingPropertyID4]
		  ,[purchasingPropertyID5]
		  ,[purchasingPropertyID6]
		  ,[purchasingPropertyID7]
		  ,[closeDate]
		  ,[completionDate]
		  ,[unitsReceived]
		  ,[statusCode])
	SELECT OLD.orderID, 
		   OLD.stockLocationID, 
		   OLD.supplierID,
		   OLD.skuID,
		   OLD.quantity,
		   OLD.orderPrice,
		   OLD.orderDate,
		   OLD.promisedDueDate,
		   OLD.purchasingPropertyID1,
		   OLD.purchasingPropertyID2,
		   OLD.purchasingPropertyID3,
		   OLD.purchasingPropertyID4,
		   OLD.purchasingPropertyID5,
		   OLD.purchasingPropertyID6,
		   OLD.purchasingPropertyID7,
		   GETDATE(),
		   NULL,
		   0,
		   NULL 
	FROM 
	Symphony_PurchasingOrderPrev OLD Left Join Symphony_PurchasingOrder NEW
	ON OLD.orderID = NEW.orderID
	WHERE OLD.isISTOrder = 1 AND NEW.orderID IS NULL

END

GO
/****** Object:  StoredProcedure [dbo].[Symphony_spMtoSkuHistory]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Symphony_spMtoSkuHistory]
        @stockLocationID INT=-1,
        @updateDate smalldatetime=null, 
        @yesterday smalldatetime=null,
        @doUpdateSkuTable bit=0
AS
BEGIN

    IF (@stockLocationID = -1 or @updateDate is null)
        return

        INSERT INTO Symphony_MTOSkusHistory(skuID, stockLocationID, 
        inventoryAtSite, totalIn, consumption, updateDate, inventoryAtTransit, inventoryAtProduction,
        unitPrice, throughput, tvc, tempInventoryAtSite,
        worstInventoryAtSite, avgInventoryAtSite, inventoryAtSiteUpdatesNum, isDuplicatedRow)
        
        SELECT skuID, @stockLocationID, inventoryAtSite, 0  as totalIn, 0 as consumption, @updateDate,
        inventoryAtTransit, inventoryAtProduction, unitPrice, throughput, tvc, inventoryAtSite as tempInventoryAtSite,
    inventoryAtSite as WorstInventoryAtSite, inventoryAtSite as avgInventoryAtSite ,1, 1
        
        FROM Symphony_MTOSkusHistory S WITH(NOLOCK)
        WHERE S.isDeleted = 0
        AND S.stockLocationID=@stockLocationID
        AND updateDate = @yesterday
        AND not exists (select 1 from Symphony_MTOSkusHistory
                                where skuID = S.skuID and
                                stockLocationID = S.stockLocationID and
                                updateDate = @updateDate)

    IF (@doUpdateSkuTable = 1)
    BEGIN
        update Symphony_MTOSkus set updateDate = @updateDate, totalIN = 0, consumption = 0
         WHERE Symphony_MTOSkus.stockLocationID=@stockLocationID
                and Symphony_MTOSkus.updateDate < @updateDate
    END

END
GO
/****** Object:  StoredProcedure [dbo].[Symphony_spMTOSkusToPurchaseData]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[Symphony_spMTOSkusToPurchaseData] 

AS
BEGIN
       -- SET NOCOUNT ON added to prevent extra result sets from
        -- interfering with SELECT statements.
        SET NOCOUNT ON;

   
        DECLARE @WOEXTENDED TABLE (woID nvarchar(100) NOT NULL
				,clientOrderID nvarchar(50)
                ,skuID INT NOT NULL
                ,plantID INT NOT NULL
                ,dueDate smalldatetime
                ,quantity decimal(18,5)
                ,bufferSize decimal(18,5)
                ,tractionHorizon int NULL
                ,materialReleaseActualDate smalldatetime
                ,materialReleaseScheduledDate smalldatetime)

        INSERT INTO @WOEXTENDED
                        SELECT 
                                WO.woid
                                ,WO.clientOrderID
                                ,WO.skuID
                                ,WO.plantID
                                ,WO.dueDate
                                ,WO.quantity
                                ,ISNULL(WO.bufferSize,CAST(PF.bufferSize as decimal(18,5))) AS bufferSize
                                ,CCR.tractionHorizon
                                ,WO.materialReleaseActualDate
                                ,WO.materialReleaseScheduledDate

                        FROM 
                          Symphony_WorkOrders WO
                          INNER JOIN Symphony_SKUs MSKU ON WO.componentID = '' 
                                                                                                AND WO.isPhantom = 0 
                                                                                                AND WO.orderType != 1 
                                                                                                AND WO.materialReleaseActualDate IS NULL 
                                                                                                AND MSKU.skuID = WO.skuID
                          LEFT JOIN Symphony_StockLocationSkusProductionData SLSPD ON SLSPD.stockLocationID = WO.plantID AND SLSPD.skuID = MSKU.skuID
                          LEFT JOIN Symphony_ProductionFamilies PF ON PF.ID = SLSPD.productionFamily
                          LEFT JOIN Symphony_CCRs CCR ON CCR.plantID = WO.plantID AND CCR.ID = PF.flowDictatorID

        DECLARE @CANDIDATES TABLE (
                ID int IDENTITY(1,1)
                ,woID nvarchar(100) NOT NULL
                ,clientOrderID nvarchar(50)
                ,plantID INT NOT NULL
                ,dueDate smalldatetime
                ,bufferSize decimal(18,5) NULL
                ,tractionHorizon int NULL
                ,materialReleaseActualDate smalldatetime
                ,materialReleaseScheduledDate smalldatetime
                ,quantityNeeded decimal(18,5)
                ,skuID INT NOT NULL
                ,skuName nvarchar(100) NOT NULL
                ,supplierID INT
                ,stockLocationID INT
                ,supplierLeadTime int NOT NULL
                ,timeProtection int NOT NULL
                ,quantityProtection decimal(18,5) NOT NULL
                ,minimumOrderQuantity decimal(18,5) NOT NULL
                ,orderMultiplications decimal(18,5) NOT NULL
                ,lastBatchReplenishment decimal(18,5) NOT NULL
                ,additionalTimeTillArrival int NOT NULL
                ,supplierSKUName nvarchar(100)
                ,mlSlID INT NOT NULL)

        -- Fill temporary table
        INSERT INTO @CANDIDATES
                SELECT 
                        WO.woid
                        ,WO.clientOrderID
                        ,WO.plantID
                        ,WO.dueDate
                        ,WO.bufferSize
                        ,WO.tractionHorizon
                        ,WO.materialReleaseActualDate
                        ,WO.materialReleaseScheduledDate
                        ,BOM.quantity * WO.quantity
                        ,BOM.skuID
                        ,PD.skuName
                        ,PD.supplierID
                        ,PD.stockLocationID
                        ,PD.supplierLeadTime
                        ,PD.timeProtection
                        ,PD.quantityProtection
                        ,PD.minimumOrderQuantity
                        ,PD.orderMultiplications
                        ,PD.lastBatchReplenishment
                        ,PD.additionalTimeTillArrival
                        ,PD.supplierSKUName
                        ,ml.stockLocationID
                FROM 
                  @WOEXTENDED WO
                  INNER JOIN Symphony_SkusBom BOM ON WO.plantID = BOM.plantID AND WO.skuID = BOM.masterSkuID
                  INNER JOIN Symphony_MaterialsStockLocations ML ON BOM.plantID = ML.plantID AND (BOM.skuID = ML.skuID OR ML.skuID = -1)
                  INNER JOIN Symphony_SKUs SKU ON BOM.skuID = SKU.skuID
                  INNER JOIN Symphony_SkuProcurementData PD ON SKU.skuName = PD.skuName AND PD.stockLocationID = ML.stockLocationID AND PD.isDefaultSupplier = 1
                --WHERE
                  --NOT EXISTS (SELECT skuID FROM Symphony_StockLocationSkus WHERE isDeleted = 0 AND skuID = BOM.skuID AND stockLocationID = ML.stockLocationID)
                  --AND NOT EXISTS (SELECT ID FROM Symphony_PurchasingRecommendation WHERE woid = WO.woid AND skuID = BOM.skuID AND stockLocationID = ML.stockLocationID AND (isAwaitsConfirmation = 1 OR isConfirmed = 1 OR isDeleted = 1))
                --ORDER BY WO.woid, WO.plantID, SKU.skuName, ML.skuID DESC

        -- Remove duplicates resulting from multiple matches in the MaterialsStockLocations table
        SELECT * FROM @CANDIDATES C1
                WHERE C1.ID = (SELECT TOP 1 C2.ID FROM @CANDIDATES C2 WHERE C1.woID = C2.woID AND C1.plantID = C2.plantID AND C1.skuID = C2.skuID) and
            NOT EXISTS (SELECT skuID FROM Symphony_StockLocationSkus WHERE isDeleted = 0 AND skuID = C1.skuID AND stockLocationID = c1.stockLocationID) and
            NOT EXISTS (SELECT ID FROM Symphony_PurchasingRecommendation WHERE woid = c1.woid AND skuID = c1.skuID AND stockLocationID = c1.mlSlID AND (isAwaitsConfirmation = 1 OR isConfirmed = 1 OR isDeleted = 1))
        ORDER BY c1.woid, c1.plantID, c1.skuName, c1.skuID DESC

END

IF OBJECT_ID('dbo.Symphony_spMTOSkusToPurchaseData') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.Symphony_spMTOSkusToPurchaseData >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.Symphony_spMTOSkusToPurchaseData >>>'
GO
/****** Object:  StoredProcedure [dbo].[Symphony_spMTOSkuToPurchaseData]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[Symphony_spMTOSkuToPurchaseData] 
        @woID NVarChar(50),
        @skuID INT,
        @supplierID INT

AS
BEGIN
        -- SET NOCOUNT ON added to prevent extra result sets from
        -- interfering with SELECT statements.
        SET NOCOUNT ON;

    -- Insert statements for procedure here
        -- Create a temporary table 

        DECLARE @WOEXTENDED TABLE (woID nvarchar(100) NOT NULL
				,clientOrderID nvarchar(50)
                ,skuID INT NOT NULL
                ,plantID INT NOT NULL
                ,dueDate smalldatetime
                ,quantity decimal(18,5)
                ,bufferSize decimal(18,5) NULL
                ,tractionHorizon int NULL
                ,materialReleaseActualDate smalldatetime
                ,materialReleaseScheduledDate smalldatetime)

        INSERT INTO @WOEXTENDED
                        SELECT 
                                WO.woid
								,WO.clientOrderID
                                ,WO.skuID
                                ,WO.plantID
                                ,WO.dueDate
                                ,WO.quantity
                                ,ISNULL(WO.bufferSize,CAST(PF.bufferSize as decimal(18,5))) AS bufferSize
                                ,CCR.tractionHorizon
                                ,WO.materialReleaseActualDate
                                ,WO.materialReleaseScheduledDate

                        FROM 
                          Symphony_WorkOrders WO
                          INNER JOIN Symphony_SKUs MSKU 
                                ON WO.woid = @woId
                                AND WO.componentID = '' 
                                AND WO.isPhantom = 0 
                                AND WO.orderType != 1 
                                AND WO.materialReleaseActualDate IS NULL 
                                AND MSKU.skuID = WO.skuID
                          LEFT JOIN Symphony_StockLocationSkusProductionData SLSPD ON SLSPD.stockLocationID = WO.plantID AND SLSPD.skuID = MSKU.skuID
                          LEFT JOIN Symphony_ProductionFamilies PF ON PF.ID = SLSPD.productionFamily
                          LEFT JOIN Symphony_CCRs CCR ON CCR.plantID = WO.plantID AND CCR.ID = PF.flowDictatorID

        DECLARE @CANDIDATES TABLE (
                ID int IDENTITY(1,1)
                ,woID nvarchar(100) NOT NULL
				,clientOrderID nvarchar(50)
                ,plantID INT NOT NULL
                ,dueDate smalldatetime
                ,bufferSize decimal(18,5) NULL
                ,tractionHorizon int NULL
                ,materialReleaseActualDate smalldatetime
                ,materialReleaseScheduledDate smalldatetime
                ,quantityNeeded decimal(18,5)
                ,skuID INT NOT NULL
                ,skuName nvarchar(100) NOT NULL
                ,supplierID INT
                ,stockLocationID INT
                ,supplierLeadTime int NOT NULL
                ,timeProtection int NOT NULL
                ,quantityProtection decimal(18,5) NOT NULL
                ,minimumOrderQuantity decimal(18,5) NOT NULL
                ,orderMultiplications decimal(18,5) NOT NULL
                ,lastBatchReplenishment decimal(18,5) NOT NULL
                ,additionalTimeTillArrival int NOT NULL
                ,supplierSKUName nvarchar(100))

        -- Fill temporary table
        INSERT INTO @CANDIDATES
                SELECT 
                        WO.woid
						,WO.clientOrderID
                        ,WO.plantID
                        ,WO.dueDate
                        ,WO.bufferSize
                        ,WO.tractionHorizon
                        ,WO.materialReleaseActualDate
                        ,WO.materialReleaseScheduledDate
                        ,BOM.quantity * WO.quantity
                        ,BOM.skuID
                        ,PD.skuName
                        ,PD.supplierID
                        ,PD.stockLocationID
                        ,PD.supplierLeadTime
                        ,PD.timeProtection
                        ,PD.quantityProtection
                        ,PD.minimumOrderQuantity
                        ,PD.orderMultiplications
                        ,PD.lastBatchReplenishment
                        ,PD.additionalTimeTillArrival
                        ,PD.supplierSKUName

                FROM 
                  @WOEXTENDED WO
                  INNER JOIN Symphony_SkusBom BOM ON BOM.skuID = @skuID AND WO.plantID = BOM.plantID AND WO.skuID = BOM.masterSkuID
                  INNER JOIN Symphony_MaterialsStockLocations ML ON BOM.plantID = ML.plantID AND (BOM.skuID = ML.skuID OR ML.skuID = -1)
                  INNER JOIN Symphony_SKUs SKU ON BOM.skuID = SKU.skuID
                  INNER JOIN Symphony_SkuProcurementData PD ON SKU.skuName = PD.skuName AND PD.stockLocationID = ML.stockLocationID AND PD.supplierID = @supplierID
                WHERE
                  NOT EXISTS (SELECT skuID FROM Symphony_StockLocationSkus WHERE isDeleted = 0 AND skuID = BOM.skuID AND stockLocationID = ML.stockLocationID)
                  AND NOT EXISTS (SELECT ID FROM Symphony_PurchasingRecommendation WHERE woid = WO.woid AND skuID = BOM.skuID AND stockLocationID = ML.stockLocationID 
                  AND (isConfirmed = 1 OR isDeleted = 1))
                ORDER BY WO.woid, WO.plantID, SKU.skuName, ML.skuID DESC

        -- Remove duplicates resulting from multiple matches in the MaterialsStockLocations table
        SELECT * FROM @CANDIDATES C1
                WHERE C1.ID = (SELECT TOP 1 C2.ID FROM @CANDIDATES C2 WHERE C1.woID = C2.woID AND C1.plantID = C2.plantID AND C1.skuID = C2.skuID)

END

IF OBJECT_ID('dbo.Symphony_spMTOSkuToPurchaseData') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.Symphony_spMTOSkuToPurchaseData >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.Symphony_spMTOSkuToPurchaseData >>>'
GO
/****** Object:  StoredProcedure [dbo].[Symphony_spProcurementMatching]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO


CREATE PROCEDURE [dbo].[Symphony_spProcurementMatching] 
        -- Add the parameters for the stored procedure here
AS
BEGIN
        -- SET NOCOUNT ON added to prevent extra result sets from
        -- interfering with SELECT statements.
        SET NOCOUNT ON;

	DECLARE @AllMatches TABLE(
		 [id] int IDENTITY(1,1)
		,[OrderID] [int]
		,[RecommendationID] [int]
	);

	DECLARE @MatchedRecommendations TABLE
	(
		[RecommendationID] int
	)
	
	DECLARE @Matches as TABLE(
		 [OrderID] [int]
		,[RecommendationID] [int]
	);

	-- orders
	INSERT INTO @AllMatches
	SELECT
		 PO.ID
		,PR.ID 
	FROM [dbo].[Symphony_PurchasingOrder] PO
	INNER JOIN [dbo].[Symphony_PurchasingRecommendation] PR
	ON PO.clientOrderID = PR.clientOrderID

	INSERT INTO @AllMatches
	SELECT
		 PO.ID
		,PR.ID 
	FROM [dbo].[Symphony_PurchasingOrder] PO
	INNER JOIN [dbo].[Symphony_PurchasingRecommendation] PR
	ON	PR.isDeleted = 0
		AND PO.isToOrder = 1  
		AND PO.needsMatch = 1
		AND PO.skuID = PR.skuID
		AND PO.stockLocationID = PR.stockLocationID
		AND DATEDIFF(DAY, PO.neededDate,PR.needDate) = 0
		AND PO.quantity BETWEEN 0.95 * PR.quantity AND 1.05 * PR.quantity
   where not exists (select PO.ID from @AllMatches a where a.[OrderID] = PO.ID)

	--Stock
	INSERT INTO @AllMatches
	SELECT
		 PO.ID
		,PR.ID 
		--,1
	FROM [dbo].[Symphony_PurchasingOrder] PO
		INNER JOIN [dbo].[Symphony_PurchasingRecommendation] PR ON 
		PO.isToOrder = 0  
		AND PO.needsMatch = 1
		AND PO.skuID = PR.skuID
		AND PO.stockLocationID = PR.stockLocationID
    where not exists (select PO.ID from @AllMatches a where a.[OrderID] = PO.ID)

	DECLARE 
		 @id int
		,@prID int
		,@poID int
		,@maxID int;
		
	SELECT @id = 1, @maxID = COUNT(1) FROM @AllMatches

	WHILE @id <= @maxID
	BEGIN
		SELECT @poID = [orderID], @prID = [RecommendationID] FROM @AllMatches WHERE [id] = @id;
		IF NOT EXISTS( SELECT [RecommendationID] FROM @MatchedRecommendations WHERE [RecommendationID] = @prID)
			BEGIN
				INSERT INTO @Matches SELECT @poID, @prID
				INSERT INTO @MatchedRecommendations SELECT @prID
			END
		SELECT @id = @id + 1	
	END

	UPDATE PO
		SET needsMatch = 0
    FROM [dbo].[Symphony_PurchasingOrder] PO
    INNER JOIN @Matches MPO 
		ON PO.ID = MPO.OrderID 
    WHERE PO.needsMatch = 1 

	UPDATE PR
		SET isConfirmed = 1
	FROM [dbo].[Symphony_PurchasingRecommendation] PR
	INNER JOIN @Matches MPO 
		ON PR.ID = MPO.RecommendationID 
	WHERE PR.orderType = 0

	DELETE FROM PR
    FROM [dbo].[Symphony_PurchasingRecommendation] PR
    INNER JOIN @Matches MPO
		ON PR.ID = MPO.RecommendationID 
    WHERE PR.orderType = 1
END
GO
/****** Object:  StoredProcedure [dbo].[Symphony_spRebuildIndexes]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[Symphony_spRebuildIndexes]
   @dbName nvarchar(100) 
AS
BEGIN
   SET NOCOUNT ON;
   SET QUOTED_IDENTIFIER OFF;
	  
	 DECLARE @Table NVARCHAR(255)  
	 DECLARE @cmd NVARCHAR(500)  
	 DECLARE @fillfactor INT 
	 
	 DECLARE @frag float = 0
	 DECLARE @buildCMD NVARCHAR(500)
	 DECLARE @buildCMD_online NVARCHAR(500)
	 DECLARE @indexname NVARCHAR(1000)
	 DECLARE @objectid int;  
	 DECLARE @indexid int;  
	  
	 DECLARE @msg NVARCHAR(1000)
	 DECLARE @msgOUT NVARCHAR(1000)
	
	 DECLARE @t1 DATETIME;
	 DECLARE @t2 DATETIME;
	 DECLARE @rebuildONLINE bit;

   SET @fillfactor = 90 
   SET @rebuildONLINE = 0

   IF (object_id( 'tempdb..#ISIndexList' ) IS NOT NULL)
     DROP TABLE ..#ISIndexList
   
   --Create temp indexes table
   SELECT 
      OBJECT_NAME(ind.OBJECT_ID) as tbl, indexstats.object_id AS objectid, indexstats.index_id AS indexid, indexstats.avg_fragmentation_in_percent as frag
   INTO 
      #ISIndexList  
   FROM 
      sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) indexstats INNER JOIN 
	    sys.indexes ind ON ind.object_id = indexstats.object_id AND ind.index_id = indexstats.index_id 
   WHERE 
      ind.index_id > 0 and 
	    indexstats.avg_fragmentation_in_percent > 10
  
  DECLARE TableCursor CURSOR FOR SELECT tbl as tableName, objectid, indexid, frag FROM #ISIndexList

  OPEN TableCursor   
  
  FETCH NEXT FROM TableCursor INTO @Table, @objectid, @indexid, @frag   
  WHILE @@FETCH_STATUS = 0   
  BEGIN   
     set @msg = @table
	   set @Table = @dbName + '.dbo.' + @Table

	   SELECT @indexname = QUOTENAME(name) FROM sys.indexes WHERE  object_id = @objectid AND index_id = @indexid;  
	   
	   if (@frag>=30)
	   begin
		    set @msg = @msg + ': REBUILD ' + @indexname
		    set @buildCMD = ' REBUILD WITH (ONLINE = OFF, FILLFACTOR = ' + CONVERT(VARCHAR(3),@fillfactor) + ')'
		    set @buildCMD_online = ' REBUILD WITH (ONLINE = ON, FILLFACTOR = ' + CONVERT(VARCHAR(3),@fillfactor) + ')'
	   end
	   else
	   begin
		    set @msg = @msg + ': REORGANIZE ' + @indexname
		    set @buildCMD_online = ' REORGANIZE WITH ( LOB_COMPACTION = ON )'
	   end

	   SET @t1 = GETDATE();
	   BEGIN TRY 
		   SET @msgOUT = @msg + ' (ONLINE)'
		   if (@rebuildONLINE = 0)
		   begin
		   	   SET @cmd = 'SET QUOTED_IDENTIFIER ON; ALTER INDEX ' + @indexname + ' ON ' + @Table + @buildCMD
		   end
		   else	
		   begin
		      SET @cmd = 'SET QUOTED_IDENTIFIER ON; ALTER INDEX ' + @indexname + ' ON ' + @Table + @buildCMD_online 
		   end
		   EXEC (@cmd)  
	   END TRY
	   BEGIN CATCH
		   SET @msgOUT = @msg + ' (OFFLINE)'
		   SET @cmd = 'SET QUOTED_IDENTIFIER ON; ALTER INDEX ' + @indexname +' ON ' + @Table + @buildCMD
		   EXEC (@cmd)  
	   END CATCH


	   SET @t2 = GETDATE();
	   --print @msgOUT + ' - duration: ' + cast(DATEDIFF(millisecond,@t1,@t2) as nvarchar(200)) + 'ms';
	   
     FETCH NEXT FROM TableCursor INTO @Table, @objectid, @indexid, @frag 
  END   

  CLOSE TableCursor   
  DEALLOCATE TableCursor  

  DROP TABLE #ISIndexList  
  
  SET QUOTED_IDENTIFIER OFF
END
GO
/****** Object:  StoredProcedure [dbo].[Symphony_spSalesOrderPastDueDate]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[Symphony_spSalesOrderPastDueDate]
AS
    BEGIN

                CREATE TABLE #countSalesOrder(
                        saleOrderID nvarchar(50) COLLATE database_default,
                        counter int)

                INSERT INTO #countSalesOrder
                select saleOrderID,count(*) as counter
                from Symphony_WorkOrders
                where   dueDate <= getdate() AND
                                saleOrderID IS NOT NULL AND
                                (LOWER(saleOrderID) NOT IN ('','0','null')) AND
                                orderType!=1
                group by saleOrderID

                select count(*) from #countSalesOrder

                drop table #countSalesOrder
    END
GO
/****** Object:  StoredProcedure [dbo].[Symphony_spSetChangeTriggersEnabled]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[Symphony_spSetChangeTriggersEnabled]
	 @ENABLED bit
	,@UPDATE_LAST_CHANGE_DATE bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	--Get trigger/table name pairs
	DECLARE @PARAMETERS AS TABLE([ID] [int] IDENTITY (0,1),[tableName] [nvarchar](100), [triggerName] [nvarchar](150))
	
	INSERT INTO @PARAMETERS
		SELECT [tableName], [triggerName] 
		FROM [dbo].[Symphony_DataChanged]
		
	DECLARE
		 @COUNT int
		,@INDEX int
		,@TABLE_NAME NVARCHAR(100)
		,@TRIGGER_NAME NVARCHAR(150)
		
	SELECT @COUNT = COUNT(1), @INDEX = 0 FROM @PARAMETERS;
	
	WHILE @INDEX < @COUNT
	BEGIN
	
		SELECT @TABLE_NAME = [tableName], @TRIGGER_NAME = [triggerName] 
			FROM @PARAMETERS
			WHERE [ID] = @INDEX
		
		IF @ENABLED = 0
			EXECUTE('DISABLE TRIGGER [dbo].[' + @TRIGGER_NAME + '] ON [dbo].[' + @TABLE_NAME + ']')
		ELSE
			BEGIN
				EXECUTE('ENABLE TRIGGER [dbo].[' + @TRIGGER_NAME + '] ON [dbo].[' + @TABLE_NAME + ']')
				IF @UPDATE_LAST_CHANGE_DATE = 1
					UPDATE [dbo].[Symphony_DataChanged]
					   SET[lastDataChange] = GETDATE()
			END
		SET @INDEX = @INDEX + 1;
		
	END
	
END
GO
/****** Object:  StoredProcedure [dbo].[Symphony_spSetISTComplianceStatuses]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
/*****  IS EXECUTED AFTER THE LOAD & RECALCULATE AND AFTER Symphony_spHandleISTComplianceHistory *****/
CREATE PROCEDURE [dbo].[Symphony_spSetISTComplianceStatuses] 
      @threshold1 int = 10,
      @threshold2 int = 30
AS
BEGIN

	DECLARE @statusNonCompliant int
	DECLARE @statusOnTime int 
	DECLARE @statusMissingUnits int
	DECLARE @statusLate int

	SELECT @statusNonCompliant = 0
	SELECT @statusOnTime = 1
	SELECT @statusMissingUnits = 2
	SELECT @statusLate = 3


	UPDATE Symphony_ISTComplianceHistory SET statusCode = @statusNonCompliant
	WHERE DATEDIFF(d, isnull(orderDate,closeDate), getdate()) > @threshold2
	AND statusCode IS NULL


	UPDATE H SET H.unitsReceived = T.quantity,
				 H.statusCode = CASE WHEN T.quantity < H.quantity THEN @statusMissingUnits
									 WHEN DATEDIFF(d, isnull(H.orderDate,H.closeDate),T.reportedDate) > @threshold1 THEN @statusLate
									 ELSE @statusOnTime END,
				H.completionDate = T.reportedDate
			  
	FROM 
	Symphony_ISTComplianceHistory H INNER JOIN 
	Symphony_Transactions T ON H.orderID = T.transactionID
	WHERE H.statusCode IS NULL AND T.transactionType = 1

END

GO
/****** Object:  StoredProcedure [dbo].[Symphony_spSLSkuHistory]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[Symphony_spSLSkuHistory]
        @stockLocationID INT=-1,
        @updateDate smalldatetime=null, 
        @yesterday smalldateTime=null,
        @doUpdateSkuTable bit=0
AS
BEGIN

    IF (@stockLocationID = -1 or @updateDate is null)
        return

        INSERT INTO Symphony_StockLocationSkuHistory(skuID, stockLocationID, bufferSize,
        inventoryAtSite, consumption, totalIn, irrConsumption, irrTotalIn,irrInvAtSite,irrInvAtTransit,irrInvAtProduction, updateDate, inventoryAtTransit, inventoryAtProduction,
        unitPrice, throughput, tvc, avgMonthlyConsumption, tempInventoryAtSite, 
        worstInventoryAtSite, avgInventoryAtSite, inventoryAtSiteUpdatesNum, originStockLocation, originSKU, originType,
        bpSite, bpTransit, bpProduction, greenBpLevel, redBpLevel, safetyStock, isDuplicatedRow)

        SELECT skuID, @stockLocationID, bufferSize, inventoryAtSite, 0 as consumption, 0 as totalIn, 0 as irrConsumption, 0 as irrTotalIn, irrInvAtSite, irrInvAtTransit, irrInvAtProduction, @updateDate as updateDate,
        inventoryAtTransit, inventoryAtProduction, unitPrice, throughput, tvc, avgMonthlyConsumption, inventoryAtSite as tempInventoryAtSite,
        inventoryAtSite as worstInventoryAtSite, inventoryAtSite as avgInventoryAtSite ,1, originStockLocation, originSKU,
        originType, bpSite, bpTransit, bpProduction, greenBpLevel, redBpLevel, safetyStock, 1

        FROM Symphony_StockLocationSkuHistory S WITH(NOLOCK)
             
        WHERE S.isDeleted = 0
        AND S.stockLocationID=@stockLocationID
        AND updateDate = @yesterday
        AND not exists (select 1 from Symphony_StockLocationSkuHistory
                                where skuID = S.skuID and
                                stockLocationID = S.stockLocationID and
                                updateDate = @updateDate)

    --IF (@doUpdateSkuTable = 1)
    --BEGIN
    --    update Symphony_StockLocationSkus set updateDate = @updateDate, consumption=0, totalIn=0, irrTotalIn = 0, irrConsumption = 0
    --     WHERE Symphony_StockLocationSkus.stockLocationID=@stockLocationID
    --            and Symphony_StockLocationSkus.updateDate < @updateDate
    --END

END

GO
/****** Object:  StoredProcedure [dbo].[Symphony_spStockLocationsAdjacent]    Script Date: 6/6/2022 12:22:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[Symphony_spStockLocationsAdjacent]
AS
    BEGIN

        CREATE TABLE #StockLocationsAdjacent(
            stockLocationID1   INT,
            stockLocationID2   INT,
            stockLocationName1 nvarchar(100),
            stockLocationName2 nvarchar(100),
            inD1toD2NotNeeded     bit,
            inD2toD1NotNeeded     bit)

    INSERT INTO     #StockLocationsAdjacent
    SELECT DISTINCT stockLocationID1, stockLocationID2, '', '', inD1toD2NotNeeded, inD2toD1NotNeeded
    FROM            Symphony_StockLocationsAdjacent, Symphony_StockLocations
    WHERE           stockLocationID1=stockLocationID OR stockLocationID2=stockLocationID

    UPDATE      #StockLocationsAdjacent
    SET         stockLocationName1=stockLocationName
    FROM        Symphony_StockLocations
        WHERE   stockLocationID1=stockLocationID

    UPDATE      #StockLocationsAdjacent
    SET         stockLocationName2=stockLocationName
    FROM        Symphony_StockLocations
        WHERE   stockLocationID2=stockLocationID

    SELECT * from #StockLocationsAdjacent

    DROP TABLE #StockLocationsAdjacent

END
GO
