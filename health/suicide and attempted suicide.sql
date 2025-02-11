/**************************************************************************************************
Title: Suicide
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Sandpit].[DL-MAA2023-46].[cw_202406_suicide]
	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_support_needs]
	[IDI_Clean_202406].[moh_clean].[PRIMHD]
	[IDI_Adhoc].[clean_read_MOH_PRIMHD].[primhd_diagnoses]
	[IDI_Clean_202406].[msd_clean].[msd_customer]
	[IDI_Clean_202406].[cyf_clean].[cyf_abuse_event]
	[IDI_Clean_202406].[acc_clean].[medical_codes]
	[IDI_Clean_202406].[acc_clean].[claims]
	[IDI_Clean_202406].[moh_clean].[mortality_registrations]
	[IDI_Adhoc].[clean_read_CYF].[cyf_gateway_cli_needs]
	[IDI_Clean_202406].[moh_clean].[pub_fund_hosp_discharges_diag]
	[IDI_Clean_202406].[moh_clean].[priv_fund_hosp_discharges_event]
	[IDI_Clean_202406].[pol_clean].[nia_links]
	
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[suicide_or_attempted]

Description:
	All attempted suicide and completed suicide

Notes:
- Sources reviewed:
	--1. Y DEATHS : moh cause of death up to 2016, dec will have 2017
	--2.a Y Public and Private hospital discharge
	--2.b Y Private hospital discharge
	--3. Y PRIMHD  - ad hoc tables : code and team
	--4. Y ACC claims
	--5. Y Police NIA 
	--6. Y CYF FIndings
	--7. N MSD Incapacitation - no code for suicide or slef harm
	--8. Y CYF Gateway
	--9. Y SOCRATES

Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-08-30 CWright version 3
2024-08-07 CWright version 2
2024-05-13 CWright version 1
**************************************************************************************************/

---------------------------------------------------------------------
--1: Deaths : cause of death

--ICD10 self harm and suicide - X60-X84

DROP TABLE IF EXISTS #suicide_cod
SELECT [snz_uid]
    , 'MOH_COD' AS source
    , EOMONTH(DATEFROMPARTS([moh_mor_death_year_nbr],[moh_mor_death_month_nbr],1)) AS date
    , [moh_mor_icd_d_code] AS code_raw
    , 'Suicide' AS type
INTO #suicide_cod
FROM [IDI_Clean_202406].[moh_clean].[mortality_registrations]
WHERE(
    SUBSTRING([moh_mor_icd_d_code],1,3) >= 'X60'
    AND SUBSTRING([moh_mor_icd_d_code],1,3) <= 'X84'
)

---------------------------------------------------------------------
--2.1 public hosps part of 1999 to part of 2020

DROP TABLE IF EXISTS #suicide_pub

SELECT b.snz_uid
    , 'MOH_PUB' AS source
    , [moh_dia_clinical_code] AS code
    , [moh_dia_op_date] AS date
    , b.[moh_evt_evst_date] AS alt_date
    , 'Attempted' AS type
INTO #suicide_pub
FROM [IDI_Clean_202406].[moh_clean].[pub_fund_hosp_discharges_diag] AS a
    , [IDI_Clean_202406].[moh_clean].[pub_fund_hosp_discharges_event] AS b
WHERE SUBSTRING([moh_dia_clinical_code],1,3) >= 'X60'
AND SUBSTRING([moh_dia_clinical_code],1,3) <= 'X84'
AND [moh_dia_event_id_nbr] = [moh_evt_event_id_nbr]
AND [moh_dia_clinical_sys_code] = [moh_dia_submitted_system_code]

---------------------------------------------------------------------
-- 2.2 private hosps

DROP TABLE IF EXISTS #moh_pri
SELECT [snz_uid]
    , 'MOH_PRI' source
    , CAST([moh_pri_evt_start_date] AS date) AS alt_date
    , CAST([moh_pri_diag_op_ac_date] AS date) AS date
    , [moh_pri_diag_clinic_code] AS code_raw
    , 'Attempted' AS type
