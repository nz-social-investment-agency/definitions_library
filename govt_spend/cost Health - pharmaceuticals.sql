/**************************************************************************************************
Title: Fiscal costs - Pharmaceutical subsidies (DSS)
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_pharmaceuticals]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_pharmaceuticals]

Description:
	The purpose of this cost is to estimate costs incurred subsidising the filling of pharmaceutical prescriptions to individuals.

Notes:
- This relies solely on information collected in the pharmaceutical table. The cost data excludes GST, and GST has not been re-added.
	This does not include hospital dispensing except for pharmaceutical cancer treatments.
- Part of the pharmaceutical appropriation is paid directly to pharmacies for dispensing services. 
	This is not apportioned in this table.
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

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_pharmaceuticals]
GO

WITH setup AS (

SELECT [snz_uid]
    , 'PHA' source
    , YEAR([moh_pha_dispensed_date])AS cal_year
    , [moh_pha_dispensed_date]
    , [moh_pha_remimburs_cost_exc_gst_amt] AS cost
FROM [IDI_Clean_202410].[moh_clean].[pharmaceutical]
WHERE YEAR([moh_pha_dispensed_date]) BETWEEN 2019 AND 2023

)
--Adjust nominal costs to real (2024 dollars) based on CPI
SELECT snz_uid
    , source
    , a.cal_year
    , COUNT(DISTINCT [moh_pha_dispensed_date])AS value
    , SUM(cost * cpi_adj_2024) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_pharmaceuticals]
FROM setup AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON a.cal_year = b.cal_year
GROUP BY snz_uid
    , source
    , a.cal_year
