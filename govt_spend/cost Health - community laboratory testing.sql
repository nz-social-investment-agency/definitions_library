/**************************************************************************************************
Title: Fiscal costs - Community laboratory testing
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[moh_clean].[lab_claims]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_lab_tests]

Description:
	The purpose of this cost is to estimate costs incurred for lab claims.

Notes:
- This relies solely on information collected in the lab_claims table. The resulting costs exclude GST.
- The nominal costs have been converted to real via the CPI.

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-13	AW	Adding documentation
2024-11-11	CW	Initial creation
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_lab_tests]
GO

WITH setup AS (

SELECT [snz_uid]
    , 'LAB' source
    , YEAR([moh_lab_visit_date])AS cal_year
    , moh_lab_visit_date
    , [moh_lab_est_excl_amt] cost
FROM [IDI_Clean_202410].[moh_clean].[lab_claims]
WHERE YEAR([moh_lab_visit_date]) >= 2019

)
--Adjust nominal costs to real (2024 dollars) based on CPI
SELECT a.snz_uid
    , a.source
    , a.cal_year
    , COUNT(*) AS value
    , SUM(cost*cpi_adj_2024) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_lab_tests]
FROM setup AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON a.cal_year = b.cal_year
GROUP BY snz_uid
    , source
    , a.cal_year
