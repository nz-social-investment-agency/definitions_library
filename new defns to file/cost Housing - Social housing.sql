/**************************************************************************************************
Title: Fiscal costs - Social housing
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[hnz_clean].[tenancy_snapshot]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]

Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_social_housing]

Description:
	The purpose of this cost is to estimate costs incurred in providing social housing to individuals.
	This includes housing provided by Kainga Ora - Homes and Communities, as well as those provided by Community Housing Providers (CHPs).

Notes:
- This relies solely on rental subsidy information collected in the monthly tenancy snapshot HNZ table. The monthly cost is derived
	via turning the reported weekly subsidy into a daily figure, and then multiplying by the number of days in the relevant month.
	All costs are allocated solely to the primary applicant, per the counting rule in the source table. 
	This could optionally be allocated across all known household members.

- The nominal costs have been converted to real via the CPI.

- Note that there are a couple of snz_household_uids in this table that have multiple snz_uids for the same snapshot period
	(see the below query to identify how many). If multiple members of the same household are separately included in the snapshot,
	then it raises the possibility that we are double-counting the subsidy for these people. However:
	a. There are very few households that have duplicates in this way
	b. Closer inspection of the source table for these 'duplicate' households indicates that they are likely to actually be
		different (they have different household characteristics as recorded by MSD, different msd_house_uid, different snz_address_uid).
		So the most plausible explanation is that this is a false duplicate in the matching process to derive snz_household_uid, 
		rather than different members of the same household being counted multiple times.

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-13	AW	Adding documentation
2024-11-11	CW	Initial creation
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_social_housing]
GO
WITH setup AS (

SELECT snz_uid
    , 'HNZ' source
    , CAST([hnz_ts_snapshot_date] AS DATE) AS event_date
    , YEAR([hnz_ts_snapshot_date]) AS cal_year
    , [snz_household_uid]
    , DAY([hnz_ts_snapshot_date]) AS duration -- this is often the end of the month, so rent applies to whole month

	-- this is the estimate of what the govt pays in rental subsidy
	-- convert weekly to daily and then multiply by days in month
    , 1.0 * [hnz_ts_inc_reltd_rent_subsdy_nbr] / 7 * DAY([hnz_ts_snapshot_date]) AS cost

	-- ,[hnz_ts_inc_related_rent_nbr]
	-- ,[hnz_ts_market_rent_nbr]
FROM [IDI_Clean_202410].[hnz_clean].[tenancy_snapshot]
WHERE YEAR([hnz_ts_snapshot_date]) BETWEEN 2019 AND 2023

)
--Adjust nominal costs to real (2024 dollars) based on CPI
SELECT snz_uid
    , source
    , a.cal_year
    , SUM(duration) AS value
    , SUM(cost * cpi_adj_2024) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_social_housing]
FROM setup AS a
INNER JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON a.cal_year = b.cal_year
GROUP BY snz_uid
    , source
    , a.cal_year
