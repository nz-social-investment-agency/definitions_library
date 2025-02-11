/**************************************************************************************************
Title: Epilepsy
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202310].[moh_clean].[pub_fund_hosp_discharges_diag]
	[IDI_Clean_202310].[moh_clean].[pub_fund_hosp_discharges_event]
	[IDI_Clean_202310].[moh_clean].[priv_fund_hosp_discharges_event]
	[IDI_Clean_202310].[moh_clean].[priv_fund_hosp_discharges_diag]
	[IDI_Clean_202310].[msd_clean].[msd_incapacity]
	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_disability]
	[IDI_Clean_202310].[security].[concordance]
	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_needs_assessment]
	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_referral]
	
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[epilepsy]

Description:

Notes:
- Childhood onset
- Likely limited to serious events where treatement is affected by epilepsy or status epilepsyticus
	- rule set for diagnosis of epilepsy: two seizures 24+ hours apart
- Does not at present include pharmaceitucals
- Currently includes
	- 1. any diagnosed epilepsy
	- 2. incidence of seizures
	- 3. sole epilepsy medication/treatment
	- 4. treatment with mutiple indications

Parameters & Present values:
  Current refresh = 202310
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-05-21 CWright version 1
**************************************************************************************************/

---------------------------------------------------------------------
--public hospital discharge

--CLINICAL_CODE_TYPE	CLINICAL_CODE_TYPE_DESCRIPTION	CLINICAL_CODE	CLINICAL_CODE_DESCRIPTION
--A	Diagnosis	U803	Epilepsy


DROP TABLE IF EXISTS #pub

SELECT b.[snz_uid]
    , [moh_evt_evst_date] AS start_date
    , [moh_evt_even_date] AS end_date
    , b.moh_evt_adm_src_code
    , b.moh_evt_adm_type_code
    , b.moh_evt_event_type_code
    , b.moh_evt_end_type_code
    , [moh_dia_submitted_system_code] AS code_sys_1
    , [moh_dia_diagnosis_type_code] AS code_sys_2
    , [moh_dia_clinical_code] AS code
INTO #pub
FROM [IDI_Clean_202310].[moh_clean].[pub_fund_hosp_discharges_diag] AS a
    , [IDI_Clean_202310].[moh_clean].[pub_fund_hosp_discharges_event] AS b
WHERE [moh_dia_clinical_sys_code] = [moh_dia_submitted_system_code]
AND [moh_evt_event_id_nbr] = [moh_dia_event_id_nbr]
AND (
    (
        SUBSTRING([moh_dia_clinical_code],1,3) IN ('G40','G41')
        AND [moh_dia_diagnosis_type_code] IN ('A','B','P','V')
        AND [moh_dia_submitted_system_code] >= '10'
    )
    OR (
        SUBSTRING([moh_dia_clinical_code],1,4) IN ('Z820','U803')
        AND [moh_dia_diagnosis_type_code] IN ('A','B','P','V')
        AND [moh_dia_submitted_system_code] >= '10'
    )
    OR (
        SUBSTRING([moh_dia_clinical_code],1,3) IN ('345')
        AND [moh_dia_diagnosis_type_code] IN ('A','B','P','V')
        AND [moh_dia_submitted_system_code] = '06'
    )
    OR (
        SUBSTRING([moh_dia_clinical_code],1,7) IN ('4070000','4070300','4070301','4070302','4070600','4070900','4070901','4071200','4071201')
        AND [moh_dia_diagnosis_type_code] IN ('O')
        AND [moh_dia_submitted_system_code] >= '10'
    )
)

---------------------------------------------------------------------
--private hospital discharge

DROP TABLE IF EXISTS #pri

SELECT a.[snz_uid]
    , 'PRI' AS source
    , CAST([moh_pri_evt_start_date] AS date) AS start_date
    , CAST([moh_pri_evt_end_date] AS date) AS end_date
    , [moh_pri_diag_sub_sys_code] AS code_sys_1
    , [moh_pri_diag_diag_type_code] AS code_sys_2
    , [moh_pri_diag_clinic_code] AS code
INTO #pri
FROM [IDI_Clean_202310].[moh_clean].[priv_fund_hosp_discharges_event] AS a
    , [IDI_Clean_202310].[moh_clean].[priv_fund_hosp_discharges_diag] AS b
WHERE a.[moh_pri_evt_event_id_nbr] = b.[moh_pri_diag_event_id_nbr]
AND [moh_pri_diag_sub_sys_code] = [moh_pri_diag_clinic_sys_code]
AND (
    (
        SUBSTRING([moh_pri_diag_clinic_code],1,3) IN ('G40','G41')
        AND [moh_pri_diag_diag_type_code] IN ('A','B','P','V')
        AND [moh_pri_diag_sub_sys_code] >= '10'
    )
    OR (
        SUBSTRING([moh_pri_diag_clinic_code],1,4) IN ('Z820','U803')
        AND [moh_pri_diag_diag_type_code] IN ('A','B','P','V')
        AND [moh_pri_diag_sub_sys_code] >= '10'
    )
    OR (
        SUBSTRING([moh_pri_diag_clinic_code],1,3) IN ('345')
        AND [moh_pri_diag_diag_type_code] IN ('A','B','P','V')
        AND [moh_pri_diag_sub_sys_code] = '06'
    )
    OR (
        SUBSTRING([moh_pri_diag_clinic_code],1,7) IN ('4070000','4070300','4070301','4070302','4070600','4070900','4070901','4071200','4071201')
        AND [moh_pri_diag_diag_type_code] IN ('O')
        AND [moh_pri_diag_sub_sys_code] >= '10'
    )
)

