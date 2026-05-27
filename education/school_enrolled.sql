/**************************************************************************************************
Title: enrolled in School
Author: Ashleigh Arendt
Peer review: Charlotte Rose

Inputs & Dependencies:
- [IDI_Clean_202506].[moe_clean].[student_enrol] - this can be generated as part of the school attendance code module

Outputs:
- [IDI_UserCode].[DL-MAA2023-46].[defn_school_enrolled_202506]
- [IDI_UserCode].[DL-MAA2023-46].[defn_school_enrolled_no_overlaps_202506]

Description:
Indication of whether a child was enrolled in school as indicated by moe's student enrol dataset.

Intended purpose:
Get base populations to calculate rates for children's interactions with the school system.

Notes:
1) The student enrol data should have been updated within 5 days of a student joining
2) We are including children who attend private schools in our base population where we have enrolment data for them.
3) Primary and secondary school ages are determined with the following logic:
	- If someone is in year 1-8 AND between the ages of 5-13 inclusive then they are assigned to primary school, 
	or else if they are not in year 9-15 and are of primary school age (5-12) then they are assigned to primary school
	- If someone is in year 9-15 AND between the ages of 12 to 18 inclusive then they are assigned to secondary school,
	or else if they are not in year 1-8 and are of secondary school age (13-18) then they are assigned to secondary school
4) Excludes 1 day enrolments as recommended by MoE
5) Concurrent enrollment at more than one school is possible:
	In some cases this is due to enrollment at an Alternative Education Provider or Teen Parent Unit that is hosted
	within a school - the student is enrolled at both the specialist school and the host school.
	In other cases this is because of differences in the timing of enrollment and unenrollment. For example, a student
	may change schools but the old school only unenrolls them several weeks after they enrolled at the new school.
6) Concurrent enrollment hinders straightforward calculation of duration enrolled.
	Hence additional work is done to end previous enrollments when new enrollments start.
	We take this approach rather than merging spells because it allows us to preserve education provider entity IDs,
	which are needed for confidentiality purposes.
	When tested runtime was only 30 seconds, so saving as View rather than table.


Parameters & Present values:
  Current refresh = 202506
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
  Earliest start date = 2007

Issues: 
- Data quality issues for student_enrol prior to 2007
- There are some children with unrealistic school years
- Extraction appears to be annual in August, therefore will only be updated in October refreshes. Max enrolment dates (by complete quarter) for refreshes are below:
	202303 Q22022
	202306 Q22022
	202310 Q22023
	202403 Q22023
	202406 Q22023
	202410 Q22024


 Runtime (before joining to master) - 00:04:17
 Runtime (joining to master) - 01:58:59 

History (reverse order):
2025-09-19 CR adding back in private and correspondence schools for better coverage
2025-09-19 SA revise to enable duration
2023-03-14 - AA
**************************************************************************************************/

USE IDI_UserCode
GO

DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_school_enrolled_202506]
GO

CREATE VIEW [DL-MAA2023-46].[defn_school_enrolled_202506] AS
SELECT a.snz_uid
    , a.moe_esi_provider_code
	, a.moe_esi_entry_year_lvl_nbr
	, a.moe_esi_start_date
	, COALESCE(a.moe_esi_end_date,'9999-12-31') AS moe_esi_end_date
FROM [IDI_Clean_202506].[moe_clean].[student_enrol] a
LEFT JOIN [IDI_Clean_202506].[moe_clean].[provider_profile] b
	ON a.moe_esi_provider_code = b.moe_pp_provider_code
LEFT JOIN [IDI_Clean_202506].[moe_clean].[student_per] c
	ON a.snz_uid = c.snz_uid
WHERE DATEDIFF(DAY, moe_esi_start_date,  COALESCE(a.moe_esi_end_date,'9999-12-31')) ! = 1 -- exclude one day enrolments
--AND(
--    b.moe_pp_provider_auth_code NOT IN (42002, 42003)
--    OR b.moe_pp_provider_auth_code IS NULL
--) -- exclude private schools
--AND(
--    b.moe_pp_provider_type_code NOT IN (10031)
--    OR b.moe_pp_provider_type_code IS NULL
--)  -- exclude correspondence schools
AND(
    c.moe_spi_domestic_status_code != 60004
    OR c.moe_spi_domestic_status_code IS NULL
) -- exclude foreign fee paying students
GO

---------------------------------------------------------------------------------------------------
-- Removing overlaps

DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_school_enrolled_no_overlaps_202506]
GO

CREATE VIEW [DL-MAA2023-46].[defn_school_enrolled_no_overlaps_202506] AS
WITH
add_row_number AS (

	SELECT *
		,ROW_NUMBER() OVER (PARTITION BY snz_uid ORDER BY moe_esi_start_date, moe_esi_end_date, moe_esi_provider_code) AS row_num
	FROM [IDI_UserCode].[DL-MAA2023-46].[defn_school_enrolled_202506]

),
trimmed_end_date AS (

	SELECT a.snz_uid
		, a.moe_esi_provider_code
		, a.moe_esi_entry_year_lvl_nbr
		, a.moe_esi_start_date
		, IIF(
			b.moe_esi_start_date IS NOT NULL AND b.moe_esi_start_date <= a.moe_esi_end_date, -- if there is a start date and it is before the end date
			DATEADD(DAY, -1, b.moe_esi_start_date), -- then one day before the next start date
			a.moe_esi_end_date -- else the original end date
		) AS moe_esi_end_date
	FROM add_row_number AS a
	LEFT JOIN add_row_number AS b
	ON a.snz_uid = b.snz_uid
	AND a.row_num + 1 = b.row_num

)
SELECT *
FROM trimmed_end_date
WHERE moe_esi_start_date < moe_esi_end_date
GO
