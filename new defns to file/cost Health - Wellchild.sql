/**************************************************************************************************
Title: Cost of Wellchild
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Clean_202410].[moh_clean].[maternity_baby]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_wellchild]

Description:
	Estimated cost of Wellchild

Notes:
- Actual prices for services are colledcted but not loaded into the IDI
	The price for children will be non differential
	But the vote approaiation will be represented
- Estimated that a wellchild contact costs 150 in 2014
	and  the 1 core and 1 additional contact per child per check

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-11	CW	Initial creation
**************************************************************************************************/


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_wellchild]
GO

WITH live AS(
    
    SELECT b.[snz_uid]
        , DATEFROMPARTS(b.moh_matb_baby_birth_year_nbr, b.moh_matb_baby_birth_month_nbr, 15) AS dob
    FROM [IDI_Clean_202410].[moh_clean].[maternity_baby] AS b

),
visit_dates AS (

	SELECT snz_uid
		, YEAR(start_date) AS cal_year
	FROM(
		SELECT snz_uid, DATEADD(DAY,7,dob) AS start_date FROM live
		UNION ALL
		SELECT snz_uid, DATEADD(DAY,(4*7),dob) AS start_date FROM live
		UNION ALL
		SELECT snz_uid, DATEADD(DAY,(9*7),dob) AS start_date FROM live
		UNION ALL
		SELECT snz_uid, DATEADD(DAY,(13*7),dob) AS start_date FROM live
		UNION ALL
		SELECT snz_uid, DATEADD(DAY,(6*30),dob) AS start_date FROM live
		UNION ALL
		SELECT snz_uid, DATEADD(DAY,(11.5*30),dob) AS start_date FROM live
		UNION ALL
		SELECT snz_uid, DATEADD(DAY,(13.5*30),dob) AS start_date FROM live
		UNION ALL
		SELECT snz_uid, DATEADD(DAY,(4.5*365),dob) AS start_date FROM live
	)AS a
	WHERE YEAR(start_date) BETWEEN 2019 AND 2023

)
--Adjust nominal costs to real (2024 dollars) based on CPI.
SELECT a.snz_uid
    , 'WCTO' AS source
    , a.cal_year
    , COUNT(*)AS value -- number visits
    , COUNT(*) * 300 * cpi_adj_2024 AS cost_real -- $300 per visit
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_wellchild]
FROM visit_dates AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON b.cal_year = 2014
GROUP BY snz_uid
    , a.cal_year
    , cpi_adj_2024
