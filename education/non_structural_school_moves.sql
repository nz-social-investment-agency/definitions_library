/**************************************************************************************************
Title: Number of school moves
Author: Charlotte Rose
Peer review: Ashleigh Arendt

Inputs & Dependencies:
- [IDI_Clean_202506].[moe_clean].[student_enrol]
- [IDI_Clean_202506].[moe_clean].[provider_profile]
- [IDI_Metadata_202506].[moe_school].[provider_type_code] 
- [IDI_Metadata_202506].[moe_school].[sch_region_code]

Description:
Non-structural school changes for students.

*Structural moves are a movement between schools or kura forced by the structure of the schooling system 
(e.g. a student moving between primary and intermediate, or intermediate and secondary school)

Intended purpose:
This indicator shows the number of students who have had more than two non-structural school moves in a year.
Finding the number of students who have had more than two non-structural* school or kura moves more than twice in one school year. (MoE covers 1 March - 1 Nov as a 'year')

Notes:
1) Research has found students who move schools OR kura regularly are more likely to underachieve in formal education compared 
	with students with a more stable school life.
2) Results from this definition compared against MOE and OT:
	- MoE look at moves within the calendar year, between 1 Mar and 1 Nov.
	- OT have a similar indicator (WEL-31 dev-enrol) where they look at the prev 12mo,
		do not take into account primary to secondary as a structural move and do not filter 
		for moves between Mar & Nov.
	- OTs figures are slightyly higher than MoE, however reporting periods dont match.
	- Considering last 12 months with our defintion, moves within the school year (Mar - Nov), and not structural 
		We get ~35% lower numbers to OT for Q2 2021
		and about  ~30% less than MoEs annual figures when matched to our population
- School enrol table extraction appears to be annual in August, therefore will only be updated in October refreshes. Max enrolment dates (by complete quarter) for refreshes are below;
	202303 Q22022
	202306 Q22022
	202310 Q22023
	202403 Q22023
	202406 Q22023
	202410 Q22024

Parameters & Present values:
  Current refresh = 202506
  Prefix = defn_
  Project schema = [DL-MAA2023-55]
  Earliest start date = '2018-01-01'

Issues:

History (reverse order):
2025-06-18 - SA polish for Commissioning Cohorts
2024-05-01 - AA small tweaks to remove Alt Ed duplicates
2024-03-18 - CR adapted code from AW Alt ed analysis
**************************************************************************************************/ 

DROP TABLE IF EXISTS [SIA_Sandpit].[DL-MAA2023-55].[defn_school_changes_202506]
GO

