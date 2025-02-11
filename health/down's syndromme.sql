/**************************************************************************************************
Title: Downs syndrome
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202303].[moh_clean].[pub_fund_hosp_discharges_diag]
	[IDI_Clean_202303].[moh_clean].[priv_fund_hosp_discharges_diag]
	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_disability]
	[IDI_Adhoc].[clean_read_MOH_PRIMHD].[primhd_diagnoses]
	[IDI_Adhoc].[clean_read_MOH_PRIMHD].[moh_primhd_mhinc]
	[IDI_Clean_202303].[moh_clean].[mortality_diagnosis]

Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[downs_syndromme]
Description:

Notes:
- code congenital heart deffects, birth weight and maternal age, and ID and IDD
	--ICD 10 Q90
	--ICD 9 7580
	--soc diagnosis 1101
	--DSM IV has no code
	--MSD incp ? 
	--ACC READ codes? 

Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-03-05 CWright version 1
**************************************************************************************************/

---------------------------------------------------------------------
--1.1 public hosps part of 1999 to part of 2020

DROP TABLE IF EXISTS #moh_pub_ds

SELECT b.snz_uid
    , [moh_dia_clinical_code] AS code
    , [moh_dia_op_date] AS date
    , b.[moh_evt_evst_date] AS alt_date
INTO #moh_pub_ds
FROM [IDI_Clean_202303].[moh_clean].[pub_fund_hosp_discharges_diag] AS a
    , [IDI_Clean_202303].[moh_clean].[pub_fund_hosp_discharges_event] AS b
WHERE (
    (
        SUBSTRING([moh_dia_clinical_code],1,3) IN ('Q90')
        AND [moh_dia_submitted_system_code] >= '10'
        AND [moh_dia_diagnosis_type_code] IN ('A','B')
    )
    OR (
        SUBSTRING([moh_dia_clinical_code],1,4) IN ('7580')
        AND [moh_dia_submitted_system_code] IN ('6','06')
        AND [moh_dia_diagnosis_type_code] IN ('A','B')
    )
)
AND [moh_dia_event_id_nbr] = [moh_evt_event_id_nbr]
AND [moh_dia_clinical_sys_code] = [moh_dia_submitted_system_code]

---------------------------------------------------------------------
--1.2 private hosps

DROP TABLE IF EXISTS #moh_pri_ds

SELECT [snz_uid]
    , [moh_pri_diag_clinic_code] AS code
    , [moh_pri_diag_op_ac_date] AS date
      --,[moh_pri_diag_op_ac_ind]
    , [moh_pri_evt_start_date] AS alt_date
INTO #moh_pri_ds
FROM [IDI_Clean_202303].[moh_clean].[priv_fund_hosp_discharges_diag] AS a
    , [IDI_Clean_202303].[moh_clean].[priv_fund_hosp_discharges_event] AS b
WHERE a.[moh_pri_diag_event_id_nbr] = b.[moh_pri_evt_event_id_nbr]
AND SUBSTRING([moh_pri_diag_clinic_code],1,3) IN ('Q90')
AND [moh_pri_diag_diag_type_code] IN ('A','B')

---------------------------------------------------------------------
--2.0 socrates
--1101	Down syndrome (Trisomy 21)

DROP TABLE IF EXISTS #moh_soc_ds

SELECT b.snz_uid
    , CAST(SUBSTRING(c.firstcontactdate,1,7) AS date) AS alt_date
    , c.firstcontactdate
    , [Code]
    , [Description]
INTO #moh_soc_ds
FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_disability] AS a
    , [IDI_Clean_202303].[moh_clean].[pop_cohort_demographics] AS b
    , [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_needs_assessment] AS c
WHERE [Code] = '1101'
AND a.snz_moh_uid = b.snz_moh_uid
AND a.snz_moh_uid = c.snz_moh_uid

---------------------------------------------------------------------
--3.0 PRIMHD

DROP TABLE IF EXISTS #moh_primhd_ds

SELECT b.snz_uid
    , 'PRIMHD' AS source
    , CONVERT(date,[CLASSIFICATION_START_DATE],103) AS alt_date
    , [CLINICAL_CODE] AS code
    , 'Down''s Syndrome' AS type
INTO #moh_primhd_ds
FROM [IDI_Adhoc].[clean_read_MOH_PRIMHD].[primhd_diagnoses] AS a
    , [IDI_Clean_202303].[moh_clean].[pop_cohort_demographics] AS b
WHERE SUBSTRING([CLINICAL_CODE],1,3) IN ('Q90')
AND a.snz_moh_uid = b.snz_moh_uid

---------------------------------------------------------------------
--MHINC

DROP TABLE IF EXISTS #moh_mhinc_ds

SELECT b.snz_uid
    , [classification_start] AS alt_date
    , [CLINICAL_CODE] AS code
INTO #moh_mhinc_ds
FROM [IDI_Adhoc].[clean_read_MOH_PRIMHD].[moh_primhd_mhinc] AS a
    , [IDI_Clean_202303].[moh_clean].[pop_cohort_demographics] AS b
WHERE(
    (
        SUBSTRING([CLINICAL_CODE],1,3) = 'Q90'
        AND [clinical_coding_system_id] >= '10'
    )
    OR(
        SUBSTRING([CLINICAL_CODE],1,4) = '7580'
        AND [clinical_coding_system_id] >= '06'
    )
)
AND a.snz_moh_uid = b.snz_moh_uid

---------------------------------------------------------------------
--4.0 mortality

DROP TABLE IF EXISTS #moh_mort_ds

SELECT [snz_uid]
    , [moh_mort_diag_clinical_code] AS code
    , DATEFROMPARTS([moh_mor_death_year_nbr],[moh_mor_death_month_nbr],1) AS alt_date
INTO #moh_mort_ds
FROM [IDI_Clean_202303].[moh_clean].[mortality_diagnosis] AS a
    , [IDI_Clean_202303].[moh_clean].[mortality_registrations] AS b
WHERE(
    (
        SUBSTRING([moh_mort_diag_clinical_code],1,3) = 'Q90'
        AND [moh_mort_diag_clinic_sys_code] >= '10'
    )
    OR(
        SUBSTRING([moh_mort_diag_clinical_code],1,4) = '7580'
        AND [moh_mort_diag_clinic_sys_code] >= '06'
    )
)
AND a.[snz_dia_death_reg_uid] = b.[snz_dia_death_reg_uid]

---------------------------------------------------------------------
-- Final

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[downs_syndromme]

SELECT snz_uid
    , MIN(alt_date) AS min_date
INTO [IDI_Sandpit].[DL-MAA2023-46].[downs_syndromme]
FROM(
    SELECT snz_uid
        , alt_date
    FROM #moh_mort_ds
    
	UNION ALL
    
	SELECT snz_uid
        , alt_date
    FROM #moh_pub_ds
    
	UNION ALL
    
	SELECT snz_uid
        , alt_date
    FROM #moh_pri_ds
    
	UNION ALL
    
	SELECT snz_uid
        , alt_date
    FROM #moh_soc_ds
    
	UNION ALL
    
	SELECT snz_uid
        , alt_date
    FROM #moh_mhinc_ds
    
	UNION ALL
    
	SELECT snz_uid
        , alt_date
    FROM #moh_primhd_ds
)AS a
GROUP BY snz_uid
