/**************************************************************************************************
Title: Bipolar disorder
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Sandpit].[DL-MAA2021-49].[cw_202306_mha_bipolar]
	[IDI_Clean_202306].[moh_clean].[mortality_diagnosis]
	[IDI_Metadata_202310].moh_pharm.dim_form_pack_subsidy_code
	[IDI_Clean_202403].[moh_clean].[pharmaceutical]
	[IDI_Clean_202306].[moh_clean].[pharmaceutical]
	[IDI_Clean_202306].[moh_clean].interrai
	[IDI_Adhoc].[clean_read_MOH_SOCRATES].moh_disability
	[IDI_Clean_20211020].[security].[concordance]
	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_needs_assessment] 
	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_referral] 
	[IDI_Clean_202306].[msd_clean].[msd_incapacity]
	[IDI_Clean_202306].[moh_clean].[lab_claims]
	[IDI_Clean_202306].[moh_clean].[priv_fund_hosp_discharges_event]
	[IDI_Clean_202306].[moh_clean].[pub_fund_hosp_discharges_diag]
	[IDI_Adhoc].[clean_read_MOH_PRIMHD].[moh_primhd_mhinc]
	[IDI_Adhoc].[clean_read_MOH_PRIMHD].[primhd_diagnoses]

Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[mha_bipolar]

Description:
	Observed bipolar disorder

Notes:
- Specific codes are noted in each section
- Pharmaceuticals can be used to treat other conditions than Bipolar
	We only include multi-condition bipolar pharmaceuticals if there is additional evidence
	of Bipolar.

Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-04-26 CWright treatment spells for biploar
2023-09-22 CWright earliest date of treatement for biploar
**************************************************************************************************/

---------------------------------------------------------------------
--mortality

DROP TABLE IF EXISTS #mos_bpd

SELECT b.snz_uid
    , a.[snz_dia_death_reg_uid]
    , [moh_mort_diag_clinical_code] AS code
    , [moh_mort_diag_clinic_type_code]
    , [moh_mort_diag_clinic_sys_code]
    , [moh_mort_diag_diag_type_code]
    , [moh_mor_death_month_nbr]
    , [moh_mor_death_year_nbr]
    , DATEFROMPARTS(([moh_mor_death_year_nbr]),[moh_mor_death_month_nbr],DAY(EOMONTH(DATEFROMPARTS([moh_mor_death_year_nbr],[moh_mor_death_month_nbr],1)))) AS start_date
    , DATEFROMPARTS(([moh_mor_death_year_nbr]),[moh_mor_death_month_nbr],DAY(EOMONTH(DATEFROMPARTS([moh_mor_death_year_nbr],[moh_mor_death_month_nbr],1)))) AS end_date
INTO #mos_bpd
FROM [IDI_Clean_202306].[moh_clean].[mortality_diagnosis] AS a
    , [IDI_Clean_202306].[moh_clean].[mortality_registrations] AS b
WHERE
    (
        SUBSTRING([moh_mort_diag_clinical_code],1,3) IN ('F30','F31')
        OR SUBSTRING([moh_mort_diag_clinical_code],1,4) = 'F340'
    )
AND [moh_mort_diag_clinic_sys_code] >= 10
AND a.[snz_dia_death_reg_uid] = b.snz_dia_death_reg_uid

---------------------------------------------------------------------
-- Pharmaceuticals

--  TG_NAME3	CHEMICAL_ID	CHEMICAL_NAME	FORMULATION_ID
--Anxiolytics	1316	Clonazepam	131602
--Anxiolytics	1316	Clonazepam	131601
--Multiple BD/Schiz		General	1011	Risperidone
--Multiple Mania/Schiz		General	3878	Aripiprazole
--Multiple Antipsychotics	Depot Injections	1140	Olanzapine
--Multiple Antipsychotics	Depot Injections	3940	Olanzapine pamoate monohydrate
--Multiple Bipolar			Depot Injections	1011	Risperidone
--Multiple BP/SS			General	1183	Quetiapine
--Multiple Bipolar			General	1183	Quetiapine Fumarate
--Mutliple Bipolar			Depot Injections	1140	Olanzapine
--Mutliple Schizophrenia	General	3873	Ziprasidone

--Sole Bipolar			General	2466	Lithium carbonate

DROP TABLE IF EXISTS #phh_bpd

SELECT snz_uid
    , type
    , MIN(start_date) AS start_date
    , MAX(end_date) AS end_date
