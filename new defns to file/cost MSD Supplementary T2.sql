/**************************************************************************************************
Title: Fiscal costs - MSD supplementary (T2) payments 
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[msd_clean].[msd_second_tier_expenditure]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_calendar_years]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_supplementary_benefits]

Description:
	The purpose of this cost is to estimate the tier 2 payments paid by MSD. We have
	excluded Accommodation Supplement from this total as that is being separately estimated in a different script.

Notes:
- This solely relies on data in the msd_second_tier_expenditure table. All costs are allocated solely to the primary
	applicant, per the counting rule in the source table. This could optionally be allocated across all known household members.

- Supplementary benefits are non-taxable, so no need to account for tax paid.
- We exclude accomodation supplement as this is estimated separately in the {cost} definitions

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-13	AW	Adding documentation
2024-11-11	CW	Initial creation
**************************************************************************************************/

--Extracting relevant payment data
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_supplementary_benefits]
GO

WITH setup AS (

SELECT [snz_uid]
    , 'T2' source
    , b.cal_year
    , [msd_ste_start_date]
    , [msd_ste_end_date]
    , [msd_ste_daily_gross_amt] -- daily amount
    , IIF(a.[msd_ste_start_date] <= b.start_date, b.start_date, a.[msd_ste_start_date]) AS trim_start_date -- latest start date
    , IIF(a.[msd_ste_end_date] <= b.end_date, a.[msd_ste_end_date], b.end_date) AS trim_end_date -- earliest_end_date
FROM [IDI_Clean_202410].[msd_clean].[msd_second_tier_expenditure] AS a
--This is necessary to apportion multi-year spells into the duration that occurs in each calendar year
INNER JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_calendar_years] AS b
ON a.[msd_ste_start_date] <= b.end_date
AND b.start_date <= a.[msd_ste_end_date]
WHERE b.cal_year BETWEEN 2019 AND 2023
--Excluding Accommodation Supplement (as this is separately estimated)
AND [msd_ste_supp_serv_code] ! = '471'

)
--Adjust nominal costs to real (2024 dollars) based on CPI
SELECT a.snz_uid
    , a.source
    , a.cal_year
    , SUM(1 + DATEDIFF(DAY, trim_start_date, trim_end_date))AS duration
    , SUM([msd_ste_daily_gross_amt] * (1 + DATEDIFF(DAY, trim_start_date, trim_end_date)) * cpi_adj_2024)AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_supplementary_benefits]
FROM setup AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON a.cal_year = b.YEAR
GROUP BY snz_uid
    , source
    , a.cal_year
