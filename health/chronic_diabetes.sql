/**************************************************************************************************
Title: Chronic condition: Diabetes
Author: Lexi Xu

Inputs & Dependencies:
- [IDI_Clean].[moh_clean].[pub_fund_hosp_discharges_diag]
- [IDI_Clean].[moh_clean].[priv_fund_hosp_discharges_diag]
- [IDI_Clean].[moh_clean].[pub_fund_hosp_discharges_event]
- [IDI_Clean].[moh_clean].[priv_fund_hosp_discharges_event]
- [IDI_Clean].[moh_clean].[nnpac]
- [IDI_Clean].[moh_clean].[pharmaceutical]
- [IDI_Metadata].[clean_read_CLASSIFICATIONS].[moh_dim_form_pack_subsidy_code]
Outputs:
- [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506]

Description:
Diagnosis at a hospital with Diabetes or dispensing of diabetes drugs.

Intended purpose:
Determine who has been diagnosed with the chronic condition diabetes.
And when they were diagnosed.
 
Notes:
1) In the September 2018 refresh notes:
   "The data contained in the [moh.clean].[chronic_condition] table has changed due to some data
    sources being too outdated to provide value for researchers. COPD and CHD are no longer included
	in this table, and alternatives should be used to identify these conditions. The remaining
	conditions have been updated. Diabetes now uses data from the updated Virtual Diabetes 
	Register (VDR) methodology (v686) and contains data from the VDR 2017."
   IDI wiki Source:
   wprdtfs05/sites/DefaultProjectCollection/IDI/IDIwiki/UserWiki/Documents/September%202018%20IDI%20Refresh%20Updates.pdf
   However, we do not have access to the VDR within the IDI.
2) We have constructed this definition from the description given in the MoH IDI Data dictionary.
   This includes a list of diagnosis and proceedure codes, as well as a list of pharmaceuticals.
3) Testing against Chronic condition table in the 2018-07-20 refresh suggests high consistency.
4) To reduce the amount of data written/copied during the construction of these tables, we have
   commented out non-critical fields (lines starting with "--"). Uncommenting these lines is
   recommended is validating the construction/definition.
5) The [end_date] in this table is the end of the hospital visit when diagnosis took place,
   NOT the date that the chronic condition ended.
6) The new CHEMICAL_ID from "https://www.tewhatuora.govt.nz/publications/virtual-diabetes-register-technical-guide"

Parameters & Present values:
  Current refresh = 202506
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
 
Issues:
1) it is advised to exlude the following - this has yet to be added to this definition
	
	-Women aged 12-45 ONLY dispensed Metformin

1) it is advised to exlude the following - these are excluded in a 'broad brush' way, this could be further refined

	-Women dispensed insulin ONLY within the pregnancy period
	-Women who had an HbA1c lab test ONLY within the pregnancy period

 
History (reverse order):
2025-08-19 CR added lab tests & pregnancy exclusion
2025-06-03 LX updated [CHEMICAL_ID]
2020-05-26 SA v1
**************************************************************************************************/


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506];
GO

CREATE TABLE [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506] (
	snz_uid INT NOT NULL
	, source VARCHAR(20)
	, start_date DATE NOT NULL
	, end_date DATE NOT NULL
)

/************************************ publically funded hospital discharages ************************************/

INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506]
SELECT  b.[snz_uid]	  
	  , 'pub_diab' AS [source]
	  , b.[moh_evt_evst_date] AS [start_date]
	  , b.[moh_evt_even_date] AS [end_date]