INTO #moh_pri
FROM [IDI_Clean_202406].[moh_clean].[priv_fund_hosp_discharges_event] AS a
    , [IDI_Clean_202406].[moh_clean].[priv_fund_hosp_discharges_diag] AS b
WHERE a.[moh_pri_evt_event_id_nbr] = b.[moh_pri_diag_event_id_nbr]
AND SUBSTRING([moh_pri_diag_clinic_code],1,3) >= 'X60'
AND SUBSTRING([moh_pri_diag_clinic_code],1,3) <= 'X84'
AND [moh_pri_diag_sub_sys_code] = [moh_pri_diag_clinic_sys_code]

---------------------------------------------------------------------
--3. PRIMHD

DROP TABLE IF EXISTS #MOH_PRIMHD_TEAM

SELECT DISTINCT [snz_uid]
    , 'MOH_PRIMHD_TEAM' AS source
    , [moh_mhd_referral_start_date] AS alt_date
    , [moh_mhd_team_code]
INTO #MOH_PRIMHD_TEAM
FROM [IDI_Clean_202406].[moh_clean].[PRIMHD]
WHERE [moh_mhd_team_code] IN ('013561','010716')
ORDER BY [snz_uid]

DROP TABLE IF EXISTS #moh_primhd_code

SELECT b.[snz_uid]
    , 'MOH_PRIMHD_CODE' AS source
    , CONVERT(date,SUBSTRING([CLASSIFICATION_START_DATE],1,10),103) AS alt_date
    , [CLINICAL_CODE] AS code_RAW
INTO #moh_primhd_code
FROM [IDI_Adhoc].[clean_read_MOH_PRIMHD].[primhd_diagnoses] AS a
    , [IDI_Clean_202406].[moh_clean].[pop_cohort_demographics] AS b
WHERE(
    SUBSTRING([CLINICAL_CODE],1,3) >= 'X60'
    AND SUBSTRING([CLINICAL_CODE],1,3) <= 'X84'
)
AND a.snz_moh_uid = b.snz_moh_uid
  
---------------------------------------------------------------------
--4. ACC claims

--willful self inflicted

--Code	Descriptor
--	ADDED IN ERROR
--	CONFIRMED
--	INACTIVE
--	INVESTIGATING
--	NONE
--Y	YES
--N	NO

--E951	Suicide and self-inflicted poisoning by gases in domestic use		
--E9510	Gas distributed by pipeline		
--E9511	Liquefied petroleum gas distributed in mobile containers		
--E9518	Other utility gas		
--E952	Suicide and self-inflicted poisoning by other gases and vapors		
--E9520	Motor vehicle exhaust gas		
--E9521	Other carbon monoxide		
--E9528	Other specified gases and vapors		
--E9529	Unspecified gases and vapors		
--E953	Suicide and self-inflicted injury by hanging, strangulation, and suffocation		
--E9530	Hanging		
--E9531	Suffocation by plastic bag		
--E9538	Other specified means		
--E9539	Unspecified means		
--E954	Suicide and self-inflicted injury by submersion [drowning]		
--E955	Suicide and self-inflicted injury by firearms, air guns and explosives		
--E9550	Handgun		
--E9551	Shotgun		
--E9552	Hunting rifle		
--E9553	Military firearms		
--E9554	Other and unspecified firearm		
--E9555	Explosives		
--E9556	Air gun		
--E9557	Paintball gun		
--E9559	Unspecified		
--E956	Suicide and self-inflicted injury by cutting and piercing instrument		
--E957	Suicide and self-inflicted injuries by jumping from high place		

