/**************************************************************************************************
Title: Fiscal costs - MSD adhoc (T3) payments 
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[msd_clean].[msd_third_tier_expenditure]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_adhoc_benefits]

Description:
	The purpose of this cost is to estimate the tier 3 payments paid by MSD. This includes all special needs/hardship grants. We have
	excluded Emergency Housing special needs grants from this total as that is being separately estimated in a different script.

Notes:
- This solely relies on data in the msd_third_tier_expenditure table. All costs are allocated solely to the primary
	applicant, per the counting rule in the source table. This could optionally be allocated across all known household members.

- Adhoc / emergency benefits are non-taxable, so no need to account for tax paid.
- We exclude emergency housing as this is estimated separately in the {cost} definitions

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-13	AW	Adding documentation
2024-11-11	CW	Initial creation
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_adhoc_benefits]
GO

WITH setup AS (

SELECT [snz_uid]
    , [msd_tte_decision_date]
    , [msd_tte_pmt_amt] AS cost
    , YEAR([msd_tte_decision_date]) AS cal_year
    , 'T3' AS source
FROM [IDI_Clean_202410].[msd_clean].[msd_third_tier_expenditure] AS a 
--exclude Emergency Housing as this is separately estimated
WHERE [msd_tte_pmt_rsn_type_code] NOT IN ('855')
AND YEAR([msd_tte_decision_date]) BETWEEN 2019 AND 2023

)
--Adjust nominal costs to real (2024 dollars) based on CPI
SELECT a.snz_uid
    , a.source
    , a.cal_year
    , COUNT(*) AS value
    , SUM(cost*cpi_adj_2024) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_adhoc_benefits]
FROM setup AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON a.cal_year = b.cal_year
GROUP BY snz_uid
    , source
    , a.cal_year

