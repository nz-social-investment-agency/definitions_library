/**************************************************************************************************
Title: Fiscal costs - Police investigation costs
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[pol_clean].[post_count_offenders]
	[IDI_Clean_202410].[pol_clean].[post_count_victimisations]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
	[IDI_Clean_202410].[pol_clean].[pre_count_offenders]
	[IDI_Clean_202410].[pol_clean].[pre_count_victimisations]
	[IDI_Metadata_202410].[moj].[offence_code]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_police_investigations]
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_police_investigations_offender]
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_police_investigations_victim]

Description:
	The purpose of this is to estimate the costs incurred by police when investigating offences. 

Notes:
- This is an indirect costing method that relies primarily on some unpublished analysis undertaken by Police in 2019.
	That analysis aimed to estimate the average effort expended on investigating particular types of offences.
	We have applied costs only to the offences that were in the scope of this analysis, which is a subset of all offences
	Police deals with. No costs are allocated for offences without an identified offender. Note that this includes low-level
	traffic offences, which are not included in the IDI offending tables.

- The investigation costs are allocated to individuals via the data in the post_count offenders table, which includes only
	one offence for each offender/incident. This might have the effect of underestimating investigations costs.

- There is a large (~25%) reduction in implied total investigation costs that happens between 2019/2020 and 2021/2023. This
	requires more exploration - it could be real (COVID-related?) but could also be an artifact of changes in the way that
	Police record offences. The potential series break occurs during 2021.

- ANZSCO codes for violent crime:
	061 = robbery
	031 = sexual assault
	0323 = sexual servitude offences
	0329 = non-assaultive sexual offences
	0300 = sexual assault & related offences not further defined
	021 = assault
	0299 = other acts intended to cause injury
	012 = attempted murder

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-15	AW	Adding documentation
2024-11-12	CW	Initial creation
**************************************************************************************************/

---------------------------------------------------------------------
-- Costs

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_police_investigations]
GO

WITH pooled_data AS (

	--Pooling victim data and offender data together for the same offence
    SELECT [snz_uid]
        , 'RCOS' source
        , [snz_pol_occurrence_uid]
        , [snz_pol_offence_uid]
        , [pol_poo_proceeding_date] AS cal_date
        , [pol_poo_anzsoc_offence_code] anzsoc
    FROM [IDI_Clean_202410].[pol_clean].[post_count_offenders]

    UNION ALL

    SELECT [snz_uid]
        , 'RCVS' source
        , [snz_pol_occurrence_uid]
        , [snz_pol_offence_uid]
        , [pol_pov_reported_date] AS cal_date
        , [pol_pov_anzsoc_offence_code] anzsoc
    FROM [IDI_Clean_202410].[pol_clean].[post_count_victimisations]

),
classified_event AS (

	SELECT [snz_pol_occurrence_uid]
		, [snz_pol_offence_uid]
		, anzsoc
		, MIN(cal_date)AS cal_date
		, SUM(CASE WHEN source='RCOS' THEN 1 ELSE 0 END )rcos_nbr
		, SUM(CASE WHEN source='RCVS' THEN 1 ELSE 0 END )rcvs_nbr
		  --Assign anzsoc 2-digit groups to anzsoc incident codes	  
		, CASE WHEN SUBSTRING(anzsoc,1,2) ='01' THEN 1 --Homicide
				WHEN SUBSTRING(anzsoc,1,2) ='03' THEN 2 --Sexual assault
				WHEN SUBSTRING(anzsoc,1,2) ='15' THEN 3 --Offence against justice
				WHEN SUBSTRING(anzsoc,1,2) ='06' THEN 4 --Robbery
				WHEN SUBSTRING(anzsoc,1,2) ='10' THEN 5 --Drug
				WHEN SUBSTRING(anzsoc,1,2) ='05' THEN 6 --Abduction/threats
				WHEN SUBSTRING(anzsoc,1,2) ='02' THEN 7 --Assault
				WHEN SUBSTRING(anzsoc,1,2) ='04' THEN 8 --Dangerous/negligent acts
				WHEN SUBSTRING(anzsoc,1,2) ='11' THEN 9 --Weapons
				WHEN SUBSTRING(anzsoc,1,2) ='07' THEN 10 --Burglary
				WHEN SUBSTRING(anzsoc,1,2) ='12' THEN 11 --Graffiti/property damage
				WHEN SUBSTRING(anzsoc,1,2) ='13' THEN 12 --Public order
				WHEN SUBSTRING(anzsoc,1,2) ='16' THEN 13 --Public health/safety
				WHEN SUBSTRING(anzsoc,1,2) ='14' THEN 14 --Traffic
				WHEN SUBSTRING(anzsoc,1,2) ='08' THEN 15 --Theft
				WHEN SUBSTRING(anzsoc,1,2) ='09' THEN 16 --Fraud
				ELSE 99 END AS cost_rank
	FROM pooled_data
	WHERE YEAR(cal_date) BETWEEN 2019 AND 2023
	GROUP BY [snz_pol_occurrence_uid]
		, [snz_pol_offence_uid]
		, anzsoc

),
costed_event AS (

	SELECT a.*
		, b.snz_uid
		, IIF(rcos_nbr = 0, 1, rcos_nbr) + rcvs_nbr AS ppl
		, YEAR(cal_date)AS cal_year
		--Assign 12 months mean investgation costs to each 2 digit anzsoc code  
		, CASE WHEN cost_rank=1 THEN 167219
				WHEN cost_rank=2 THEN 20376
				WHEN cost_rank=3 THEN 9186
				WHEN cost_rank=4 THEN 5945
				WHEN cost_rank=5 THEN 3093
				WHEN cost_rank=6 THEN 2477
				WHEN cost_rank=7 THEN 2476
				WHEN cost_rank=8 THEN 843
				WHEN cost_rank=9 THEN 326
				WHEN cost_rank=10 THEN 202
				WHEN cost_rank=11 THEN 175
				WHEN cost_rank=12 THEN 164
				WHEN cost_rank=13 THEN 107
				WHEN cost_rank=14 THEN 82
				WHEN cost_rank=15 THEN 67
				WHEN cost_rank=16 THEN 58
				ELSE NULL END AS invest_cost
	FROM classified_event AS a
	--Add on the offender's identity by joining back to the offenders table
	--Inner join to remove offences that don't have an identified offender
	INNER JOIN [IDI_Clean_202410].[pol_clean].[post_count_offenders] b
	ON a.[snz_pol_occurrence_uid] = b.[snz_pol_occurrence_uid]
	AND a.[snz_pol_offence_uid] = b.[snz_pol_offence_uid]
	AND a.anzsoc = b.[pol_poo_anzsoc_offence_code]

)
--Adjust nominal costs to real (2024 dollars) based on CPI
SELECT snz_uid
    , 'POL' AS source
    , a.cal_year
    , COUNT(*)AS value -- number of investigations
    , SUM(1.0 * invest_cost / ppl * cpi_adj_2024)cost_real
