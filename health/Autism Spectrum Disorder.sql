/**************************************************************************************************
Title: Autism Spectrum Disorder
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202403].[moh_clean].[nnpac]
	[IDI_Adhoc].[clean_read_MOH_PRIMHD].[primhd_diagnoses] 
	[IDI_Clean_202403].[moh_clean].[pop_cohort_demographics]
	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_disability] 
	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_needs_assessment]
	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_referral]
	[IDI_Clean_202403].[moh_clean].[priv_fund_hosp_discharges_event] 
	[IDI_Clean_202403].[moh_clean].[priv_fund_hosp_discharges_diag] 
	[IDI_Adhoc].[clean_read_MOH_PRIMHD].[moh_primhd_mhinc] 
	[IDI_Clean_202403].[security].[concordance] 
	[IDI_Adhoc].[clean_read_CYF].[cyf_gateway_cli_needs] 

Outputs:
- [IDI_Sandpit].[DL-MAA2023-46].[defn_autism_spectrum_disorder]

Description:
The purpose of this code is to generate an indicator per person of whether someone has evidence of Autism Spectrum Disorder.
	This evidence can be a:
	1. diagnosis; and/or
	2. treatment solely indicated for autism spectrum disorder; and/or
	3. treatment indicated for ASD and other conditions (marker of higher risk).

Notes:
- Condition type: Effectively congential - present from birth / non-remitting
	although ASD is not congenital, it's sysmptoms are often seen in the first year of life
	and as such can be treated as such. More to the point, even if the date of diagnosis is
	recorded at later ages, like 9 years for example, one can treat it such that the impacts
	of the condition are opportating from the first few years of life.
- Quality: appears to reach prevalent capture for 10-18 year olds in 2021
	this code estimates lower prevalence before age 9 and greater than age 19 years
- This indicator relies only on category 1 data sources.
	- ACC, MOE, NNPAC, interrai and MHINC teams do not have sufficient detail to use AS SOURCES OF DIANOGSES
	- PRIMHD team description has no value for ASD
	- MOH PHARMACEUTICALS DO NOT HAVE DRUGS SOLELY PRESCRIBED TO PEOPLE WITH ASD 
		THEY DO HAVE DRUGS FOR TREATENT OF SYMPTOMS THAT ARE COMMON FOR PEOPLE WITH ASD
		BUT THEY ARE PRESCRIBED FOR OTHER CONDITIONS AS WELL
- ICD-10 F84.2 Rhett disease or RTT is not included as ASD in this code
- FINAL ASD CONDITION TABLE: - one row per person with an asd diagosis
	this includes anyone, irrespective if alive or dea or migrated
    see code for linking to srp-ref table to calculate age specific prevalence

Parameters & Present values:
  Current refresh = 202403
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-06-26 PMok: updated to 202403 refresh
2023-05-02 Craig Wright: added documentation and context, some validation against prevalence, added PRIMHD provisional diagnoses (type = 'P')
2023-02-13 Andrew Webber: updated to 202210 refresh removed validation code to focus on indicator
2021-10-20 C Wright: created
**************************************************************************************************/

---------------------------------------------------------------------
--Checking NNPAC data

--equivalent purchase unit codes: code and description of unit of service
--DSS221 assessment of ASD and further support
--DSS220A 

--MOH NPP non admitted patent collection 
--NO ASD RELATED PUS IN NAP TABLE

--TYPE : this variable is used to indicate where the data source is:
--(not need for ASD but used for other conditions)
--S = solely indicated for the condition
--M = indicated for multiple conditions including the condition

DROP table IF EXISTS #npp_asd
SELECT [snz_uid]
    , [moh_nnp_service_date]
    , [moh_nnp_purchase_unit_code]
    , CASE WHEN [moh_nnp_purchase_unit_code] IN ('DSS220A') THEN 'S' ELSE 'M' END AS type