---------------------------------------------------------------------
--MSD Incapacitation

--011 120	epilepsy


DROP TABLE IF EXISTS #msd

SELECT a.[snz_uid]
    , 'INCP' AS source
    , from_date AS start_date
    , to_date AS end_date
    , '83' AS code_sys_1
    , NULL AS code_sys_2
    , code_raw AS code
INTO #msd
FROM(
        SELECT [snz_uid]
            , [msd_incp_incp_from_date] AS from_date
            , [msd_incp_incp_to_date] AS to_date
            , [msd_incp_incrsn_code] AS code_raw
            , '0' AS agency_sys
            , 1 AS value
            , '[msd_incp_incrsn_code]' AS variable_name
        FROM [IDI_Clean_202310].[msd_clean].[msd_incapacity]
    
    UNION ALL
        SELECT [snz_uid]
            , [msd_incp_incp_from_date] AS from_date
            , [msd_incp_incp_to_date] AS to_date
            , [msd_incp_incrsn95_1_code] AS code_raw
            , '1' AS agency_sys
            , 1 AS value
            , '[msd_incp_incrsn95_1_code]' AS variable_name
        FROM [IDI_Clean_202310].[msd_clean].[msd_incapacity]
    
    UNION ALL
        SELECT [snz_uid]
            , [msd_incp_incp_from_date] AS from_date
            , [msd_incp_incp_to_date] AS to_date
            , [msd_incp_incrsn95_2_code] AS code_raw
            , '2' AS agency_sys
            , 1 AS value
            , '[msd_incp_incrsn95_2_code]' AS variable_name
        FROM [IDI_Clean_202310].[msd_clean].[msd_incapacity]
    
    UNION ALL
        SELECT [snz_uid]
            , [msd_incp_incp_from_date] AS from_date
            , [msd_incp_incp_to_date] AS to_date
            , [msd_incp_incrsn95_3_code] AS code_raw
            , '3' AS agency_sys
            , 1 AS value
            , '[msd_incp_incrsn95_3_code]' AS variable_name
        FROM [IDI_Clean_202310].[msd_clean].[msd_incapacity]
    
    UNION ALL
        SELECT [snz_uid]
            , [msd_incp_incp_from_date] AS from_date
            , [msd_incp_incp_to_date] AS to_date
            , [msd_incp_incrsn95_4_code] AS code_raw
            , '4' AS agency_sys
            , 1 AS value
            , '[msd_incp_incrsn95_4_code]' AS variable_name
        FROM [IDI_Clean_202310].[msd_clean].[msd_incapacity]
    
    UNION ALL
        SELECT [snz_uid]
            , [msd_incp_incp_from_date] AS from_date
            , [msd_incp_incp_to_date] AS to_date
            , [msd_incp_incapacity_code] AS code_raw
            , '9' AS agency_sys
            , 1 AS value
            , '[msd_incp_incapacity_code]' AS variable_name
        FROM [IDI_Clean_202310].[msd_clean].[msd_incapacity]

) AS a
WHERE code_raw IN ('011','120')

---------------------------------------------------------------------
--MOH SOCRATES diagnoses 

DROP TABLE IF EXISTS #soc_seizures

SELECT DISTINCT b.snz_uid
    , 'SOC' AS source
    , CASE WHEN CAST(SUBSTRING([FirstContactDate],1,7) AS DATE) IS NOT NULL THEN CAST(SUBSTRING([FirstContactDate],1,7) AS DATE) 
		  WHEN CAST(SUBSTRING([ReferralDate],1,7) AS DATE) IS NOT NULL THEN CAST(SUBSTRING([ReferralDate],1,7) AS DATE) 
	  END AS date
    , '80' AS code_sys_1
    , NULL AS code_sys_2
	--,0 as agency_sys 
    , a.[Code] AS code
    , a.[Description] AS description
	--,'Code' as variable_name 
INTO #soc_seizures
FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].moh_disability AS a
LEFT JOIN [IDI_Clean_202310].[security].[concordance] AS b
ON a.snz_moh_uid = b.snz_moh_uid
LEFT JOIN [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_needs_assessment] AS c
ON a.snz_moh_uid = c.snz_moh_uid
LEFT JOIN [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_referral] AS e
ON a.snz_moh_uid = e.snz_moh_uid
WHERE a.snz_moh_uid = c.snz_moh_uid
AND a.code = '1807'

---------------------------------------------------------------------
-- final

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[epilepsy]

SELECT DISTINCT snz_uid
    , start_date AS alt_date
INTO [IDI_Sandpit].[DL-MAA2023-46].[epilepsy]
FROM(
    SELECT snz_uid
        , start_date
        , code
    FROM #msd

    UNION ALL

    SELECT snz_uid
        , start_date
        , code
    FROM #pub

    UNION ALL

    SELECT snz_uid
        , start_date
        , code
    FROM #pri

    UNION ALL

    SELECT snz_uid
        , date start_date
        , code
    FROM #soc_seizures
)AS a
  