/**************************************************************************************************
Title: Attendance Service Support
Author: Lexi XU

Inputs & Dependencies:
	[IDI_Clean_202506].[moe_clean].[student_interventions]
	[IDI_Clean_202506].[moe_clean].[student_enrol]
	[IDI_Metadata_202506].[moe_school].[intervention_type_code]

Description: 
-- This view identifies students who referred to the attendence service for truancy (code 32) or non-enrollment (code 9)
-- Including each student's intervention periods and the school they were enrolled in at that time.

Intended purpose:
-- Identify student referred to the attendance, with enrolment status.

Note:
-- Students with no matching enrolment data are also included because non-enrollment referrals (code 9) target those not
   currently enrolled. Excluding them would miss the group the intervention aims top help.
   (This is why we use a LEFT JOIN rather than an INNER JOIN for the enrollments table)
-- Some students are enrolled at a school even while an intervention for non-enrollment takes place.
	Best guess is that intervention starts while not enrolled or not attending
	but during period of intervention enrollment / attendnace is addressed, so there is some overlap
	between enrollment and end of the intervention.
-- Some students show no enrollment despite receiving an internvetion due to non-attendance.
	Non-attendnace would imply that they are enrolled.
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

DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_attendance_service_support_202506] 
GO

CREATE VIEW [DL-MAA2023-46].[defn_attendance_service_support_202506] AS 
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
	FROM [IDI_Clean_202506].[moe_clean].[student_interventions]
	WHERE YEAR([moe_inv_start_date]) <> 1900
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
  ,[moe_inv_start_date] AS start_date
  ,CAST([moe_inv_end_date]AS DATE) AS end_date
  ,MAX([moe_esi_provider_code]) AS [moe_esi_provider_code]
  ,IIF(MAX([moe_esi_provider_code]) IS NOT NULL,  'Enrolled', 'Unenrolled') AS enrolment_status
FROM 
	student_intervention_setup AS si
INNER JOIN 
	[IDI_Metadata_202506].[moe_school].[intervention_type_code] AS t 
	ON t.InterventionID = si.moe_inv_intrvtn_code
LEFT JOIN      -- Including unenrolled student
	[IDI_Clean_202506].[moe_clean].[student_enrol] AS e
	ON si.snz_uid = e.snz_uid
	AND e.moe_esi_start_date <= si.moe_inv_end_date
	AND si.moe_inv_start_date <= e.moe_esi_end_date
WHERE
	[moe_inv_intrvtn_code] IN (9, 32) -- 9:Non Enrolment Truancy Service; 32:Truancy (Unjustified Absence)
GROUP BY 
	si.[snz_uid]
  ,[moe_inv_intrvtn_code]
  ,t.InterventionName
  ,[moe_inv_start_date]
  ,[moe_inv_end_date]
GO


