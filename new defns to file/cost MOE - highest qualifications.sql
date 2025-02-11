/**************************************************************************************************
Title: Highest NQF qualification
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[data].[apc_time_series]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_learning_support]

Description:
	Highest qualification by National Qualification Framework (NQF)

Notes:

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-13 CWright version 1
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_learning_support]

SELECT [snz_uid]
    , [apc_ref_year_nbr] AS cal_year
    , 'HQ' AS source
    , [apc_hst_qual_code]
    , IIF([apc_hst_qual_code] = 0, 1, 0)AS HQ0
    , IIF([apc_hst_qual_code] = 1, 1, 0)AS HQ1
    , IIF([apc_hst_qual_code] = 2, 1, 0)AS HQ2
    , IIF([apc_hst_qual_code] = 3, 1, 0)AS HQ3
    , IIF([apc_hst_qual_code] = 4, 1, 0)AS HQ4
    , IIF([apc_hst_qual_code] = 5, 1, 0)AS HQ5
    , IIF([apc_hst_qual_code] = 6, 1, 0)AS HQ6
    , IIF([apc_hst_qual_code] = 7, 1, 0)AS HQ7
    , IIF([apc_hst_qual_code] = 8, 1, 0)AS HQ8
    , IIF([apc_hst_qual_code] = 9, 1, 0)AS HQ9
    , IIF([apc_hst_qual_code] = 10, 1, 0)AS HQ10
    , apc_hst_qual_provider_code
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_learning_support]
FROM [IDI_Clean_202410].[data].[apc_time_series]
WHERE [apc_ref_year_nbr] BETWEEN 2019 AND 2023
