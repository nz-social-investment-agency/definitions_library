/**************************************************************************************************
Title: Maternity services costs
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[moh_clean].[maternity_mother]
    [IDI_Clean_202410].[moh_clean].[maternity_baby]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_calendar_years]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_maternity_services]

Description:
	Estimate cost of primary maternity services from conception to 6 weeks post birth

Notes:

	--actual prices for services are colledcted but nt in the IDI
	--the pice for pregnant women will be non differential
	--but where certain populations are more often pregnant the costs will differentiate
	--real dollars 2024

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-11	CW	Initial creation
**************************************************************************************************/


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_maternity_services]
GO

WITH year_range AS(
    
    SELECT cal_year
        , start_date AS yr_start
        , end_date AS yr_end
    FROM [IDI_Sandpit].[DL-MAA2023-46].[ref_calendar_years]
    WHERE cal_year BETWEEN 2019 AND 2023

),
maternity_events AS (

	SELECT a.[snz_uid]
        , [moh_matm_last_mens_period_date]
        , [moh_matm_estimated_delivery_date]
        , [moh_matm_dim_mat_preg_key_code]
        , MIN(DATEFROMPARTS(b.moh_matb_baby_birth_year_nbr, b.moh_matb_baby_birth_month_nbr, 15)) AS baby_dob
        , MIN(moh_matb_gestational_age_nbr) AS gestation
    FROM [IDI_Clean_202410].[moh_clean].[maternity_mother] AS a
    LEFT JOIN [IDI_Clean_202410].[moh_clean].[maternity_baby] AS b
    ON a.moh_matm_dim_mat_preg_key_code = b.moh_matb_dim_mat_pregnancy_code
    GROUP BY a.[snz_uid]
        , [moh_matm_last_mens_period_date]
        , [moh_matm_estimated_delivery_date]
        , [moh_matm_dim_mat_preg_key_code]

),
time_period AS (

	SELECT a.*
		-- conception estimate
		, DATEADD(DAY, -gestation*7, baby_dob) AS date_of_conception
		-- 6 weeks to transfer to wellchild
		, DATEADD(DAY, 6*7, baby_dob) AS date_of_transfer
	FROM maternity_events
    
),
within_year_period AS (

	SELECT snz_uid
		, [moh_matm_dim_mat_preg_key_code]
		, IIF(a.date_of_conception <= b.yr_start, b.yr_start, a.date_of_conception)AS trim_start -- latest start
		, IIF(a.date_of_transfer <= b.yr_end, a.date_of_transfer, b.yr_end)AS trim_end -- earliest end
	FROM time_period AS a
	INNER JOIN year_range AS b
	ON a.date_of_conception <= b.yr_end
	AND b.yr_start <= a.date_of_transfer

)
--Adjust nominal costs to real (2024 dollars) based on CPI.
SELECT a.snz_uid
    , 'MAT' AS source
    , YEAR(trim_start) AS cal_year
    , SUM(1 + DATEDIFF(DAY, trim_start, trim_end)) AS value -- duration
    , SUM(11.51 * (1 + DATEDIFF(DAY, trim_start, trim_end)) * cpi_adj_2024) AS cost_real -- rate * duration * CPI adjustment
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_maternity_services]
FROM within_year_period AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON b.cal_year = 2021
GROUP BY snz_uid
    , YEAR(trim_start)