--X6	Intentional self-harm
--X60	Intentional self-poisoning by and exposure to nonopioid analgesics, antipyretics and antirheumatics
--X61	Intentional self-poisoning by and exposure to antiepileptic, sedative-hypnotic, antiparkinsonism and psychotropic drugs, not elsewhere classified
--X62	Intentional self-poisoning by and exposure to narcotics and psychodysleptics [hallucinogens], not elsewhere classified
--X63	Intentional self-poisoning by and exposure to other drugs acting on the autonomic nervous system
--X64	Intentional self-poisoning by and exposure to other and unspecified drugs, medicaments and biological substances
--X65	Intentional self-poisoning by and exposure to alcohol
--X66	Intentional self-poisoning by and exposure to organic solvents
--X67	Intentional self-poisoning by and exposure to other gases and vapours
--X68	Intentional self-poisoning by and exposure to pesticides
--X69	Intentional self-poisoning by and exposure to other and unspecified chemicals and noxious substances
--X70	Intentional self-harm by hanging, strangulation and suffocation
--X71	Intentional self-harm by drowning and submersion
--X72	Intentional self-harm by handgun discharge
--X73	Intentional self-harm by rifle, shotgun and larger firearm discharge
--X74	Intentional self-harm by other and unspecified firearm discharge
--X749	Intentional self-harm by rifle, shotgun and larger firearm discharge, home
--X75	Intentional self-harm by explosive material
--X76	Intentional self-harm by smoke, fire and flames
--X77	Intentional self-harm by steam, hot vapours and hot objects
--X78	Intentional self-harm by sharp object
--X79	Intentional self-harm by blunt object
--X8	Assault
--X80	Intentional self-harm by jumping from a high place
--X81	Intentional self-harm by jumping or lying before moving object
--X82	Intentional self-harm by crashing of motor vehicle 
--X83	Intentional self-harm by other specified means 
--X84	Intentional self-harm by unspecified means

