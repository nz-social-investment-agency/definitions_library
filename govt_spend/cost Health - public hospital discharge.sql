/**************************************************************************************************
Title: Fiscal costs - Public hospital
Author: Craig Wright

Inputs & Dependencies:
	[IDI_CLEAN_202410].[MOH_CLEAN].[PUB_FUND_HOSP_DISCHARGES_EVENT]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cst_hospital_discharge]

Description:
The purpose of this cost is to estimate costs associated with hospital stays.

Notes:
- WIES cost weight
	WIES is a method used in NZ to represent the resource cost relating to a hospital separation event
	It relies on a number of processes to derive a cost for each hospital discharge event, but there 
	are a few fields on the hospital table that allow the cost estimate calculation
		[moh_evt_cost_wgt_code]: the weis cost weight version
		[moh_evt_cost_weight_amt]: the scaleless resouce weight - multiplied by the med/surg 
									price for the financial year gives an estimate of the resource cost
		[moh_evt_pur_unit_text]!='EXCLU' - events to be excluded form the cost weight calculation
- Note the WIES costweight includes a component for ED attendances where the hospital event started in ED
	these are represented in the NNPAC ED data as purchase units of the form ED000NNA
	where A indicates the ED event ended in an acute hospital admission

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-13	AW	Adding documentation
2024-11-11	CW	Initial creation
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cst_hospital_discharge]
GO

WITH setup AS (

SELECT [snz_uid]
    , 'PUB' source
    , [moh_evt_evst_date] AS start_date
    , [moh_evt_even_date] AS end_date
    , YEAR([moh_evt_evst_date]) AS cal_year
    --,[moh_evt_pur_unit_text]
    --,[moh_evt_exclu_pu_code]
    , [moh_evt_cost_weight_amt] AS cost_weight
    , 'WIES' method

	--This is an estimate for the med_surg price for 2021, based on a report published by Capital and Coast DHB
    , [moh_evt_cost_wgt_code]
    , CASE 
	  WHEN [moh_evt_cost_wgt_code]='15' THEN 6856
	  WHEN [moh_evt_cost_wgt_code]='16' THEN 6856
	  WHEN [moh_evt_cost_wgt_code]='17' THEN 6856
	  WHEN [moh_evt_cost_wgt_code]='18' THEN 6856
	  WHEN [moh_evt_cost_wgt_code]='19' THEN 6856
	  WHEN [moh_evt_cost_wgt_code]='20' THEN 6856
	  WHEN [moh_evt_cost_wgt_code]='21' THEN 6856
	  WHEN [moh_evt_cost_wgt_code]='22' THEN 6856
	  WHEN [moh_evt_cost_wgt_code]='23' THEN 6856
	  WHEN [moh_evt_cost_wgt_code]='24' THEN 6856
	  ELSE NULL END AS unit_price

    , DATEDIFF(DAY,[moh_evt_evst_date],[moh_evt_even_date] )+1 AS duration
FROM [IDI_Clean_202410].[moh_clean].[pub_fund_hosp_discharges_event]
WHERE YEAR([moh_evt_evst_date]) BETWEEN 2019 AND 2023
AND [moh_evt_pur_unit_text] ! = 'EXCLU'

)
--Adjust nominal costs to real (2024 dollars) based on CPI.
SELECT a.snz_uid
    , a.source
    , a.cal_year
    , SUM(duration) AS value
    , SUM(1.0 * cost_weight * unit_price * cpi_2024 / cpi_adj) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cst_hospital_discharge]
FROM setup AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON b.cal_year = 2022
GROUP BY snz_uid
    , source
    , a.cal_year


