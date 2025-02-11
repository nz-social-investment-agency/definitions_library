/**************************************************************************************************
Title: Health Service User Population
Author: Craig Wright

Description:
Proxy to Health Service User Population within the IDI, from 2020 onward.

Inputs & Dependencies:
	[IDI_SANDPIT].[DL-MAA2021-49].[CW_20211020_HSU_20202021_V02]
	[IDI_CLEAN_20211020].[MOH_CLEAN].[INTERRAI]
	[IDI_CLEAN_20211020].[MOH_CLEAN].[LAB_CLAIMS]
	[IDI_CLEAN_20211020].[MOH_CLEAN].[NES_ENROLMENT]
	[IDI_CLEAN_20211020].[MOH_CLEAN].[NNPAC]
	[IDI_CLEAN_20211020].[MOH_CLEAN].[PHARMACEUTICAL]
	[IDI_CLEAN_20211020].[MOH_CLEAN].[PRIMHD]
	[IDI_CLEAN_20211020].[MOH_CLEAN].[PRIV_FUND_HOSP_DISCHARGES_EVENT]
	[IDI_CLEAN_20211020].[MOH_CLEAN].[PUB_FUND_HOSP_DISCHARGES_EVENT]
	[IDI_ADHOC].[CLEAN_READ_MOH_SOCRATES].[MOH_SERVICE_HIST_202110]

Outputs:
	[IDI_Sandpit].[DL-MAA2021-49].[pop_health_service_users_2020]

Notes:
- MOH used an internal population of HSU or Health Service Users.
	This script creates a proxy for this population within the IDI.


Parameters & Present values:
	Current refresh = 20211020
	Prefix = pop_
	Project schema = [DL-MAA2021-49]
 
Issues:

History (reverse order):
2021-09-30 C Wright: created
**************************************************************************************************/

---------------------------------------------------------------------
--1. interrai

DROP TABLE IF EXISTS #moh_irai

SELECT DISTINCT [snz_uid]
	--,[snz_moh_uid]
	--,[moh_irai_assessment_date]
INTO #moh_irai
FROM [IDI_Clean_20211020].[moh_clean].[interrai]
WHERE [moh_irai_assessment_date] >= '2020-01-01'

---------------------------------------------------------------------
--2. labs claims

DROP TABLE IF EXISTS #moh_lab

SELECT DISTINCT [snz_uid]
	--,[snz_moh_uid]
	-- ,[moh_lab_visit_date]
INTO #moh_lab
FROM [IDI_Clean_20211020].[moh_clean].[lab_claims]
WHERE [moh_lab_visit_date] >= '2020-01-01'

---------------------------------------------------------------------
--3. NES enrolment

DROP TABLE IF EXISTS #moh_nes

SELECT DISTINCT b.snz_uid
	--[snz_moh_uid]
    --,[moh_nes_snapshot_month_date]
INTO #moh_nes
FROM [IDI_Clean_20211020].[moh_clean].[nes_enrolment] AS a
    , [IDI_Clean_20211020].[moh_clean].[pop_cohort_demographics] AS b
WHERE CAST([moh_nes_snapshot_month_date] AS date) >= '2020-01-01'
AND a.snz_moh_uid = b.snz_moh_uid

---------------------------------------------------------------------
--4. nnpac

DROP TABLE IF EXISTS #moh_nnp

SELECT DISTINCT [snz_uid]
	--,[snz_moh_uid]
	--,[moh_nnp_service_date]
INTO #moh_nnp
FROM [IDI_Clean_20211020].[moh_clean].[nnpac]
WHERE [moh_nnp_service_date] >= '2020-01-01'

---------------------------------------------------------------------
--5. PHARMS

DROP TABLE IF EXISTS #moh_pha

SELECT DISTINCT [snz_uid]
	--,[snz_moh_uid]
	--,[moh_pha_dispensed_date]
INTO #moh_pha
FROM [IDI_Clean_20211020].[moh_clean].[pharmaceutical]
WHERE [moh_pha_dispensed_date] >= '2020-01-01'

---------------------------------------------------------------------
--6. PRIMHD

DROP TABLE IF EXISTS #moh_primhd

SELECT DISTINCT [snz_uid]
	--,[snz_moh_uid]
	--,[moh_mhd_referral_start_date]
	--,[moh_mhd_referral_end_date]
INTO #moh_primhd
FROM [IDI_Clean_20211020].[moh_clean].[PRIMHD]
WHERE [moh_mhd_referral_end_date] >= '2020-01-01'
OR [moh_mhd_referral_end_date] IS NULL

---------------------------------------------------------------------
--7. private hospital

DROP TABLE IF EXISTS #moh_pri

SELECT DISTINCT [snz_uid]
	--,[snz_moh_uid]
	--,[moh_pri_evt_start_date]
	--,[moh_pri_evt_end_date]
INTO #moh_pri
FROM [IDI_Clean_20211020].[moh_clean].[priv_fund_hosp_discharges_event]
WHERE [moh_pri_evt_end_date] >= '2020-01-01'

---------------------------------------------------------------------
--8. public hospital 

DROP TABLE IF EXISTS #moh_pub

SELECT DISTINCT [snz_uid]
	--,[snz_moh_uid]
	--,[moh_evt_evst_date]
	--,[moh_evt_even_date]
INTO #moh_pub
FROM [IDI_Clean_20211020].[moh_clean].[pub_fund_hosp_discharges_event]
WHERE [moh_evt_even_date] >= '2020-01-01'

---------------------------------------------------------------------
--9. socrates

DROP TABLE IF EXISTS #moh_soc

SELECT DISTINCT b.snz_uid
	--[snz_moh_uid]
	--,[snz_moh_soc_client_uid]
	--,[ServiceCoordinationID]
	--,[StartDate_Value]
	--,[EndDate_Value]
	--,[FMISAccountCode_Value]
	--,[ServiceQuantity_Value]
	--,[UnitCost_Value]
	--,[TransparentPricingModelVariableD]
	--,[UnitOfService_Value]
	--,[ServiceFrequency_Value]
	--,[AverageWeeklyCost_Value]
	--,[TotalCost_Value]
	--,[AnnualisedPackageCost_Value]
	--,[MOHContractID_Value]
	--,[CommonContractKey_Value]
INTO #moh_soc
FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_service_hist_202110] AS a
    , [IDI_Clean_20211020].[moh_clean].[pop_cohort_demographics] AS b
WHERE a.snz_moh_uid = b.snz_moh_uid
AND [EndDate_Value] >= '2020-01-01'

---------------------------------------------------------------------
-- Output table - list of all snz_uid

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2021-49].[pop_health_service_users]

SELECT DISTINCT snz_uid
INTO [IDI_Sandpit].[DL-MAA2021-49].[pop_health_service_users_2020]
FROM(
    SELECT * FROM #moh_primhd
    UNION ALL
    SELECT * FROM #moh_nes
    UNION ALL
    SELECT * FROM #moh_pha
    UNION ALL
    SELECT * FROM #moh_pri
    UNION ALL
    SELECT * FROM #moh_irai
    UNION ALL
    SELECT * FROM #moh_lab
    UNION ALL
    SELECT * FROM #moh_nnp
    UNION ALL
    SELECT * FROM #moh_pha
    UNION ALL
    SELECT * FROM #moh_soc
)AS a
