/**************************************************************************************************
Title: Fiscal costs - Payments to primary care organisations
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[moh_clean].[nes_enrolment]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_primary_care]

Description:
	The purpose of this is to estimate the costs incurred relating to primary health care visits.
	
Notes:
- Each month, MOH pays the PHO management organisation a capitation amount determined by a weighted version 
	of each practices' patient register. This code uses the PHO enrolment data to allocate this funding to 
	specific individuals.
	Note that this funding arrangement is not reliant on actual service usage, and so these costs are unlikely to
	be strongly affected by changes in the context of one's life (other than whether an individual is enrolled in a PHO).
- The time series for this dataset misses three months at the start of 2019, and 6 months at the end of 2023. 
	However, the funding amounts show relatively little month to month variation. We have approximated the missing 
	costs by multiplying the most proximate monthly costs by 3/6 as appropriate.

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-15	AW	Adding documentation
2024-11-11	CW	Initial creation
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_primary_care]
GO

WITH setup AS (

	--All data that is available
    SELECT [snz_uid]
        , 'NES' source
        , YEAR([moh_nes_snapshot_month_date]) AS cal_year
        , [moh_nes_total_amt] AS cost
    FROM [IDI_Clean_202410].[moh_clean].[nes_enrolment]
    WHERE YEAR([moh_nes_snapshot_month_date]) BETWEEN 2019 AND 2023

    UNION ALL

	--Estimate the missing costs for the first 3 months in 2019 by multiplying the April 2019 cost by 3
    SELECT [snz_uid]
        , 'NES' source
        , YEAR([moh_nes_snapshot_month_date]) AS cal_year
        , [moh_nes_total_amt]*3 AS cost
    FROM [IDI_Clean_202410].[moh_clean].[nes_enrolment]
    WHERE CAST([moh_nes_snapshot_month_date] AS DATE) = '2019-04-01'

    UNION ALL

	--Estimate the missing costs for the last 6 months in 2023 by multiplying the June 2023 cost by 6
    SELECT [snz_uid]
        , 'NES' source
        , YEAR([moh_nes_snapshot_month_date]) AS cal_year
        , [moh_nes_total_amt]*6 AS cost
    FROM [IDI_Clean_202410].[moh_clean].[nes_enrolment]
    WHERE CAST([moh_nes_snapshot_month_date] AS date) = '2023-06-01'

)
--Adjust nominal costs to real (2024 dollars) based on CPI
SELECT snz_uid
    , source
    , a.cal_year
    , SUM(cost*cpi_adj_2024) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_primary_care]
FROM setup AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON a.cal_year = b.cal_year
GROUP BY snz_uid
    , source
    , a.cal_year