INTO #phh_bpd
FROM(
    SELECT a.[snz_uid]
        , [moh_pha_dispensed_date] AS start_date
        , IIF(a.[moh_pha_days_supply_nbr] > 0, DATEADD(DAY,a.[moh_pha_days_supply_nbr],[moh_pha_dispensed_date]), [moh_pha_dispensed_date]) AS end_date
        , IIF(b.[chemical_ID] IN ('2466'), 'S', 'M') AS type
    FROM [IDI_Clean_202306].[moh_clean].[pharmaceutical] AS a
        , [IDI_Metadata_202306].[moh_pharm].[dim_form_pack_subsidy22_code] AS b
    WHERE a.[moh_pha_dim_form_pack_code] = b.[DIM_FORM_PACK_SUBSIDY_KEY]
    AND(
        CHEMICAL_ID IN ('2466','3873','1140','1183','1011','3940','1140','3878')
        OR formulation_id IN ('131601','131602')
    )
)AS a
GROUP BY snz_uid, type

---------------------------------------------------------------------
-- Interai

DROP TABLE IF EXISTS #irai_bpd

SELECT snz_uid
    , MIN([moh_irai_assessment_date]) AS start_date
    , MAX([moh_irai_assessment_date]) AS end_date
INTO #irai_bpd
FROM(
    SELECT [snz_uid]
        , moh_irai_bipolar_code
        , [moh_irai_assessment_date]
    FROM [IDI_Clean_202306].[moh_clean].interrai
    WHERE moh_irai_bipolar_code > 0
)AS a
GROUP BY snz_uid

---------------------------------------------------------------------
-- SOCRATES

--code	description
--1303	Bipolar disorder (manic depression)

DROP TABLE IF EXISTS #soc_bpd

SELECT DISTINCT b.snz_uid
    , COALESCE(CAST(SUBSTRING([FirstContactDate],1,7) AS DATE), CAST(SUBSTRING([ReferralDate],1,7) AS DATE)) AS start_date
    , a.[Code] AS code
    , COALESCE(CAST(SUBSTRING([FirstContactDate],1,7) AS DATE), CAST(SUBSTRING([ReferralDate],1,7) AS DATE)) AS end_date 
INTO #soc_bpd
FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].moh_disability AS a
LEFT JOIN [IDI_Clean_202306].[security].[concordance] AS b
ON a.snz_moh_uid = b.snz_moh_uid
LEFT JOIN [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_needs_assessment] AS c
ON a.snz_moh_uid = c.snz_moh_uid
LEFT JOIN [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_referral] AS e
ON a.snz_moh_uid = e.snz_moh_uid
WHERE a.snz_moh_uid = c.snz_moh_uid
AND a.[Code] = '1303'

---------------------------------------------------------------------
-- MSD incapacity codes

DROP TABLE IF EXISTS #incp_bpd

SELECT snz_uid
    , MIN(start_date) AS start_date
    , MAX(end_date) AS end_date
INTO #incp_bpd
FROM(
    SELECT a.[snz_uid]
        , from_date AS start_date
        , to_date AS end_date
    FROM(
            SELECT [snz_uid]
                , [msd_incp_incp_from_date] AS from_date
                , [msd_incp_incp_to_date] AS to_date
                , [msd_incp_incrsn_code] AS code_raw
                , '0' AS agency_sys
                , 1 AS value
                , '[msd_incp_incrsn_code]' AS variable_name
            FROM [IDI_Clean_202306].[msd_clean].[msd_incapacity]
        
        UNION ALL
            SELECT [snz_uid]
                , [msd_incp_incp_from_date] AS from_date
                , [msd_incp_incp_to_date] AS to_date
                , [msd_incp_incrsn95_1_code] AS code_raw
                , '1' AS agency_sys
                , 1 AS value
                , '[msd_incp_incrsn95_1_code]' AS variable_name
            FROM [IDI_Clean_202306].[msd_clean].[msd_incapacity]
        
        UNION ALL
            SELECT [snz_uid]
                , [msd_incp_incp_from_date] AS from_date
                , [msd_incp_incp_to_date] AS to_date
                , [msd_incp_incrsn95_2_code] AS code_raw
                , '2' AS agency_sys
                , 1 AS value
                , '[msd_incp_incrsn95_2_code]' AS variable_name
            FROM [IDI_Clean_202306].[msd_clean].[msd_incapacity]
        
        UNION ALL
            SELECT [snz_uid]
                , [msd_incp_incp_from_date] AS from_date
                , [msd_incp_incp_to_date] AS to_date
                , [msd_incp_incrsn95_3_code] AS code_raw
                , '3' AS agency_sys
                , 1 AS value
                , '[msd_incp_incrsn95_3_code]' AS variable_name
            FROM [IDI_Clean_202306].[msd_clean].[msd_incapacity]
        
        UNION ALL
            SELECT [snz_uid]
                , [msd_incp_incp_from_date] AS from_date
                , [msd_incp_incp_to_date] AS to_date
                , [msd_incp_incrsn95_4_code] AS code_raw
                , '4' AS agency_sys
                , 1 AS value
                , '[msd_incp_incrsn95_4_code]' AS variable_name
            FROM [IDI_Clean_202306].[msd_clean].[msd_incapacity]
        
        UNION ALL
            SELECT [snz_uid]
                , [msd_incp_incp_from_date] AS from_date
                , [msd_incp_incp_to_date] AS to_date
                , [msd_incp_incapacity_code] AS code_raw
                , '9' AS agency_sys
                , 1 AS value
                , '[msd_incp_incapacity_code]' AS variable_name
            FROM [IDI_Clean_202306].[msd_clean].[msd_incapacity]
    )AS a
    WHERE code_raw = '162'
)AS a
GROUP BY snz_uid

