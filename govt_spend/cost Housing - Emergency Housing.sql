/**************************************************************************************************
Title: Fiscal costs - Emergency Housing (EH) special needs grants
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[msd_clean].[msd_third_tier_expenditure]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_emergency_housing]

Description:
	The purpose of this cost is to estimate costs incurred in providing Emergency Housing to individuals.

Notes:
- This relies solely on information collected in in MSD's third tier benefit tables. All costs are allocated solely to the primary
	applicant, per the counting rule in the source table. This could optionally be allocated across all known household members.

- The nominal costs have been converted to real via the CPI.
- 2019 costs are lower as EH provision wa smuch lower in ealier years

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-13	AW	Adding documentation
2024-11-11	CW	Initial creation
**************************************************************************************************/

--Extract all raw payment events with the EH SNG type code
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_emergency_housing]
GO

WITH setup AS (

SELECT [snz_uid]
    , [msd_tte_decision_date] date
    , [msd_tte_pmt_amt] cost
    , YEAR([msd_tte_decision_date])AS cal_year
    , 'EH' source
FROM [IDI_Clean_202410].[msd_clean].[msd_third_tier_expenditure] AS a
WHERE [msd_tte_pmt_rsn_type_code] IN ('855') -- Emergency Housing
AND YEAR([msd_tte_decision_date]) IN ('2019','2020','2021','2022','2023')

)
--Adjust nominal costs to real (2024 dollars) based on CPI
SELECT a.snz_uid
    , a.source
    , a.cal_year
    , COUNT(*)AS value
    , SUM(cost)AS cost
    , SUM(cost*cpi_adj_2024)AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_emergency_housing]
FROM setup AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON a.cal_year = b.cal_year
GROUP BY snz_uid
    , source
    , a.cal_year
