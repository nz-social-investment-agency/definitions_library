/**************************************************************************************************
Title: Developmental delay
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202203].[moh_clean].[nnpac]
	[IDI_Adhoc].[clean_read_MOH_PRIMHD].[primhd_diagnoses]
	[IDI_Adhoc].[clean_read_MOH_PRIMHD].[moh_primhd_mhinc]
	[IDI_Clean_202203].[moh_clean].[pop_cohort_demographics]
	[IDI_Clean_202203].[moh_clean].[pub_fund_hosp_discharges_diag]
	[IDI_Clean_202203].[moh_clean].[priv_fund_hosp_discharges_event]
	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_disability]
	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_needs_assessment]
	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_referral]

Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[developmental_delay]

Description:
	developmental disability/delay / global developmental delay

Notes:
- Specific codes are given with each component dataset
- PRIMHD team description has no value for development
- ACC, MOE, NNPAC, interrai and MHINC teams do not have sufficient detail to use

Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2021-10-20 C Wright: version 1
**************************************************************************************************/

---------------------------------------------------------------------
--DSS1012	255	Child Development

/*
Child Development services are non medical, multidisciplinary allied health
and community based.  Whilst a significant component of the service is early
intervention for pre-school children who have disabilities or who are not
achieving developmental milestones, the service is intended to promote and
facilitate each child's developmental pathway so that their maximal potential
is attained throughout their development and growth.  It is envisaged that
Child Development services will provide a centre of excellence to meet the
needs of young children/young people, who have disabilities, in some localities
this is up to the age of leaving school.
*/

DROP TABLE IF EXISTS #npp_dd

--MOH NPP non admitted patent collection -- none  n=0
SELECT [snz_uid]
    , [moh_nnp_service_date] AS date
    , [moh_nnp_purchase_unit_code] AS code
    , CASE WHEN [moh_nnp_purchase_unit_code] IN ('DSS1012') THEN 'S' ELSE 'M' END AS type
INTO #npp_dd
FROM [IDI_Clean_202203].[moh_clean].[nnpac]
WHERE [moh_nnp_purchase_unit_code] IN ('DSS1012')

---------------------------------------------------------------------
--PRIMHD diangosis codes DSM / ICD

DROP TABLE IF EXISTS #moh_primhd_code

SELECT b.snz_uid
    , 'PRIMHD' AS source
    , 'DD' AS type
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
    , CONVERT(date,[CLASSIFICATION_START_DATE],103) AS date
    , [CLINICAL_CODE] code
    , 'NOT available' AS description
INTO #moh_primhd_code
FROM [IDI_Adhoc].[clean_read_MOH_PRIMHD].[primhd_diagnoses] AS a
    , [IDI_Clean_202203].[moh_clean].[pop_cohort_demographics] AS b
WHERE a.[snz_moh_uid] = b.[snz_moh_uid]
AND(
    (
        SUBSTRING([CLINICAL_CODE],1,3) IN ('F88')
        AND [clinical_CODing_system_ID] >= '10'
        AND [DIAGNOSIS_TYPE] IN ('A','B')
    )
    OR(
        (
            SUBSTRING([CLINICAL_CODE],1,4) IN ('3158')
        )
        AND [clinical_CODing_system_ID] = '06'
        AND [DIAGNOSIS_TYPE] IN ('A','B')
    )
    OR(
        (
            SUBSTRING([CLINICAL_CODE],1,4) IN ('3158')
        )
        AND [clinical_CODing_system_ID] = '07'
        AND [DIAGNOSIS_TYPE] IN ('A','B')
    )
)

---------------------------------------------------------------------
--MOH SOCRATES 1211,1206,1207/ note issue with dates
--code	Description
--1204	Motor delay, developmental dyspraxia
--1210	Developmental delay, type not specified
--1299	Other intellectual, learning or developmental disorder (specify)

DROP TABLE IF EXISTS #moh_soc_dd

SELECT DISTINCT b.snz_uid
    , 'SOC' AS source
    , 'DD' AS type
    , '80' AS code_sys_1
    , 'D' AS code_sys_2
    , CASE WHEN CAST(SUBSTRING([FirstContactDate],1,7) AS date) IS NOT NULL THEN CAST(SUBSTRING([FirstContactDate],1,7) AS date) 
	  WHEN CAST(SUBSTRING([ReferralDate],1,7) AS date) IS NOT NULL THEN CAST(SUBSTRING([ReferralDate],1,7) AS date) 
	  END AS date
    , CAST(code AS VARCHAR(7)) AS code
    , [Description]
INTO #moh_soc_dd
FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_disability] AS a
LEFT JOIN [IDI_Clean_202203].[moh_clean].[pop_cohort_demographics] AS b
ON a.snz_moh_uid = b.snz_moh_uid
LEFT JOIN [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_needs_assessment] AS c
ON a.snz_moh_uid = c.snz_moh_uid
LEFT JOIN [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_referral] AS e
ON a.snz_moh_uid = e.snz_moh_uid
WHERE code IN ('1210','1204','1299')
AND a.snz_moh_uid = c.snz_moh_uid 