INTO #npp_asd
FROM [IDI_Clean_202403].[moh_clean].[nnpac]
WHERE [moh_nnp_purchase_unit_code] IN('DSS220A','DSS221')

---------------------------------------------------------------------
--PRIMHD diangosis codes DSM IV/ ICD 10
--SPECIALIST ACUTE MENTAL HEALTH AND ADICTION SERVICES

DROP table IF EXISTS #moh_primhd_code

SELECT b.snz_uid
    , 'PRIMHD' AS source
    , 'ASD' AS type
      --,[CLASSIFICATION_END_DATE]
      --,[CLINICAL_CODING_SYSTEM_ID]
      --,[CLINICAL_CODE_TYPE]
      --,[DIAGNOSIS_GROUPING_CODE]
	  --,[clinical_CODing_system_ID]
    , CASE 
		  WHEN [clinical_CODing_system_ID]=10 THEN '10'
		  WHEN [clinical_CODing_system_ID]=11 THEN '11'
		  WHEN [clinical_CODing_system_ID]=12 THEN '12'
		  WHEN [clinical_CODing_system_ID]=13 THEN '13'
		  WHEN [clinical_CODing_system_ID]=14 THEN '14'
		  WHEN [clinical_CODing_system_ID]=7 THEN '07'
		  WHEN [clinical_CODing_system_ID]=6 THEN '06'
		  END AS code_sys_1
    , [DIAGNOSIS_TYPE] AS code_sys_2
    , CONVERT(date,[CLASSIFICATION_START_DATE],103)AS date
    , [CLINICAL_CODE] code
    , 'NOT available' AS description
INTO #moh_primhd_code
FROM [IDI_Adhoc].[clean_read_MOH_PRIMHD].[primhd_diagnoses] AS a
    , [IDI_Clean_202403].[moh_clean].[pop_cohort_demographics] AS b
WHERE a.[snz_moh_uid] = b.[snz_moh_uid]
AND(
    (
        SUBSTRING([CLINICAL_CODE],1,4) IN ('F840','F841','F843','F845','F848','F849')
        AND [clinical_CODing_system_ID] >= '10'
        AND [DIAGNOSIS_TYPE] IN('A','B','P')
    )
    OR(
        SUBSTRING([CLINICAL_CODE],1,4) IN ('2990','2991','2998')
        AND [clinical_CODing_system_ID] = '06'
        AND [DIAGNOSIS_TYPE] IN('A','B','P')
    )
    OR(
        SUBSTRING([CLINICAL_CODE],1,5) IN ('29900','29910','29980')
        AND [clinical_CODing_system_ID] = '07'
        AND [DIAGNOSIS_TYPE] IN('A','B','P')
    )
)

---------------------------------------------------------------------
--SOCRATES - MOH DSS NASC DATA - NEEDS ASSESMENT AND SERVICE COORDINATION

--CODE	Description
--1211	Autistic Spectrum Disorder (ASD)
--1206	Asperger's syndrome
--1207	Retired - Other autistic spectrum disorder (ASD)

-- Noted concern with dates

DROP table IF EXISTS #moh_soc_id
SELECT DISTINCT b.snz_uid
    , 'SOC' AS source
    , 'ASD' AS type
    , '80' AS code_sys_1
    , 'D' AS code_sys_2
    , CASE WHEN CAST(SUBSTRING([FirstContactDate],1,7) AS date) IS NOT NULL THEN CAST(SUBSTRING([FirstContactDate],1,7) AS date) 
		WHEN CAST(SUBSTRING([ReferralDate],1,7) AS date) IS NOT NULL THEN CAST(SUBSTRING([ReferralDate],1,7) AS date) 
		END AS date
    , CAST(code AS VARCHAR(7))AS code
    , [Description]
