/**************************************************************************************************
Title: Any indication of serious mental health
Author: Craig Wright

Inputs & Dependencies:
	[IDI_METADATA].[CLEAN_READ_CLASSIFICATIONS].[ACC_ICD10_CODE]
	[IDI_Clean_202203].[MOH_CLEAN].[PUB_FUND_HOSP_DISCHARGES_DIAG]
	[IDI_Clean_202203].[MOH_CLEAN].[PRIMHD]
	[IDI_ADHOC].[CLEAN_READ_MOH_PRIMHD].[PRIMHD_DIAGNOSES]
	[IDI_Clean_202203].[MOH_CLEAN].[INTERRAI]
	[IDI_ADHOC].[CLEAN_READ_MOH_SOCRATES].[MOH_DISABILITY]
	[IDI_Clean_202203].[MOH_CLEAN].[POP_COHORT_DEMOGRAPHICS]
	[IDI_ADHOC].[CLEAN_READ_MOH_SOCRATES].[MOH_NEEDS_ASSESSMENT] 
	[IDI_ADHOC].[CLEAN_READ_MOH_SOCRATES].[MOH_REFERRAL] 
	[IDI_METADATA].[CLEAN_READ_CLASSIFICATIONS].[MSD_INCAPACITY_REASON_CODE_3]
	[IDI_METADATA].[CLEAN_READ_CLASSIFICATIONS].[MSD_INCAPACITY_REASON_CODE_4]
	[IDI_Clean_202203].[MSD_CLEAN].[MSD_INCAPACITY] 
	[IDI_METADATA].[CLEAN_READ_CLASSIFICATIONS].[MOH_NNPAC_PURCHASE_UNIT]
	[IDI_Clean_202203].[MOH_CLEAN].[NNPAC]
	
Outputs:
	[IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health]
	[IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health_sml]

Description:

Notes:
- Based on:
	1. any serious diagnosis - schizophrenia, Bi polar, major depressive disorder, schizoaffective disorder - 
	2. any current PRIMHD/MHINC service so referral period
- Key sources:
	1. Y public hospital discharge diagnosis (ICD10) x 6 3 digit codes
	2. Y private hospital discharge diagnosis (ICD10) x 6 3 digit codes
	3. N MHINC service -- no as too early
	4.a Y PRIMHD service by refferal period by date -- NB BASED ON RECENT SERVICE DATE
	4.b Y PRIMHD diagnosis codes
	5. Y InterRAI diagnosis by question x 2 questions
	6. Y SOCRATES by diagnosis x 2 codes
	7. Y MSD incapaciation
- Key codes
	ICD10
	- F33 major pressive disorder
	- F30 manic
	- F31 Bipolar
	- F20 schizophrenia
	- F21 schizotypal
	- F25 schizaffective
	Interrai
	- [moh_irai_depression_code]
	- [moh_irai_schizophrenia_code]
	- [moh_irai_bipolar_code]
		with codes 0 = Not present, 1 = Primary diagnosis / diagnoses for current stay
		2 = Diagnosis present, receiving active treatment, 3 = Diagnosis present, monitored but no active treatment
	SOCRATES
	- 1306 schizophrenia
	- 1303 Bipolar
	Hospitalisations
	- COOC0058	Mental Health Worker
	- HOP235	AT & R (Assessment  Treatment & Rehabilitation) Inpatient - Mental Health service(s) for Elderly

	MSD - med certificates / incapacitation
	- 161	Depression
	- 162	Bipolar disorder
	- 163	Schizophrenia

Parameters & Present values:

 
Issues:
- snz_moh_uid is not unique within clean_read_MOH_SOCRATES
	More consideration may be required to remove potential duplicates.

History (reverse order):
2021-11-02 C Wright: version 1
**************************************************************************************************/

---------------------------------------------------------------------
-- Base table

CREATE TABLE [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health] (
	snz_uid INT
	, code VARCHAR(12)
    , source VARCHAR(5)
    , type VARCHAR(5)
    , date DATE
)