---------------------------------------------------------------------
--lithium testing

DROP TABLE IF EXISTS #lab_lith

SELECT snz_uid
    , MIN(date) AS start_date
    , MAX(date) AS end_date
INTO #lab_lith
FROM(
    SELECT [snz_uid]
        , [moh_lab_visit_date] AS date
    FROM [IDI_Clean_202306].[moh_clean].[lab_claims]
    WHERE [moh_lab_test_code] = 'BM2'
)AS a
GROUP BY snz_uid

---------------------------------------------------------------------
--private hospital discharge

DROP TABLE IF EXISTS #pri_bpd

SELECT a.[snz_uid]
    , CAST([moh_pri_evt_start_date] AS date) AS start_date
    , CAST([moh_pri_evt_end_date] AS date) AS end_date
    , [moh_pri_diag_sub_sys_code] AS code_sys_1
    , [moh_pri_diag_diag_type_code] AS code_sys_2
    , [moh_pri_diag_clinic_code] AS code
INTO #pri_bpd
FROM [IDI_Clean_202306].[moh_clean].[priv_fund_hosp_discharges_event] AS a
    , [IDI_Clean_202306].[moh_clean].[priv_fund_hosp_discharges_diag] AS b
WHERE a.[moh_pri_evt_event_id_nbr] = b.[moh_pri_diag_event_id_nbr]
AND [moh_pri_diag_sub_sys_code] = [moh_pri_diag_clinic_sys_code]
AND (
	(
        (
            SUBSTRING([moh_pri_diag_clinic_code],1,3) IN ('F30','F31')
            OR SUBSTRING([moh_pri_diag_clinic_code],1,4) IN ('F340')
        )
        AND [moh_pri_diag_sub_sys_code] >= '10'
    )
	OR (
        [moh_pri_diag_clinic_code] IN (
			'29600','29601','29602','29603','29604','29605','29606','29610','29611','29612','29613','29614','29615','29616',
			'29640','29641','29642','29643','29644','29645','29646','29650','29651','29652','29653','29654','29655','29656',
			'29660','29661','29662','29663','29664','29665','29666','2967','29680','29681'
		)
        AND [moh_pri_diag_sub_sys_code] IN ('06','6')
        AND [moh_pri_diag_diag_type_code] IN ('A','B','V')
    )
)

---------------------------------------------------------------------
-- Publicly funded hospital discharge

DROP TABLE IF EXISTS #pub_bpd

SELECT b.[snz_uid]
    , [moh_evt_evst_date] AS start_date
    , [moh_evt_even_date] AS end_date
    , [moh_dia_submitted_system_code] AS code_sys_1
    , [moh_dia_diagnosis_type_code] AS code_sys_2
    , [moh_dia_clinical_code] AS code
INTO #pub_bpd
FROM [IDI_Clean_202306].[moh_clean].[pub_fund_hosp_discharges_diag] AS a
    , [IDI_Clean_202306].[moh_clean].[pub_fund_hosp_discharges_event] AS b
WHERE [moh_dia_clinical_sys_code] = [moh_dia_submitted_system_code]
AND [moh_evt_event_id_nbr] = [moh_dia_event_id_nbr]
AND(
    (
        (
            SUBSTRING([moh_dia_clinical_code],1,3) IN ('F30','F31')
            OR SUBSTRING([moh_dia_clinical_code],1,4) IN ('F340')
        )

        AND [moh_dia_submitted_system_code] >= '10'
    )

    OR(
            [moh_dia_clinical_code] IN (
				'29600','29601','29602','29603','29604','29605','29606','29610','29611','29612','29613','29614','29615','29616',
				'29640','29641','29642','29643','29644','29645','29646','29650','29651','29652','29653','29654','29655','29656',
				'29660','29661','29662','29663','29664','29665','29666','2967','29680','29681'
			)
            AND [moh_dia_submitted_system_code] IN ('06','6')
            AND [moh_dia_diagnosis_type_code] IN ('A','B','V')
    )
)

