/**************************************************************************************************
Title: Fiscal costs - Corrections programmes
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[cor_clean].[ra_programmes]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_corrections_programmes]

Description:
	The purpose of this cost is to estimate costs incurred in providing rehabilitation programmes to individuals 
	who are in the care of Corrections.

Notes:
- This is an indirect estimate, based on advice from Corrections that programme interventions make up approximately 
	20% of the total Corrections budget. We have taken this 20% budget figure and divided it by the number of
	interventions per year in the IDI data to arrive at a notional average cost per intervention. Costs per individual
	are then estimated by looking at enrolment data in the ra_programmes table.

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
	2024-11-18	AW	Adding documentation
	2024-11-11	CW	Initial creation
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_corrections_programmes]
GO

WITH setup AS (

	SELECT [snz_uid]
		, [snz_jus_uid]
		, [cor_pro_site_type]
		, [cor_pro_programme_name_text]
		, YEAR([cor_pro_completion_date])AS cal_year
		, CASE WHEN YEAR([cor_pro_completion_date])=2019 THEN 7504.63
				WHEN YEAR([cor_pro_completion_date])=2020 THEN 10784.51
				WHEN YEAR([cor_pro_completion_date])=2021 THEN 12630.24
				WHEN YEAR([cor_pro_completion_date])=2022 THEN 19920.99
				WHEN YEAR([cor_pro_completion_date])=2023 THEN 17606.92
				ELSE NULL END AS cost
		, 'PRO' source
	FROM [IDI_Clean_202410].[cor_clean].[ra_programmes]
	WHERE YEAR([cor_pro_completion_date]) IN (2019,2020,2021,2022,2023)

)
--Adjust nominal costs to real (2024 dollars) based on CPI
SELECT snz_uid
    , source
    , a.cal_year
    , COUNT(*) AS value
    , SUM(cost*cpi_adj_2024) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_corrections_programmes]
FROM setup AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON a.cal_year = b.cal_year
GROUP BY snz_uid
    , source
    , a.cal_year
