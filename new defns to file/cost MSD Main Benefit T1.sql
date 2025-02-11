/**************************************************************************************************
Title: Fiscal costs - MSD main benefits
Author: Craig Wright (edited by Andrew Webber)

Inputs & Dependencies:
	[IDI_Community].[cm_read_MSD_ISE_MAIN_BENEFIT].[msd_ise_main_benefit_202410]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_calendar_years]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_main_benefits]

Description:
	The purpose of this cost is to estimate main benefits paid by MSD. This does not include Superannuation/Veteran's Pension.

Notes:
- This relies on the code module relating to main benefit payments. All costs are allocated solely to the primary
	applicant, per the counting rule in the source table. This could optionally be allocated across all known household members.

- A limitation of this is that this doesn't account for tax paid by the recipient (which reduces the fiscal cost of the benefit payment).

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-13	AW	Adding documentation
2024-11-11	CW	Initial creation
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_main_benefits]
GO

WITH setup AS (

SELECT [snz_uid]
    , 'T1' source
    , [benefit_lvl2]
    , [benefit_lvl1]
    , b.cal_year
    , [payment_start]
    , [payment_end]
    , [payment_rate_gross] -- daily amount
    , [payment_rate_tax]

    , IIF(a.[payment_start] <= b.start_date, b.start_date, a.[payment_start]) AS trim_start_date -- latest start date
    , IIF(a.[payment_end] <= b.end_date, a.[payment_end], b.end_date) AS trim_end_date -- earliest_end_date
FROM [IDI_Community].[cm_read_MSD_ISE_MAIN_BENEFIT].[msd_ise_main_benefit_202410] AS a
--This is necessary to apportion multi-year spells into the duration that occurs in each calendar year
INNER JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_calendar_years] AS b
ON a.[payment_start] <= b.end_date
AND b.start_date <= a.[payment_end]
WHERE b.cal_year BETWEEN 2019 AND 2023

)
--Adjust nominal costs to real (2024 dollars) based on CPI
SELECT snz_uid
    , source
    , a.cal_year
    , SUM(1 + DATEDIFF(DAY, trim_start_date, trim_end_date)) AS duration
    , SUM(payment_rate_gross * (1 + DATEDIFF(DAY, trim_start_date, trim_end_date)) * cpi_adj_2024) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_main_benefits]
FROM setup AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON a.cal_year = b.cal_year
GROUP BY snz_uid
    , source
    , a.cal_year
