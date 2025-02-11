/**************************************************************************************************
Title: Child with parent in corrections
Author: Ashleigh Arendt

Inputs & Dependencies:
- [IDI_Clean_{refresh}].[cor_clean].[ra_ofndr_major_mgmt_period_a]
- [IDI_Clean_{refresh}.[data].[personal_detail]

Outputs:
- [IDI_Sandpit].[DL-MAA2023-46].[defn_incarcerated_parent]

Description: 
Identifies children with parents who have had any interaction with corrections in the past 12 months, and the subset of which whose parents were incarcerated (in prison or in remand)

Intended purpose:
There's evidence to suggest children with a parent in prison experience a wide range of negative impacts, including long-term poor health, educational and social outcomes and are at high risk of future improsonment themselves.

Notes:
1) Relies on the parents being identified in the personal_details table. For a given quarter, about 15% of people aged 0-24 do not have parents identified, 10% of ages 0-14.
This statistic may well be higher for the corrections population as they have interacted with the system. 
2) We compare the number of parents identified and extrapolate to the prison population assuming the % of parents is 66% (using 2015 report by superu - Improving outcomes for children with a parent in prison) and align closely with corrections figures
3) Process to identify children with incarcerated parents
	-- 1. Limit corrections data to min max spells
	-- 2. Get parent-child links for those in corrections
	-- 3. Flag where for a given quarter the parent was in corrections

Parameters & Present values:
  Current refresh = 202406
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
  Earliest start date = '01-1919' Consistent records appear at this date

Issues:

History (reverse order):
2024-04-19 - AA, adapted from CW code
**************************************************************************************************/

---------------------------------------------------------------------
/* 1. CORRECTIONS DATA */
-- Limit the time window and keep anyone who was managed by corrections
DROP TABLE IF EXISTS #corrections;

SELECT [snz_uid]
    , [cor_rommp_directive_type]
    , [cor_rommp_period_start_date]
    , [cor_rommp_period_end_date]
INTO #corrections
FROM [IDI_Clean_202406].[cor_clean].ra_ofndr_major_mgmt_period_a
WHERE [cor_rommp_directive_type] NOT IN ('ALIVE'); --alive is used to show periods not managed by corrections

---------------------------------------------------------------------
/* 2. PARENT CHILD LINKS */
-- Get parent child list for all of the people in corrections
-- less than half have parents identified in the personal details table

DROP TABLE IF EXISTS #child_parents;

SELECT b.snz_uid AS child_snz_uid
    , snz_parent1_uid AS parent_snz_uid
INTO #child_parents
FROM #corrections AS a
INNER JOIN [IDI_Clean_202406].[data].[personal_detail] AS b
ON a.snz_uid = b.snz_parent1_uid
WHERE snz_parent1_uid IS NOT NULL

UNION

SELECT b.snz_uid AS child_snz_uid
    , snz_parent2_uid AS parent_snz_uid
FROM #corrections AS a
INNER JOIN [IDI_Clean_202406].[data].[personal_detail] AS b
ON a.snz_uid = b.snz_parent2_uid
WHERE snz_parent2_uid IS NOT NULL
AND snz_parent1_uid <> snz_parent2_uid; -- parents are different

---------------------------------------------------------------------
/* 3. CREATE FLAG FOR CORRECTION IN GIVEN TIME WINDOW */
-- List of children - might blow up if you have multiple parents
-- so need to do group by afterwards, only selecting cases where children are identified

DROP TABLE IF EXISTS #corr_with_kids;

SELECT child_snz_uid
	, 1 AS corrections_flag
	, IIF(cor_rommp_directive_type IN ('imprisonment', 'remand'), 1, 0) AS incarcerated_flag
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_incarcerated_parent]
FROM #corrections c
INNER JOIN #child_parents cp
ON c.snz_uid = cp.parent_snz_uid
