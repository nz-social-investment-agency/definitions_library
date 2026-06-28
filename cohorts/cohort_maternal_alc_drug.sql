/**************************************************************************************************
Title: Maternal Substance Use
Author: Charlotte Rose
Reviewer: Simon Anastasiadis

Description:
This definition takes children born in NZ (still or live births) and looks at their mother's obseravble substance use before, during and after pregnancy.

The cohorts of interest are:

- Children under the age of five who have a mother with evidence of substance use at any time conception to th child's 5th birthday
- Mothers with child(ren) under the age of 5 with evidence of substance use at any time a childs conception to the child(ren)'s 5th birthday

We split this into 4 time frames:

- 1 year before pregnancy (i.e. 'recent' use)
- Prenatal period (conception to <28 days after birth)
- Early life (28 days after birth to 2nd birthday)

and a combined

- First 1000 days which includes the period between conception to 2nd birthday (prenatal and early life)

and 

- First 2000 days which includes the period between conception to 5nd birthday

Use is split into 
- Alchol use
- Drug use

and a combined

- AOD use (alcohol and or drug use)

The first three measures and susbstance type splits are primerily included for modelling purposes, and the first 1000 days is used for valiadation against published figures.

Our overall interest being 'any use in the first 2000 days' 

Substance use is defined by SIA's existing measures which draw from data from:
- Justice
- Health (hospital/primhd)
- Pharmaceuticals
- ACC
etc

Additionally we look at signals of in-utero exposure in hospital data and diagnoses of FASD.

Inputs & Dependencies:
- [IDI_Clean_$(REFRESH)].[dia_clean].[births]
- [IDI_Clean_$(REFRESH)].[data].[personal_detail]
- [IDI_Clean_$(REFRESH)].[security].[concordance]
- [IDI_Community].[dsbl_fasd].[fasd_$(REFRESH)]
- [IDI_Clean_$(REFRESH)].[moh_clean].[socrates_disability]
- [IDI_Adhoc].[clean_read_MOH_PRIMHD].[primhd_diagnoses_202510]
- [IDI_Adhoc].[clean_read_CYF].[cyf_gateway_cli_needs_202511]
- [IDI_Clean_$(REFRESH)].[moh_clean].[pub_fund_hosp_discharges_event]
- [IDI_Clean_$(REFRESH)].[moh_clean].[pub_fund_hosp_discharges_diag]
- [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_mha_alcohol_abuse_or_dependence_$(REFRESH)] (mha_alcohol_abuse_or_dependence.sql)
- [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_mha_drug_abuse_or_dependence_$(REFRESH)] (mha_drug_abuse_or_dependence.sql)

Output:
- [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[mother_child_w_aod_flag_$(REFRESH)]
- [IDI_UserCode].[$(PROJECT_SCHEMA)].[cohort_maternal_aod_$(REFRESH)] -- for pipeline


Notes:
1) As birth date proxy is used, 28 days post birth is an estimate only.
2) Gestation (weeks) where available is used to calculate conception, however where this is missing, 40 weeks has been used as standard.
3) % figures for births between 2008 and 2017 were compared to a published study of maternal substance abuse in New South Wales.
	That study used health, child protection and mortality data. Our results are within one percentage point of the NSW results.
	While there will be differences in data and NSW vs. NZ context, this is reassuring that our results are consistent with
	the general pattersn observed elsewhere.

			% of children born 2008-2017 exposed to maternal substance abuse in first 1000 days 
					total children  	alcohol			drug		 	either/both
			NSW		970,470				13,637(1.4%)	23,485(2.4%)	32,647 (3.4%)

	"Powell et al (2025) Prevalence of maternal substance use problems during pregnancy and the first 2 years of life:
	a whole-population birth cohort of 970,470 Australian children born 2008-2017: pubmed.ncbi.nlm.nih.gov/40127908/"

5) Estimated rates of maternal substance use are generally higher than can be observed. 
In an NZ context it is reported that:
- An estimated 22-28% of mothers continue to consume alcohol after recognising they are pregnant with 12-13% continuing to drink into the 2nd trimester. (Growing up in New Zealand Study 2017 & 2018)
- 4.5% of pregnant women report cannabis use (2012/13 NZHS)
- Little is known about the prevalence of meth, opioid and other drug use during preganncy in NZ (See Maessen & Wouldes (2019) Parental alcohol, cannabis, methamphetamine and opioid use during pregnancy. MoH)

Parameters & Present values:
  Current refresh = $(REFRESH)
  Prefix = cohort_
  Project schema = [$(PROJECT_SCHEMA)]
  Residence year range = 2009 to 2025

Issues:
1) We are waiting for the FASD code module to be updated with new data tables. Once complete, the additional tables in the script can be removed (PRIMHD, socrates, gateway)

History (reverse order):
2026-01-16 CR changed intermediate sandpit table name to avoid confusion (it is ALL mothers and children, with a flag for AOD)
2026-01-15 CR updated definition to reflect definition agrred to by the Crown Response Office
2026-01-09 SA restyle and review
2025-02-12 CR v1
**************************************************************************************************/

 :SETVAR PROJECT_DB "SIA_Sandpit"
 :SETVAR PROJECT_SCHEMA "DL-MAA2026-04"
 :SETVAR REFRESH "202603"

