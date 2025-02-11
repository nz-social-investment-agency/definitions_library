/**************************************************************************************************
Title: Fiscal costs - Learning support
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[moe_clean].[student_interventions]
	[IDI_Metadata_202410].[moe_school].[intervention_type_code]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_learning_supports]

Description:
	The purpose of this is to estimate the costs incurred by MoE through the provision of learning support. 

Notes:
- This is derived from funding information previously received from MoE, covering programme-level costs for
	2021. This is combined with official figures on the number of students receiving each learning support programme 
	to derive a notional average cost per year per student for each programme.
	
	This average cost is combined with data on learning support receipt in the student_interventions table to
	estimate cost per student.

	Average cost numbers based on the MoE learning support data index, provided to SWA in 2022:
		--Alternative Education				$10,193
		--Attendance Service				   $907
		--Behaviour Service					 $9,834
		--Boarding Allowance				 $4,716
		--Communication Service				 $3,180
		--Early Intervention				 $4,101
		--ESOL								 $1,026
		--Intensive Wraparound Service		$41,240
		--ORS - Fund-holder					$14,894
		--ORS - MoE specialist				$16,696
		--ORS - weighted average			$15,941
		--Physical Disability				 $5,902
		--Reading Recovery					   $713
		--RTLB								 $1,327
		--School High Health Needs Fund		 $6,711
		--Year 11+							 $8,346

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-18	AW	Documentation
2024-11-11	CW	Initial creation
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_learning_supports]
GO

WITH setup AS (

	SELECT snz_uid
		, [moe_inv_intrvtn_code] AS code
		, b.[InterventionName]
		, CASE 
			WHEN [moe_inv_intrvtn_code] IN (6)			THEN 'Alternative Education' 
			WHEN [moe_inv_intrvtn_code] IN (9,32)		THEN 'Attendance Service' 
			WHEN [moe_inv_intrvtn_code]=39 
				AND moe_inv_se_service_category_code=2	THEN 'Behaviour Service' 
			WHEN [moe_inv_intrvtn_code] IN (40,14,13)	THEN 'Boarding Allowance'
			WHEN [moe_inv_intrvtn_code]=39 
				AND moe_inv_se_service_category_code=3	THEN 'Communication Service' 
			WHEN [moe_inv_intrvtn_code]=39 
				AND moe_inv_se_service_category_code=5	THEN 'Early Intervention' 
			WHEN [moe_inv_intrvtn_code] IN (5)			THEN 'ESOL' 
			WHEN [moe_inv_intrvtn_code]=39	
				AND moe_inv_se_service_category_code=10 
				AND moe_inv_se_service_group_code=4		THEN 'Intensive Wrap Around'
			WHEN [moe_inv_intrvtn_code]=25				THEN 'ORS'
			WHEN [moe_inv_intrvtn_code]=39 
				AND moe_inv_se_service_category_code=16 
				AND moe_inv_se_service_group_code=11	THEN 'Physical Disability'
			WHEN [moe_inv_intrvtn_code]=16				THEN 'Reading Recovery'
			WHEN [moe_inv_intrvtn_code]=48				THEN 'RTLB'
			WHEN [moe_inv_intrvtn_code]=27				THEN 'School High Health Needs Fund'
			WHEN [moe_inv_intrvtn_code]=46				THEN 'YEAR 11+'
			ELSE NULL END service_name
		, 'Learning support' AS source
		, CASE 
			WHEN [moe_inv_intrvtn_code] in (6)			THEN 10193
			WHEN [moe_inv_intrvtn_code] in (9,32)		THEN 907
			WHEN [moe_inv_intrvtn_code]=39 
				AND moe_inv_se_service_category_code=2	THEN 9834
			WHEN [moe_inv_intrvtn_code] in (40,14,13)	THEN 4716
			WHEN [moe_inv_intrvtn_code]=39 
				AND moe_inv_se_service_category_code=3	THEN 3180
			WHEN [moe_inv_intrvtn_code]=39 
				AND moe_inv_se_service_category_code=5	THEN 4101
			WHEN [moe_inv_intrvtn_code] in (5)			THEN 1026
			WHEN [moe_inv_intrvtn_code]=39 
				AND moe_inv_se_service_category_code=10 
				AND moe_inv_se_service_group_code=4		THEN 41240
			WHEN [moe_inv_intrvtn_code]=25				THEN 15941
			WHEN [moe_inv_intrvtn_code]=39 
				AND moe_inv_se_service_category_code=16 
				AND moe_inv_se_service_group_code=11	THEN 5902
			WHEN [moe_inv_intrvtn_code]=16				THEN 713
			WHEN [moe_inv_intrvtn_code]=48				THEN 1327
			WHEN [moe_inv_intrvtn_code]=27				THEN 6711
			WHEN [moe_inv_intrvtn_code]=46				THEN 8346
			ELSE NULL END AS service_cost
		,YEAR(moe_inv_start_date) AS cal_year
		,moe_inv_se_service_category_code
		,moe_inv_se_service_group_code
		,moe_inv_inst_num_code AS entity
	FROM [IDI_Clean_202410].[moe_clean].[student_interventions] AS a 
	LEFT JOIN [IDI_Metadata_202410].[moe_school].intervention_type_code AS b
	ON a.[moe_inv_intrvtn_code]=b.[InterventionID]
	WHERE [moe_inv_intrvtn_code]  NOT IN (7,8) --exclude standdowns/suspensions
	AND YEAR(moe_inv_start_date) BETWEEN 2019 AND 2023

),
cost_adjusted AS (

	--Adjust nominal costs to real (2024 dollars) based on CPI
	SELECT a.snz_uid
			,a.source
			,a.cal_year
			,SUM(service_cost * cpi_adj_2024) AS cost_real
			,COUNT(*) AS value
			,entity
	FROM setup AS a
	LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
	ON b.YEAR = 2021
	WHERE service_cost IS NOT NULL
	GROUP BY snz_uid, source, a.cal_year, entity

)
-- Combine entities
SELECT snz_uid
	,source
	,cal_year
	,SUM(cost_real) AS cost_real
	,SUM(value) AS value
	,STRING_AGG(entity, ';')AS entity
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_learning_supports]
FROM cost_adjusted
GROUP BY snz_uid
	, source
	, cal_year
	, entity
