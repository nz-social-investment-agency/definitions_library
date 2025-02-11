/**************************************************************************************************
Title: Attention Deficit Hyperactivity Disorder (ADHD)
Author: Craig Wright

Inputs & Dependencies:
	[IDI_SANDPIT].[DL-MAA2023-46].CW_202410_ADHD 
	[IDI_CLEAN_202410].[MOH_CLEAN].[MORTALITY_DIAGNOSIS]
	[IDI_CLEAN_202410].[MOH_CLEAN].[PHARMACEUTICAL]
	[IDI_CLEAN_202410].[MOH_CLEAN].[PRIV_FUND_HOSP_DISCHARGES_EVENT]
	[IDI_CLEAN_202410].[MOH_CLEAN].[PUB_FUND_HOSP_DISCHARGES_DIAG]
	[IDI_ADHOC].[CLEAN_READ_MOH_PRIMHD].[MOH_PRIMHD_MHINC]
	[IDI_ADHOC].[CLEAN_READ_MOH_PRIMHD].[PRIMHD_DIAGNOSES_202312]
	[IDI_ADHOC].[CLEAN_READ_MOH_SOCRATES].MOH_DISABILITY_2022
	[IDI_CLEAN_202410].[SECURITY].[CONCORDANCE]
	[IDI_ADHOC].[CLEAN_READ_MOH_SOCRATES].[MOH_NEEDS_ASSESSMENT_2022]
	[IDI_ADHOC].[CLEAN_READ_MOH_SOCRATES].[MOH_REFERRAL_2022] 
	[IDI_ADHOC].[CLEAN_READ_CYF].[CYF_GATEWAY_CLI_NEEDS]

Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_ADHD]

Description:
Aim is to have identify people with ADHD
Supports calculation of ADHD incidence and prevalence

Notes:
- Two classes of information:
	- 1. solely indicated for adhd
	- 2. used to treat adhd but also other things - can't use fr ID but can use for date of diangosis
- Method:
	- STEP 1: first date from sources of data that constitute a diagnosis
		- Y hospital diagnosis code
		- X MSD incapacitation code
		- X Outpatient purchase units
		- interrai diabetes indicator
		- Y MHA MHINC/PRIMHD diagnosis code
		- X SOCRATES diagnosis 
	- -STEP 2: get dates from sources that constitute treatment for adhd
		- X hospital health specialty of .......
		- X drug dispensing for drugs for adhd
		- Y drug dispensing for adhd only
- Relevant codes:
	- vortioxetine
	- sole indicated 
	- multiple indications
	- R41840 attention concentraation
	- R134 screen for developmental
	- dsm iv 7 31400 31401 3149  
- For Pharm it appears that drugs are coded down to indication so ADHD for a drug with dual indications is coded 
	seperately from the other indications. For example:

	--TG_NAME3	CHEMICAL_ID	CHEMICAL_NAME
	--Stimulants/ADHD Treatments	M 1389	Dexamfetamine sulfate
	--Stimulants/ADHD Treatments	? 1578	Glycopyrronium Bromide
	--Stimulants/ADHD Treatments	M 1809	Methylphenidate hydrochloride
	--Stimulants/ADHD Treatments	? 2367	Calcium carbimide
	--Stimulants/ADHD Treatments	M 3735	Melatonin
	--Stimulants/ADHD Treatments	? 3750	Rivastigmine
	--Stimulants/ADHD Treatments	M 3880	Methylphenidate hydrochloride extended-release
	--Stimulants/ADHD Treatments	S 3887	Atomoxetine
	--Stimulants/ADHD Treatments	M 3935	Modafinil

	--Only dementia - Stimulants/ADHD Treatments	3750	Rivastigmine
	--Not listed - Stimulants/ADHD Treatments	2367	Calcium carbimide
	--Multiple but not ADHD Stimulants/ADHD Treatments	1578	Glycopyrronium Bromide


Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2022-10-06 C Wright: created
**************************************************************************************************/

---------------------------------------------------------------------
-- Mortality

DROP TABLE IF EXISTS #mos