--READ
--TK...	Suicide and selfinflicted injury
--TK0..	Suicide + selfinflicted poisoning by solid/liquid substances
--TK00.	Suicide + selfinflicted poisoning by analgesic/antipyretic
--TK01.	Suicide + selfinflicted poisoning by barbiturates
--TK010	Suicide and self inflicted injury by Amylobarbitone
--TK011	Suicide and self inflicted injury by Barbitone
--TK012	Suicide and self inflicted injury by Butabarbitone
--TK013	Suicide and self inflicted injury by Pentabarbitone
--TK014	Suicide and self inflicted injury by Phenobarbitone
--TK015	Suicide and self inflicted injury by Quinalbarbitone
--TK01z	Suicide and self inflicted injury by barbituarates
--TK02.	Suicide + selfinflicted poisoning by oth sedatives/hypnotics
--TK03.	Suicide + selfinflicted poisoning tranquilliser/psychotropic
--TK04.	Suicide + selfinflicted poisoning by other drugs/medicines
--TK05.	Suicide + selfinflicted poisoning by drug or medicine NOS
--TK06.	Suicide + selfinflicted poisoning by agricultural chemical
--TK07.	Suicide + selfinflicted poisoning by corrosive/caustic subst
--TK08.	Suicide + selfinflicted poisoning by arsenic + its compounds
--TK0z.	Suicide + selfinflicted poisoning by solid/liquid subst NOS
--TK1..	Suicide + selfinflicted poisoning by gases in domestic use
--TK10.	Suicide + selfinflicted poisoning by gas via pipeline
--TK11.	Suicide + selfinflicted poisoning by liquified petrol gas
--TK1y.	Suicide and selfinflicted poisoning by other utility gas
--TK1z.	Suicide + selfinflicted poisoning by domestic gases NOS
--TK2..	Suicide + selfinflicted poisoning by other gases and vapours
--TK20.	Suicide + selfinflicted poisoning by motor veh exhaust gas
--TK21.	Suicide and selfinflicted poisoning by other carbon monoxide
--TK2y.	Suicide + selfinflicted poisoning by other gases and vapours
--TK2z.	Suicide + selfinflicted poisoning by gases and vapours NOS
--TK3..	Suicide + selfinflicted injury by hang/strangulate/suffocate
--TK30.	Suicide and selfinflicted injury by hanging
--TK31.	Suicide + selfinflicted injury by suffocation by plastic bag
--TK3y.	Suicide + selfinflicted inj oth mean hang/strangle/suffocate
--TK3z.	Suicide + selfinflicted inj by hang/strangle/suffocate NOS
--TK4..	Suicide and selfinflicted injury by drowning
--TK5..	Suicide and selfinflicted injury by firearms and explosives
--TK50.	Suicide and selfinflicted injury by handgun
--TK51.	Suicide and selfinflicted injury by shotgun
--TK52.	Suicide and selfinflicted injury by hunting rifle
--TK53.	Suicide and selfinflicted injury by military firearms
--TK54.	Suicide and selfinflicted injury by other firearm
--TK55.	Suicide and selfinflicted injury by explosives
--TK5z.	Suicide and selfinflicted injury by firearms/explosives NOS
--TK6..	Suicide and selfinflicted injury by cutting and stabbing
--TK60.	Suicide and selfinflicted injury by cutting
--TK601	Self inflicted lacerations to wrist
--TK61.	Suicide and selfinflicted injury by stabbing
--TK6z.	Suicide and selfinflicted injury by cutting and stabbing NOS
--TK7..	Suicide and selfinflicted injury by jumping from high place
--TK70.	Suicide+selfinflicted injury-jump from residential premises
--TK71.	Suicide+selfinflicted injury-jump from oth manmade structure
--TK72.	Suicide+selfinflicted injury-jump from natural sites
--TK7z.	Suicide+selfinflicted injury-jump from high place NOS
--TKx..	Suicide and selfinflicted injury by other means
--TKx0.	Suicide + selfinflicted injury-jump/lie before moving object
--TKx00	Suicide + selfinflicted injury-jumping before moving object
--TKx01	Suicide + selfinflicted injury-lying before moving object
--TKx0z	Suicide + selfinflicted inj-jump/lie before moving obj NOS
--TKx1.	Suicide and selfinflicted injury by burns or fire
--TKx2.	Suicide and selfinflicted injury by scald
--TKx3.	Suicide and selfinflicted injury by extremes of cold
--TKx4.	Suicide and selfinflicted injury by electrocution
--TKx5.	Suicide and selfinflicted injury by crashing motor vehicle
--TKx6.	Suicide and selfinflicted injury by crashing of aircraft
--TKx7.	Suicide and selfinflicted injury caustic subst, excl poison
--TKxy.	Suicide and selfinflicted injury by other specified means
--TKxz.	Suicide and selfinflicted injury by other means NOS
--TKy..	Late effects of selfinflicted injury
--TKz..	Suicide and selfinflicted injury NOS

DROP TABLE IF EXISTS #suicide_acc_med

SELECT b.snz_uid
    , a.[snz_acc_claim_uid]
    , 'ACC_MED' AS source
    , [acc_med_read_code] AS code_raw
    , [acc_med_read_code_text] AS txt_raw
    , [acc_cla_accident_date] AS date
    , 'Self-harm' AS type
INTO #suicide_acc_med
FROM [IDI_Clean_202406].[acc_clean].[medical_codes] AS a
LEFT JOIN [IDI_Clean_202406].[acc_clean].[claims] AS b
ON a.snz_acc_claim_uid = b.snz_acc_claim_uid
WHERE [acc_med_read_code_text] LIKE '%SUICIDE%'
OR [acc_med_read_code_text] LIKE '%SELFINF%'
OR [acc_med_read_code_text] LIKE '%SELF INF%' 


DROP TABLE IF EXISTS #suicide_acc_claims_2

