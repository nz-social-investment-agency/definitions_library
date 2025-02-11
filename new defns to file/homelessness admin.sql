/**************************************************************************************************
Title: Homelessness indicator
Author: Verity Warn, based on Craig's Wright code

Inputs & Dependencies:
- [IDI_Metadata].[clean_read_CLASSIFICATIONS].[CEN_OCCDWELTYPE]
- [IDI_Clean_20211020].[msd_clean].[msd_third_tier_expenditure]
- [IDI_Metadata].[clean_read_CLASSIFICATIONS].[msd_income_support_pay_reason]
- [IDI_Clean_20211020].[msd_clean].[msd_partner]
- [IDI_Clean_20211020].[msd_clean].[msd_child]
- [IDI_Clean_20211020].[hnz_clean].[new_applications]
- [IDI_Clean_20211020].[hnz_clean].[new_applications_household]

Outputs:
- [IDI_Sandpit].[DL-MAA2021-60].[homelessness_ind]

Description:
- Create a list of all snz_uids who, based on this definition, are homeless
- This definition uses MSD emergency housing and HNZ social housing applications in order to identify homelessness/severly inadequate housing

Intended purpose:
- To identify characteristics & service interactions of those who are homeless

Notes:
- Analytic approach
	1. Identify homelessness through emergency housing
	2. Identify homelessness through social housing applications
	3. Union all snz_uid (distinct) = homeless-at-some-pt-in-2019 population 

Parameters & Present values:
  Current refresh = 20211020
  Prefix = defn_
  Project schema = [DL-MAA2021-60]
  Study year: 2019

Issues:

History (reverse order):
2022-05-16 VWarn Change date from parts to 'YYYY-MM-DD' to remove redundancy 
2022-03-01 CWright original version
**************************************************************************************************/

---------------------------------------------------------------------
-- Emergency housing (MSD) users in 2019

/* 1. Identify all primary applicants */
DROP TABLE IF EXISTS #primary_eh

SELECT snz_uid
    , msd_tte_app_date
INTO #primary_eh
FROM (
    SELECT *
    FROM [IDI_Clean_20211020].[msd_clean].[msd_third_tier_expenditure]
    WHERE [msd_tte_pmt_rsn_type_code] IN ('855') -- emergency housing  
    AND [msd_tte_app_date] >= '2019-01-01'
    AND [msd_tte_app_date] <= '2019-12-31'
)AS a
LEFT JOIN [IDI_Metadata].[clean_read_CLASSIFICATIONS].[msd_income_support_pay_reason] AS b
ON a.msd_tte_pmt_rsn_type_code = b.payrsn_code


/* 2. Identify partners of primary applications */
DROP TABLE IF EXISTS #partner_eh

SELECT a.snz_uid
    , [partner_snz_uid]
    , [msd_tte_app_date]
INTO #partner_eh
FROM #primary_eh AS a
INNER JOIN [IDI_Clean_20211020].[msd_clean].[msd_partner] AS b
ON a.snz_uid = b.snz_uid
WHERE [msd_ptnr_ptnr_from_date] <= [msd_tte_app_date]
AND [msd_ptnr_ptnr_to_date] >= [msd_tte_app_date]


/* 3. Identify children of primary applicants */
DROP TABLE IF EXISTS #children_eh

SELECT DISTINCT a.[snz_uid]
    , [child_snz_uid]
    , [msd_tte_app_date]
INTO #children_eh
FROM #primary_eh AS a
INNER JOIN [IDI_Clean_20211020].[msd_clean].[msd_child] AS b
ON a.snz_uid = b.snz_uid
WHERE [msd_chld_child_from_date] <= [msd_tte_app_date]
AND [msd_chld_child_to_date] >= [msd_tte_app_date]


/* 4. Union distinct primary, partner and children emergency housing users */
DROP TABLE IF EXISTS #EH_homeless

SELECT snz_uid
    , COUNT(*) AS num_eh -- this count is just for interest, not need for definition
INTO #EH_homeless
FROM(
    SELECT snz_uid
    FROM #primary_eh
    UNION ALL
    SELECT partner_snz_uid AS snz_uid
    FROM #partner_eh
    UNION ALL
    SELECT child_snz_uid AS snz_uid
    FROM #children_eh
)AS a
GROUP BY snz_uid

---------------------------------------------------------------------
-- Homelessness from social housing applications

DROP TABLE IF EXISTS #SH_homeless

SELECT b.[snz_uid]
		--,[hnz_na_date_of_application_date]
		--,a.[snz_msd_application_uid]
		--,[hnz_na_main_reason_app_text]
		--,[snz_idi_address_register_uid]
INTO #SH_homeless
FROM [IDI_Clean_20211020].[hnz_clean].[new_applications] AS a
    , [IDI_Clean_20211020].[hnz_clean].[new_applications_household] AS b
WHERE a.snz_msd_application_uid = b.snz_msd_application_uid
AND CAST([hnz_na_date_of_application_date] AS date) >= '2019-01-01'
AND CAST([hnz_na_date_of_application_date] AS date) <= '2019-12-31'
AND [hnz_na_main_reason_app_text] IN('HOMELESSNESS','CURRENT ACCOMMODATION IS INADEQUATE OR UNSUITABLE','INADEQUATE','UNSUITABLE')

---------------------------------------------------------------------
-- Homelessness from public hospital causes

-- Diagnosis table includes causes:
-- Z590 homeless
-- Z591 inadequate housing

DROP TABLE IF EXISTS #HOSP_homeless

SELECT b.[snz_uid]
INTO #HOSP_homeless
FROM [IDI_Clean_20211020].[moh_clean].[pub_fund_hosp_discharges_diag] AS a
    , [IDI_Clean_20211020].[moh_clean].[pub_fund_hosp_discharges_event] AS b
WHERE [moh_dia_clinical_sys_code] = [moh_dia_submitted_system_code]
AND [moh_evt_event_id_nbr] = [moh_dia_event_id_nbr]
AND SUBSTRING([moh_dia_clinical_code],1,4) IN ('Z590','Z591')

---------------------------------------------------------------------
-- Join all homeless groups together, find distinct population

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2021-60].[homelessness_ind]

SELECT DISTINCT snz_uid
INTO [IDI_Sandpit].[DL-MAA2021-60].[homelessness_ind]
FROM(
    SELECT snz_uid
    FROM #EH_homeless

    UNION ALL

    SELECT snz_uid
    FROM #SH_homeless
	
	UNION ALL
	
	SELECT snz_uid
	FROM #HOSP_homeless
)AS a
GROUP BY snz_uid