SELECT [snz_uid]
    , 'MORT' AS source
    , DATEFROMPARTS([moh_mor_death_year_nbr],[moh_mor_death_month_nbr],1)AS start_date
    , DATEFROMPARTS([moh_mor_death_year_nbr],[moh_mor_death_month_nbr],1)AS end_date
    , [moh_mort_diag_clinical_code] AS code
    , [moh_mort_diag_clinic_type_code] code_type
    , [moh_mort_diag_clinic_sys_code] code_system
    , [moh_mort_diag_diag_type_code] death_type
    , 'ADHD' AS type
INTO #mos
FROM [IDI_Clean_202410].[moh_clean].[mortality_diagnosis] AS a
    , [IDI_Clean_202410].[moh_clean].[mortality_registrations] AS b
WHERE a.[snz_dia_death_reg_uid] = b.[snz_dia_death_reg_uid]
AND (
		(
			SUBSTRING(code,1,5) IN ('F900','F901','F908','F909','R134','R418')
			AND code_system >= '10'
		)
	OR (
	    SUBSTRING(code,1,5) IN ('31400','31401','3141','3142','3148','3149')
		AND code_system IN ('06','6')
		AND code_type IN ('A','B','V')
	)
)

---------------------------------------------------------------------
-- Pharmaceutical

--TG_NAME3																			CHEMICAL_ID	CHEMICAL_NAME
--Y Multiple Narcolepsy -- Stimulants/ADHD Treatments									1389	Dexamfetamine sulfate
--Y Multiple ADHAD narcolepsy depression in PC - Stimulants/ADHD Treatments				1809	Methylphenidate hydrochloride
--Y Multiple Primary insomnia - Stimulants/ADHD Treatments								3735	Melatonin
--Y MULTIPLE ADHAD narcolepsy depression in PC  - Stimulants/ADHD Treatments			3880	Methylphenidate hydrochloride extended-release
--Y SOLE ADHD - Stimulants/ADHD Treatments												3887	Atomoxetine
--Y MUTIPLE narcolepsy, apnoea,hypopnoea, sleep disorder - Stimulants/ADHD Treatments	3935	Modafinil

DROP TABLE IF EXISTS #phh

SELECT snz_uid
    , type
    , MIN(start_date)AS start_date
    , MAX(end_date)AS end_date
INTO #phh
FROM(
    SELECT a.[snz_uid]
        , [moh_pha_dispensed_date] AS start_date
        , CASE WHEN a.[moh_pha_days_supply_nbr] >0 THEN DATEADD(DAY,a.[moh_pha_days_supply_nbr],[moh_pha_dispensed_date]) 
	  ELSE [moh_pha_dispensed_date]	  END AS end_date
	  --S is soley indicatoed for ADHD , M means there a re multiple indications which can be used for the date
        , CASE WHEN b.[chemical_ID] IN (3887) THEN 'S' ELSE 'M' END AS type
    FROM [IDI_Clean_202410].[moh_clean].[pharmaceutical] AS a
        , [IDI_Metadata_202410].moh_pharm.dim_form_pack_subsidy_code AS b
    WHERE a.[moh_pha_dim_form_pack_code] = b.[DIM_FORM_PACK_SUBSIDY_KEY]
    AND CHEMICAL_ID IN (1389,1809,3735,3880,3887,3935,1578,2367,3750)
)AS a
GROUP BY snz_uid
    , type

---------------------------------------------------------------------
--private hospital discharge

DROP TABLE IF EXISTS #pri

SELECT a.[snz_uid]
--,'PRI' as source
    , CAST([moh_pri_evt_start_date] AS date)AS start_date
    , CAST([moh_pri_evt_end_date] AS date)AS end_date
    , [moh_pri_diag_sub_sys_code] AS code_system
    , [moh_pri_diag_diag_type_code] AS code_type
    , [moh_pri_diag_clinic_code] AS code
INTO #pri
FROM [IDI_Clean_202410].[moh_clean].[priv_fund_hosp_discharges_event] AS a
    , [IDI_Clean_202410].[moh_clean].[priv_fund_hosp_discharges_diag] AS b
WHERE a.[moh_pri_evt_event_id_nbr] = b.[moh_pri_diag_event_id_nbr]
AND [moh_pri_diag_sub_sys_code] = [moh_pri_diag_clinic_sys_code]
AND (
	(
		SUBSTRING(code,1,4) IN ('F900','F901','F908','F909','R134','R418')
		AND code_system >= '10'
	)
	OR (
		SUBSTRING(code,1,5) IN ('31400','31401','3141','3142','3148','3149')
		AND code_system IN ('06','6')
		AND code_type IN ('A','B','V')
	)
)

