/**************************************************************************************************
Title: Alternative Education
Author: Lexi XU

Inputs & Dependencies:
	[IDI_Clean_202506].[moe_clean].[student_interventions]
	[IDI_Clean_202506].[moe_clean].[student_enrol]
	[IDI_Metadata_202506].[moe_school].[intervention_type_code]

Description: 
-- This view identifies students who received an Alternative Education intervention ([moe_inv_intrvtn_code] = 6)
-- Including each student's intervention periods and the school they were enrolled in at that time.
-- A student is included only if their school enrolment overlapped with the intervention period.

Intended purpose:
Indicator for cohort analysis which show students who placed in alternative education and link to their school 
enrolment at the time
Not suitable for duration calculations in its present form.

Note:
-- Students with no matching enrolment data are excluded, as we cannot determine their school context.
-- End dates for interventions are NULL, 9999, and 1900 in the raw data.
	Best guess is that these records reflect inconistent handling of ongoing interventions.
	If the start date is recent (>2020), then such end dates are set to today's date.
	If the start date is older, then assumed end date was never provided and discard record as incomplete.

Parameters & Present values:
  Current refresh = 202506
  Project schema = [DL-MAA2023-46]

History (reverse order):
2025-06-19 LX v1
2025-06-23 LX & SA update with improved end dates
**************************************************************************************************/

USE IDI_UserCode
GO

DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_alternative_education_202506]
GO

CREATE VIEW [DL-MAA2023-46].[defn_alternative_education_202506] AS
WITH student_intervention_setup AS (
	SELECT snz_uid
		,[moe_inv_intrvtn_code]
		,[moe_inv_start_date]
		,CASE -- all reference dates become today's date
			WHEN [moe_inv_end_date] IS NULL THEN GETDATE()
			WHEN YEAR([moe_inv_end_date]) = 1900 THEN GETDATE()
			WHEN YEAR([moe_inv_end_date]) = 9999 THEN GETDATE()
			ELSE [moe_inv_end_date]
			END AS [moe_inv_end_date]
	FROM 
		[IDI_Clean_202506].[moe_clean].[student_interventions]
	WHERE
		YEAR([moe_inv_start_date]) <> 1900
		-- exclude records with inconsistent end dates (effects <200 records, <0.1% of records)
		AND (
			YEAR([moe_inv_end_date]) < 9999
			OR (YEAR([moe_inv_start_date]) > 2020 AND YEAR([moe_inv_end_date]) = 9999)
			OR (YEAR([moe_inv_start_date]) > 2020 AND [moe_inv_end_date] IS NULL)
			)
)
SELECT 
    si.[snz_uid]
   ,[moe_inv_intrvtn_code] AS intervention_type_id
   ,t.InterventionName AS intervention_type_name
   ,[moe_inv_start_date]  AS start_date
   ,CAST([moe_inv_end_date]AS DATE) AS end_date
   ,[moe_esi_provider_code]
FROM 
	student_intervention_setup AS si	
INNER JOIN 
	[IDI_Metadata_202506].[moe_school].[intervention_type_code] AS t 
	ON t.InterventionID = si.moe_inv_intrvtn_code
INNER JOIN
	[IDI_Clean_202506].[moe_clean].[student_enrol] AS e
	ON si.snz_uid = e.snz_uid
	AND moe_esi_start_date <= moe_inv_end_date
	AND moe_inv_start_date <= moe_esi_end_date
WHERE 
	si.[moe_inv_intrvtn_code] = 6  -- alternative education
GO


