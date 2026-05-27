/**************************************************************************************************
Title: Birth dates of youngest and oldest children for parents
Author: Simon Anastasiadis

Inputs & Dependencies:
- [IDI_Clean_202506].[data].[personal_detail]
Outputs:
- [IDI_UserCode].[DL-MAA2023-46].[defn_child_birthdates]

Description:
Date of earliest and latest child's birth

Intended purpose:
Calculating age of youngest / oldest child.
When master table contains snz_uid and snz_parent_uid provides
indication of younger siblings.
 
Notes:
- Run time is ~1 minute. We judged this fast enough for a View
	but could be converted to a table and indexed if required.
- This data produces a very different distribution of children per adult than Census produces
	of children per household:
	- In Census 2023, of households with children, about 40% have 1 child and about 40% have 2 children.
	- While this table, of adults with children, about 80% have 1 child and about 10% have 2 children.
	Limiting to only recent NZ residents produces proportions more similar to Census 2023, suggesting
	that differences with Census are due to non-residents.
- Results consistent with, though a little higher than, official birth rates.

Parameters & Present values:
  Current refresh = 202506
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
 
Issues:
 
History (reverse order):
2025-06-18 SA version 1
**************************************************************************************************/

USE IDI_UserCode
GO

DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_child_birthdates_202506]
GO

CREATE VIEW [DL-MAA2023-46].[defn_child_birthdates_202506] AS
WITH parents_and_birthdates AS (

	SELECT snz_parent1_uid AS snz_uid
		,snz_birth_date_proxy
	FROM [IDI_Clean_202506].[data].[personal_detail]
	WHERE snz_parent1_uid IS NOT NULL

	UNION ALL

	SELECT snz_parent2_uid AS snz_uid
		,snz_birth_date_proxy
	FROM [IDI_Clean_202506].[data].[personal_detail]
	WHERE snz_parent2_uid IS NOT NULL
	AND snz_parent1_uid <> snz_parent2_uid

)
SELECT snz_uid
	,MIN(snz_birth_date_proxy) AS oldest_child_birth
	,MAX(snz_birth_date_proxy) AS youngest_child_birth
	,COUNT(*) AS num_children
FROM parents_and_birthdates
GROUP BY snz_uid
GO

/*
-- calculate number of children per parent for NZ residents
SELECT num_children, COUNT(*) AS num_parents
FROM [DL-MAA2023-46].[defn_child_birthdates]
WHERE snz_uid IN (SELECT snz_uid FROM [IDI_Clean_202506].[data].[snz_res_pop] WHERE YEAR(srp_ref_date) >= 2020)
GROUP BY num_children
ORDER BY num_children
*/