---------------------------------------------------------------------
-- mothers temporary table
---------------------------------------------------------------------

-- create table
DROP TABLE IF EXISTS #mothers
GO

CREATE TABLE #mothers (
	child_snz_uid INT NOT NULL
	,mother_snz_uid INT NOT NULL
	,birth_date_proxy DATE NOT NULL
	,[gestation_weeks] INT
	,still_born INT
	,death_date_proxy DATE
)

-- populate with all parents
INSERT INTO #mothers
SELECT b.snz_uid AS child_snz_uid
	, [parent1_snz_uid] AS mother_snz_uid
	, DATEFROMPARTS([dia_bir_birth_year_nbr], [dia_bir_birth_month_nbr], 15) AS birth_date_proxy
	, IIF([dia_bir_birth_gestation_nbr] BETWEEN 1 AND 50, [dia_bir_birth_gestation_nbr], 40) AS [gestation_weeks]
	, IIF(dia_bir_still_birth_code IS NOT NULL, 1, NULL) AS still_born
	, DATEFROMPARTS(pd.snz_deceased_year_nbr, pd.snz_deceased_month_nbr, 15) AS death_date_proxy
FROM [IDI_Clean_$(REFRESH)].[dia_clean].[births] AS b
INNER JOIN [IDI_Clean_$(REFRESH)].[data].[personal_detail] pd ON pd.snz_uid = b.snz_uid
WHERE [dia_bir_birth_year_nbr] > 2005 --most AOD data starts in the late 2010s
AND [parent1_snz_uid] IS NOT NULL
AND snz_spine_ind = 1
AND snz_person_ind = 1
AND ([parent1_snz_uid] <> [parent2_snz_uid] OR [parent2_snz_uid] IS NULL)
-- exclude if parent1 = parent2, we have been advised these records are of low reliability
GO

INSERT INTO #mothers
SELECT b.snz_uid as child_snz_uid
	, [parent2_snz_uid] AS mother_snz_uid
	, DATEFROMPARTS([dia_bir_birth_year_nbr], [dia_bir_birth_month_nbr], 15) AS birth_date_proxy
	, IIF([dia_bir_birth_gestation_nbr] BETWEEN 1 AND 50, [dia_bir_birth_gestation_nbr], 40) AS [gestation_weeks]
	, IIF(dia_bir_still_birth_code IS NOT NULL, 1, NULL) AS still_born
	, DATEFROMPARTS(pd.snz_deceased_year_nbr, pd.snz_deceased_month_nbr, 15) AS death_date_proxy
FROM [IDI_Clean_$(REFRESH)].[dia_clean].[births] AS b
INNER JOIN [IDI_Clean_$(REFRESH)].[data].[personal_detail] pd ON pd.snz_uid = b.snz_uid
WHERE [dia_bir_birth_year_nbr] > 2005 --most AOD data starts in the late 2010s
AND [parent2_snz_uid] IS NOT NULL
AND snz_spine_ind = 1
AND snz_person_ind = 1
AND ([parent1_snz_uid] <> [parent2_snz_uid] OR [parent1_snz_uid] IS NULL) -- exclude if parent1 = parent2
GO

-- index
CREATE NONCLUSTERED INDEX i_mother ON #mothers (mother_snz_uid)
CREATE NONCLUSTERED INDEX i_child ON #mothers (child_snz_uid)
GO

-- remove non-mothers
DELETE FROM #mothers
WHERE NOT EXISTS (
	SELECT 1
	FROM [IDI_Clean_$(REFRESH)].[data].[personal_detail] AS p
	WHERE #mothers.mother_snz_uid = p.snz_uid
	AND p.[snz_sex_gender_code] = 2
	AND p.snz_spine_ind = 1
	AND p.snz_person_ind = 1
	AND p.snz_deceased_year_nbr IS NULL --mother is alive
)


---------------------------------------------------------------------
-- main table
---------------------------------------------------------------------

