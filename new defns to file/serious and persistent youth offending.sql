/**************************************************************************************************
Title: Serious and Persistent youth offenders (SPYO)
Author: Anna and Jeremy MOJ

Inputs & Dependencies:
	[IDI_Metadata_202403].[moj].[offence_code]
	[IDI_Clean_202403].[pol_clean].[pre_count_offenders]
	[IDI_Clean_202403].[msd_clean].[msd_child]
	[IDI_Clean_202403].[msd_clean].[msd_partner]
	[IDI_Clean_202403].[dia_clean].[births]
	[IDI_Clean_202403].[wff_clean].[fam_children]
	[IDI_Clean_202403].[wff_clean].[fam_return_parents] 
	[IDI_Clean_202403].[data].[personal_detail]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_serious_persistent_youth_offending]

Description:
	Offending by youth that is both (1) serious and (2) persistent.

Notes:
- SPYO is defined as committing 3 or more distinct offending events within 12 months (persistent)
	where at least one of those offences committed has a max penalty >= 7 years imprisonment (serious). 

- Major changes from original
		- introducing "primary proceedings" 
		- centering the code around proceedings and proceedings dates instead of occurrences
		- deleting a condition for excluding duplicate occurrences
		- joining serious offences on offence codes instead of anzsoc codes
		- adjusting the CYP age definition.

Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-08-22 PMok
2024-08-21 Craig W review
Anna and Jeremy MOJ - ?
**************************************************************************************************/

---------------------------------------------------------------------
-- Select serious offences

DROP TABLE IF EXISTS #youth_offences

;WITH seven_plus_years AS (

	SELECT DISTINCT seriousnessscore AS seriousness_score
		, MAXYEARS AS max_penalty
		, OFFENCE_CODE AS offence_code
		--, [offence_code_description]
		--, [anzsoc]
		, 1 AS seven_plus_years
	FROM [IDI_Metadata_202403].[moj].[offence_code]
	WHERE [MAXYEARS] >= 7

)
-- Select all proceedings for CYP, since 1 July 2009
SELECT snz_uid
    , snz_pol_offence_uid
    , pol_pro_birth_year_nbr
    , pol_pro_age_at_occurrence_code
    , b.seven_plus_years
    , pol_pro_proceeding_date
    , ROUND(seriousness_score,0) AS seriousness_score
    , ROUND(max_penalty, 0) AS max_penalty
INTO #youth_offences
FROM [IDI_Clean_202403].[pol_clean].[pre_count_offenders] AS a
LEFT JOIN seven_plus_years AS b
ON a.pol_pro_offence_code = b.offence_code
WHERE (
	[pol_pro_age_at_occurrence_code] BETWEEN 10 AND 13
	AND [pol_pro_age_at_proceeding_code] <= 17
)
/* Children */
OR (
    [pol_pro_age_at_occurrence_code] BETWEEN 14 AND 16
    AND [pol_pro_age_at_proceeding_code] <= 17
)
/* Young people before 1 July 2017 */
OR (
	[pol_pro_proceeding_date] >= '2017-07-01'
	AND [pol_pro_age_at_occurrence_code] = 17
	AND [pol_pro_age_at_proceeding_code] <= 18 /* Adding 17 yos as young people after 1 July 2017 */
)


---------------------------------------------------------------------
-- Select "primary proceedings"
-- proceeding for the most serious offence on a proceeding date

DROP TABLE IF EXISTS #primary_proceedings

;WITH ranked_youth_offences AS (

	SELECT *
		, ROW_NUMBER() OVER (
			PARTITION BY snz_uid, pol_pro_proceeding_date
			ORDER BY snz_uid, pol_pro_proceeding_date, pol_pro_age_at_occurrence_code, max_penalty DESC, seriousness_score DESC, snz_pol_offence_uid
		) AS primary_offence
	FROM #youth_offences

)
SELECT snz_uid
    , pol_pro_proceeding_date AS proc_date
	, MAX(seven_plus_years) AS serious_indicator
INTO #primary_proceedings
FROM #youth_offences
WHERE primary_offence = 1
GROUP BY snz_uid, pol_pro_proceeding_date

---------------------------------------------------------------------
-- Serious and persistent offending

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_serious_persistent_youth_offending] 

;WITH recent_proceedings AS (

	-- Select proceedings which occurred within a year
	SELECT a.snz_uid
		, a.proc_date
		, COUNT(*) AS num_proceedings_in_last_year
		, SUM(b.serious_indicator) AS num_serious_offences
	FROM #primary_proceedings AS a
	INNER JOIN #primary_proceedings AS b
	ON a.snz_uid = b.snz_uid
	AND b.proc_date BETWEEN DATEADD(YEAR,-1,a.proc_date) AND a.proc_date

)
SELECT snz_uid
	, proc_date
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_serious_persistent_youth_offending]
FROM recent_proceedings
WHERE num_proceedings_in_last_year >= 3
AND num_serious_offences >= 1
