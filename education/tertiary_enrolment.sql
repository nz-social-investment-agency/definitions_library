/**************************************************************************************************
Title: Spell enrolled in tertiary education
Author: Simon Anastasiadis
Modified by Dan Young for data for communities project, Verity Warn for Regional Data Project
Peer Review: Ashleigh Arendt

Inputs & Dependencies:
- [IDI_Clean_202506].[moe_clean].[enrolment]
- [IDI_Clean_202506].[moe_clean].[course]
- [IDI_Clean_202506].[moe_clean].[tec_it_learner]

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
   Some withdrawl dates from courses can be retrieved from [moe_clean].[course] where this   
   is important. Withdrawls from industry training are not available.
3) When aggregating by region this will likely coincide with tertiary education providers (e.g. Universities Auckland, Wellington, Christchurch, Dunedin)
4) Full time is prioritised over part time. If someone has both full- and part-time study they are recorded as full-time for that
   quarter (as they're essentialy doing more-than full-time).
5) Using 202310 refresh wouldn't recommend using data after 2020Q4 as coverage drops dramatically (lose about 80%)
6) Where nulls exist in the end_dates for industry training, the end date for the last year reported on for the individual and training provider are imputed.
7) As tertiary enrollment spells can overlap, when computing duration, need to use the merged spells table.

Parameters & Present values:
  Current refresh = 202506
  Prefix = defn_
  Project schema = [DL-MAA2023-46]



Issues:
1) Industry training duration of enrollment can differ widely from expected duration of
   course. We are yet to determine how best to reconcile this difference. At present we consider
   only enrollment.
2) Lag in both Tert and TEC datasets - 202410 Refresh latest date 202312

History (reverse order):
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
SELECT enr.snz_uid
    , CAST([moe_enr_provider_code] AS INT) AS provider_code
    , 'tertiary' AS [source]
    , [moe_enr_prog_start_date] AS [start_date] -- [moe_enr_prog_start_date] has no NULLs
    , CASE WHEN [moe_crs_withdrawal_date] IS NOT NULL AND [moe_crs_withdrawal_date] < [moe_enr_prog_end_date] THEN [moe_crs_withdrawal_date] ELSE [moe_enr_prog_end_date] END AS [end_date] -- [moe_enr_prog_end_date] has no NULLs
    , 1 AS tertiary_study_any -- this will include those with NULL as study_type_code (meaning 'non applicable (non type D courses)') who are not included elsewhere
    , 1 AS tertiary_excl_ITO
	, NULL AS tertiary_ITO
	, CASE WHEN [moe_enr_study_type_code] IN (3,4) THEN 1 ELSE NULL END AS tertiary_study_part_time
    , CASE WHEN [moe_enr_study_type_code] NOT IN (3,4) THEN 1 ELSE NULL END AS tertiary_study_full_time -- approximating 120 credits (for full time) times .03 as a minimum threshold

FROM [IDI_Clean_202506].[moe_clean].[enrolment] enr
LEFT JOIN [IDI_Clean_202506].[moe_clean].[course] crs
ON enr.snz_uid = crs.snz_uid
AND enr.[moe_enr_snz_unique_nbr] = crs.[moe_crs_snz_unique_nbr]
AND enr.[moe_enr_prog_start_date] = crs.[moe_crs_start_date]
WHERE moe_enr_qual_type_code = 'D' -- include formal education of more than 1 week duration and .03 EFTS

UNION ALL

/*Enrolment in industry training*/
SELECT [snz_uid]
    , [provider_code]
    , 'tec_it_learner' AS [source]
    , [start_date]
    , COALESCE([moe_itl_end_date], end_date_proxy) AS end_date --where end_date is NULL, impute the end date as the last day of the final year of recorded participation
	, 1 AS tertiary_study_any
	, NULL AS tertiary_excl_ITO
	, 1 AS tertiary_ITO
	, NULL AS tertiary_study_part_time
	, NULL AS tertiary_study_full_time
FROM 
(
    SELECT [snz_uid]
        , CAST([moe_itl_ito_edumis_id_code] AS INT) AS provider_code
        , [moe_itl_start_date] AS [start_date] -- [moe_itl_start_date] has no NULLs
		, [moe_itl_end_date]
		, DATEADD(MONTH,moe_itl_duration_months_nbr,[moe_itl_start_date]) AS end_date_proxy
    FROM [IDI_Clean_202506].[moe_clean].[tec_it_learner]
    WHERE [moe_credit_value_nbr] >= 40 -- approximateing 120 credits (for full time) times .03 as a minimum threshold
)k
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
	, s.provider_code
INTO [SIA_Sandpit].[DL-MAA2023-46].[defn_any_tertiary_study_202506]
FROM spell_starts s
INNER JOIN spell_ends e
ON s.snz_uid = e.snz_uid
AND s.[start_date] <= e.[end_date]
GROUP BY s.snz_uid, s.[start_date], s.provider_code
GO

/* Add index */
CREATE NONCLUSTERED INDEX my_index_name ON [SIA_Sandpit].[DL-MAA2023-46].[defn_any_tertiary_study_202506] (snz_uid)
GO

