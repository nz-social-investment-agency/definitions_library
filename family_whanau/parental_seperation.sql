/**************************************************************************************************
Title: Seperation
Author: Charlotte Rose
Peer review: Lexi Xu

Inputs & Dependencies:
	[IDI_Clean_202506].[dia_clean].[marriages]
	[IDI_Clean_202506].[dia_clean].[civil_unions]
	[IDI_Clean_202506].[data].[personal_detail]


Description:
Finds formal seperations as per DIA marriage and civil union dissolutions


Notes:
1) Two years of seperation is required before marriages and unions can be officially disolved, thus this will not capture recent seperations
2) There is currently no way of reliably capturing seperations amoung those partners who are not legally married/in a civil union, thus this is not by any means a comprehensive measure of seperation

Parameters & Present values:
  Current refresh = 202506
  Project schema = MAA2023-46

Issues: 


History (reverse order):
2025-07-22 CR adapted from PM 
**************************************************************************************************/

USE [IDI_UserCode]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_separation_202506]
GO

CREATE VIEW [DL-MAA2023-46].[defn_separation_202506] AS
WITH
marriage AS (
	SELECT DISTINCT [partnr1_snz_uid]
	      ,[dia_mar_partnr1_sex_snz_code]
		  ,[partnr2_snz_uid]
	      ,[dia_mar_partnr2_sex_snz_code]
	      ,[dia_mar_marriage_date]
		  ,[dia_mar_disolv_order_date]
		  ,DATEFROMPARTS(b.[snz_deceased_year_nbr], b.[snz_deceased_month_nbr], 28) AS [partnr1_deceased_date]
		  ,DATEFROMPARTS(c.[snz_deceased_year_nbr], c.[snz_deceased_month_nbr], 28) AS [partnr2_deceased_date]
	FROM [IDI_Clean_202506].[dia_clean].[marriages] a
	INNER JOIN [IDI_Clean_202506].[data].[personal_detail] b
	ON a.[partnr1_snz_uid] = b.snz_uid
	INNER JOIN [IDI_Clean_202506].[data].[personal_detail] c
	ON a.[partnr2_snz_uid] = c.snz_uid
	WHERE [dia_mar_marriage_date] IS NOT NULL
	AND [partnr1_snz_uid] <> [partnr2_snz_uid]
	AND [dia_mar_marriage_date] < [dia_mar_disolv_order_date]
	AND [dia_mar_marriage_date] > '1940-12-31' -- keeping to reasonable range
),
civil_union AS (
	SELECT DISTINCT [partnr1_snz_uid]
		  ,[dia_civ_partnr1_sex_snz_code]
		  ,[partnr2_snz_uid]
		  ,[dia_civ_partnr2_sex_snz_code]
		  ,[dia_civ_civil_union_date]
		  ,[dia_civ_dissolution_type_text]
		  ,[dia_civ_disolv_order_date]
		  ,DATEFROMPARTS(b.[snz_deceased_year_nbr], b.[snz_deceased_month_nbr], 28) AS [partnr1_deceased_date]
		  ,DATEFROMPARTS(c.[snz_deceased_year_nbr], c.[snz_deceased_month_nbr], 28) AS [partnr2_deceased_date]
	FROM [IDI_Clean_202506].[dia_clean].[civil_unions] a
	INNER JOIN [IDI_Clean_202506].[data].[personal_detail] b
	ON a.[partnr1_snz_uid] = b.snz_uid
	INNER JOIN [IDI_Clean_202506].[data].[personal_detail] c
	ON a.[partnr2_snz_uid] = c.snz_uid
	WHERE [dia_civ_civil_union_date] IS NOT NULL
	AND [partnr1_snz_uid] <> [partnr2_snz_uid]
	AND [dia_civ_civil_union_date] < [dia_civ_disolv_order_date]
	AND [dia_civ_civil_union_date] > '1940-12-31' -- keeping to reasonable range

)
/* Partner 1, marriage */
SELECT DISTINCT [partnr1_snz_uid] as snz_uid
	,[dia_mar_marriage_date] AS [start_date]
	,COALESCE([dia_mar_disolv_order_date],
		IIF([partnr1_deceased_date] < [partnr2_deceased_date], [partnr1_deceased_date], [partnr2_deceased_date]),
		[partnr1_deceased_date],
		[partnr2_deceased_date],
		'9999-12-31') AS [end_date]
FROM marriage


UNION ALL

/* Partner 2, marriage */
SELECT DISTINCT [partnr2_snz_uid] as snz_uid
	,[dia_mar_marriage_date] AS [start_date]
	,COALESCE([dia_mar_disolv_order_date],
		IIF([partnr1_deceased_date] < [partnr2_deceased_date], [partnr1_deceased_date], [partnr2_deceased_date]),
		[partnr1_deceased_date],
		[partnr2_deceased_date],
		'9999-12-31') AS [end_date]
FROM marriage

UNION ALL

/* Partner 1, civil union */
SELECT DISTINCT [partnr1_snz_uid] AS [snz_uid]
	  ,[dia_civ_civil_union_date] AS [start_date]
	  ,COALESCE([dia_civ_disolv_order_date],
		IIF([partnr1_deceased_date] < [partnr2_deceased_date], [partnr1_deceased_date], [partnr2_deceased_date]),
		[partnr1_deceased_date],
		[partnr2_deceased_date],
		'9999-12-31') AS [end_date]
FROM civil_union


UNION ALL

/* Partner 2, civil union */
SELECT DISTINCT [partnr2_snz_uid] AS [snz_uid]
	  ,[dia_civ_civil_union_date] AS [start_date]
	  ,COALESCE([dia_civ_disolv_order_date],
		IIF([partnr1_deceased_date] < [partnr2_deceased_date], [partnr1_deceased_date], [partnr2_deceased_date]),
		[partnr1_deceased_date],
		[partnr2_deceased_date],
		'9999-12-31') AS [end_date]
FROM civil_union
;

GO


