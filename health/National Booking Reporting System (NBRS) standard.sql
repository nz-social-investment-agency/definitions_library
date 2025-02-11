/**************************************************************************************************
Title: NBRS Waitlist standard code
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Adhoc].[clean_read_MOH_NBRS].[moh_nbrs]
	[IDI_Metadata].[clean_read_CLASSIFICATIONS_CLIN_DIAG_CODES].[clinical_codes]
	[IDI_Metadata_202406].[moh_nmds].[health_speciality23_code]
Outputs:

Description:
	Base code for investigating the National Booking System
	This is the system that is used to manage health waitlists.

Notes:
	National booking reporting system:
	  patients receive a fas - first specialist assessment
	  thay are given a cpac score - within the surgical group they are given a clinical priority assesment code
	  this determines how urgently their status is viewed

Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-08-30 CWright: version 1
**************************************************************************************************/

SELECT [snz_moh_uid]
    , [calendar_year_and_month]

    , [booked_procedure_code]

    , a.[clinical_code]
    , a.[clinical_code_system]

    , [latest_cpac_score]
    , [latest_cpac_scoring_syst_code]
    , a.[health_specialty_code]
    , c.[HEALTH_SPECIALTY_DESCRIPTION]


    , [CLINICAL_SYSTEM_DESCRIPTION]
    , [CLINICAL_CODE_TYPE]
    , [CLINICAL_CODE_TYPE_DESCRIPTION]

    , [CLINICAL_CODE_DESCRIPTION]
    , [BLOCK]
    , [BLOCK_SHORT_DESCRIPTION]
    , [BLOCK_LONG_DESCRIPTION]
FROM [IDI_Adhoc].[clean_read_MOH_NBRS].[moh_nbrs] AS a
LEFT JOIN [IDI_Metadata].[clean_read_CLASSIFICATIONS_CLIN_DIAG_CODES].[clinical_codes] b
ON a.[clinical_code_system] = b.[CLINICAL_CODE_SYSTEM]
AND a.[clinical_code] = b.[CLINICAL_CODE]
LEFT JOIN [IDI_Metadata_202406].[moh_nmds].[health_speciality23_code] AS c
ON a.health_specialty_code = c.[HEALTH_SPECIALTY_CODE]