DROP TABLE IF EXISTS [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[mother_child_w_aod_flag_$(REFRESH)]
GO

WITH mothers_with_date_ranges AS (

	SELECT child_snz_uid
		, mother_snz_uid
		, birth_date_proxy
		, DATEADD(WEEK, -1 * gestation_weeks, birth_date_proxy) AS conception_date_proxy
		, DATEADD(YEAR, -1, DATEADD(WEEK, -1 * gestation_weeks, birth_date_proxy)) AS year_before_conception_proxy
		, DATEADD(MONTH, 1, EOMONTH(birth_date_proxy)) AS prenatal_period_end_proxy
		, DATEADD(YEAR, 2, birth_date_proxy) AS second_birthday_proxy
		, DATEADD(YEAR, 5, birth_date_proxy) AS fifth_birthday_proxy
		, gestation_weeks
		, still_born
		, death_date_proxy
	FROM #mothers

),
-- Fetal Alcohol Syndrome Disorder
FASD AS (

    SELECT c.snz_uid
        , IIF(
			f.snz_uid IS NOT NULL
			OR a.snz_msd_uid IS NOT NULL
			OR s.snz_uid IS NOT NULL
			OR p.snz_moh_uid IS NOT NULL , 1, 0) AS FASD

    FROM [IDI_Clean_$(REFRESH)].[security].[concordance] AS c

    LEFT JOIN [IDI_Community].[dsbl_fasd].[fasd_$(REFRESH)] AS f --FASD (not yet updated with 2025 socrates/202603 primhd or 202511 gateway)
    ON c.snz_uid = f.snz_uid

	--the below can be removed when code module is updated
    LEFT JOIN [IDI_Adhoc].[clean_read_CYF].[cyf_gateway_cli_needs_202511] AS a
    ON c.snz_msd_uid = a.snz_msd_uid
    AND need_type_code = 'FAE' -- Foetal Alcohol Spectrum Disorder

    LEFT JOIN [IDI_Clean_$(REFRESH)].[moh_clean].[socrates_disability] AS s
    ON c.snz_uid = s.snz_uid
    AND soc_dis_code = 1106 -- FASD

    LEFT JOIN [IDI_Adhoc].[clean_read_MOH_PRIMHD].[primhd_diagnoses_202510] AS p
    ON c.snz_moh_uid = p.snz_moh_uid
    AND SUBSTRING(p.[clinical_code],1,4) = 'Q860'
    AND p.[clinical_coding_system_id] >= '10'

),
-- exposure detected during neonates
neonates AS (

    SELECT DISTINCT e.snz_uid -- child snz_uid
        , SUBSTRING(moh_dia_clinical_code,1,4) AS code

    FROM [IDI_Clean_$(REFRESH)].[moh_clean].[pub_fund_hosp_discharges_event] AS e
    INNER JOIN [IDI_Clean_$(REFRESH)].[moh_clean].[pub_fund_hosp_discharges_diag] AS d
    ON e.moh_evt_event_id_nbr = d.moh_dia_event_id_nbr
    WHERE moh_dia_clinical_sys_code = moh_dia_submitted_system_code
	--Clinical codes--
    AND SUBSTRING([moh_dia_clinical_code],1,4) IN (
		'P043' -- fetus and newborn affected by maternal use of alcohol
		, 'P044' -- fetus and newborn affected by maternal use of drugs of addiction 
		, 'P961' -- withdrawal symptoms from maternal use of drugs of addiction
	)

)
SELECT child_snz_uid -- should appear only once
	, mother_snz_uid -- should appear once for each birth
	, birth_date_proxy
	, conception_date_proxy
	, year_before_conception_proxy
	, prenatal_period_end_proxy
	, second_birthday_proxy
	, fifth_birthday_proxy
	, gestation_weeks
	, still_born
	, CASE WHEN still_born = 1 THEN birth_date_proxy
		WHEN death_date_proxy IS NOT NULL THEN death_date_proxy
		ELSE NULL
		END AS death_date_proxy

	--Previous: 1 yr before pregnancy
    , MAX(IIF(a.event_date BETWEEN year_before_conception_proxy AND conception_date_proxy, 1, 0)) AS alc_1yr_prior
    , MAX(IIF(d.event_date BETWEEN year_before_conception_proxy AND conception_date_proxy, 1, 0)) AS drg_1yr_prior
    , MAX(IIF(COALESCE(a.event_date,d.event_date) BETWEEN year_before_conception_proxy AND conception_date_proxy, 1, 0)) AS aod_1yr_prior
	
	--Prenatal period: conception to ~<28 days post birth) -- ~ due to birth date proxy
    , MAX(IIF(a.event_date BETWEEN conception_date_proxy AND prenatal_period_end_proxy OR c.code = 'P043' OR f.snz_uid IS NOT NULL, 1, 0)) AS alc_prenatal
    , MAX(IIF(d.event_date BETWEEN conception_date_proxy AND prenatal_period_end_proxy OR c.code IN ('P044','P961'),1,0)) AS drg_prenatal
    , MAX(IIF(COALESCE(a.event_date,d.event_date) BETWEEN conception_date_proxy AND prenatal_period_end_proxy OR f.snz_uid IS NOT NULL OR c.snz_uid IS NOT NULL, 1, 0)) AS aod_prenatal
	
	--Early life: ~28 days to 2nd birthday
    , MAX(IIF(a.event_date BETWEEN prenatal_period_end_proxy AND second_birthday_proxy, 1, 0)) AS alc_early_life
    , MAX(IIF(d.event_date BETWEEN prenatal_period_end_proxy AND second_birthday_proxy, 1, 0)) AS drg_early_life
    , MAX(IIF(COALESCE(a.event_date,d.event_date) BETWEEN prenatal_period_end_proxy AND second_birthday_proxy, 1, 0)) AS aod_early_life
	
	--First 1000 days: conception to 2nd birthday
    , MAX(IIF(a.event_date BETWEEN conception_date_proxy AND second_birthday_proxy OR c.code = 'P043' OR f.snz_uid IS NOT NULL, 1, 0)) AS alc_f1000days
    , MAX(IIF(d.event_date BETWEEN conception_date_proxy AND second_birthday_proxy OR c.code IN ('P044','P961'), 1, 0)) AS drg_f1000days
    , MAX(IIF(COALESCE(a.event_date,d.event_date) BETWEEN conception_date_proxy AND second_birthday_proxy OR f.snz_uid IS NOT NULL OR c.snz_uid IS NOT NULL, 1, 0)) AS aod_f1000days 

	--First 2000 days: conception to 5th birthday - note this definition of 2000 days differs slightly to the standard (which is birth to 5yr ~9mo)
    , MAX(IIF(a.event_date BETWEEN conception_date_proxy AND fifth_birthday_proxy OR c.code = 'P043' OR f.snz_uid IS NOT NULL, 1, 0)) AS alc_f2000days
    , MAX(IIF(d.event_date BETWEEN conception_date_proxy AND fifth_birthday_proxy OR c.code IN ('P044','P961'), 1, 0)) AS drg_f2000days
    , MAX(IIF(COALESCE(a.event_date,d.event_date) BETWEEN conception_date_proxy AND fifth_birthday_proxy OR f.snz_uid IS NOT NULL OR c.snz_uid IS NOT NULL, 1, 0)) AS aod_f2000days -- indiciator for analysis

	--cohort membership--

	, conception_date_proxy AS cohort_start
	, CASE WHEN still_born = 1 THEN birth_date_proxy
		WHEN death_date_proxy IS NOT NULL THEN death_date_proxy
		ELSE DATEADD(YEAR, 5, birth_date_proxy) 
		END AS cohort_end