SELECT [snz_uid]
    , 'ACC' AS source
    , [acc_cla_accident_date] AS alt_date
    , acc_cla_wil_self_infl_ind_date AS date
    , CASE WHEN [acc_cla_fatal_ind]='Y' THEN 'Suicide'
	  ELSE 'Attempted'
	  END AS type
    , [acc_cla_wil_self_infl_stat_text]
    , [snz_acc_claim_uid]
    , acc_cla_cause_desc
    , [acc_cla_contact_desc]
    , [acc_cla_external_agency_text]
    , [acc_cla_read_code]
    , [acc_cla_read_code_text]
INTO #suicide_acc_claims_2
FROM [IDI_Clean_202406].[acc_clean].[claims]
WHERE(
    [acc_cla_wil_self_infl_stat_text] IS NOT NULL
    AND [acc_cla_wil_self_infl_stat_text] ! = 'NONE'
)
OR [acc_cla_read_code_text] LIKE '%SUICIDE%'
OR [acc_cla_read_code_text] LIKE '%SELFINF%'
OR [acc_cla_read_code_text] LIKE '%SELF INF%'
OR(
    SUBSTRING([acc_cla_ICD9_code],1,4) >= 'E950'
    AND SUBSTRING([acc_cla_ICD9_code],1,4) <= 'E957'
)
OR(
    SUBSTRING([acc_cla_ICD10_code],1,3) >= 'X60'
    AND SUBSTRING([acc_cla_ICD10_code],1,3) <= 'X84'
)

---------------------------------------------------------------------
--5. NIA 2009 July - 2017 + a few in 2018

DROP TABLE IF EXISTS #suicide_nia

SELECT [snz_uid]
    , 'NIA' AS source
    , NULL AS date
    , [nia_links_rec_date] AS alt_date
    , [nia_links_latest_inc_off_code] AS code_raw
    , [nia_links_latest_inc_off_desc] AS txt_raw
    , 'Attempted' AS type
INTO #suicide_nia
FROM [IDI_Clean_202406].[pol_clean].[nia_links]
WHERE [nia_links_latest_inc_off_code] IN ('1X')
ORDER BY snz_uid
    , [nia_links_rec_date]

---------------------------------------------------------------------
--6. CYF findings

--Code	Label
--**OTHER**	Unknown
--BRD	Behavioural/Relationship Difficulties
--EMO	Emotionally abused by
--NEG	Neglected by
--NTF	Not Found
--PHY	Physically abused by
--SEX	Sexually abused by
--SHM	Self Harm
--SHS	Self Harm/Suicidal
--SUC	Suicidal
--UNK	Unknown or not entered
--XXX	Not applicable

DROP TABLE IF EXISTS #suicide_cyf_fnd

SELECT [snz_uid]
    , 'CYF_FND' AS source
    , [cyf_abe_source_uk_var2_text] AS code
	  --need to check the codes are correct
    , CASE WHEN [cyf_abe_source_uk_var2_text] IN ('SUC') THEN 'Suicidal'
	  WHEN [cyf_abe_source_uk_var2_text] IN ('SHM','SHS') THEN 'Attempted'
	  ELSE NULL END AS type
    , [cyf_abe_event_from_date_wid_date] AS date
    , NULL AS alt_date
INTO #suicide_cyf_fnd
FROM [IDI_Clean_202406].[cyf_clean].[cyf_abuse_event]
WHERE [cyf_abe_source_uk_var2_text] IN ('SHS','SHM','SUC')

---------------------------------------------------------------------
--7. msd incap - no self harm categories

--Code	Label
--ACDN	Accident
--DK	Not known
--NACD	Natural causes - non-accident
--NACS	Suicide - non-accident n=278 need to find table

DROP TABLE IF EXISTS #msd_cod

SELECT [snz_uid]
    , [msd_cus_cod_code] AS code_raw
    , 'MSD_COD' AS source
    , 'Suicide - non-accident' AS txt_raw
    , DATEFROMPARTS([msd_cus_death_year_nbr],[msd_cus_death_month_nbr],1) AS alt_date
    , DATEFROMPARTS(NULL,NULL,NULL) AS date
    , 'Suicide' AS type