FROM [IDI_Clean_202506].[moh_clean].[pub_fund_hosp_discharges_diag] AS a
INNER JOIN [IDI_Clean_202506].[moh_clean].[pub_fund_hosp_discharges_event] AS b
ON a.[moh_dia_event_id_nbr] = b.[moh_evt_event_id_nbr]
WHERE a.[moh_dia_submitted_system_code] = a.[moh_dia_clinical_sys_code] /* higher accuracy when systems match */
AND a.[moh_dia_diagnosis_type_code] IN ('A', 'B') /* diagnosies */
AND a.[moh_dia_clinical_sys_code] IN ('10', '11', '12', '13', '14') /* ICD-10-AM */
AND b.moh_evt_even_date >= DATEADD(YEAR,-10,GETDATE())
AND (
	SUBSTRING(a.[moh_dia_clinical_code], 1, 3) IN (
		 'E10' /* Type 1 DM */
		,'E11' /* TYPE 2 DM */
		,'E13' /* Other specified DM */
		,'E14' /* Unspecified DM */
	)
	OR SUBSTRING(a.[moh_dia_clinical_code], 1, 3) IN ('O240', 'O241', 'O242', 'O243') /* pre-existing diabetes in pregnancy */
)
GO

/************************************ privately funded hospital discharages ************************************/

INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506]
SELECT  b.[snz_uid]
	  ,'priv_diab' AS [source]
	  , b.[moh_pri_evt_start_date] AS [start_date]
	  , b.[moh_pri_evt_end_date] AS [end_date]
FROM [IDI_Clean_202506].[moh_clean].[priv_fund_hosp_discharges_diag] AS a
INNER JOIN [IDI_Clean_202506].[moh_clean].[priv_fund_hosp_discharges_event] AS b
ON a.[moh_pri_diag_event_id_nbr] = b.[moh_pri_evt_event_id_nbr]
WHERE a.[moh_pri_diag_sub_sys_code] = a.[moh_pri_diag_clinic_sys_code] /* higher accuracy when systems match */
AND a.[moh_pri_diag_diag_type_code] IN ('A', 'B') /* diagnosies */
AND a.[moh_pri_diag_clinic_sys_code] IN ('10', '11', '12', '13','14') /* ICD-10-AM */
AND b.moh_pri_evt_end_date >= DATEADD(YEAR,-10,GETDATE())
AND (
	SUBSTRING(a.[moh_pri_diag_clinic_code], 1, 3) IN (
		 'E10' /* Type 1 DM */
		,'E11' /* TYPE 2 DM */
		,'E13' /* Other specified DM */
		,'E14' /* Unspecified DM */
	)
	OR SUBSTRING(a.[moh_pri_diag_clinic_code], 1, 3) IN ('O240', 'O241', 'O242', 'O243') /* pre-existing diabetes in pregnancy */
)
GO

/************************************ pharmaceuticals ************************************/
/* Ignores one chemical IDs:
1794 - Metformin hydrochloride
The chronic table also includes this chemical, but excludes women aged 12-45 who may have only been dispensed Metformin
AND do not meet any of the other criteria.
Note: This is intended to exclude women age 12-45 whom may have polycystic ovary syndrome treated with metformin.
*/

INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506]
SELECT a.[snz_uid]
	  , 'pha_diab' AS [source]
      , MIN([moh_pha_dispensed_date]) AS [start_date]
	  , MAX([moh_pha_dispensed_date]) AS [end_date]
