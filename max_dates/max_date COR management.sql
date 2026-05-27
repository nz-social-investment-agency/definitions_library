/*
Methodology for finding maximum date for a source dataset
Simon Anastasiadis
2025-03-19

Logic is:
1 - Discard future dates as errors
2 - Keep only records within the last five years (to minimse impact of changes in data collection on calculation)
3 - Count number of records on each date (very low counts will later imply incomplete data)
4 - Compute threshold for low counts = one-fifth x 25th-percentile of count
5 - Discard records with count below this threshold (official collection ends earlier but some few dates occur later)
6 - Take the latest remaining date


The 202506 refresh changed the structure of the corrections tables.
SA created a definition to reconstruct the major management periods.
However, because [directives] has future dates, neither [directives] nor our constructed table that depends upon it,
are well suited to max_date methodology. Instead we use the [muster] table.

2025-08-19 SA swap to muster table
*/

USE IDI_UserCode
GO

DROP VIEW IF EXISTS [DL-MAA2023-46].[max_date_COR_management_202506]
GO

CREATE VIEW [DL-MAA2023-46].[max_date_COR_management_202506] AS
WITH uid_list AS (

	SELECT DISTINCT snz_uid
	FROM [IDI_Clean_202506].[data].[personal_detail]

),
count_each_date AS (

	SELECT CAST([cor_mus_muster_start_date] AS DATE) AS the_date
		, COUNT(*) AS num
--	FROM [IDI_Clean_202503].[cor_clean].[ra_ofndr_major_mgmt_period_a] -- use this for 202503 and earlier refreshes
--	FROM [SIA_Sandpit].[DL-MAA2023-46].[def_COR_major_management_periods] -- constructed table for 202506 (and later refreshes)
	FROM [IDI_Clean_202506].[cor_clean].[muster] -- has tidiest end dates of Corrections collection
	WHERE [cor_mus_muster_start_date] BETWEEN DATEADD(YEAR, -5, GETDATE()) AND GETDATE() -- events between now and five years ago
	GROUP BY CAST([cor_mus_muster_start_date] AS DATE) -- remove times if DATETIME

),
rolling_average AS (

	SELECT *
		,AVG(num) OVER (ORDER BY the_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling7dayavg
	FROM count_each_date
	
),
threshold_calculation AS (

	SELECT the_date
		,num
		,rolling7dayavg
		,0.2 * PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY rolling7dayavg) OVER () AS threshold
	FROM rolling_average
	
),
max_date AS (

	SELECT MAX(the_date) AS max_date
	FROM threshold_calculation
	WHERE num >= threshold

)
SELECT snz_uid, max_date
FROM uid_list
	,max_date
GO