---------------------------------------------------------------------
--Publicly funded hospital discharge

DROP TABLE IF EXISTS #pub

SELECT b.[snz_uid]
--	,'PUB' as source
--TOP (1000) [moh_dia_event_id_nbr]
--,[moh_dia_clinical_sys_code]
--,[moh_dia_submitted_system_code]
--,[moh_dia_diagnosis_type_code]
--,[moh_dia_diag_sequence_code]
    , [moh_evt_evst_date] AS start_date
    , [moh_evt_even_date] AS end_date
    , [moh_dia_submitted_system_code] AS code_system
    , [moh_dia_diagnosis_type_code] AS code_type
    , [moh_dia_clinical_code] AS code
--,[moh_dia_op_date]
--,[moh_dia_op_flag_ind]
--,[moh_dia_condition_onset_code]
--,[snz_moh_uid]
--,[moh_evt_event_id_nbr]
INTO #pub
FROM [IDI_Clean_202410].[moh_clean].[pub_fund_hosp_discharges_diag] AS a
    , [IDI_Clean_202410].[moh_clean].[pub_fund_hosp_discharges_event] AS b
WHERE [moh_dia_clinical_sys_code] = [moh_dia_submitted_system_code]
AND [moh_evt_event_id_nbr] = [moh_dia_event_id_nbr]
AND(
	(
		SUBSTRING(code,1,4) IN ('F900','F901','F908','F909','R134','R418')
		AND code_system >= '10'
	)
	OR(
		SUBSTRING(code,1,5) IN ('31400','31401','3141','3142','3148','3149')
		AND code_system IN ('06','6')
		AND code_type IN ('A','B','V')
	)
)

---------------------------------------------------------------------
-- Mental health

DROP TABLE IF EXISTS #mha

SELECT snz_uid
    , start_date
    , end_date
    , code
    , code_system
    , code_type
INTO #mha
FROM(
    SELECT b.snz_uid
        , [classification_start] AS start_date
        , [classification_start] AS end_date
        , [CLINICAL_CODE] AS code
        , [clinical_coding_system_id] AS code_system
        , diagnosis_type AS code_type
    FROM [IDI_Adhoc].[clean_read_MOH_PRIMHD].[moh_primhd_mhinc] AS a
        , [IDI_Clean_202410].[security].[concordance] AS b
    WHERE a.snz_moh_uid = b.snz_moh_uid
    UNION ALL
    SELECT snz_uid
	  --[snz_moh_uid]
      --,[REFERRAL_ID]
      --,[ORGANISATION_ID]
      --,[CLASSIFICATION_CODE_ID]
        , [CLASSIFICATION_START_DATE] AS start_date
        , [CLASSIFICATION_END_DATE] AS end_date
      --,datefromparts(substring([CLASSIFICATION_START_DATE],7,4),substring([CLASSIFICATION_START_DATE],4,2),substring([CLASSIFICATION_START_DATE],1,2)) as START_DATE
      --,datefromparts(substring([CLASSIFICATION_end_DATE],7,4),substring([CLASSIFICATION_end_DATE],4,2),substring([CLASSIFICATION_end_DATE],1,2)) as end_DATE
        , [CLINICAL_CODE] AS code
        , [CLINICAL_CODING_SYSTEM_ID] code_system
        , [DIAGNOSIS_TYPE] code_type
      --,[CLINICAL_CODE_TYPE]
      --,[DIAGNOSIS_GROUPING_CODE]
    FROM [IDI_Adhoc].[clean_read_MOH_PRIMHD].[primhd_diagnoses_202312] AS a
        , [IDI_Clean_202410].[security].[concordance] AS b
    WHERE a.snz_moh_uid = b.snz_moh_uid

)AS a
WHERE(
    SUBSTRING(code,1,4) IN ('F900','F901','F908','F909','R134','R418')
    AND code_system >= '10'
)
OR(
    SUBSTRING(code,1,5) IN ('31400','31401')
    AND code_system IN ('06','6''07','7')
    AND code_type IN ('A','B','V')
)
OR(
    SUBSTRING(code,1,4) IN ('3141','3142','3148','3149')
    AND code_system IN ('06','6''07','7')
    AND code_type IN ('A','B','V')
)

