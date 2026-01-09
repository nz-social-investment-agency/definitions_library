/**************************************************************************************************
Title: Spell enrolled in tertiary education
Author: Simon Anastasiadis
Modified by Dan Young for data for communities project, Verity Warn for Regional Data Project
Peer Review: Ashleigh Arendt

Inputs & Dependencies:
- [IDI_Clean_202506].[moe_clean].[enrolment]
- [IDI_Clean_202506].[moe_clean].[course]
- [IDI_Clean_202506].[moe_clean].[tec_it_learner]
- max_date MOE enrolment.sql >> [IDI_UserCode].[DL-MAA2023-46].[max_date_MOE_enrolment]
- max_date MOE tec_it_learner.sql >> [IDI_UserCode].[DL-MAA2023-46].[max_date_MOE_tec_it_learner]


Outputs/additions:
- [IDI_UserCode].[DL-MAA2023-46].[defn_tertiary_enrol_202506]
- [SIA_Sandpit].[DL-MAA2023-46].[defn_any_tertiary_study_202506]

Description:
Tertiary study includes the participation in one of universities, Te Pūkenga, wānanga, government-funded private training establishments and industry training.
This code creates an indication of whether a person has participated in tertiary study in a given time period, split by industry vs. non-industry training, 
as well as into part time or full time study for the 

A spell with any enrollment in tertiary education, regardless of source (tertiary education or industry training).
Seperate spells for part time, full time and both for non industry training (IT).

Intended purpose:
Creating indicators of whether a person is studying at a tertiary institution in a given quarter,
and whether this is part or full time.

Notes:
1) Writing a staging table (rather than a staging view) is faster as we can add an index.
2) [moe_clean].[enrolment] does not include cancellations/withdrawls. Hence it may overcount.
	Some withdrawl dates from courses can be retrieved from [moe_clean].[course]
	> Course withdrawls are used to shorten enroll times when all courses are withdrawn from.
	> Programme enrollments where all courses are withdrawn from before the course starts are dropped from results.
	> Withdrawls from industry training are not available.
3) When aggregating by region this will likely coincide with tertiary education providers (e.g. Universities Auckland, Wellington, Christchurch, Dunedin)
4) Metadata reports that programmes are constructed from courses, however method is not provided.
	To handle withdrawls, we join tertiary programmes and courses.
	This join is by person (snz_uid), provider, qualification, and date range.
	Provider and qualification are needed as some people can be enrolled at multiple providers or in multiple quals concurrently.
	Joining by date range requires course dates to be within programme dates.
	> Initial join used course overlaps with programme, but this produced duplication
	> If courses are used to produce programme, then reasonable to assume programme dates contain all course dates.
	There may be another column or columns needed for the join but we are yet to identify them.
5) Full time is prioritised over part time. If someone has both full- and part-time study they are recorded as full-time for that
   quarter (as they're essentialy doing more-than full-time).
6) Only type D courses are included (at least 1 week duration, 0.03 EFT)
7) Where nulls exist in the end_dates for industry training, the end date for the last year reported on for the individual and training provider are imputed.
8) As tertiary enrollment spells can overlap, when computing duration, need to use the merged spells table.
	As people can be enrolled with more than one provider at once, we take the min provider ID as a tie-breaker.


Parameters & Present values:
  Current refresh = 202506
  Prefix = defn_
  Project schema = [DL-MAA2023-46]



Issues:
1) Industry training duration of enrollment can differ widely from expected duration of
   course. We are yet to determine how best to reconcile this difference. At present we consider
   only enrollment.

History (reverse order):
2026-01-08 SA corrected handling of course withdrawls for early study end
2025-11-06 SA cap spell ends with max_dates
2025-07-25 SA Add merged spells for duration calculation
2024-05-09 AA Imputation for industry training end dates, removal of targeted training
2024-04-26 VW Updated to RDP refresh (202410), remove secondary enrolment, alter filters to add additional flags 
		      (part time, full time, any), filter dates to overlap with RDP quarters, remove spell overlap
			  condensing as only interested in if enrolled in the quarter (not duration) and want to preserve different 
			  spell types (part/full time) - replace with select distinct to remove some of these duplicate cases. 
2023-06-16 DY updated for latest refresh and incorporated join to master dataset for MT
2022-05-19 JG updated with provider code for entity count
2022-04-05 JG updated project and refresh for Data for Communities
2020-05-26 SA corrected to include secondary school enroll
2020-03-02 SA v1
**************************************************************************************************/
--Check max dates

 -- SELECT TOP 40 enr.moe_enr_prog_start_date
	--,COUNT(*)
 -- FROM [IDI_Clean_202506].[moe_clean].[enrolment] enr
 -- GROUP BY enr.moe_enr_prog_start_date
 -- Order by enr.moe_enr_prog_start_date desc

