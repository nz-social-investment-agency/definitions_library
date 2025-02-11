/**************************************************************************************************
Title: Disability Support Services Costs (to individuals)
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_service_hist_2022]
	[IDI_Clean_202410].[security].[concordance]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_disability_support_services]

Description:
	The purpose of this cost is to estimate costs incurred in providing Disability Support Services to individuals.

Notes:
- This relies solely on information collected in SOCRATES, the system used to store operational DSS data.
- The nominal costs have been converted to real via the CPI.
- Testing completeness of data - note that 2022 data is incomplete, and 2023 data is missing entirely

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-13	AW	Adding documentation
2024-11-11	CW	Initial creation
**************************************************************************************************/

--Capture nominal costs per entry in SOCRATES
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_disability_support_services]
GO

WITH setup AS (

SELECT b.snz_uid
    , a.[snz_moh_uid]
    , YEAR([StartDate_Value]) AS cal_year
    , [StartDate_Value] AS start_date
    , [EndDate_Value] AS end_date
	, [FMISAccountCode_Value] AS code
    , [TransparentPricingModelVariableD]
    , [UnitOfService_Value]
    , [ServiceFrequency_Value]
	, 1 + DATEDIFF(DAY,[StartDate_Value],[EndDate_Value]) AS duration
    , [AverageWeeklyCost_Value]/7 AS daily_cost
    , 1.0 * [AverageWeeklyCost_Value] / 7 *(1 + DATEDIFF(DAY,[StartDate_Value],[EndDate_Value])) AS total
    , [TotalCost_Value] total_cost
FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_service_hist_2022] AS a
--Join on concordance to get snz_uid
INNER JOIN [IDI_Clean_202410].[security].[concordance] AS b
ON a.snz_moh_uid = b.snz_moh_uid
--Removing entries that correspond to system migration, and may not represent individual events
WHERE FMISAccountCode_Value ! = 'MIGRATION'
--Removing very large values (more than $1m). This is intended to remove erroneous entries that are known to exist 
--in SOCRATES, but where there is no other existing business rule to identify.
AND 1.0 * [AverageWeeklyCost_Value] / 7 * (1 + DATEDIFF(DAY,[StartDate_Value],[EndDate_Value])) < 1000000

)
--Adjust nominal costs to real (2024 dollars) based on CPI
SELECT a.snz_uid
    , 'SOC' AS source
    , a.cal_year
    , COUNT(*) AS value
    , SUM(total * cpi_adj_2024) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_disability_support_services]
FROM setup AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON a.cal_year = b.cal_year
GROUP BY snz_uid
    , a.cal_year