INTO #msd_cod
FROM [IDI_Clean_202406].[msd_clean].[msd_customer]
WHERE [msd_cus_cod_code] = 'NACS'

---------------------------------------------------------------------
--8. Gateway

DROP TABLE IF EXISTS #msd_gtw

SELECT b.[snz_uid]
    , 'MSD_GTW' AS source
    , [needs_desc] AS type
    , [need_category_code] AS code_raw

    , [needs_created_date] AS alt_date
INTO #msd_gtw
FROM [IDI_Adhoc].[clean_read_CYF].[cyf_gateway_cli_needs] AS a
    , [IDI_Clean_202406].[msd_clean].[msd_customer] AS b
WHERE [needs_desc] IN ('Suicidal','Self Harm/Suicide','Self Harm')
AND a.[snz_msd_uid] = b.[snz_msd_uid]

---------------------------------------------------------------------
--9. - SOCRATES

DROP TABLE IF EXISTS #SUICIDE_MOH_SOC

SELECT DISTINCT C.snz_uid
    , a.[snz_moh_uid]
    , 'MOH_SOC' AS source
    , [Code] AS CODE_RAW
    , [Description] AS type
    , CAST(SUBSTRING([DateAssessmentCompleted],1,7) AS date) AS alt_date
INTO #suicide_moh_soc
FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_support_needs] AS a
    , [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_needs_assessment] AS b
    , [IDI_Clean_202406].[moh_clean].[pop_cohort_demographics] AS C
WHERE CODE = '1707'
AND a.[snz_moh_uid] = b.[snz_moh_uid]
AND a.[NeedsAssessmentID] = b.[NeedsAssessmentID]
AND a.[snz_moh_soc_client_uid] = b.[snz_moh_soc_client_uid]
AND A.snz_moh_uid = C.snz_moh_uid

---------------------------------------------------------------------
-- final


--master file
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[suicide_or_attempted]

SELECT DISTINCT source
    , snz_uid
    , COALESCE(date, alt_date) AS date
    , IIF(source = 'MOH_COD' OR type='Suicide', 1, 0) AS suicide
INTO [IDI_Sandpit].[DL-MAA2023-46].[suicide_or_attempted]
FROM(
    SELECT type
        , source
        , snz_uid
        , date
        , alt_date
    FROM #suicide_pub
    UNION ALL
    SELECT type
        , source
        , snz_uid
        , NULL AS date
        , alt_date
    FROM #suicide_nia
    UNION ALL
    SELECT type
        , source
        , snz_uid
        , date
        , NULL AS alt_date
    FROM #suicide_cod
    UNION ALL
    SELECT type
        , source
        , snz_uid
        , NULL AS date
        , alt_date
    FROM #suicide_moh_soc
    UNION ALL
    SELECT NULL AS type
        , source
        , snz_uid
        , NULL AS date
        , alt_date
    FROM #moh_primhd_team
    UNION ALL
    SELECT NULL AS type
        , source
        , snz_uid
        , NULL AS date
        , alt_date
    FROM #moh_primhd_code
    UNION ALL
    SELECT type
        , source
        , snz_uid
        , date
        , NULL AS alt_date
    FROM #suicide_cyf_fnd
    UNION ALL
    SELECT type
        , source
        , snz_uid
        , date
        , alt_date
    FROM #moh_pri
    UNION ALL
    SELECT type
        , source
        , snz_uid
        , NULL AS date
        , alt_date
    FROM #msd_gtw
    UNION ALL
    SELECT type
        , source
        , snz_uid
        , date
        , NULL AS alt_date
    FROM #suicide_acc_med
    UNION ALL
    SELECT type
        , source
        , snz_uid
        , NULL AS date
        , alt_date
    FROM #msd_cod
)AS a
