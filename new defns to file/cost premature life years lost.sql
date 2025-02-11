/**************************************************************************************************
Title: Premature Years Life Lost (Non Financial)
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].data.personal_detail
	[IDI_Sandpit].[DL-MAA2023-46].[ref_life_expectancy]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_premature_years_life_lost]

Description:
	Estmate value of premature years of life lost

Notes:
- Calculation of Premature years of life lost is done by comparing
	Life expectancy at death against age at death

- Calculation based on NZ female life table
	Though ideally the model life table should be West level 26 female or some aspirational equivalent
	Data fetched from SNZ: New-Zealand-period-life-tables-2017-2019
	
- Max age in life expectancy table is 105
	Set expectancy for ages 106+ to 1.7 years of life

- Common abbreviations:
	le0 = remaining expected years of life
	PYLL = premature Years of Life Lost

- Value of premature years life lost is drawn from CBAx

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-12-02 CWright: calcualte pyll based on nz life table form snz
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_premature_years_life_lost]
GO

WITH mortality AS(
    
    SELECT a.[snz_uid]
        , a.snz_deceased_year_nbr AS cal_year
        , snz_birth_year_nbr
        , DATEFROMPARTS(snz_deceased_year_nbr,snz_deceased_month_nbr,15) AS date_of_birth_proxy
        , DATEFROMPARTS(snz_birth_year_nbr,snz_birth_month_nbr,15) AS date_of_death_proxy
        , FLOOR(DATEDIFF(DAY, 
			DATEFROMPARTS(snz_birth_year_nbr,snz_birth_month_nbr,15), -- birth date proxy
			DATEFROMPARTS(snz_deceased_year_nbr,snz_deceased_month_nbr,15) -- death date proxy
		) / 365.24) AS age
    FROM [IDI_Clean_202410].data.personal_detail AS a
    WHERE a.snz_deceased_year_nbr BETWEEN 2019 AND 2023

),
life_lost AS (

	SELECT snz_uid
		, cal_year
		, 'PYLL' AS source
		, a.age
		, IIF(a.age > 105, 1.7, b.life_expectancy) AS value
		, 43000 * IIF(a.age > 105, 1.7, b.life_expectancy) AS cost
	FROM mortality AS a
	LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_life_expectancy] AS b
	ON a.age = b.age

)
--Adjust nominal costs to real (2024 dollars) based on CPI
SELECT a.snz_uid
    , a.source
    , a.cal_year
    , SUM(value) AS value
    , SUM(cost*cpi_adj_2024) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_premature_years_life_lost]
FROM life_lost AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON a.cal_year = b.cal_year
GROUP BY snz_uid
    , source
    , a.cal_year
