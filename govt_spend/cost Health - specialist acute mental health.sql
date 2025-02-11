/**************************************************************************************************
Title: Fiscal costs - Specialist acute mental health and addications services
Author: Craig Wright


Inputs & Dependencies:
	[IDI_Clean_202410].[moh_clean].[primhd]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_calendar_years]
	[IDI_Adhoc].[clean_read_MOH_PRIMHD].[moh_primhd_pu_pricing_20170720]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cst_specialist_mental_health]

Description:
	The purpose of this is to estimate the costs incurred for specialist MHA services. 

Notes:
- The base method comes from a 2015 paper from MOH, involving experts costing activities in specialist mental health providers.
	This created a series of relative weights for different activities (which were loaded as an adhoc load in the IDI).
	The relative weights are combined with the service use data and the annual budget for MHA services to estimate a 
	cost per activity.
- Note that the costs exclude forensic services and seclusions because these were excluded from the original 
	2015 costing exercise.
- The 2015 nominal costs have been converted to real via the CPI.

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-18	CW	added entities - primhd team code as initity field
2024-11-18	AW	Documentation
2024-11-18	CW	Add cost allocation from 2015 method by moh
2024-11-11	CW	Initial creation
**************************************************************************************************/


--Create table for creating an indicator for whether someone was referred to MHA services within the particular year
--This is to populate a "value" field, which will complement the "cost" field, as a more general social outcome indicator

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cst_specialist_mental_health]
GO

WITH cal_year_mapping AS(

	-- handle time periods that run over multiple years
    SELECT [snz_uid]
        , [moh_mhd_referral_start_date]
        , COALESCE([moh_mhd_referral_end_date], [moh_mhd_activity_end_date]) AS end_date
        , a.moh_mhd_team_code
        , a.moh_mhd_activity_setting_code
        , a.moh_mhd_activity_type_code
        , a.moh_mhd_activity_unit_type_text
        , a.moh_mhd_activity_start_date
        , a.moh_mhd_activity_unit_count_nbr
        , b.cal_year
    FROM [IDI_Clean_202410].[moh_clean].[primhd] AS a
    INNER JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_calendar_years] AS b
    ON a.[moh_mhd_referral_start_date] <= b.end_date
    AND b.start_date <= COALESCE(a.[moh_mhd_referral_end_date], a.[moh_mhd_activity_end_date])
    WHERE b.YEAR BETWEEN 2019 AND 2023

),
event_costing AS (

	SELECT snz_uid
		, a.cal_year
		, moh_mhd_activity_unit_type_text AS source
		-- moh_mhd_activity_unit_count_nbr = 1 for single events, and not-1 for duration events
		-- 365 limit ensures that multi-year durations can report no more than a full year
		, IIF(a.moh_mhd_activity_unit_count_nbr > 365, 365, a.moh_mhd_activity_unit_count_nbr) AS value
		, moh_mhd_team_code AS entity
		, c.activity_price
	FROM cal_year_mapping AS a
	LEFT JOIN [IDI_Adhoc].[clean_read_MOH_PRIMHD].[moh_primhd_pu_pricing_20170720] AS c
	ON YEAR(c.start_date) = 2013
	AND a.moh_mhd_activity_unit_type_text = c.activity_unit_type
	AND a.moh_mhd_activity_setting_code = c.activity_setting_code
	AND a.moh_mhd_activity_type_code = c.activity_type_code

),
--Adjust nominal costs to real (2024 dollars) based on CPI
dedup_entity AS(
    

    SELECT snz_uid
        , source
        , cal_year
        , SUM(value * activity_price * cpi_adj_2024) AS cost_real
        , SUM(value)AS value
        , entity
    FROM event_costing AS a
    LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
    ON b.cal_year = 2013
    GROUP BY snz_uid
        , source
        , a.cal_year
        , entity -- group by entity, ensures that STRING_AGG entity only contains distinct entities

)
SELECT snz_uid
    , source
    , cal_year
    , SUM(cost_real)AS cost_real
    , SUM(value)AS value
    , STRING_AGG(entity, ';') AS entity
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cst_specialist_mental_health]
FROM dedup_entity
GROUP BY snz_uid
    , source
    , cal_year
