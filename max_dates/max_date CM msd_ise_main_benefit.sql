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

The original approach for all max_date scripts, including this one,  was to make a view.
While it is fast to query the entire view (< 2 minutes for millions of rows) it is very slow to join/assemble the
view to the master table. This is likely due to how the base data is indexed (in columnstore indexes).
Hence we have converted this script and several like it to sandpit tables for performance.
*/

DROP TABLE IF EXISTS [SIA_Sandpit].[DL-MAA2023-46].[max_date_CM_msd_ise_main_benefit_202506]
GO

WITH uid_list AS (

	SELECT DISTINCT snz_uid
	FROM [IDI_Clean_202506].[data].[personal_detail]

),
count_each_date AS (

	SELECT CAST([payment_start] AS DATE) AS the_date
		, COUNT(*) AS num
	FROM [IDI_Community].[inc_ise_main_benefit].[ise_main_benefit_202506]
	WHERE [payment_start] BETWEEN DATEADD(YEAR, -5, GETDATE()) AND GETDATE() -- events between now and five years ago
	GROUP BY CAST([payment_start] AS DATE) -- remove times if DATETIME

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
INTO [SIA_Sandpit].[DL-MAA2023-46].[max_date_CM_msd_ise_main_benefit_202506]
FROM uid_list
	,max_date
GO

CREATE NONCLUSTERED INDEX i_uid ON [SIA_Sandpit].[DL-MAA2023-46].[max_date_CM_msd_ise_main_benefit_202506] (snz_uid) INCLUDE (max_date)
GO