FROM [IDI_Clean_202506].[moh_clean].[pharmaceutical] AS a
LEFT JOIN [IDI_Metadata_202506].[moh_pharm].[dim_form_pack_subsidy_code] AS b
ON a.[moh_pha_dim_form_pack_code] = b.[DIM_FORM_PACK_SUBSIDY_KEY]
WHERE a.snz_uid <> -1 /* remove non-personal identities */
AND a.moh_pha_dispensed_date >= DATEADD(YEAR,-2,GETDATE())
AND [CHEMICAL_ID] IN (
	 1192 /* Insulin lispro */	
	,1247 /* Acarbose */
	,1567 /* Glibenclamide */
	,1568 /* Gliclazide */
	,1569 /* Glipizide */
	,1570 /* Glucagon hydrochloride */ --
	,1648 /* Insulin Neutral */
	,1649 /* Insulin isophane */
	,1655 /* Insulin zinc suspension */
	,2276 /* Tolazamide */
	,2277 /* Tolbutamide */
	,3739 /* Rosiglitazone */
	,3783 /* Insulin aspart */	
	,3800 /* Pioglitazone */
	,3857 /* Insulin glargine */	
	,3882 /* Insulin lispro with lispro protamine */
	,3908 /* Insulin glulisine */
	,3982 /* Insulin aspart with aspart protamine */
	,4103 /* Vildagliptin */
	,4104 /* Vildagliptin with metformin hydrochloride */
	,4137 /* Empagliflozin */ --
	,4138 /* Empagliflozin with metformin hydrochloride */ --
	,4149 /* Dulaglutide */ --
	,4173 /* Liraglutide */ --
	,6300 /* Insulin isophane with insulin neutral */ --
)

GROUP BY [snz_uid]
GO


/************************************ National Non-Admitted Patient Collection ************************************/

INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506]
SELECT n.[snz_uid]
	  , 'out_diab' AS [source]
	  , MIN(n.[moh_nnp_service_date]) AS [start_date]
	  , MAX(n.[moh_nnp_service_date]) AS [end_date]
FROM [IDI_Clean_202506].[moh_clean].[nnpac] n
WHERE n.[moh_nnp_purchase_unit_code] IN ('M20006', 'M20007')
AND n.[moh_nnp_attendence_code] = 'ATT' /* attended */
AND n.[moh_nnp_service_date] >= DATEADD(YEAR,-10,GETDATE())
AND  NOT EXISTS (SELECT b.[snz_uid]	  
				, b.[moh_nnp_service_date]
				, b.[moh_nnp_service_date]
			FROM [IDI_Clean_202506].[moh_clean].[nnpac] b
			INNER JOIN [IDI_Metadata_202506].[moh_nmds].[dhb_code] d on d.DHB_CODE = b.moh_nnp_idf_dhb_code
			WHERE d.DHB_CODE = 121 
			AND YEAR(b.[moh_nnp_service_date]) = 2018 
			AND MONTH(b.[moh_nnp_service_date]) BETWEEN 10 AND 12 --exclude data for Canterbury DHB diabetes fundus screening between October and December 2018
			AND [moh_nnp_purchase_unit_code] = 'M20007'
			AND b.snz_uid = n.snz_uid AND b.[moh_nnp_service_date] = n.[moh_nnp_service_date]
			)
GROUP BY [snz_uid]
GO

/************************************ Lab tests ************************************/

INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506]

SELECT [snz_uid]
	  , 'lab_test' AS [source]
      , MIN([moh_lab_visit_date]) AS [start_date]
	  , MAX([moh_lab_visit_date]) AS [end_date]
FROM [IDI_Clean_202506].[moh_clean].[lab_claims] l 
WHERE [moh_lab_visit_date] > DATEADD(YEAR,-2,'2024-12-31') --max current date for lab tests
GROUP BY [snz_uid]
HAVING SUM(IIF([moh_lab_test_code] = 'BG2',1,NULL)) >=4
AND SUM(IIF([moh_lab_test_code] = 'BP8',1,NULL)) >= 2
GO

/************************************ Remove errors and deceased people ************************************/

DELETE FROM [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506]
WHERE snz_uid IN (
	SELECT d.snz_uid
	FROM [IDI_Clean_202506].[data].[personal_detail] d
	WHERE d.snz_spine_ind <> 1 --not linked
	OR d.snz_person_ind <> 1 --not a person
	OR d.snz_deceased_year_nbr IS NOT NULL -- deceased
	)

/************************************ Removing gestational diabetes ************************************/

----OPTION 1----

----Remove all women with test and medication spells which fall only in the pregnancy period----

----This will exclude all rather than just those receiving insulin and getting HbA1c tests, however we assume someone with ongoing or pre existing diabetes will hhave start and date outside of this period----

