/**************************************************************************************************
Title: C13 Eating Disorders
Author: 

Description:
C13 - eating disorders incidence and prevalence

Inputs & Dependencies:
	[IDI_METADATA].[CLEAN_READ_CLASSIFICATIONS_CLIN_DIAG_CODES].[CLINICAL_CODES]
	[IDI_ADHOC].[CLEAN_READ_MOH_SOCRATES].MOH_DISABILITY
	[IDI_CLEAN_20211020].[SECURITY].[CONCORDANCE]
	[IDI_ADHOC].[CLEAN_READ_MOH_SOCRATES].[MOH_NEEDS_ASSESSMENT] 
	[IDI_ADHOC].[CLEAN_READ_MOH_SOCRATES].[MOH_REFERRAL] 
	[IDI_METADATA].[CLEAN_READ_CLASSIFICATIONS].[MOH_INTERRAI_QUESTION_LOOKUP]
	[IDI_CLEAN_202306].[MOH_CLEAN].INTERRAI
	[IDI_ADHOC].[CLEAN_READ_MOH_PRIMHD].[MOH_PRIMHD_MHINC]
	[IDI_ADHOC].[CLEAN_READ_MOH_PRIMHD].[PRIMHD_DIAGNOSES]

Outputs:
	#primhd_bpd



Notes:
- Examines 'ever have an eating disorder'
- Uses diagnosis/treatement spells
	--1. nervose
	--2. bulimia
	--3. binge eating disorder
	--4. pica
	--5. ??
	--9. nec or NS

Parameters & Present values:

 
Issues:

History (reverse order):

**************************************************************************************************/

---------------------------------------------------------------------
--SOCRATES - DSS

DROP TABLE IF EXISTS #soc_bpd

SELECT DISTINCT b.snz_uid
    , CASE WHEN CAST(SUBSTRING([FirstContactDate],1,7) AS date) IS NOT NULL THEN CAST(SUBSTRING([FirstContactDate],1,7) AS date) 
	  WHEN CAST(SUBSTRING([ReferralDate],1,7) AS date) IS NOT NULL THEN CAST(SUBSTRING([ReferralDate],1,7) AS date) 
	  END AS start_date
    , a.[Code] AS code
    , CASE WHEN CAST(SUBSTRING([FirstContactDate],1,7) AS date) IS NOT NULL THEN CAST(SUBSTRING([FirstContactDate],1,7) AS date) 
	  WHEN CAST(SUBSTRING([ReferralDate],1,7) AS date) IS NOT NULL THEN CAST(SUBSTRING([ReferralDate],1,7) AS date) 
	  END AS end_date
	--,a.[Description] as description
	--,1 as value
	--,'Code' as variable_name 
INTO #soc_bpd
FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].moh_disability AS a
LEFT JOIN [IDI_Clean_20211020].[security].[concordance] AS b
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
WHERE a.snz_moh_uid = c.snz_moh_uid
AND a.[Code] = '1303'

---------------------------------------------------------------------
-- INTERRAI

DROP table IF EXISTS #irai_bpd

SELECT snz_uid
    , MIN([moh_irai_assessment_date])AS start_date
    , MAX([moh_irai_assessment_date])AS end_date
INTO #irai_bpd
FROM(
    SELECT [snz_uid]
        , moh_irai_bipolar_code
        , [moh_irai_assessment_date]

    FROM [IDI_Clean_202306].[moh_clean].interrai
    WHERE moh_irai_bipolar_code > 0
)AS a
GROUP BY snz_uid
SELECT DISTINCT a.[Code] AS code
    , a.[Description] AS description
FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].moh_disability AS a
WHERE a.[Description] LIKE '%eat%'

---------------------------------------------------------------------
-- PRIMHD

DROP TABLE IF EXISTS #mha_bpd


SELECT b.snz_uid
    , [classification_start] AS start_date
    , [classification_start] AS end_date
	  --,[clinical_coding_system_id] as code_sys_1
	  --,diagnosis_type as code_sys_2
    , [CLINICAL_CODE] AS code
INTO #mha_bpd
FROM [IDI_Adhoc].[clean_read_MOH_PRIMHD].[moh_primhd_mhinc] AS a
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
        (
            [CLINICAL_CODE] IN('2967','29600','29601','29602','29603','29604','29605','29606','29640','29641','29642','29643','29644','29645','29646','29650','29651','29652','29653','29654','29655','29656',
'29660','29661','29662','29663','29664','29665','29666','29680','29689','30113')
        )
        AND [clinical_coding_system_id] IN ('07','7')
    )

)

DROP TABLE IF EXISTS #primhd_bpd

SELECT snz_uid
  --[snz_moh_uid]
      --,[REFERRAL_ID]
      --,[ORGANISATION_ID]
      --,[CLASSIFICATION_CODE_ID]
      --,[DIAGNOSIS_TYPE]
    , DATEFROMPARTS(SUBSTRING([CLASSIFICATION_START_DATE],7,4),SUBSTRING([CLASSIFICATION_START_DATE],4,2),SUBSTRING([CLASSIFICATION_START_DATE],1,2))AS START_DATE
    , DATEFROMPARTS(SUBSTRING([CLASSIFICATION_end_DATE],7,4),SUBSTRING([CLASSIFICATION_end_DATE],4,2),SUBSTRING([CLASSIFICATION_end_DATE],1,2))AS end_DATE
      --,[CLINICAL_CODING_SYSTEM_ID]
      --,[CLINICAL_CODE]
      --,[CLINICAL_CODE_TYPE]
      --,[DIAGNOSIS_GROUPING_CODE]
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
        [CLINICAL_CODE] IN('2967','29600','29601','29602','29603','29604','29605','29606','29640','29641','29642','29643','29644','29645','29646','29650','29651','29652','29653','29654','29655','29656',
'29660','29661','29662','29663','29664','29665','29666','29680','29689','30113')
        AND [clinical_coding_system_id] IN('07','7')
    )
)