INTO #moh_soc_id
FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_disability] AS a
LEFT JOIN [IDI_Clean_202403].[moh_clean].[pop_cohort_demographics] AS b
ON a.snz_moh_uid = b.snz_moh_uid
LEFT JOIN(
    SELECT DISTINCT snz_moh_uid
        , [FirstContactDate]
    FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_needs_assessment]
)AS c
ON a.snz_moh_uid = c.snz_moh_uid
LEFT JOIN(
    SELECT DISTINCT snz_moh_uid
        , [ReferralDate]
    FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_referral]
)AS e
ON a.snz_moh_uid = e.snz_moh_uid
WHERE code IN('1211','1206','1207')
AND a.snz_moh_uid = c.snz_moh_uid

---------------------------------------------------------------------
--PUBLIC HOSPITAL DISCHARGES
--ICD9 AND ICD10 ASD CODES

DROP table IF EXISTS #moh_pub
SELECT [snz_uid]
    , 'PUB' AS source
    , 'ASD' AS type
--TOP (1000) [moh_dia_event_id_nbr]
--      ,[moh_dia_clinical_sys_code]
--      ,[moh_dia_submitted_system_code]
    , [moh_dia_submitted_system_code] AS code_sys_1
    , [moh_dia_diagnosis_type_code] AS code_sys_2
    , [moh_evt_evst_date] AS date
    , [moh_dia_clinical_code] AS code
    , 'NOT avaiable' AS description
INTO #moh_pub
FROM [IDI_Clean_202403].[moh_clean].[pub_fund_hosp_discharges_diag] AS a
    , [IDI_Clean_202403].[moh_clean].[pub_fund_hosp_discharges_event] AS b

WHERE [moh_dia_clinical_sys_code] = [moh_dia_submitted_system_code]
AND [moh_evt_event_id_nbr] = [moh_dia_event_id_nbr]
AND(
    (
        SUBSTRING([moh_dia_clinical_code],1,4) IN ('F840','F841','F843','F845','F848','F849')
        AND [moh_dia_clinical_sys_code] >= '10'
        AND [moh_dia_diagnosis_type_code] IN('A','B')
    )
    OR(
        SUBSTRING([moh_dia_clinical_code],1,4) IN ('2990','2991','2998')
        AND [moh_dia_clinical_sys_code] >= '06'
        AND [moh_dia_diagnosis_type_code] IN('A','B')
    )
    OR(
        SUBSTRING([moh_dia_clinical_code],1,5) IN ('29900','29910','29980')
        AND [moh_dia_clinical_sys_code] >= '07'
        AND [moh_dia_diagnosis_type_code] IN('A','B')
    )
)

---------------------------------------------------------------------
--private hospital discharges / ICD9 / ICD10 ID codes

DROP table IF EXISTS #moh_pri_code
SELECT a.[snz_uid]
    , 'PRI' AS source
    , 'ASD' AS type
    , [moh_pri_diag_sub_sys_code] AS code_sys_1
    , [moh_pri_diag_diag_type_code] AS code_sys_2
    , CAST([moh_pri_evt_start_date] AS date)AS date
    , [moh_pri_diag_clinic_code] AS code
    , 'NOT avaiable' AS description
      --,[moh_pri_diag_op_ac_date]
INTO #moh_pri_code
FROM [IDI_Clean_202403].[moh_clean].[priv_fund_hosp_discharges_event] AS a
    , [IDI_Clean_202403].[moh_clean].[priv_fund_hosp_discharges_diag] AS b
WHERE a.[moh_pri_evt_event_id_nbr] = b.[moh_pri_diag_event_id_nbr]
AND [moh_pri_diag_clinic_sys_code] = [moh_pri_diag_sub_sys_code]
AND(
    (
        SUBSTRING([moh_pri_diag_clinic_code],1,4) IN ('F840','F841','F843','F845','F848','F849')
        AND [moh_pri_diag_sub_sys_code] >= '10'
        AND [moh_pri_diag_diag_type_code] IN('A','B')
    )
    OR(
        SUBSTRING([moh_pri_diag_clinic_code],1,4) IN ('2990','2991','2998')
        AND [moh_pri_diag_sub_sys_code] = '06'
        AND [moh_pri_diag_diag_type_code] IN('A','B')
    )
)

