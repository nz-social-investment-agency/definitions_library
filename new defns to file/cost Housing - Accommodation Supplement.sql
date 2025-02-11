/**************************************************************************************************
Title: Fiscal costs - Accomodation Supplement
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[msd_clean].[msd_second_tier_expenditure]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_accomodation_supplement]

Description:
	The purpose of this cost is to estimate costs incurred in providing Accommodation Supplement to individuals.

Notes:
- This relies solely on information collected in in MSD's second tier benefit tables. All costs are allocated solely to the primary
	applicant, per the counting rule in the source table. This could optionally be allocated across all known household members.

- A limitation in the current method is that all costs are summed up per spell and allocated to the year in which the spell started. 
	This means that if applicants receive the payment over several years, then the payment will not be appropriately split over these
	years.

- The nominal costs have been converted to real via the CPI.
	--Note that all of the costs are allocated to the year of the date the spell started. This means that spells that
	--span multiple years will have some of their costs incorrectly allocated.

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-13	AW	Adding documentation
2024-11-11	CW	Initial creation
**************************************************************************************************/



--Extract all relevant payment spells with the Accommodation Supplement payment type
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_accomodation_supplement]
GO

WITH setup AS (

SELECT [snz_uid]
    , 'ACC_SUP' AS source
    , YEAR([msd_ste_start_date]) AS cal_year
    , [msd_ste_start_date] AS start_date
    , [msd_ste_end_date] AS end_date
    --,[msd_ste_srvst_code]
    --,[msd_ste_parent_serv_code]
    --,[msd_ste_servf_code]
    --,[msd_ste_supp_serv_code]
    , [msd_ste_daily_gross_amt] AS daily
    --,[msd_ste_daily_nett_amt]
    , [msd_ste_period_nbr]
    , [msd_ste_period_nbr] * [msd_ste_daily_gross_amt] AS cost
    --,[msd_ste_supp_source_text]
FROM [IDI_Clean_202410].[msd_clean].[msd_second_tier_expenditure]
WHERE [msd_ste_supp_serv_code] = '471' -- Accommodation Supplement
AND YEAR([msd_ste_start_date]) BETWEEN 2019 AND 2023

)
--Adjust nominal costs to real (2024 dollars) based on CPI
SELECT a.snz_uid
    , a.source
    , a.cal_year
    , SUM([msd_ste_period_nbr]) AS value
    , SUM(cost*cpi_adj_2024) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_accomodation_supplement]
FROM setup AS a
INNER JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON a.cal_year = b.YEAR
GROUP BY snz_uid
    , source
    , a.cal_year
