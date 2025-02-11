/**************************************************************************************************
Title: Structural moves between schools
Author: Andrew Webber

Description:
Comparing cases where students make structural shift from one school to another.
Structural moves are a movement between schools forced by the structure of the schooling system
(e.g. a student moving between primary and intermediate, or intermediate and secondary school).

Inputs & Dependencies:
	[IDI_Clean_202210].[moe_clean].[student_enrol]
	[IDI_Metadata].[clean_read_CLASSIFICATIONS].[moe_Provider_Profile_20190830]
	[IDI_Metadata_202210].[moe_school].[provider_type_code]
	[IDI_Metadata_202210].[moe_school].[sch_region_code]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-40].[defn_structural_school_moves]

Notes:

Parameters & Present values:
  Current refresh = 202210
  Prefix = defn_
  Project schema = MAA2023-46
 
Issues:

History (reverse order):
2025-01-21 SA: extraction from surrounding analysis
2023-03-06 AW: version 1
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-40].[defn_structural_school_moves]

WITH school_spells AS (

	SELECT a.*
		, b.providertypeid
		, c.ProviderType
		, b.decilecode
		, b.schoolregionid
		, d.SchoolRegion
		, ROW_NUMBER() OVER (PARTITION BY a.snz_uid ORDER BY a.moe_esi_start_date, a.moe_esi_end_date) AS rn
	FROM [IDI_Clean_202210].[moe_clean].[student_enrol] AS a
	LEFT JOIN [IDI_Metadata].[clean_read_CLASSIFICATIONS].[moe_Provider_Profile_20190830] AS b
	ON a.moe_esi_provider_code = b.ProviderNumber
	LEFT JOIN [IDI_Metadata_202210].[moe_school].[provider_type_code] AS c
	ON b.ProviderTypeId = c.ProviderTypeId
	LEFT JOIN [IDI_Metadata_202210].[moe_school].[sch_region_code] AS d
	ON b.SchoolRegionId = d.SchoolRegionID

)
SELECT a.*
    , IIF(a.moe_esi_provider_code != b.moe_esi_provider_code, 1, 0) AS any_move

	-- start school is Y1-6, next school is Y1-8/7-8/7-10/7-13/1-13/9-13, moving into Y7 or above
	, IIF(
		a.moe_esi_provider_code != b.moe_esi_provider_code
		AND b.providertypeid = 10024
		AND a.providertypeid IN (10023, 10025, 10032, 10029, 10030, 10033)
		AND a.moe_esi_entry_year_lvl_nbr >= 7,
		1, 0) AS structural_move_Y7

	-- start school is Y1-8, next school is Y7-10/7-13/1-13/9-13, moving into Y9 or above
	, IIF(
		a.moe_esi_provider_code != b.moe_esi_provider_code
		AND b.providertypeid = 10023
		AND a.providertypeid IN (10032, 10029, 10030, 10033)
		AND a.moe_esi_entry_year_lvl_nbr >= 9,
		1, 0) AS structural_move_Y9a

	-- start school is Y7-8, next school is Y7-10/7-13/1-13/9-13, moving into Y9 or above
	, IIF(
		a.moe_esi_provider_code != b.moe_esi_provider_code
		AND b.providertypeid = 10025
		AND a.providertypeid IN (10032, 10029, 10030, 10033)
		AND a.moe_esi_entry_year_lvl_nbr >= 9,
		1, 0) AS structural_move_Y9b

	-- start school is Y7-10, next school is Y7-13/1-13/9-13, moving into Y11 or above
	, IIF(
		a.moe_esi_provider_code != b.moe_esi_provider_code
		AND b.providertypeid = 10032
		AND a.providertypeid IN (10029, 10030, 10033)
		AND a.moe_esi_entry_year_lvl_nbr >= 11,
		1, 0) AS structural_move_Y11

	-- start school is home school, te kura, or special school, moving into any mainstream school
	, IIF(
		a.moe_esi_provider_code != b.moe_esi_provider_code
		AND (b.moe_esi_provider_code IN (972,498) OR a.providertypeid=10026)
		AND a.providertypeid IN (10024, 10023, 10025, 10032, 10029, 10030, 10033),
		1, 0) AS structural_move_to_main

	-- start school is a mainstream school, moving into home school, te kura, or special school
	, IIF(
		a.moe_esi_provider_code != b.moe_esi_provider_code
		AND b.providertypeid IN (10024, 10023, 10025, 10032, 10029, 10030, 10033)
		AND (a.moe_esi_provider_code IN (972,498) OR a.providertypeid=10026),
		1, 0) AS structural_move_from_main

INTO [IDI_Sandpit].[DL-MAA2023-40].[defn_structural_school_moves]
FROM school_spells AS a
LEFT JOIN school_spells AS b
ON a.snz_uid = b.snz_uid
AND a.rn-1 = b.rn