USE IDI_UserCode
GO

/**************************************************************************************
Tertiary
**************************************************************************************/

DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_tertiary_enrol_202506]
GO

/* Enrolment in tertiary education - [moe_enr_prog_start_date] and [moe_enr_prog_end_date] don't have NULLs*/
CREATE VIEW [DL-MAA2023-46].[defn_tertiary_enrol_202506] AS

-- CTE for max dates
WITH max_date_tertiary AS (
	SELECT TOP 1 max_date AS max_date_tertiary
	FROM [IDI_UserCode].[DL-MAA2023-46].[max_date_MOE_enrolment_202506]
),
max_date_ito AS (
	SELECT TOP 1 max_date AS max_date_ito
	FROM [IDI_UserCode].[DL-MAA2023-46].[max_date_MOE_tec_it_learner_202506]
),

/* Enrollment in tertiary institute */
tidy_courses AS (

	SELECT *
		-- refined end date if unenroll early
		,CASE
			WHEN [moe_crs_withdrawal_date] IS NULL THEN [moe_crs_end_date]
			WHEN [moe_crs_end_date] < [moe_crs_withdrawal_date] THEN [moe_crs_end_date]
			ELSE [moe_crs_withdrawal_date]
		END moe_crs_end_date_refined
		-- withdraws before programme start will crased end date earlier than start date

		, IIF([moe_crs_withdrawal_date] < [moe_crs_end_date], 1, 0) AS relevant_withdrawl
		, IIF([moe_crs_withdrawal_date] < [moe_crs_start_date], 1, 0) AS withdraw_before_start

	FROM [IDI_Clean_202506].[moe_clean].[course]

),
joined_all AS (

	SELECT enr.snz_uid
		,enr.moe_enr_year_nbr
		,enr.[moe_enr_provider_code]
		,enr.[moe_enr_study_type_code]
		,enr.[moe_enr_prog_start_date] -- [moe_enr_prog_start_date] has no NULLs
		,enr.[moe_enr_prog_end_date] -- [moe_enr_prog_end_date] has no NULLs

		,[moe_crs_start_date]
	    ,[moe_crs_end_date]
		,[moe_crs_withdrawal_date]
		,[moe_crs_end_date_refined]
		,[moe_crs_course_code]
		,relevant_withdrawl
		,withdraw_before_start

	FROM [IDI_Clean_202506].[moe_clean].[enrolment] AS enr
	LEFT JOIN tidy_courses AS crs
		ON enr.snz_uid = crs.snz_uid
		AND enr.moe_enr_provider_code = crs.moe_crs_provider_code
		AND enr.moe_enr_qual_code = crs.moe_crs_qual_code
		-- course must be within programme (not just overlapping, see notes)
		AND enr.[moe_enr_prog_start_date] <= crs.[moe_crs_start_date]
		AND crs.[moe_crs_end_date] <= enr.[moe_enr_prog_end_date]
	
	WHERE moe_enr_qual_type_code = 'D' -- include formal education of more than 1 week duration and .03 EFTS

)
SELECT snz_uid
    , CAST([moe_enr_provider_code] AS INT) AS provider_code
    , 'tertiary' AS [source]
    , [moe_enr_prog_start_date] AS [start_date]
	
	-- programme ends early if student withdraws from courses 
	, CASE
		WHEN MAX([moe_crs_end_date_refined]) < [moe_enr_prog_end_date] THEN MAX([moe_crs_end_date_refined])
		ELSE [moe_enr_prog_end_date]
		END AS [raw_end_date] -- [moe_enr_prog_end_date] has no NULLs

	-- end dates should not extend beyond max date otherwise potential confusion with partial observaiton of future enrollment
	, CASE
		WHEN MAX([moe_crs_end_date_refined]) < [moe_enr_prog_end_date]
			AND MAX([moe_crs_end_date_refined]) < max_date_tertiary
			THEN MAX([moe_crs_end_date_refined])
		WHEN [moe_enr_prog_end_date] < max_date_tertiary
			THEN [moe_enr_prog_end_date]
		ELSE max_date_tertiary
		END AS [end_date] -- End at dataset max_date

    , 1 AS tertiary_study_any
    , 1 AS tertiary_excl_ITO
	, NULL AS tertiary_ITO
	, MAX(IIF([moe_enr_study_type_code] IN (3,4), 1, NULL)) AS tertiary_study_part_time
    , MAX(IIF([moe_enr_study_type_code] NOT IN (3,4), 1, NULL)) AS tertiary_study_full_time -- approximating 120 credits (for full time) times .03 as a minimum threshold

	,COUNT(*) AS num_records
	,COUNT(moe_crs_course_code) AS num_courses
	,SUM(relevant_withdrawl) AS num_withdraws