----------------------------------------------------------------------------------------------------
-- all school spells
WITH schoolspells AS(

    SELECT DISTINCT e.snz_uid
        , e.snz_moe_uid
        , e.moe_esi_entry_year_lvl_nbr
        , e.moe_esi_provider_code
        , c.ProviderTypeId
        , c.ProviderTypeDescription AS [school_type]
        , e.moe_esi_start_date AS [date_started]
        , COALESCE(e.moe_esi_end_date, GETDATE()) AS [date_left] --imputing a dummy end date if still attending
        , e.moe_esi_extrtn_date AS [EXTRACT date]
    FROM [IDI_Clean_202506].[moe_clean].[student_enrol] e
    LEFT JOIN [IDI_Clean_202506].[moe_clean].[provider_profile] b
    ON e.moe_esi_provider_code = b.moe_pp_provider_code
    LEFT JOIN [IDI_Metadata_202506].[moe_school].[provider_type_code] c
    ON b.moe_pp_provider_type_code = c.ProviderTypeId

),
-- keep into period of interest
rank_schoolspells AS(

    SELECT *
        , ROW_NUMBER() OVER(PARTITION BY snz_uid ORDER BY date_started) AS [RANK]
    FROM schoolspells

)
-- specify whether move was structural OR not.
SELECT to_s.*
    , IIF(to_s.moe_esi_provider_code != from_s.moe_esi_provider_code, 1, 0) AS any_move
    , IIF(
		to_s.moe_esi_provider_code != from_s.moe_esi_provider_code
		AND (
			-- start school is Y1-6, next school is Y1-8/7-8/7-10/7-13/1-13/9-13, moving into Y7 OR above
			(
				from_s.ProviderTypeId = 10024
				AND to_s.ProviderTypeId IN (10023, 10025, 10032, 10029, 10030, 10033)
				AND to_s.moe_esi_entry_year_lvl_nbr >= 7
			)
			-- start school is Y1-8, next school is Y7-10/7-13/1-13/9-13, moving into Y9 OR above
			OR (
				from_s.ProviderTypeId = 10023
				AND to_s.ProviderTypeId IN (10032, 10029, 10030, 10033)
				AND to_s.moe_esi_entry_year_lvl_nbr >= 9
			)
			-- start school is Y7-8, next school is Y7-10/7-13/1-13/9-13, moving into Y9 OR above
			OR (
				from_s.ProviderTypeId = 10025
				AND to_s.ProviderTypeId IN (10032, 10029, 10030, 10033)
				AND to_s.moe_esi_entry_year_lvl_nbr >= 9
			)
			-- start school is Y7-10, next school is Y7-13/1-13/9-13, moving into Y11 OR above
			OR (
				from_s.ProviderTypeId = 10032
				AND to_s.ProviderTypeId IN (10029, 10030, 10033)
				AND to_s.moe_esi_entry_year_lvl_nbr >= 11
			)
			-- start school is home school, te kura, OR special school, moving into any mainstream school
			OR (
				(from_s.moe_esi_provider_code IN (972,498) OR to_s.ProviderTypeId=10026)
				AND to_s.ProviderTypeId IN (10024, 10023, 10025, 10032, 10029, 10030, 10033)
			)
			-- start school is a mainstream school, moving into home school, te kura, OR special school
			OR (
				from_s.ProviderTypeId IN (10024, 10023, 10025, 10032, 10029, 10030, 10033)
				AND (to_s.moe_esi_provider_code IN (972,498) OR to_s.ProviderTypeId=10026)
			)
			
		),
		1, 0) AS structural_move
    , CASE
		-- next school is alt Ed provider AND they started a new associated school within week of starting alt ed
		WHEN (to_s.school_type = 'Alternative Education Provider' OR from_s.school_type = 'Alternative Education Provider')
		AND DATEDIFF(DAY, from_s.date_started, to_s.date_started) < 7 THEN 1
		-- next school is Teen Parent Unit AND they started a new associated school within week of joining TPU
		WHEN (to_s.school_type = 'Teen Parent Unit' OR from_s.school_type = 'Teen Parent Unit' ) 
		AND DATEDIFF(DAY, from_s.date_started, to_s.date_started) < 7 THEN 1
			ELSE 0 END AS multipurpose_school
INTO [SIA_Sandpit].[DL-MAA2023-55].[defn_school_changes_202506]
FROM rank_schoolspells AS to_s
LEFT JOIN rank_schoolspells AS from_s
ON to_s.snz_uid = from_s.snz_uid
AND to_s.[RANK]-1 = from_s.[RANK]
GO

----------------------------------------------------------------------------------------------------
-- remove spells that are not of interest

DELETE FROM [SIA_Sandpit].[DL-MAA2023-55].[defn_school_changes_202506]
WHERE structural_move = 1 --not a stuctural move

DELETE FROM [SIA_Sandpit].[DL-MAA2023-55].[defn_school_changes_202506]
WHERE multipurpose_school = 1 --not teen parent OR alt ed duplicate

DELETE FROM [SIA_Sandpit].[DL-MAA2023-55].[defn_school_changes_202506]
WHERE any_move <> 1 -- must not be their first school
OR any_move IS NULL
GO

----------------------------------------------------------------------------------------------------
-- transcience is then indicated by 2+ school moves

CREATE NONCLUSTERED INDEX my_index_name ON  [SIA_Sandpit].[DL-MAA2023-55].[defn_school_changes_202506] ([snz_uid])
GO

ALTER TABLE [SIA_Sandpit].[DL-MAA2023-55].[defn_school_changes_202506] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
GO
