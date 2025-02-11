/**************************************************************************************************
Title: Stand downs, suspensions, exclusions and expulsions (SSEE's) 
Author: Ashleigh Arendt

Inputs & Dependencies:
- [IDI_Clean_202210].[moe_clean].[student_interventions]
Outputs:
- [IDI_Sandpit].[DL-MAA2023-55].[defn_student_interventions]

Description:
	This code identifies students who have experiencied stand downs or suspensions in the past 12 months.

Intended purpose:
	Student attendance and engagement are critical factors relating to student achievement. 
	The levels of SSEE's help provide indications of where engagement in productive learning may be absent and students are missing out on their education.

Notes:
0) Common acronym: SSEE = stand-downs, suspensions, exclusions & expulsions
1) It's important to note that SSEE's are not a measure of student behaviour, but measures of a school's reaction to such behaviours.
2) Following advice from Claire Davies at MoE on 12/4/24 we are reporting the number of students who experienced an SSEE rather than the number of individual events.
3) Please refer to legislation on SSEE's - sections 78-89 of the Education and Training Act 2020
4) If you wish to use this code to look at exclusions there is code commented out that will do this - not these are a subset of the suspensions

Parameters & Present values:
  Current refresh = 202310
  Prefix = defn_
  Project schema = [DL-MAA2023-55]

Issues:
- SSEE rates vary greatly with age, they should ideally be age-standardised to account for differing
	numbers of people at each age, due to suppression limitations we instead split into primary school
	and secondary school ages
- Note from Jane Krause on 17/4/24: the ministry have been completing an IDI remediation project
	over the past 18 months to improve level of their data quality. To date they have not remediated
	the student intervention file.

Runtime (before adding to master): 

History (reverse order):
2024-04-15 - Code adapted from Andrew Webber's Alt Ed work
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[defn_student_interventions]
GO

WITH ssee_events AS (

	SELECT a.snz_uid
		, a.moe_inv_start_date AS startdate
		, a.moe_inv_inst_num_code
		, CASE WHEN a.moe_inv_end_date > GETDATE()THEN GETDATE() ELSE a.moe_inv_end_date END AS enddate
		, CASE WHEN a.moe_inv_intrvtn_code = 8 THEN 1 ELSE 0 END AS standdown
		, CASE WHEN a.moe_inv_intrvtn_code = 7 THEN 1 ELSE 0 END AS suspension
		, CASE WHEN a.moe_inv_intrvtn_code IN (7,8) THEN 1 ELSE 0 END AS sd_sus
		--,CASE WHEN a.moe_inv_intrvtn_code = 7 AND a.moe_inv_standwn_susp_type_code IN (5,6,7,13) THEN 1 ELSE 0 END AS exclusion 
		, moe_inv_inst_num_code AS education_entity
	FROM [IDI_Clean_202406].[moe_clean].[student_interventions] AS a
	WHERE a.moe_inv_intrvtn_code IN (7,8)

)
-- Flag experienced in time period
SELECT a.snz_uid
    , MAX(IIF(a.standdown = 1, 1, NULL)) AS stood_down
	, SUM(IIF(a.standdown = 1, 1, NULL)) AS num_stood_down
    , MAX(IIF(a.suspension = 1, 1, NULL)) AS suspended
	, SUM(IIF(a.suspension = 1, 1, NULL)) AS num_suspended
    , MAX(IIF(a.sd_sus = 1, 1, NULL)) AS edu_excluded
	, SUM(IIF(a.sd_sus = 1, 1, NULL)) AS num_edu_excluded
	, STRING_AGG(entity, ';') AS entity
INTO [IDI_Sandpit].[DL-MAA2023-55].[defn_student_interventions]
FROM ssee_events AS a
WHERE a.startdate BETWEEN '2022-01-01' AND '2022-12-31' -- date range of interest for the intervention
GROUP BY snz_uid

