/**************************************************************************************************
Title: Parental benefit duration indicator
Author: Charlotte Rose
Peer review: Simon Anastasiadis

Inputs & Dependencies:
- [IDI_Community].[inc_ise_main_benefit].[ise_main_benefit_202506]
- [IDI_Clean_202506].[data].[person_relationship]
- [IDI_Clean_202506].[data].[personal_detail]
- [IDI_Clean_202506].[data].[snz_res_pop]
 
Outputs:
- [IDI_Sandpit].[DL-MAA2023-46].[defn_parent_benefit_duration_202506]

Description:
Creates a table with child-parent pairs and the % of the childs life that parent was on a main benefit

Intended purpose:
For use in ACE score calculation

Notes:
1) This is a lifetime measure, not a spell measure
	So joining by a date range 


Parameters & Present values:
  Current refresh = 202506
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
 
Issues: 

History (reverse order):
2025-09-11 SA review and QA
2024-10-22 - CR 
**************************************************************************************************/

/* Condensed spells */
DROP TABLE IF EXISTS #mainbenspells;

WITH
/* shared staging filter */
staging_spells AS (
	SELECT a.snz_uid as parent
		, a.payment_start
		, a.payment_end
	FROM  [IDI_Community].[inc_ise_main_benefit].[ise_main_benefit_202506] AS a

),
/* exclude start dates that are within another spell */
spell_starts AS (
	SELECT parent
		, [payment_start]
	FROM staging_spells s1
	WHERE NOT EXISTS (
		SELECT 1
		FROM staging_spells s2
		WHERE s1.parent = s2.parent
		AND DATEADD(DAY, -1, s1.[payment_start]) BETWEEN s2.[payment_start] AND s2.[payment_end]
	)
),
/* exclude end dates that are within another spell */
spell_ends AS (
	SELECT parent
		, [payment_end]
	FROM staging_spells t1
	WHERE NOT EXISTS (
		SELECT 1 
		FROM staging_spells t2
		WHERE t2.parent = t1.parent
		AND  t1.[payment_end] BETWEEN DATEADD(DAY, -1, t2.[payment_start]) AND DATEADD(DAY, -1, t2.[payment_end])
	)
)

SELECT s.parent
	, s.[payment_start] as [payment_start]
	, MIN(e.[payment_end]) as [payment_end]
INTO #mainbenspells
FROM spell_starts AS s
INNER JOIN spell_ends AS e
	ON s.parent = e.parent
	AND s.[payment_start] <= e.[payment_end]
GROUP BY s.parent
	, s.[payment_start]
GO

--------------------------------------------------------------------------------------------
-- Output

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_parent_benefit_duration_202506]
GO

WITH join_w_child AS (

	SELECT b.parent
		, p.snz_uid AS child
		, p.snz_birth_date_proxy
		, b.payment_start
		, b.payment_end
		, IIF(b.payment_start < p.snz_birth_date_proxy, p.snz_birth_date_proxy, b.payment_start) AS trim_start -- latest start date
		, IIF(b.payment_end < DATEADD(YEAR,17,p.snz_birth_date_proxy), b.payment_end, DATEADD(YEAR,17,p.snz_birth_date_proxy)) AS trim_end -- eariest end date
	FROM #mainbenspells AS b
	INNER JOIN [IDI_Clean_202506].[data].[person_relationship] AS r
		ON b.parent = r.snz_uid
	INNER JOIN [IDI_Clean_202506].[data].[personal_detail] AS p
		ON r.snz_associated_uid = p.snz_uid
		AND r.prl_relationship_type_code = 'CH'
		-- payment range overlaps with child age 0-17 range
		AND p.snz_birth_date_proxy < b.payment_end
		AND b.payment_start < DATEADD(YEAR,17,p.snz_birth_date_proxy)
		AND b.payment_start <= b.payment_end

),
calculation AS (

	SELECT parent
		, child
		, SUM(DATEDIFF(DAY, trim_start, trim_end)) AS days_benefit
		, SUM(DATEDIFF(
			DAY,
			snz_birth_date_proxy,
			IIF(DATEADD(YEAR, 17, snz_birth_date_proxy) < GETDATE(), DATEADD(YEAR, 17, snz_birth_date_proxy), GETDATE())
		)) AS days_childhood
	FROM join_w_child
	GROUP BY parent
		, child
		, snz_birth_date_proxy

)
SELECT child
	, parent
	, ROUND(100.0 * days_benefit / days_childhood, 1) AS perc_childhood_on_ben
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_parent_benefit_duration_202506]
FROM calculation
GO
