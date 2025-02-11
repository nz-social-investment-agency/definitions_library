/**************************************************************************************************
Title: Fiscal costs - Corrections sentences
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[cor_clean].[ra_ofndr_major_mgmt_period_a]
	[IDI_Metadata_202410].[cor].ov_mmc_code
	[IDI_Sandpit].[DL-MAA2023-46].[ref_calendar_years]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_corrections_sentences]

Description:
	The purpose of this cost is to estimate the costs incurred by Corrections through the supervision of community and custodial sentences.

Notes:
- This relies on the ra_ofndr_major_mgmt_period_a table, combined with costs recorded in the associated metadata table.
	The metadata table is not clear when it was last updated, but all of the costs in this table are unchanged from the values in 
	the (very old) data dictionary on the IDI wiki, which says it was last updated in 2013. Therefore we have inflated costs from
	2013 values using the CPI.

- One current limitation is that the directive type "Electronically monitored bail" does not feature in the metadata table, and
	so we have no costs for it. This directive type is currently being assigned zero cost.

- The Corrections management tables were changed in 2022 to move from the old MMC codes to instead 
	record a new 'directive type' for each supervision spell. However, the metadata tables (which hold the relevant
	daily cost information) have not been updated and still use the old MMC codes. Almost all of the MMC codes
	map 1:1 onto the new directive types, so we can generate a manual concordance. 
	There are four exceptions to the ease of mapping:
		1. There are two Extended Supervision Order directive types, but only one ESO MMC. We have mapped both directives to the same MMC.
		2. There is only one "home detention" directive type, but two HD MMCs. One MMC (HD_REL) has much higher entry cost.
			To be conservative with costings we have mapped the directive on the MMC with lower entry costs (HD_SENT)
		3. There are several MMC codes that appear to no longer be used, and where there are no corresponding directive types.
			These have been coded as NA. 
		4. There is a new directive type "Electronically monitored bail" which has no obvious MMC analogue (as it's a new 
			type of supervision order). This is currently mapped to MMC code NA, which means it will be allocated zero costs. 

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-13	AW	Adding documentation and creating logic to apply durations to appropriate calendar years
2024-11-11	CW	Initial creation
**************************************************************************************************/

---------------------------------------------------------------------
-- Crossmetadata concordance

DROP TABLE IF EXISTS #concordance

CREATE table #concordance(
    [mmc_code] VARCHAR(1000)
    , [directive_type] NVARCHAR(1000)
);

INSERT INTO #concordance([mmc_code], [directive_type])
VALUES('AGED_OUT', 'NA')
    , ('ALIVE', 'ALIVE')
    , ('COM_DET', 'COMMUNITY DETENTION')
    , ('COM_PROG', 'COMMUNITY PROGRAMME')
    , ('COM_SERV', 'COMMUNITY SERVICE')
    , ('CW', 'COMMUNITY WORK')
    , ('ERROR', 'NA')
    , ('ESO', 'EXTENDED SUPERVISION ORDER')
    , ('ESO', 'EXTENDED SUPERVISION ORDER (INTERIM)')
    , ('HD_REL', 'NA')
	,  ('HD_SENT', 'HOME DETENTION') --Note have allocated all HD sentences to the lower cost version below
    , ('INT_SUPER', 'INTENSIVE SUPERVISION')
    , ('NA', 'ELECTRONICALLY MONITORED BAIL') --Note have allocated EMBs to NA which has the effect of assigning zero cost
	,  ('OTH_COM', 'NA')
    , ('PAROLE', 'PAROLE')
    , ('PDC', 'POST DETENTION CONDITIONS')
    , ('PERIODIC', 'PERIODIC DETENTION')
    , ('PRISON', 'IMPRISONMENT')
    , ('REMAND', 'REMAND')
    , ('ROC', 'RELEASED ON CONDITIONS')
    , ('ROO', 'RETURNING OFFENDER ORDER')
    , ('SUPER', 'SUPERVISION');

---------------------------------------------------------------------
-- Extract management periods and count duration within each calendar year

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_corrections_sentences]
GO

WITH remove_duplicates AS(
    
    SELECT a.*
    FROM [IDI_Clean_202410].[cor_clean].[ra_ofndr_major_mgmt_period_a] AS a
    INNER JOIN(
        SELECT snz_uid
            , MAX(cor_rommp_max_period_nbr) AS cor_rommp_max_period_nbr
        FROM [IDI_Clean_202410].[cor_clean].[ra_ofndr_major_mgmt_period_a] AS b
        GROUP BY snz_uid
    )AS b
    ON a.snz_uid = b.snz_uid
    AND a.cor_rommp_max_period_nbr = b.cor_rommp_max_period_nbr

),
trimmed_periods AS (

	SELECT a.snz_uid
		, b.cal_year AS cal_year
		, a.cor_rommp_period_start_date
		, a.cor_rommp_period_end_date

		, b.start_date AS year_start_date
		, b.end_date AS year_end_date
		, a.cor_rommp_directive_type
		, a.cor_rommp_prev_directive_type
		, a.cor_rommp_next_directive_type

		, IIF(a.cor_rommp_period_start_date <= b.start_date, b.start_date, a.cor_rommp_period_start_date) AS trim_start_date -- latest start date
		, IIF(a.cor_rommp_period_end_date <= b.end_date, a.cor_rommp_period_end_date, b.end_date) AS trim_end_date -- earliest_end_date

	FROM remove_duplicates AS a
	--This is necessary to apportion multi-year spells into the duration that occurs in each calendar year
	INNER JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_calendar_years] AS b
	ON a.cor_rommp_period_start_date <= b.end_date
	AND b.start_date <= a.cor_rommp_period_end_date
	WHERE b.cal_year BETWEEN 2019 AND 2023

),
attached_costs AS (

	SELECT a.snz_uid
		, a.cal_year
		, 'COR' AS source
		, 1 + DATEDIFF(DAY, trim_start_date, trim_end_date) AS duration
		, b.[Daily_Cost] *(1 + DATEDIFF(DAY, trim_start_date, trim_end_date)) -- duration cost
			+ IIF(a.cor_rommp_directive_type != a.cor_rommp_prev_directive_type AND cor_rommp_period_start_date BETWEEN year_start_date AND year_end_date, b.Entry_Cost, 0) -- start cost
			+ IIF(a.cor_rommp_directive_type != a.cor_rommp_next_directive_type AND cor_rommp_period_end_date BETWEEN year_start_date AND year_end_date, b.Exit_Cost, 0) -- end cost
			AS cost
	FROM trimmed_periods AS a
	LEFT JOIN #concordance c
	ON a.cor_rommp_directive_type = c.directive_type
	LEFT JOIN [IDI_Metadata_202410].[cor].ov_mmc_code b -- costs from 2013
	ON c.mmc_code = b.[MMC_Code]
	WHERE a.cor_rommp_directive_type NOT IN ('ALIVE')

)
--Adjust nominal costs to real (2024 dollars) based on CPI. This is based on an assumption that 
SELECT snz_uid
    , source
    , a.cal_year
    , SUM(duration) AS value
    , SUM(cost*cpi_adj_2024) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_corrections_sentences]
FROM attached_costs AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON b.cal_year = 2013
GROUP BY snz_uid
    , source
    , a.cal_year
