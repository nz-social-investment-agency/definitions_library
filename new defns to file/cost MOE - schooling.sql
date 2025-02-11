/**************************************************************************************************
Title: Schooling enrollments
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Sandpit].[DL-MAA2023-46].[ref_calendar_years]
	[IDI_Clean_202410].[moe_clean].[student_enrol]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_schooling]

Description:
	Enrollment in compulsory schooling (primary, intermediate, and secondary)

Notes:
- Costs not currently included

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-13 CWright version 1
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_schooling]
GO

--This is necessary to apportion multi-year spells into the duration that occurs in each calendar year
WITH year_range AS(
    
    SELECT cal_year
        , start_date AS yr_start
        , end_date AS yr_end
    FROM [IDI_Sandpit].[DL-MAA2023-46].[ref_calendar_years]
    WHERE cal_year BETWEEN 2019 AND 2023

),
enrollment_events AS (

	SELECT DISTINCT snz_uid
		, cal_year
		, 'ENR' source
		, moe_esi_start_date AS start_date
		, COALESCE(moe_esi_end_date, moe_esi_extrtn_date) AS end_date
		, a.moe_esi_provider_code AS entity
		, IIF(moe_esi_start_date <= yr_start, yr_start, moe_esi_start_date) AS trim_start -- latest start date
		, IIF(COALESCE(moe_esi_end_date, moe_esi_extrtn_date) <= yr_end, COALESCE(moe_esi_end_date, moe_esi_extrtn_date), yr_end) AS trim_end -- earliest end date
	FROM [IDI_Clean_202410].[moe_clean].[student_enrol] AS a
	INNER JOIN year_range AS b
	ON moe_esi_start_date <= yr_end
	AND yr_start <= COALESCE(moe_esi_end_date, moe_esi_extrtn_date)

),
dedupe_entities AS(

    SELECT snz_uid
        , source
        , cal_year
        , entity
        , SUM(DATEDIFF(DAY, trim_start, trim_end)) AS duration
    FROM enrollment_events
    GROUP BY snz_uid
        , source
        , cal_year
        , entity

)
SELECT snz_uid
    , source
    , cal_year
    , SUM(duration)AS value
    , STRING_AGG(entity, ';') AS entity
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_schooling]
FROM dedupe_entities
GROUP BY snz_uid
    , source
    , cal_year

