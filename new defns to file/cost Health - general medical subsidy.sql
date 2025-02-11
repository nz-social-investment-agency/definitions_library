/**************************************************************************************************
Title: Fiscal costs - General medical subsidy (GMS)
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[moh_clean].[gms_claims]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_general_medical_subsidy]

Description:
	The purpose of this cost is to estimate the costs incurred
	when someone attends primary care but they are not enrolled 
	in the practice.

Notes:
- The costs of primary care for PHO enrolled patients are separately estimated in the primary
	capitation script.
- This relies solely on the GMS claims table.
- The nominal costs have been converted to real via the CPI.

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-15	AW	Adding documentation
2024-11-12	CW	Initial creation
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_general_medical_subsidy]
GO

WITH setup AS (

SELECT [snz_uid]
    , 'GMS' source
    , YEAR([moh_gms_visit_date])AS cal_year
    , [moh_gms_amount_paid_amt] cost
FROM [IDI_Clean_202410].[moh_clean].[gms_claims]
WHERE YEAR([moh_gms_visit_date]) BETWEEN 2019 AND 2023

)
--Adjust nominal costs to real (2024 dollars) based on CPI
SELECT snz_uid
    , source
    , a.cal_year
    , COUNT(*) AS value
    , SUM(cost*cpi_adj_2024) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_general_medical_subsidy]
FROM setup AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON a.cal_year = b.cal_year
GROUP BY snz_uid
    , source
    , a.cal_year
