/**************************************************************************************************
Title: Fiscal costs - Courts 
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[moj_clean].[charges]
	[IDI_Metadata_202410].[moj].[court_code]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_MoJ_offense_to_category_map]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_MoJ_offense_cat_pricing]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_courts]

Description:
	The purpose of this is to estimate the costs incurred by MoJ when someone goes to criminal court.

Notes:
- This is based on a method developed by MoJ in 2017 and provided to SIA at that time. We are in the process of 
	validating this method with current MoJ officials.

- Costs are allocated to the year in which the first court hearing of a case takes place.
	At the time the method was developed, the latest cost data was as at 2016. We have inflated to 2024 costs via the CPI.

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-18	AW	Documentation
2024-11-11	CW	Initial creation
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_courts]
GO

WITH unordered_charges AS (

	SELECT snz_uid
		, COALESCE([moj_chg_first_court_hearing_date], moj_chg_charge_laid_date) AS [start_date]
		, COALESCE([moj_chg_last_court_hearing_date], [moj_chg_charge_outcome_date]) AS [end_date]
		, CASE WHEN court1.court_type IN ('Youth Court') THEN 'Youth' ELSE 'Adult' END AS court_type
		, CASE WHEN c.moj_chg_charge_outcome_type_code IN (
			'CONV','CNV','CNVS','COAD','CNVD','COND','DCP','J118','J39J','MIPS34','COCC','COCM','CCMD','CVOC',/*Convicted*/
			'CPSY','CPY','PROV','ADMF','ADFN','ADMN','ADM','ADCH','ADMD','INTRES','YCDIS','YCADM','INTACT',/*Youth Court proved*/
			'DS42','D19C','DWC','DWS','DS19', /*Discharge without conviction*/
			'YDFC','INTSEN','DCYP','YP35','WDC','DDC' /*Adult diversion, Youth Court discharge*/
			)
			THEN 'PVN' /*Proved*/
			ELSE 'UNP' /*Not proved*/
			END AS outcome_type
		, offcatmap.offence_category
	FROM IDI_Clean_202410.[moj_clean].[charges] c
	INNER JOIN [IDI_Metadata_202410].[moj].[court_code] court1
	ON c.[moj_chg_last_court_id_code] = court1.court_id
	LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_MoJ_offense_to_category_map] AS offcatmap
	ON c.moj_chg_offence_code = offcatmap.offence_code

),
ordered_charges AS (

	SELECT snz_uid
		, start_date
		, end_date
		, court_type
		, outcome_type
		, offence_category
		, ROW_NUMBER() OVER (PARTITION BY snz_uid, court_type, end_date, outcome_type ORDER BY snz_uid, court_type, end_date, outcome_type, offence_category DESC, start_date) AS row_rank
	FROM unordered_charges

),
cases AS (

	-- Only pick first rows from ordered charges. This row best represents the distinct list of cases
	SELECT snz_uid
        , start_date
        , end_date
        , court_type
        , outcome_type
        , offence_category
    FROM ordered_charges
    WHERE ordered_charges.row_rank = 1

),
priced_cases AS (

	SELECT cases.snz_uid AS snz_uid
		, 'CHG' AS source
		, YEAR(CAST(cases.start_date AS datetime))AS cal_year
		, CAST(cases.start_date AS datetime)AS [start_date]
		, CAST(cases.end_date AS datetime)AS end_date
		, CAST(pricing.price AS decimal(10,3))AS cost
		, cases.court_type
		, cases.outcome_type
		, cases.offence_category
	FROM cases
	LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_MoJ_offense_cat_pricing] AS pricing
	ON cases.offence_category = pricing.offence_category
	AND cases.court_type = pricing.court_type
	AND YEAR(pricing.start_date) = 2016

)
--Adjust nominal costs to real (2024 dollars) based on CPI
-- Costings were as at 2016, so inflate to 2024 from 2016
SELECT snz_uid
    , source
    , a.cal_year
    , COUNT(*)AS value -- number of court cases
    , SUM(a.cost * b.cpi_adj_2024)AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_courts]
FROM priced_cases AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON b.cal_year = 2016
WHERE cal_year IN ('2019','2020','2021','2022','2023')
GROUP BY snz_uid
    , source
    , a.cal_year
