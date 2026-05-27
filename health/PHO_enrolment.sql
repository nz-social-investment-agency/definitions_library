/**************************************************************************************************
Title: PHO enrolment
Author: Craig Wright

Acknowledgements:
Informatics for Social Services and Wellbeing (terourou.org) supported the publishing of these definitions

Inputs & Dependencies:
- [IDI_Clean].[moh_clean].[nes_enrolment]
- [IDI_Clean].[moh_clean].[pop_cohort_demographics]
Outputs:
- [SIA_Sandpit].[DL-MAA2023-46].[defn_pho_enrollment]

Description:
Enrolment with Primary Health Organisation (PHO).IDI_Clean_202506

Intended purpose:
Create variable reporting pho enrolment by month of enrolment pho_enrolment =(0/1)
based on monthly enrolment

Notes:
- There looks to be a potential delay with data becoming available in the dataset.
		archive		most recent record
		202406		2023-06-01
		202403		2023-06-01
		202310		2022-11-01
		202306		2022-11-01
		202303		2022-11-01
		202210		2021-11-01
		202206		2021-11-01
		202203		2021-11-01
	for 202410 refresh the latest complete quarter will be from 2023Q1.
- As a potential unenrollment date we take the latest of the snapshot and last-consult
	dates and add three years. Three years since the last contact is the point at which
	the PHO can unenroll someone from their books.

Parameters & Present values:
  Current refresh = 202506
  Prefix = pho_
  Project schema = DL-MAA2023-46
  Snapshot month = '202306'
 
 Max date for enrollment data is 2023-06-01 - Max qtr th
Issues:

History (reverse order):
2025-06-17 SA inclusion of potential unenrollment date
2025-05-28 SA corrected use of enrolment date rather than snapshot date
2023-03-27 DY compared with SWA Github version - same logic.
2022-04-13 JG Updated project and refresh for Data for Communities
2021-11-25 SA tidy
2021-10-12 CW
**************************************************************************************************/

USE IDI_UserCode
GO

DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_pho_enrollment_202506]
GO

CREATE VIEW [DL-MAA2023-46].[defn_pho_enrollment_202506] AS
SELECT DISTINCT [snz_uid]
	, moh_nes_enrolment_date AS enrolment_date
	, moh_nes_pho_id
	, moh_nes_practice_id

	-- max of snapshot date and last consult as latest evidence that individual is enrolled
	, IIF(
		moh_nes_last_consult_date < CAST(moh_nes_snapshot_month_date AS DATE)
		,CAST(moh_nes_snapshot_month_date AS DATE)
		,moh_nes_last_consult_date
	) AS latest_enroll_evidence

	-- three years after last contact an individual could be unenrolled
	, DATEADD(
		YEAR
		,3
		,IIF(
			moh_nes_last_consult_date < CAST(moh_nes_snapshot_month_date AS DATE)
			, CAST(moh_nes_snapshot_month_date AS DATE)
			, moh_nes_last_consult_date
		)
	) AS potental_unenrollment_date

FROM [IDI_Clean_202506].[moh_clean].[nes_enrolment]
GO