INTO [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[mother_child_w_aod_flag_$(REFRESH)]
FROM mothers_with_date_ranges AS m
LEFT JOIN [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_mha_alcohol_abuse_or_dependence_$(REFRESH)] AS a
ON m.mother_snz_uid = a.snz_uid
LEFT JOIN [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_mha_drug_abuse_or_dependence_$(REFRESH)] AS d
ON m.mother_snz_uid = d.snz_uid
LEFT JOIN FASD AS f
ON m.child_snz_uid = f.snz_uid
AND FASD = 1
LEFT JOIN neonates AS c
ON m.child_snz_uid = c.snz_uid
GROUP BY m.mother_snz_uid
    , m.child_snz_uid
    , birth_date_proxy
	, conception_date_proxy
	, year_before_conception_proxy
	, prenatal_period_end_proxy
	, second_birthday_proxy
	, fifth_birthday_proxy
	, gestation_weeks
	, still_born
	, death_date_proxy
GO

-- Compression
EXEC [IDI_UserCode].[$(PROJECT_SCHEMA)].[compress_table_$(PROJECT_DB)] @table = '[$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[mother_child_w_aod_flag_$(REFRESH)]'
GO

CREATE NONCLUSTERED INDEX i_mother ON [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[mother_child_w_aod_flag_$(REFRESH)] (mother_snz_uid)
CREATE NONCLUSTERED INDEX i_child ON [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[mother_child_w_aod_flag_$(REFRESH)] (child_snz_uid)
GO

-- for 202603 cohort assembly

USE IDI_UserCode
GO

DROP VIEW IF EXISTS [$(PROJECT_SCHEMA)].[cohort_maternal_aod_$(REFRESH)]
GO

CREATE VIEW [$(PROJECT_SCHEMA)].[cohort_maternal_aod_$(REFRESH)] AS
SELECT *
FROM  [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[mother_child_w_aod_flag_$(REFRESH)] AS m
WHERE aod_f2000days = 1
GO




