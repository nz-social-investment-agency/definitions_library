/**************************************************************************************************
Title: Fiscal costs - ACC claims
Author: Craig Wright (edited by Andrew Webber)

Inputs & Dependencies:
	[IDI_Clean_202410].[acc_clean].[claims]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_ACC_claims]

Description:
	The purpose of this cost is to estimate the costs incurred via ACC claims.
	Both in terms of medical fees, and also worker's compensation payments.
	
Notes:
- Medical fees and worker's compensation are differentiated by [source]
- This relies on the ACC claims table. We have linked the cost information to the year the original accident occurred. 

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-13	AW	Adding documentation
2024-11-11	CW	Initial creation
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_ACC_claims]
GO

WITH setup_medical AS (

	SELECT [snz_uid]
        , YEAR([acc_cla_accident_date]) AS cal_year
        , 'ACC_MED' AS source
        , COUNT(DISTINCT snz_acc_claim_uid) AS value -- number of claims
        , SUM([acc_cla_tot_med_fee_paid_amt]) AS cost
    FROM [IDI_Clean_202410].[acc_clean].[claims]
    WHERE acc_cla_decision_text NOT IN ('DECLINE', 'HELD', 'INTERIM ACCEPT')
    GROUP BY snz_uid, YEAR([acc_cla_accident_date])
),
setup_compensation AS (

	SELECT [snz_uid]
        , YEAR([acc_cla_accident_date]) AS cal_year
        , 'ACC_COMP' AS source
        , SUM(acc_cla_weekly_comp_days_nbr) AS value -- total days on compensation
        , SUM([acc_cla_tot_entitlement_pd_amt]) AS cost
    FROM [IDI_Clean_202410].[acc_clean].[claims]
    WHERE acc_cla_decision_text NOT IN('DECLINE', 'HELD', 'INTERIM ACCEPT')
    GROUP BY snz_uid, YEAR([acc_cla_accident_date])

),
setup_combined AS (

	SELECT *
	FROM setup_medical
	WHERE cal_year IN (2019,2020,2021,2022,2023)

    UNION ALL
	
	SELECT *
	FROM setup_compensation
	WHERE cal_year IN (2019,2020,2021,2022,2023)

)
--Convert nominal cost values into real, adj to 2024 dollars
SELECT a.snz_uid
    , a.source
    , a.cal_year
    , a.value
    , cost * b.cpi_adj_2024 AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_ACC_claims]
FROM setup_combined AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON a.cal_year = b.cal_year