INTO #cost_6
FROM costed_event AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON b.cal_year = 2017
GROUP BY snz_uid
    , a.cal_year

---------------------------------------------------------------------
-- Offence events

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_police_investigations_offender]
GO

WITH setup AS (

	--Extracting data by occurrence
	SELECT DISTINCT [snz_uid]
		, [snz_pol_occurrence_uid]
		, [snz_pol_offence_uid]
		--,a.pol_pro_proceeding_date
		, YEAR(a.pol_pro_proceeding_date)AS cal_year
		--,substring(pol_pro_anzsoc_offence_code,1,2) AS anzsco3
		, a.pol_pro_offence_code AS anzsco
		--,b.anzsoc_div_code_name
		--,b.anzsoc_div_code as code
		, CASE WHEN
				SUBSTRING(pol_pro_anzsoc_offence_code,1,3) IN ('061','031','021','012')
				OR SUBSTRING(pol_pro_anzsoc_offence_code,1,4) IN ('0323','0329','0300','0299')
			THEN 1 ELSE 2 END violent_crime
	FROM [IDI_Clean_202410].[pol_clean].[pre_count_offenders] AS a
	LEFT JOIN [IDI_Metadata_202410].[moj].[offence_code] AS b
	ON a.pol_pro_anzsoc_offence_code = b.anzsoc
	WHERE YEAR(a.pol_pro_proceeding_date) IN (2019,2020,2021,2022,2023)

)
SELECT snz_uid
    , cal_year
    , COUNT(*) AS value
    , CONCAT('POL_O',violent_crime) AS source
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_police_investigations_offender]
FROM setup
GROUP BY snz_uid
    , cal_year
    , violent_crime

---------------------------------------------------------------------
-- Victimisation events

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_police_investigations_victim]
GO

WITH setup AS (

	--Extracting data by occurrence
	SELECT DISTINCT [snz_uid]
		, [snz_pol_occurrence_uid]
		, [snz_pol_offence_uid]
		, YEAR(a.pol_prv_reported_date)AS cal_year
		, pol_prv_anzsoc_offence_code AS anzsco
		, CASE WHEN
				SUBSTRING(pol_prv_anzsoc_offence_code,1,3) IN ('061','031','021','012')
				OR SUBSTRING(pol_prv_anzsoc_offence_code,1,4) IN ('0323','0329','0300','0299')
			THEN 1 ELSE 2 END violent_crime
	FROM [IDI_Clean_202410].[pol_clean].[pre_count_victimisations] AS a
	LEFT JOIN [IDI_Metadata_202410].[moj].[offence_code] AS b
	ON a.pol_prv_anzsoc_offence_code = b.anzsoc
	WHERE YEAR(a.pol_prv_reported_date) IN (2019,2020,2021,2022,2023)

)
SELECT snz_uid
    , cal_year
    , COUNT(*) AS value
    , CONCAT('POL_V',violent_crime) AS source
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_police_investigations_victim]
FROM setup
GROUP BY snz_uid
    , cal_year
    , violent_crime

--XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