---------------------------------------------------------------------
-- Public hospitals

DROP TABLE IF EXISTS #moh_pub

SELECT [snz_uid]
    , 'PUB' AS source
    , 'ASD' AS type
    , [moh_dia_submitted_system_code] AS code_sys_1
    , [moh_dia_diagnosis_type_code] AS code_sys_2
    , [moh_evt_evst_date] AS date
    , [moh_dia_clinical_code] AS code
    , 'NOT avaiable' AS description
INTO #moh_pub
FROM [IDI_Clean_202203].[moh_clean].[pub_fund_hosp_discharges_diag] AS a
    , [IDI_Clean_202203].[moh_clean].[pub_fund_hosp_discharges_event] AS b
WHERE [moh_dia_clinical_sys_code] = [moh_dia_submitted_system_code]
AND [moh_evt_event_id_nbr] = [moh_dia_event_id_nbr]
AND(
    (
        SUBSTRING([moh_dia_clinical_code],1,3) IN ('F88')
        AND [moh_dia_clinical_sys_code] >= '10'
        AND [moh_dia_diagnosis_type_code] IN ('A','B')
    )
    OR(
        (
            SUBSTRING([moh_dia_clinical_code],1,4) IN ('3158')
        )
        AND [moh_dia_clinical_sys_code] >= '06'
        AND [moh_dia_diagnosis_type_code] IN ('A','B')
    )
)

---------------------------------------------------------------------
-- Private hospitals

DROP TABLE IF EXISTS #moh_pri_code

SELECT a.[snz_uid]
    , 'PRI' AS source
    , 'ASD' AS type
    , [moh_pri_diag_sub_sys_code] AS code_sys_1
    , [moh_pri_diag_diag_type_code] AS code_sys_2
    , CAST([moh_pri_evt_start_date] AS date) AS date
    , [moh_pri_diag_clinic_code] AS code
    , 'NOT avaiable' AS description
INTO #moh_pri_code
FROM [IDI_Clean_202203].[moh_clean].[priv_fund_hosp_discharges_event] AS a
    , [IDI_Clean_202203].[moh_clean].[priv_fund_hosp_discharges_diag] AS b
WHERE a.[moh_pri_evt_event_id_nbr] = b.[moh_pri_diag_event_id_nbr]
AND [moh_pri_diag_clinic_sys_code] = [moh_pri_diag_sub_sys_code]
AND(
    (
        SUBSTRING([moh_pri_diag_clinic_code],1,3) IN ('F88')
        AND [moh_pri_diag_sub_sys_code] >= '10'
        AND [moh_pri_diag_diag_type_code] IN ('A','B')
    )
    OR(
        (
            SUBSTRING([moh_pri_diag_clinic_code],1,4) IN ('3158')
        )
        AND [moh_pri_diag_sub_sys_code] = '06'
        AND [moh_pri_diag_diag_type_code] IN ('A','B')
    )
)

---------------------------------------------------------------------
--MHINC

DROP TABLE IF EXISTS #moh_mhinc_code

SELECT b.snz_uid
    , 'MHINC' AS source
    , 'ASD' AS type
    , [clinical_coding_system_id] AS code_sys_1
    , CAST(diagnosis_type AS VARCHAR(2)) AS code_sys_2
    , [classification_start] AS date
    , [CLINICAL_CODE] AS code
    , 'NOT avaiable' AS description
INTO #moh_mhinc_code
FROM [IDI_Adhoc].[clean_read_MOH_PRIMHD].[moh_primhd_mhinc] AS a
    , [IDI_Clean_202203].[security].[concordance] AS b
WHERE(
    (
        SUBSTRING([CLINICAL_CODE],1,4) IN ('F88')
        AND [clinical_coding_system_id] >= '10'
    )
    OR(
        (
            SUBSTRING([CLINICAL_CODE],1,4) IN ('3158')
        )
        AND [clinical_coding_system_id] >= '06'
    )
    OR(
        (
            SUBSTRING([CLINICAL_CODE],1,4) IN ('3158')
        )
        AND [clinical_coding_system_id] >= '07'
    )
)
AND a.snz_moh_uid = b.snz_moh_uid

---------------------------------------------------------------------
-- Final

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[developmental_delay]

SELECT snz_uid
    , MIN(date) AS min_date -- earliest diagnosis
INTO [IDI_Sandpit].[DL-MAA2023-46].[developmental_delay]
FROM(
    SELECT snz_uid
        , date
    FROM #npp_dd

    UNION ALL

    SELECT snz_uid
        , date
    FROM #moh_mhinc_code

    UNION ALL

    SELECT snz_uid
        , date
    FROM #moh_PRIMHD_code

    UNION ALL

    SELECT snz_uid
        , date
    FROM #moh_soc_dd

    UNION ALL

    SELECT snz_uid
        , date
    FROM #moh_pub

    UNION ALL

    SELECT snz_uid
        , date
    FROM #moh_pri_code
)AS a
GROUP BY snz_uid
