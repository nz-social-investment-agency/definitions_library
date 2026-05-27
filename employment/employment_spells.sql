/**************************************************************************************************
Title: Spell of employment
Author: Simon Anastasiadis
Re-edit: Freya Li
Reviewer: Simon Anastasiadis

Inputs & Dependencies:
- [IDI_Clean].[ir_clean].[ird_ems]
Outputs:
- [SIA_Sandpit].[DL-MAA2023-46].[defn_employed_spell]

Description:
A spell where wages or salaries are reported to IRD as evidence of employment.

Intended purpose:
Creating indicators of when/whether a person was employed.
Identifying spells when a person is employed.
Counting the number of days a person spends employed.
 
Notes:
1) Employer Monthly Summaries (EMS) records provide an indication that a person was employed
   during a specific month. Where start or end dates are provided, these are used so long
   as they are close to the month of the EMS record. For all other records (the vast majority)
   the first and last day of the month is used.
2) Employment includes receipt of Wages & Salaries (WAS or W&S), and receipt of Schedular Payments
   from which Withholding Payments are deducted (WHP). People receiving Wages & Salaries are
   employees. People receiving Schedular Payments may be contractors or business owners.
   Neither of these definitions perfectly capture self employment (sole trader, partnership,
   or company) some of which can only be observed at a (tax) year resolution.
   However, comparing EMS to tax year summaries suggests that W&S and WHP captures at least 
   some self-employment. And that this is more likely to be observed as WHP rather than W&S.
3) The EMS record includes start and end dates for employment. Where these are populated they
   may provide a more accurate indication of start and end date than the beginning and end
   of the return month (note the 'return period date' is the end of the month).
   - If the start date is provided and is within two months of the return date, then we use
     it as the best indication of start date. While employers must submit EMS monthly, an
     employee who joins once month and receivies their first pay the next month, will only
     appear in the EMS record for the second month.
   - If the end date is provided and is within the month for which the return relates,
     then we use it as the best indication of end date.
   - Inspection of the data suggests that when end dates are outside (after) the month of
     the return this is employers reporting future end dates of contracts. The employee
	 continues to have EMS records for each month of their employment. As future end dates can
	 change (be renegotiated) and their use would result in double counting of the same period
	 for the same job (different from the double counting where people work multiple jobs),
	 we only use provided end date if it is within the month of the EMS return.
4) Condensing is necessary to avoid double counting where people work multiple jobs.
   It also merges adjacent spells (e.g. 1-7 Jan and 8-14 Jan becomes 1-14 Jan).
   Condensing can be slow. But speed improvements arise from pre-filtering the input tables
   to narrower dates of interest.
5) A placeholder identity exists where the encrypted IRD number [snz_ird_uid] is equal to
   zero. Documentation states these are people who can not be linked. We exclude this identity.
6) Entity counts can be required for business information. As the need to merge spells and avoid
	double counting of days is more important than the need to get entity counts perfect, each
	output spell has the entity IDs of only the employer at the start of the spell. This means
	any count of entities will be more conservative than the true value.

Parameters & Present values:
  Current refresh = 202506
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
  Earliest start date = '2015-01-01'
  Latest end date = '2024-12-31'
 
Issues:
- Does not capture all self-employment. Use of annual tax year data is recommended for analyses at
  annual resolution, or where it is important to capture self-employment.
- Slow. For years 2014-2020 runtime more than 2 hours
 
History (reverse order):
2025-05-09 SA update for test and learns
2021-01-26 SA QA
2021-01-11 FL v2 (Change prefix and update the table to the latest refresh)
2020-07-22 JB QA
2020-07-01 SA expanded definition of employment to include WHP as this covers some self-employment
2020-03-02 SA v1
**************************************************************************************************/

/* Set database for writing views */
USE IDI_UserCode
GO

/* Clear existing view */
DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_employed_spell_staging_202506]
GO