---------------------------------------------------------------------
-- Hospital public non-admitted

INSERT INTO [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health]
SELECT [snz_uid]
    , [moh_nnp_purchase_unit_code] AS code
    , 'NAP' AS source
    , 'SHM' AS type
    , [moh_nnp_service_date] AS date
FROM [IDI_Clean_202203].[moh_clean].[nnpac]
WHERE [moh_nnp_purchase_unit_code] IN ('COOC0058','HOP235')

---------------------------------------------------------------------
-- Hospital public admitted

INSERT INTO [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health]
SELECT b.snz_uid
    , [moh_dia_clinical_code] AS code
    , 'PUB' AS source
    , 'SMH' AS type
    , [moh_evt_evst_date] AS date
    --, [moh_dia_event_id_nbr]
FROM [IDI_Clean_202203].[moh_clean].[pub_fund_hosp_discharges_diag] AS a
    , [IDI_Clean_202203].[moh_clean].[pub_fund_hosp_discharges_event] AS b
WHERE a.[moh_dia_event_id_nbr] = b.[moh_evt_event_id_nbr]
AND SUBSTRING([moh_dia_clinical_code],1,3) IN ('F30','F31','F33','F20','F21','F25')
AND [moh_dia_clinical_sys_code] = [moh_dia_submitted_system_code]

---------------------------------------------------------------------
-- Hospital private

INSERT INTO [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health]
SELECT b.snz_uid
    , moh_pri_diag_clinic_code AS code
    , 'PRI' AS source
    , 'SMH' AS type
    , CAST(moh_pri_evt_start_date AS date) AS date
FROM [IDI_Clean_202203].[moh_clean].priv_fund_hosp_discharges_diag AS a
    , [IDI_Clean_202203].[moh_clean].priv_fund_hosp_discharges_event AS b
WHERE a.moh_pri_diag_event_id_nbr = b.moh_pri_evt_event_id_nbr
AND SUBSTRING(moh_pri_diag_clinic_code,1,3) IN ('F30','F31','F33','F20','F21','F25')
AND moh_pri_diag_clinic_sys_code = moh_pri_diag_sub_sys_code

---------------------------------------------------------------------
-- PRIMHD

INSERT INTO [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health]
SELECT DISTINCT [snz_uid]
	, NULL AS code
    , 'PRM' AS source
    , 'SMH' AS type
    , [moh_mhd_referral_start_date] AS date
FROM [IDI_Clean_202203].[moh_clean].[PRIMHD]


INSERT INTO [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health]
SELECT b.[snz_uid]
	, NULL AS code
    , 'PRC' AS source
    , 'SHM' AS type
    , CONVERT(date, [CLASSIFICATION_START_DATE], 103) AS date
    , [CLINICAL_CODE] AS code
FROM [IDI_Adhoc].[clean_read_MOH_PRIMHD].[primhd_diagnoses] AS a
    , [IDI_Clean_202203].[security].[concordance] AS b
WHERE a.[snz_moh_uid] = b.[snz_moh_uid]
AND(
    (
        SUBSTRING([CLINICAL_CODE],1,3) IN ('F30','F31','F33','F20','F21','F25')
        AND [CLINICAL_CODING_SYSTEM_ID] >= 10
    )
    OR(
        (
            SUBSTRING([CLINICAL_CODE],1,4) IN ('2960','2962','2963','2964','2965','2966','2967','2968')
            OR SUBSTRING([CLINICAL_CODE],1,3) IN ('295')
        )
        AND [CLINICAL_CODING_SYSTEM_ID] >= 7
    )
)

---------------------------------------------------------------------
-- INTERRAI - health of older people assessment

INSERT INTO [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health]
SELECT [snz_uid]
	, NULL AS code
    --, [moh_irai_schizophrenia_code]
    --, [moh_irai_bipolar_code]
    , 'IRA' AS source
    , 'SHM' AS type
    , [moh_irai_assessment_date] AS date