---------------------------------------------------------------------
--MHINC and PRIMHD diagnoses

DROP table IF EXISTS #moh_mhinc_code
SELECT b.snz_uid
    , 'MHINC' AS source
    , 'ASD' AS type
    , [clinical_coding_system_id] AS code_sys_1
    , CAST(diagnosis_type AS VARCHAR(2))AS code_sys_2
    , [classification_start] AS date
    , [CLINICAL_CODE] AS code
    , 'NOT avaiable' AS description
INTO #moh_mhinc_code
--ADHOC TABLE HAS NHI / SNZ_MOH_UID SO NEED TO JOIN TO SECURITY CONDCORDANCE OF CURRENT REFRESH TO ADD SNZ_UID
FROM [IDI_Adhoc].[clean_read_MOH_PRIMHD].[moh_primhd_mhinc] AS a
    , [IDI_Clean_202403].[security].[concordance] AS b
WHERE(
    (
        SUBSTRING([CLINICAL_CODE],1,4) IN ('F840','F841','F843','F845','F848','F849')
        AND [clinical_coding_system_id] >= '10'
    )
    OR(
        SUBSTRING([CLINICAL_CODE],1,4) IN ('2990','2991','2998')
        AND [clinical_coding_system_id] >= '06'
    )
    OR(
        SUBSTRING([CLINICAL_CODE],1,5) IN ('29900','29910','29980')
        AND [clinical_coding_system_id] >= '07'
    )
)
AND a.snz_moh_uid = b.snz_moh_uid

---------------------------------------------------------------------
--cyf gateway assessment resulting in a diagnosis of ASD or autism

DROP table IF EXISTS #gw_asd
SELECT b.snz_uid
    , [snz_prsn_uid]
    , 'ASD' AS type
    , 'CYF_GW' AS source
    , [snz_current_prsn_uid]
    , a.[snz_msd_uid]
    , [snz_gateway_uid]
    , [need_selection_type_code]
    , [need_type_code] AS code
    , '87' AS code_sys_1
    , 'GW' AS code_sys_2
    , [needs_desc] AS description
    , [need_category_code]
    , [needs_cat_desc]
    , [education_yn]
    , [health_yn]
    , [needs_created_date] date
    , [extract_date]
INTO #gw_asd
--ADHOC TABLE HAS NHI / SNZ_MOH_UID SO NEED TO JOIN TO SECURITY CONDCORDANCE OF CURRENT REFRESH TO ADD SNZ_UID
FROM [IDI_Adhoc].[clean_read_CYF].[cyf_gateway_cli_needs] AS a
    , IDI_Clean_202403.security.concordance AS b
WHERE a.snz_msd_uid = b.snz_msd_uid
AND [needs_desc] LIKE '%autism%'

---------------------------------------------------------------------
--  combine all diagnoses for ASD into one record person snz_uid

DROP table IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[cw_202403_ASD]

SELECT snz_uid
    , MIN(date)AS min_date
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_autism_spectrum_disorder]
FROM(
    SELECT snz_uid
        , source
        , type
        , code
        , date
        , description
        , code_sys_1
        , code_sys_2
    FROM #moh_mhinc_code
    UNION ALL
    SELECT snz_uid
        , source
        , type
        , code
        , date
        , description
        , code_sys_1
        , code_sys_2
    FROM #moh_PRIMHD_code
    UNION ALL
    SELECT snz_uid
        , source
        , type
        , code
        , date
        , description
        , code_sys_1
        , code_sys_2
    FROM #moh_soc_id
    UNION ALL
    SELECT snz_uid
        , source
        , type
        , code
        , date
        , description
        , code_sys_1
        , code_sys_2
    FROM #moh_pub
    UNION ALL
    SELECT snz_uid
        , source
        , type
        , code
        , date
        , description
        , code_sys_1
        , code_sys_2
    FROM #moh_pri_code
)AS a
GROUP BY snz_uid
