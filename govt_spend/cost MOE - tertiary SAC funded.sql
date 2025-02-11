/**************************************************************************************************
Title: Costs- Tertiary SAC funded
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[moe_clean].[enrolment]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_

Description:
	Enrollment in Tertiary study eligable for government funding

Notes:
- No costs in this definition right now
	A method was designed but not currently relevant

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-13 CWright version 1
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_tertiary_enrollment]
GO

WITH events_setup As (

	SELECT DISTINCT snz_uid
		, [moe_enr_year_nbr] AS cal_year
		, 'TER' source
		, CAST(a.moe_enr_qual_level_code AS int)AS value
		, a.moe_enr_provider_code AS entity
	FROM [IDI_Clean_202410].[moe_clean].[enrolment] AS a
	WHERE [moe_enr_year_nbr] IN('2019','2020','2021','2022','2023')

)
-- dedupe and aggregate entityes
SELECT snz_uid
    , source
    , cal_year
    , MAX(IIF(value BETWEEN 0 AND 10, value, 0)) AS value -- highest qual enrolled in that you
    , STRING_AGG(entity, ';') AS entity
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_tertiary_enrollment]
FROM events_setup
GROUP BY snz_uid
    , source
    , cal_year


