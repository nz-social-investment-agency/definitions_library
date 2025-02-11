/**************************************************************************************************
Title: Fiscal costs - Oranga Tamariki care and protection (CNP) and youth justice (YJ)
Author: Craig Wright

Inputs & Dependencies:
	[IDI_CLEAN_202410].[CYF_CLEAN].[CYF_CEC_CLIENT_EVENT_COST]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]

Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_care_protection_youth_justice]

Description:
	The purpose of this cost is to estimate costs incurred by Oranga Tamariki through events that have been coded to individuals.
	This includes placements, investigations, family group conferences, preparing for court, etc.

Notes:
- This relies solely on information collected by OT and recorded in the client event cost table. The IDI data dictionary
	notes that these costs are based on a time use survey undertaken in 2015 and have not been changed since (to take into account
	either the amount of time events require, or the unit costs of staff time - ie through salary increases).

- In 2019, the budget for OT increased by 45%. In part this was due to salary increases for particular staff members.
	Arguably the costs could be inflated from 2015 based on changes in the total budget of OT. However, for now, we have converted
	the 2015 costs to 2024 via the CPI.

- Direct costs appear to contain data errors: Some records have costs per day that are 2 orders of magnitude larger than
	what should be expected. These small number of records distort any averages or totals produced using these people.
	We impose a correction for this:
	- Calculate the daily rate
	- If the daily rate excees $100,000 per day, recalculate the direct costs using $100,000 per day
	After this correction annual total cost for CNP and YJU becomes consistent with published figures from Treasury.
	We also tested thresholds of $50k, $25k, and $10k. The $100k threshold was selected as it best matched published figures.

- Example of published figures from Treasury:
	Document: Oranga Tamariki - Supplementary Estimates of Approriations 2023/24 - Budget 2024
	Table rows: Prevention and Early Support + Statutory Intervention and Transition 

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:
- Method for handling of large direct costs is still under discussion with subject matter experts.
- Indirect costs are considered outdated by subject matter experts.

History (reverse order):
2024-12-09	SA	fix for direct costs
2024-11-18	AW	Adding documentation
2024-11-11	CW	Initial creation
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_care_protection_youth_justice]
GO

WITH duration_fix AS(
	-- zero durations are single points in time
	-- negative values are data errors
	-- both can be converted to duration = 1
    SELECT *
        , IIF(cyf_cec_event_duration_nbr > 0, cyf_cec_event_duration_nbr, 1)AS duration_fixed
    FROM [IDI_Clean_202410].[cyf_clean].[cyf_cec_client_event_cost]

),
cost_fix AS (

	SELECT a.[snz_uid]
		, [cyf_cec_business_area_type_code] AS source
		, YEAR([cyf_cec_event_start_date]) AS cal_year
		, [cyf_cec_indirect_gross_amt] AS ot_cost_indirect
		-- if daily rate is unrealisticly high assume this is caused by data error cap daily rate and recalculate total
		, IIF(1.0 * [cyf_cec_direct_gross_amt] / duration_fixed > 100000, 100000 * duration_fixed, [cyf_cec_direct_gross_amt]) AS ot_cost_direct

		-- indicator for record adjusted if investigation required
		--,IIF(1.0 * [cyf_cec_direct_gross_amt] / duration_fixed > 10000, 1, 0) AS adj
	FROM duration_fix AS a
	WHERE cyf_cec_data_quality_issue_code = 'NO'
	AND YEAR([cyf_cec_event_start_date]) BETWEEN 2019 AND 2023

)
--Adjust nominal costs to real (2024 dollars) based on CPI
--The OT costs are based on a 2015 time use survey, and are therefore in 2015 dollars. Need to escalate to 2024
SELECT snz_uid
    , source
    , a.cal_year
    , COUNT(*) AS value
    , SUM((ot_cost_indirect + ot_cost_direct) * cpi_adj_2024) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_care_protection_youth_justice]
FROM cost_fix AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON b.cal_year = 2015
GROUP BY snz_uid
    , source
    , a.cal_year