---------------------------------------------------------------------
--SOCRATES - NONE

DROP TABLE IF EXISTS #soc

--MOH SOCRATES diagnoses 
--code	description
--1201	ADHD

SELECT b.snz_uid
    , MIN(CASE WHEN CAST(SUBSTRING([FirstContactDate],1,7) AS date) IS NOT NULL THEN CAST(SUBSTRING([FirstContactDate],1,7) AS date) 
	  WHEN CAST(SUBSTRING([ReferralDate],1,7) AS date) IS NOT NULL THEN CAST(SUBSTRING([ReferralDate],1,7) AS date) 
	  END)AS start_date
    , MIN(CASE WHEN CAST(SUBSTRING([FirstContactDate],1,7) AS date) IS NOT NULL THEN CAST(SUBSTRING([FirstContactDate],1,7) AS date) 
	  WHEN CAST(SUBSTRING([ReferralDate],1,7) AS date) IS NOT NULL THEN CAST(SUBSTRING([ReferralDate],1,7) AS date) 
	  END)AS end_date
    , a.[Code] AS code
    , a.[Description] AS description
INTO #soc
FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].moh_disability_2022 AS a
LEFT JOIN [IDI_Clean_202410].[security].[concordance] AS b
ON a.snz_moh_uid = b.snz_moh_uid
LEFT JOIN(
    SELECT DISTINCT snz_moh_uid
        , [FirstContactDate]
    FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_needs_assessment_2022]
)AS c
ON a.snz_moh_uid = c.snz_moh_uid
LEFT JOIN(
    SELECT DISTINCT snz_moh_uid
        , [ReferralDate]
    FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_referral_2022]
)AS e
ON a.snz_moh_uid = e.snz_moh_uid
WHERE a.snz_moh_uid = c.snz_moh_uid  
  --and a.description like '%ADHD%'
AND a.[code] = '1201'
GROUP BY b.snz_uid
    , a.code
    , a.description

---------------------------------------------------------------------
-- Gateway

DROP table IF EXISTS #gateway

SELECT b.snz_uid
    , a.snz_msd_uid
    , [need_type_code]
    , [needs_desc]
    , [need_category_code]
    , [needs_cat_desc]
    , needs_created_date AS start_date
    , needs_created_date AS end_date
      --,[education_yn]
      --,[health_yn]
INTO #gateway
FROM [IDI_Adhoc].[clean_read_CYF].[cyf_gateway_cli_needs] AS a
    , idi_clean_202410.security.concordance AS b
WHERE a.snz_msd_uid = b.snz_msd_uid
AND need_type_code IN ('ATT228','HYP110')

---------------------------------------------------------------------
-- Final table

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_ADHD]

SELECT snz_uid
    , MIN(start_date)AS start_date
    , MAX(end_date)AS end_date
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_ADHD]
FROM(
    SELECT snz_uid
        , start_Date
        , end_date
    FROM #pri
    WHERE code IN ('F900','F901','F908','F909','31400','31401','3141','3142','3148','3149')
    UNION ALL
    SELECT snz_uid
        , start_Date
        , end_date
    FROM #pub
    WHERE code IN ('F900','F901','F908','F909','31400','31401','3141','3142','3148','3149')
    UNION ALL
    SELECT snz_uid
        , start_Date
        , end_date
    FROM #mha
    WHERE code IN ('F900','F901','F908','F909','31400','31401','3141','3142','3148','3149')
  --UNION ALL
  --select snz_uid,start_Date,end_date from #irai_adhd
    UNION ALL
    SELECT snz_uid
        , start_Date
        , end_date
    FROM #soc
  --UNION ALL
  --select snz_uid,start_Date,end_date from #msd_adhd
    UNION ALL
    SELECT snz_uid
        , start_Date
        , end_date
    FROM #mos
    WHERE code IN ('F900','F901','F908','F909','31400','31401','3141','3142','3148','3149')
    UNION ALL
    SELECT snz_uid
        , start_Date
        , end_date
    FROM #phh
    WHERE type = 'S'
    UNION ALL
    SELECT snz_uid
        , start_date
        , end_date
    FROM #gateway
)AS a
GROUP BY snz_uid