DELETE FROM [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506]
WHERE snz_uid IN (
	SELECT d.snz_uid
	FROM [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506] d
	INNER JOIN [IDI_Clean_202506].[dia_clean].[births] b on b.parent1_snz_uid = d.snz_uid AND d.source IN ('lab_test','pha_diab')
	WHERE DATEADD(WEEK,-IIF(b.dia_bir_birth_gestation_nbr IS NULL,40,b.dia_bir_birth_gestation_nbr), DATEFROMPARTS(dia_bir_birth_year_nbr,dia_bir_birth_month_nbr,15)) <= d.start_date -- start date after conception
	AND d.end_date <= DATEADD(WEEK,2, DATEFROMPARTS(dia_bir_birth_year_nbr,dia_bir_birth_month_nbr,15)) --end date before 2 weeks after birth
	)			

/************************************ Tidy ************************************/

/* Add index */
CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506] ([snz_uid]);
GO


/* Compress final table to save space */
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);
GO

/*
----OPTION 2 for removing gestational diabetes----

--THIS CODE IS FLAWED AND INCOMPLETE--

--Women who only received insulin ONLY within the period between the 5 months prior to birth and 2 weeks following the birth--

DELETE FROM [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506]

SELECT d.snz_uid
	,d.start_date
	,d.end_date
	FROM [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506] d
	INNER JOIN (SELECT parent1_snz_uid
				, [moh_pha_dispensed_date]
				FROM [IDI_Clean_202506].[dia_clean].[births] b 
				INNER JOIN [IDI_Clean_202506].[moh_clean].[pharmaceutical] AS a on a.snz_uid = b.parent1_snz_uid
				LEFT JOIN [IDI_Metadata_202506].[moh_pharm].[dim_form_pack_subsidy_code] AS c
				ON a.[moh_pha_dim_form_pack_code] = c.[DIM_FORM_PACK_SUBSIDY_KEY]
				WHERE DATEADD(MONTH,-5, DATEFROMPARTS(dia_bir_birth_year_nbr,dia_bir_birth_month_nbr,15)) <= a.[moh_pha_dispensed_date] 
				AND a.[moh_pha_dispensed_date] <= DATEADD(WEEK,2, DATEFROMPARTS(dia_bir_birth_year_nbr,dia_bir_birth_month_nbr,15)) 
				AND [CHEMICAL_ID] IN ('1192','1648','1649', '1655', '3857', '3882', '3908', '3982', '6300') -- insulin
				) b on b.parent1_snz_uid = d.snz_uid AND b.moh_pha_dispensed_date = d.start_date

-- Women who had an HbA1c lab test ONLY within the period before birth -- 

DELETE FROM [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506]

SELECT d.snz_uid
	,d.start_date
	,d.end_date
	FROM [IDI_Sandpit].[DL-MAA2023-46].[defn_chronic_diabetes_202506] d
	INNER JOIN (SELECT parent1_snz_uid
				, a.moh_lab_visit_date
				FROM [IDI_Clean_202506].[dia_clean].[births] b 
				INNER JOIN [IDI_Clean_202506].[moh_clean].[lab_claims] AS a on a.snz_uid = b.parent1_snz_uid
				WHERE DATEADD(WEEK,-IIF(b.dia_bir_birth_gestation_nbr IS NULL,40,b.dia_bir_birth_gestation_nbr), DATEFROMPARTS(dia_bir_birth_year_nbr,dia_bir_birth_month_nbr,15)) <= a.moh_lab_visit_date
				AND a.moh_lab_visit_date <= DATEADD(WEEK,2, DATEFROMPARTS(dia_bir_birth_year_nbr,dia_bir_birth_month_nbr,15)) 
				AND [moh_lab_test_code] = 'BG2' -- HbA1c
				) b on b.parent1_snz_uid = d.snz_uid AND b.moh_lab_visit_date = d.start_date
*/