FROM joined_all
CROSS JOIN max_date_tertiary
GROUP BY snz_uid, moe_enr_year_nbr, [moe_enr_provider_code], [moe_enr_prog_start_date], [moe_enr_prog_end_date], max_date_tertiary
-- exclude programmes where all courses were withdrawn from before programme start
HAVING NOT (
	COUNT(*) = SUM(ISNULL(withdraw_before_start, 0)) -- all joined courses are withdrawn before start
	AND SUM(ISNULL(withdraw_before_start, 0)) > 0 -- at least one course withdrawn before start
)

UNION ALL

/*Enrolment in industry training*/
SELECT [snz_uid]
    , [provider_code]
    , 'tec_it_learner' AS [source]
    , [start_date]
	--where end_date is NULL, impute the end date as the last day of the final year of recorded participation
    , COALESCE([moe_itl_end_date], end_date_proxy) AS raw_end_date

	, IIF(COALESCE([moe_itl_end_date], end_date_proxy) < max_date_ito, COALESCE([moe_itl_end_date], end_date_proxy), max_date_ito) AS [end_date]

	, 1 AS tertiary_study_any
	, NULL AS tertiary_excl_ITO
	, 1 AS tertiary_ITO
	, NULL AS tertiary_study_part_time
	, NULL AS tertiary_study_full_time

	,NULL AS num_records
	,NULL AS num_courses
	,NULL AS num_withdraws
FROM 
(
    SELECT [snz_uid]
        , CAST([moe_itl_ito_edumis_id_code] AS INT) AS provider_code
        , [moe_itl_start_date] AS [start_date] -- [moe_itl_start_date] has no NULLs
		, [moe_itl_end_date]
		, DATEADD(MONTH,moe_itl_duration_months_nbr,[moe_itl_start_date]) AS end_date_proxy
    FROM [IDI_Clean_202506].[moe_clean].[tec_it_learner]
    WHERE [moe_credit_value_nbr] >= 40 -- approximateing 120 credits (for full time) times .03 as a minimum threshold
) AS k
CROSS JOIN max_date_ito
GO

/**************************************************************************************
Merge spells for duration
**************************************************************************************/

/* Condensed spells */
DROP TABLE IF EXISTS [SIA_Sandpit].[DL-MAA2023-46].[defn_any_tertiary_study_202506]
GO

WITH
/* exclude start dates that are within another spell */
spell_starts AS (
	SELECT [snz_uid], [start_date], provider_code
	FROM [IDI_UserCode].[DL-MAA2023-46].[defn_tertiary_enrol_202506] AS s1
	WHERE [start_date] <= [end_date]
	AND NOT EXISTS (
		SELECT 1
		FROM [IDI_UserCode].[DL-MAA2023-46].[defn_tertiary_enrol_202506] AS s2
		WHERE s1.snz_uid = s2.snz_uid
		AND DATEADD(DAY, -1, s1.[start_date]) BETWEEN s2.[start_date] AND s2.[end_date]
	)
),
/* exclude end dates that are within another spell */
spell_ends AS (
	SELECT [snz_uid], [end_date]
	FROM [IDI_UserCode].[DL-MAA2023-46].[defn_tertiary_enrol_202506] AS t1
	WHERE [start_date] <= [end_date]
	AND NOT EXISTS (
		SELECT 1 
		FROM [IDI_UserCode].[DL-MAA2023-46].[defn_tertiary_enrol_202506] AS t2
		WHERE t2.snz_uid = t1.snz_uid
		AND t1.[end_date] BETWEEN DATEADD(DAY, -1, t2.[start_date]) AND DATEADD(DAY, -1, t2.[end_date])
	)
)
SELECT s.snz_uid
	, s.[start_date]
	, MIN(e.[end_date]) as [end_date]
	, MIN(s.provider_code) AS provider_code
INTO [SIA_Sandpit].[DL-MAA2023-46].[defn_any_tertiary_study_202506]
FROM spell_starts s
INNER JOIN spell_ends e
ON s.snz_uid = e.snz_uid
AND s.[start_date] <= e.[end_date]
GROUP BY s.snz_uid, s.[start_date]
GO

/* Add index */
CREATE NONCLUSTERED INDEX my_index_name ON [SIA_Sandpit].[DL-MAA2023-46].[defn_any_tertiary_study_202506] (snz_uid)
GO

