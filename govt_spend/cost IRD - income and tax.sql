/**************************************************************************************************
Title: Fiscal costs - Income and Tax
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[data].[income_cal_yr_summary]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_income_and_tax]

Description:
	The purpose of this to estimate:
	1. The total income of individuals
	2. The tax payable on the total income of individuals
	3. The proportion of people earning a wage/salary.

Notes:
- The tax is calculated based on the following marginal tax rates (which applied over the 2019-2023 period):
		$0-16,800			10.5%
		16,801-57,600		17.5%
		$57,601-84,000		30%
		$84,001-216,000		33%
		$216,001+			39%

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-15	AW	Adding documentation
2024-11-11	CW	Initial creation
**************************************************************************************************/

---------------------------------------------------------------------
-- income inputs

DROP TABLE IF EXISTS #cost
GO

CREATE TABLE #cost(
    snz_uid INT
    , cal_year INT
    , source VARCHAR(3)
    , value INT
    , cost FLOAT
)

--Extract all wage and salary income from 2019-2023
INSERT INTO #cost
SELECT [snz_uid]
    , [inc_cal_yr_sum_year_nbr] AS cal_year
    , 'WAS' source
    , IIF([inc_cal_yr_sum_WAS_tot_amt] > 0, 1, 0) AS value
    , [inc_cal_yr_sum_WAS_tot_amt] AS cost
FROM [IDI_Clean_202410].[data].[income_cal_yr_summary]
WHERE [inc_cal_yr_sum_year_nbr] BETWEEN 2019 AND 2023

--Extract total income from 2019-2023
INSERT INTO #cost
SELECT [snz_uid]
    , [inc_cal_yr_sum_year_nbr] AS cal_year
    , 'INC' AS source
    , NULL AS value
    , [inc_cal_yr_sum_all_srces_tot_amt] AS cost
FROM [IDI_Clean_202410].[data].[income_cal_yr_summary]
WHERE [inc_cal_yr_sum_year_nbr] BETWEEN 2019 AND 2023

--Extract estimate of tax payable from 2019-2023
INSERT INTO #cost
SELECT [snz_uid]
    , [inc_cal_yr_sum_year_nbr] AS cal_year
    , 'TAX' source
    , NULL AS value
    , CASE WHEN [inc_cal_yr_sum_all_srces_tot_amt] <= 0 THEN 0
			WHEN [inc_cal_yr_sum_all_srces_tot_amt] <  16801 THEN            - 0.105 *  [inc_cal_yr_sum_all_srces_tot_amt]
			WHEN [inc_cal_yr_sum_all_srces_tot_amt] <  57601 THEN  -1764     - 0.175 * ([inc_cal_yr_sum_all_srces_tot_amt] - 16800)
			WHEN [inc_cal_yr_sum_all_srces_tot_amt] <  84001 THEN  -8903.825 - 0.3   * ([inc_cal_yr_sum_all_srces_tot_amt] - 57600)
			WHEN [inc_cal_yr_sum_all_srces_tot_amt] < 216001 THEN -16823.525 - 0.33  * ([inc_cal_yr_sum_all_srces_tot_amt] - 84000)
			WHEN [inc_cal_yr_sum_all_srces_tot_amt] > 216000 THEN -60383.195 - 0.39  * ([inc_cal_yr_sum_all_srces_tot_amt] - 216000)
			ELSE NULL END AS cost
FROM [IDI_Clean_202410].[data].[income_cal_yr_summary]
WHERE [inc_cal_yr_sum_year_nbr] BETWEEN 2019 AND 2023

---------------------------------------------------------------------
-- combined output

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_income_and_tax]

--Adjust nominal costs to real (2024 dollars) based on CPI
SELECT snz_uid
    , a.cal_year
    , source
    , SUM(value) AS value
    , SUM(cost*cpi_adj_2024) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_income_and_tax]
FROM #cost AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON a.cal_year = b.cal_year
GROUP BY snz_uid
    , source
    , a.cal_year