---------------------------------------------------------------------
--PRIMHD and MHINC

DROP TABLE IF EXISTS #mha_bpd

SELECT b.snz_uid
    , [classification_start] AS start_date
    , [classification_start] AS end_date
    , [CLINICAL_CODE] AS code
INTO #mha_bpd
FROM [IDI_Adhoc].[clean_read_MOH_PRIMHD].[moh_primhd_mhinc] AS a
    , [IDI_Clean_202306].[security].[concordance] AS b
WHERE a.snz_moh_uid = b.snz_moh_uid
AND(
    (
        (
            SUBSTRING([CLINICAL_CODE],1,3) IN ('F30','F31')
            OR SUBSTRING([CLINICAL_CODE],1,4) IN ('F340')
        )
        AND [clinical_coding_system_id] >= '10'
    )

    OR(
        [CLINICAL_CODE] IN (
			'2967','29600','29601','29602','29603','29604','29605','29606','29640','29641','29642','29643','29644','29645','29646',
			'29650','29651','29652','29653','29654','29655','29656','29660','29661','29662','29663','29664','29665','29666','29680',
			'29689','30113'
		)
		AND [clinical_coding_system_id] IN ('07','7')
    )

)

---------------------------------------------------------------------
-- PRIMHD

DROP TABLE IF EXISTS #primhd_bpd

SELECT snz_uid
    , DATEFROMPARTS(SUBSTRING([CLASSIFICATION_START_DATE],7,4),SUBSTRING([CLASSIFICATION_START_DATE],4,2),SUBSTRING([CLASSIFICATION_START_DATE],1,2)) AS START_DATE
    , DATEFROMPARTS(SUBSTRING([CLASSIFICATION_end_DATE],7,4),SUBSTRING([CLASSIFICATION_end_DATE],4,2),SUBSTRING([CLASSIFICATION_end_DATE],1,2)) AS end_DATE
INTO #primhd_bpd
FROM [IDI_Adhoc].[clean_read_MOH_PRIMHD].[primhd_diagnoses] AS a
    , [IDI_Clean_202306].[security].[concordance] AS b
WHERE a.snz_moh_uid = b.snz_moh_uid
AND (
    (
		(
            SUBSTRING([CLINICAL_CODE],1,3) IN ('F30','F31')
            OR SUBSTRING([CLINICAL_CODE],1,4) IN ('F340')
        )
        AND [clinical_coding_system_id] >= '10'
    )
    OR (
		[CLINICAL_CODE] IN (
			'2967','29600','29601','29602','29603','29604','29605','29606','29640','29641','29642','29643','29644','29645','29646',
			'29650','29651','29652','29653','29654','29655','29656','29660','29661','29662','29663','29664','29665','29666','29680',
			'29689','30113'
		)
		AND [clinical_coding_system_id] IN ('07','7')
    )
)

---------------------------------------------------------------------
-- Final

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2021-49].[mha_bipolar]

SELECT DISTINCT snz_uid
    , start_date
    , end_date
INTO [IDI_Sandpit].[DL-MAA2023-46].[mha_bipolar]
FROM(
    SELECT DISTINCT snz_uid
        , start_date
        , end_date
    FROM #mha_bpd
    UNION ALL
    SELECT DISTINCT snz_uid
        , start_date
        , end_date
    FROM #pri_bpd
    UNION ALL
    SELECT DISTINCT snz_uid
        , start_date
        , end_date
    FROM #pub_bpd
    UNION ALL
    SELECT DISTINCT snz_uid
        , start_date
        , end_date
    FROM #lab_lith
    UNION ALL
    SELECT DISTINCT snz_uid
        , start_date
        , end_date
    FROM #phh_bpd
    WHERE type = 'S'
    UNION ALL
    SELECT DISTINCT snz_uid
        , start_date
        , end_date
    FROM #incp_bpd
    UNION ALL
    SELECT DISTINCT snz_uid
        , start_date
        , end_date
    FROM #primhd_bpd
    UNION ALL
    SELECT DISTINCT snz_uid
        , start_date
        , end_date
    FROM #soc_bpd
    UNION ALL
    SELECT DISTINCT snz_uid
        , start_date
        , end_date
    FROM #irai_bpd
    UNION ALL
    SELECT DISTINCT snz_uid
        , start_date
        , end_date
    FROM #mos_bpd
)AS a

-- Handle multi-purpose pharmaceuticals


INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[mha_bipolar]
SELECT DISTINCT snz_uid
    , start_date
    , end_date
FROM #phh_bpd
WHERE type = 'M' -- multi-purpose
AND snz_uid IN ( -- other evidence of bipolar
	SELECT snz_uid
	FROM [IDI_Sandpit].[DL-MAA2023-46].[mha_bipolar]
)