FROM [IDI_Clean_202203].[moh_clean].[interrai]
WHERE [moh_irai_schizophrenia_code] IN (1,2,3)
OR [moh_irai_bipolar_code] IN (1,2,3)

---------------------------------------------------------------------
-- SOCRATES funded disability

INSERT INTO [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health]
SELECT b.snz_uid
    , CAST([Code] AS VARCHAR)AS code
    , 'SOC' AS source
    , 'SHM' AS type
    , COALESCE(CAST(SUBSTRING([FirstContactDate],1,7) AS DATE), CAST(SUBSTRING([ReferralDate],1,7) AS DATE)) AS date
FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_disability] AS a
LEFT JOIN [IDI_Clean_202203].[moh_clean].[pop_cohort_demographics] AS b
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
WHERE code IN ('1306','1303')
AND a.snz_moh_uid = c.snz_moh_uid

---------------------------------------------------------------------
-- SOCRATES funded disability

-- handle each of:
--,[msd_incp_incrsn95_1_code]
--,[msd_incp_incrsn95_2_code]
--,[msd_incp_incrsn95_3_code]
--,[msd_incp_incrsn95_4_code]
--,[msd_incp_incapacity_code]

INSERT INTO [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health]
SELECT [snz_uid]
    , [msd_incp_incrsn_code] AS code
    , 'INCP' AS source
    , 'SMH_I' AS type
    , [msd_incp_incp_from_date] AS date
FROM [IDI_Clean_202203].[msd_clean].[msd_incapacity]
WHERE [msd_incp_incrsn_code] IN ('162','163')

INSERT INTO [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health]
SELECT [snz_uid]
    , [msd_incp_incrsn95_1_code] AS code
    , 'INCP' AS source
    , 'SMH_1' AS type
    , [msd_incp_incp_from_date] AS date
FROM [IDI_Clean_202203].[msd_clean].[msd_incapacity]
WHERE [msd_incp_incrsn95_1_code] IN ('162','163')

INSERT INTO [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health]
SELECT [snz_uid]
    , [msd_incp_incrsn95_2_code] AS code
    , 'INCP' AS source
    , 'SMH_2' AS type
    , [msd_incp_incp_from_date] AS date
FROM [IDI_Clean_202203].[msd_clean].[msd_incapacity]
WHERE [msd_incp_incrsn95_2_code] IN ('162','163')

INSERT INTO [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health]
SELECT [snz_uid]
    , [msd_incp_incrsn95_3_code] AS code
    , 'INCP' AS source
    , 'SMH_3' AS type
    , [msd_incp_incp_from_date] AS date
FROM [IDI_Clean_202203].[msd_clean].[msd_incapacity]
WHERE [msd_incp_incrsn95_3_code] IN ('162','163')

INSERT INTO [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health]
SELECT [snz_uid]
    , [msd_incp_incrsn95_4_code] AS code
    , 'INCP' AS source
    , 'SMH_4' AS type
    , [msd_incp_incp_from_date] AS date
FROM [IDI_Clean_202203].[msd_clean].[msd_incapacity]
WHERE [msd_incp_incrsn95_4_code] IN ('162','163')

INSERT INTO [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health]
SELECT [snz_uid]
    , [msd_incp_incapacity_code] AS code
    , 'INCP' AS source
    , 'SMH_T' AS type
    , [msd_incp_incp_from_date] AS date
FROM [IDI_Clean_202203].[msd_clean].[msd_incapacity]
WHERE [msd_incp_incapacity_code] IN ('162','163')



---------------------------------------------------------------------
--any serious diangosis or recent acute mental health service

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health_sml]

SELECT DISTINCT snz_uid
    , 1 AS serious_mental_health
INTO [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health_sml]
FROM [IDI_Sandpit].[DL-MAA2021-49].[serious_mental_health] 

--serious diagnosis
WHERE source IN ('PRI','PUB','SOC','IRA','PRC','INCP') 
--recent PIMRHD service
OR(
    source IN ('PRM')
    AND date >= '2019-01-01'
)