/* Create staging */
CREATE VIEW [DL-MAA2023-46].[defn_employed_spell_staging_202506] AS
SELECT snz_uid
	,CASE
		WHEN [ir_ems_employee_start_date] IS NOT NULL
			AND [ir_ems_employee_start_date] < [ir_ems_return_period_date]
			AND DATEDIFF(DAY, [ir_ems_employee_start_date], [ir_ems_return_period_date]) < 60 -- employee started in the last two months
		THEN [ir_ems_employee_start_date]
		ELSE DATEFROMPARTS(YEAR([ir_ems_return_period_date]), MONTH([ir_ems_return_period_date]),1) END AS [start_date]
	,CASE
		WHEN [ir_ems_employee_end_date] IS NOT NULL
			AND [ir_ems_employee_end_date] < [ir_ems_return_period_date]
			AND ([ir_ems_employee_start_date] IS NULL OR [ir_ems_employee_start_date] < [ir_ems_employee_end_date])
			AND DATEDIFF(DAY, [ir_ems_employee_end_date], [ir_ems_return_period_date]) < 27 -- employee finished in the last month
		THEN [ir_ems_employee_end_date] 
		ELSE [ir_ems_return_period_date] END AS [end_date]
	,CAST(SUBSTRING([ir_ems_enterprise_nbr], 3, LEN([ir_ems_enterprise_nbr]) - 2) AS INT) AS [ir_ems_enterprise_nbr]
	,CAST(SUBSTRING([ir_ems_pbn_nbr], 3, LEN([ir_ems_pbn_nbr]) - 2) AS INT) AS [ir_ems_pbn_nbr]
FROM [IDI_Clean_202506].[ir_clean].[ird_ems]
WHERE [ir_ems_income_source_code] IN ('W&S', 'WHP') -- employment income types
AND [snz_ird_uid] > 0 -- exclude placeholder person without IRD number
AND ir_ems_gross_earnings_amt > 0 -- zero and negative earnings may be just administrative records
AND ir_ems_snz_unique_nbr = 1
AND [ir_ems_return_period_date] BETWEEN '2015-01-01' AND '2024-12-31'
GO

/* Condensed spells */
DROP TABLE IF EXISTS [SIA_Sandpit].[DL-MAA2023-46].[defn_employed_spell_202506]
GO

WITH
/* exclude start dates that are within another spell */
spell_starts AS (
	SELECT [snz_uid], [start_date], [ir_ems_enterprise_nbr], [ir_ems_pbn_nbr]
	FROM [IDI_UserCode].[DL-MAA2023-46].[defn_employed_spell_staging_202506] AS s1
	WHERE [start_date] <= [end_date]
	AND NOT EXISTS (
		SELECT 1
		FROM [IDI_UserCode].[DL-MAA2023-46].[defn_employed_spell_staging_202506] AS s2
		WHERE s1.snz_uid = s2.snz_uid
		AND DATEADD(DAY, -1, s1.[start_date]) BETWEEN s2.[start_date] AND s2.[end_date]
	)
),
/* exclude end dates that are within another spell */
spell_ends AS (
	SELECT [snz_uid], [end_date]
	FROM [IDI_UserCode].[DL-MAA2023-46].[defn_employed_spell_staging_202506] AS t1
	WHERE [start_date] <= [end_date]
	AND NOT EXISTS (
		SELECT 1 
		FROM [IDI_UserCode].[DL-MAA2023-46].[defn_employed_spell_staging_202506] AS t2
		WHERE t2.snz_uid = t1.snz_uid
		AND YEAR(t1.[end_date]) <> 9999
		AND DATEADD(DAY, 1, t1.[end_date]) BETWEEN t2.[start_date] AND t2.[end_date]
		--AND IIF(YEAR(t1.[end_date]) = 9999, t1.[end_date], DATEADD(DAY, 1, t1.[end_date])) BETWEEN t2.[start_date] AND t2.[end_date]
	)
)
SELECT s.snz_uid
	, s.[start_date]
	, s.[ir_ems_enterprise_nbr] -- entity IDs are drawn from initial employer
	, s.[ir_ems_pbn_nbr]        -- so entity counts will be (very) conservative
	, MIN(e.[end_date]) as [end_date]
INTO [SIA_Sandpit].[DL-MAA2023-46].[defn_employed_spell_202506]
FROM spell_starts s
INNER JOIN spell_ends e
ON s.snz_uid = e.snz_uid
AND s.[start_date] <= e.[end_date]
GROUP BY s.snz_uid, s.[start_date], s.[ir_ems_enterprise_nbr], s.[ir_ems_pbn_nbr]
GO

/* Add index */
CREATE NONCLUSTERED INDEX my_index_name ON [SIA_Sandpit].[DL-MAA2023-46].[defn_employed_spell_202506] (snz_uid)
GO

/* Clear staging view */
DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_employed_spell_staging_202506]
GO

