/**************************************************************************************************
Title: Corrections Manjor Management Periods - 202506 onwards
Author: Simon Anastasiadis
Reviewer: 

Description:
Corrections major management periods

Intended purpose:
Allowing researchers who are familiar with the 202503 refresh or earlier Corrections data
to continue to work with a familiar data format from the 202506 refresh onwards.

Inputs & Dependencies:
	[IDI_Clean].[cor_clean].[directive]
	[IDI_Clean].[cor_clean].[muster]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[def_COR_major_management_periods]
 
Definition notes:
- Between the 202503 and 202506 refreshes, the Corrections updated the way they provided
	data into the IDI. The new provision is more sustainable. However, it is not as easy
	for researchers to use.
- This definition constructs a researcher-friendly table equivalent to the previous
	[cor_clean].[ra_ofndr_major_mgmt_period_a] table. Validation of the new table against the
	previous one shows excellent consistency across all time periods (we tested 2000-2020)
	and all Corrections management types.
- Corrections management includes prison sentences (PRISON), remanded in custody (REMAND),
   supervision (ESO, INT_SUPER, SUPER), home detention (HD_REL, HD_SENT), conditions
   (PAROLE, ROC, PDC, PERIODIC), and community sentences (COM_DET, CW, COM_PROG, COM_SERV, OTH_COM).
- Periods not managed by corrections are not included in this definition.
- This data set includes only major management periods, of which Prison is one type.
   Where a person has multiple management/sentence types this dataset only records the
   most severe. See introduction of Corrections documentation (2016).
- Consecutive management spells will overlap by one day. The end date of the previous spell
	will be the start date of the next spell. This is consistent with how dates appear in the
	source data.
	Subtracting one day from the end date, is recommended when non-overlapping periods are needed.

Corrections context and data notes:
- From comparing the Sentence and Directive datasets:
	We focus on the Directive dataset as closer to what individuals experience.
	Multiple sentences can be served concurrently.
	Not every directive is a sentence.
- Correspondence between Sentences and Directives is consistent in the ways we care about:
	Not every sentence type matches neatly to a directive type.
	But the sentence types that are not matched are not of high interest.
	Not every directive type matches neatly to a sentence type.
	But the directive types that are not matched are non-sentence types (e.g. parole).
	Where types match, counts differ (as several sentences can be merged into a single directive)
	but proportions are consistent.
- The system date columns are not useful for determing record correctness when two records clash.
	These dates show little variation, suggesting they come from system migration rather than data entry.
	In data we explored the system dates are 5+ years later than the event (sentence / directive / muster)
	start date. Events with earlier system dates take precedence over events with more recent system dates.
- Directive dates can overlap:
	E.g. People can be remanded while in prison - prison takes prescedent.
	E.g. When a directive changes (e.g. prison to home detention) the 'from' record keeps its original end date.
	So method needs to resolve these overlaps and early ends.
- Comparing Directive & Muster to Major Management Periods 202503		:
	Where directives overlap the one with the lower MMC_Rank takes prescidence.
	The exception is where Muster indicates that a directive ends early.
	We also observe that a single directive can have multiple separate musters, suggesting that
	these directives pause and later resume (e.g. prison to parole to prison).
- Directive vs. Muster datasets
	The directive dataset contains more infromation than the muster dataset.
		For example, supervision, home detention, and parole are not included in the muster dataset.
	Muster table has [cor_mus_release_type_text] = 'NOT APPLICABLE'	only when [cor_mus_actual_release_date]
		is not null (and hence differs from muster end-date). Suggesting we can use Muster for actual end dates.
	Muster database shows very high overlap with Remand and Prison, and with Parole and Release on Conditions (ROC).
		Prison is clearly in prison. Remand can also be in prison (other options include police or court cells).
		Hence it makes sense that both of these are part of Muster database. However Parole and ROC are time within
		a prison sentence when the person is released into the community under the supervision of a probation officer.
		So the person should now be included in a muster.
	Insight to apply:
		We can interpret the muster dataset as giving the spells a person spends On Remand or In Prison.
		So where a Remand or Prison directive exists, we only keep the part that falls within the muster dataset.

Overview of methodology:
- (0) Metadata MMC table
	Create metadata table, loading data sourced from Corrections metadata.
	Needed for ranking of directive types and for enforcing consistent naming.
- (1) initialise experienced directives table
	An empty table populated in steps 2 and 3.
- (2) populate non-muster directives
	We take start and end dates of all directives that do not have musters (Prison and Remand)
	as given in the directives dataset.
- (3) populate muster directives
	Prison and Remand directives only apply during musters.
	We take start and end dates from these directives that overlap with musters.
- (4) construct all applicable date ranges
	We want to consider for each day all the directives that might apply on that day to choose
	the one with the lowest rank. Rather than working on individual days it is more effective
	to work on spells of consecutive days where there is no change in directives (stable spells).
	This step builds all possible spells that might be relevant for each individual.
- (5) identify management type options of each date range
	For each stable spell, find all directives that apply to that spell and the rank of
	all those directives.
- (6) identify single management type of each date range
	Each spell keeps only the rank of the directive that takes precedence.
	This is the lowest rank in the metadata table from step 0.
- (7) merge adjacent management types
	Where adjacent spells are of the same type, merge to reduce table size.
- (8) output
	Join back on the text labels for the types and write for future reuse.
- (9) clean up
	Drop all the temporary tables.
- (V) validation against 202503
	Commented out validation method.
	For each starting year of a management period we calculate numbe records, number people
	and total duration of periods.
	This is done for:
		- 202503 refresh (the prev. table = the target to reproduce)
		- 202506 refresh (the new constructed table = the reproduction)
		- the overlap between these two (join by snz_jus_uid)


Parameters & Present values:
  Current refresh = 202506
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
 
Issues:
 
History (reverse order):
2025-07-04 SA v1
**************************************************************************************************/

--------------------------------------------------------------------------------
-- (0) Metadata MMC table

-- Based on Corrections metadata available via Wiki.
-- Mapping of 202506 types to 202503 types done manually based raw text.
-- Rank column is used to determine which directive has precedence if several apply.

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_codes]
GO

CREATE TABLE [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_codes] (
	MMC_historic_code VARCHAR(10)
	,MMC_Description VARCHAR(40)
	,MMC_Rank INT NOT NULL
	,MMC_202506_code VARCHAR(40)
	,MMC_202503_code VARCHAR(40)
)

INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_codes] VALUES
('ERROR', 'Period code not properly handled', 1, '', ''),
('PRISON', '', 8, 'LIFE IMPRISONMENT', ''),
('PRISON', '', 9, 'PREVENTIVE DETENTION [IMPRISONMENT]', ''),
('PRISON', 'Prison sentenced', 10, 'OTHER IMPRISONMENT', 'IMPRISONMENT'),
('REMAND', 'Remanded in custody', 20, 'REMAND (ACCUSED / CONVICTED)', 'REMAND'),
('ESO', 'Extended supervision order', 30, 'EXTENDED SUPERVISION ORDER', 'EXTENDED SUPERVISION ORDER'),
('HD_REL', 'Released to HD', 40, '', ''),
('PAROLE', 'Paroled', 50, 'PAROLE', 'PAROLE'),
('ROC', 'Released with conditions', 60, 'RELEASED ON CONDITIONS', 'RELEASED ON CONDITIONS'),
('HD_SENT', 'Home detention sentenced', 70, 'HOME DETENTION', 'HOME DETENTION'),
('PDC', 'Post detention conditions', 80, 'POST DETENTION CONDITIONS', 'POST DETENTION CONDITIONS'),
('INT_SUPER', 'Intensive supervision', 90, 'INTENSIVE SUPERVISION', 'INTENSIVE SUPERVISION'),
('COM_DET', 'Community detention', 100, 'COMMUNITY DETENTION', 'COMMUNITY DETENTION'),
('SUPER', 'Supervision', 110, 'SUPERVISION', 'SUPERVISION'),
('CW', 'Community work', 120, 'COMMUNITY WORK', 'COMMUNITY WORK'),
('PERIODIC', 'Periodic detention', 130, 'PERIODIC DETENTION', 'PERIODIC DETENTION'),
('COM_PROG', 'Community programme', 140, 'COMMUNITY PROGRAMME', 'COMMUNITY PROGRAMME'),
('COM_SERV', 'Community service', 150, 'COMMUNITY SERVICE', 'COMMUNITY SERVICE'),
('OTH_COM', 'Other community', 160, 'OTHER SENTENCING OUTCOME', ''),
('ROO', 'Returning offender order', 65, 'RETURNING OFFENDER ORDER', 'RETURNING OFFENDER ORDER')

--------------------------------------------------------------------------------
-- (1) initialise experienced directives table

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_experienced_directives]
GO

SELECT TOP 0 [snz_uid]
    ,[snz_jus_uid]
    ,[cor_dir_directive_type_text]
    ,[cor_dir_management_start_date]
    ,[cor_dir_management_end_date]
INTO [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_experienced_directives]
FROM [IDI_Clean_202506].[cor_clean].[directive]
GO

--------------------------------------------------------------------------------
-- (2) populate non-muster directives

INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_experienced_directives]
SELECT [snz_uid]
    ,[snz_jus_uid]
    ,[cor_dir_directive_type_text]
    ,[cor_dir_management_start_date]
    ,[cor_dir_management_end_date]
FROM [IDI_Clean_202506].[cor_clean].[directive]
WHERE [cor_dir_directive_type_text] NOT IN ('OTHER IMPRISONMENT', 'REMAND (ACCUSED / CONVICTED)')
AND [cor_dir_management_start_date] <= [cor_dir_management_end_date]
AND [cor_dir_management_start_date] BETWEEN '1920-01-01' AND GETDATE()
GO

--------------------------------------------------------------------------------
-- (3) populate muster directives

INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_experienced_directives]
SELECT d.[snz_uid]
    ,d.[snz_jus_uid]
    ,[cor_dir_directive_type_text]
    ,IIF([cor_dir_management_start_date] <= [cor_mus_muster_start_date], [cor_mus_muster_start_date], [cor_dir_management_start_date]) AS later_start -- [cor_dir_management_start_date]
    ,IIF([cor_dir_management_end_date] <= COALESCE(m.[cor_mus_muster_end_date], GETDATE()), [cor_dir_management_end_date], COALESCE(m.[cor_mus_muster_end_date], GETDATE())) AS earlier_end -- [cor_dir_management_end_date]
FROM [IDI_Clean_202506].[cor_clean].[directive] AS d
INNER JOIN [IDI_Clean_202506].[cor_clean].[muster] AS m
ON d.snz_uid = m.snz_uid
AND d.snz_jus_uid = m.snz_jus_uid
-- overlap
AND d.[cor_dir_management_start_date] <= COALESCE(m.[cor_mus_muster_end_date], GETDATE())
AND m.[cor_mus_muster_start_date] <= d.[cor_dir_management_end_date]
WHERE [cor_dir_directive_type_text] IN ('OTHER IMPRISONMENT', 'REMAND (ACCUSED / CONVICTED)')
AND [cor_dir_management_start_date] <= [cor_dir_management_end_date]
AND [cor_dir_management_start_date] BETWEEN '1920-01-01' AND GETDATE()
GO

CREATE NONCLUSTERED INDEX i_uid ON [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_experienced_directives] (snz_uid)
GO

--------------------------------------------------------------------------------
-- (4) construct all applicable date ranges

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_all_dates]
GO

SELECT DISTINCT *
INTO [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_all_dates]
FROM (
	SELECT snz_uid
		,snz_jus_uid
		,cor_dir_management_start_date AS ref_date
	FROM [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_experienced_directives]

	UNION ALL

	SELECT snz_uid
		,snz_jus_uid
		,cor_dir_management_end_date AS ref_date
	FROM [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_experienced_directives]
) AS k
GO

CREATE NONCLUSTERED INDEX i_uid ON [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_all_dates] (snz_uid, snz_jus_uid) INCLUDE (ref_date)
GO

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_date_ranges]
GO

SELECT snz_uid
	,snz_jus_uid
	,ref_date AS [start_date]
	,LEAD(ref_date, 1, '9999-12-31') OVER (PARTITION BY snz_uid, snz_jus_uid ORDER BY ref_date) AS [end_date]
INTO [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_date_ranges]
FROM [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_all_dates]
GO

CREATE NONCLUSTERED INDEX i_uid ON [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_date_ranges] (snz_uid, snz_jus_uid) INCLUDE ([start_date], [end_date])
GO

--------------------------------------------------------------------------------
-- (5) identify management type options of each date range

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_date_ranges_w_management_type]
GO

SELECT d.snz_uid
	,d.snz_jus_uid
	,d.[start_date]
	,d.[end_date]
	,e.[cor_dir_directive_type_text]
	,e.cor_dir_management_start_date
	,e.cor_dir_management_end_date
	,c.MMC_202503_code
	,c.MMC_Rank
INTO [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_date_ranges_w_management_type]
FROM [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_date_ranges] AS d
INNER JOIN [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_experienced_directives] AS e
ON d.snz_uid = e.snz_uid
AND d.snz_jus_uid = e.snz_jus_uid
-- overlap but exclude overlap on end date
-- (use < instead of <= because this period end is next period start)
AND d.[start_date] < e.cor_dir_management_end_date
AND e.cor_dir_management_start_date < d.[end_date]
INNER JOIN [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_codes] AS c
ON e.[cor_dir_directive_type_text] = c.MMC_202506_code
GO

CREATE NONCLUSTERED INDEX i_uid ON [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_date_ranges_w_management_type] (snz_uid, snz_jus_uid, [start_date], end_date) INCLUDE (MMC_Rank)
GO

--------------------------------------------------------------------------------
-- (6) identify single management type of each date range

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_priority_management_type]
GO

SELECT snz_uid
	, snz_jus_uid
	, [start_date]
	, [end_date]
	, MIN(MMC_Rank) AS MMC_Rank
INTO [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_priority_management_type]
FROM [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_date_ranges_w_management_type]
GROUP BY snz_uid, snz_jus_uid, [start_date], [end_date]
GO

CREATE NONCLUSTERED INDEX i_uid ON [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_priority_management_type] (snz_uid, snz_jus_uid, MMC_Rank)
GO

--------------------------------------------------------------------------------
-- (7) merge adjacent management types

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_merge]
GO

WITH
/* exclude start dates that are within another spell */
possible_starts AS (
	SELECT snz_uid
		,snz_jus_uid
		,MMC_Rank
		,[start_date]
	FROM [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_priority_management_type] AS s1
	WHERE NOT EXISTS (
		SELECT 1
		FROM [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_priority_management_type] AS s2
		WHERE s1.snz_uid = s2.snz_uid
		AND s1.snz_jus_uid = s2.snz_jus_uid
		AND s1.MMC_Rank = s2.MMC_Rank
		AND DATEADD(DAY, -1, s1.[start_date]) BETWEEN s2.[start_date] AND s2.[end_date]
	)
),
/* exclude end dates that are within another spell */
possible_ends AS (
	SELECT snz_uid
		,snz_jus_uid
		,MMC_Rank
		,[end_date]
	FROM [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_priority_management_type] AS e1
	WHERE NOT EXISTS (
		SELECT 1
		FROM [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_priority_management_type] AS e2
		WHERE e1.snz_uid = e2.snz_uid
		AND e1.snz_jus_uid = e2.snz_jus_uid
		AND e1.MMC_Rank = e2.MMC_Rank
		AND e1.[end_date] BETWEEN DATEADD(DAY, -1, e2.[start_date]) AND DATEADD(DAY, -1, e2.[end_date])
	)
)
SELECT s.snz_uid
	,s.snz_jus_uid
	,s.MMC_Rank
	,s.[start_date]
	,MIN(e.[end_date]) AS [end_date]
INTO [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_merge]
FROM possible_starts AS s
INNER JOIN possible_ends AS e
ON s.snz_uid = e.snz_uid
AND s.snz_jus_uid = e.snz_jus_uid
AND s.MMC_Rank = e.MMC_Rank
AND s.[start_date] <= e.[end_date]
GROUP BY s.snz_uid
	,s.snz_jus_uid
	,s.MMC_Rank
	,s.[start_date]
GO

--------------------------------------------------------------------------------
-- (8) output

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[def_COR_major_management_periods]
GO

SELECT snz_uid
	,snz_jus_uid
	,[start_date]
	,[end_date]
	,c.MMC_202503_code AS mm_type
INTO [IDI_Sandpit].[DL-MAA2023-46].[def_COR_major_management_periods]
FROM [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_merge] AS m
INNER JOIN [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_codes] AS c
ON m.MMC_Rank = c.MMC_Rank
GO

CREATE NONCLUSTERED INDEX i_uid ON [IDI_Sandpit].[DL-MAA2023-46].[def_COR_major_management_periods] (snz_uid)
GO

--------------------------------------------------------------------------------
-- (9) clean up

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_codes]
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_experienced_directives]
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_all_dates]
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_date_ranges]
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_date_ranges_w_management_type]
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_priority_management_type]
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[tmp_COR_merge]
GO

--------------------------------------------------------------------------------
-- (V) validation against 202503

/*
DROP TABLE IF EXISTS #overlap
DROP TABLE IF EXISTS #new
DROP TABLE IF EXISTS #old

-- calculate old patterns
SELECT YEAR(a.cor_rommp_period_start_date) AS start_year
	,CASE
		WHEN a.cor_rommp_directive_type IN ('HD_REL', 'HD_SENT') THEN 'HD'
		WHEN a.cor_rommp_directive_type = 'ELECTRONICALLY MONITORED BAIL' THEN 'REMAND'
		WHEN a.cor_rommp_directive_type = 'EXTENDED SUPERVISION ORDER (INTERIM)' THEN 'EXTENDED SUPERVISION ORDER'
		ELSE a.cor_rommp_directive_type END AS cor_mmp_mmc_code
	,COUNT(*) AS num_records
	,COUNT(DISTINCT a.snz_uid) AS num_people
	,SUM(DATEDIFF(DAY, a.cor_rommp_period_start_date, a.cor_rommp_period_end_date)) AS duration
INTO #old
FROM [IDI_Clean_202503].[cor_clean].[ra_ofndr_major_mgmt_period_a] AS a
-- remove duplicate records
INNER JOIN (
	SELECT snz_uid, MAX([cor_rommp_max_period_nbr]) AS [cor_rommp_max_period_nbr]
	FROM [IDI_Clean_202503].[cor_clean].[ra_ofndr_major_mgmt_period_a]
	GROUP BY snz_uid
) AS b
ON a.snz_uid = b.snz_uid
AND a.[cor_rommp_max_period_nbr] = b.[cor_rommp_max_period_nbr]
WHERE cor_rommp_period_end_date <= GETDATE()
AND YEAR(cor_rommp_period_start_date) BETWEEN 2000 AND 2020
GROUP BY YEAR(cor_rommp_period_start_date)
	,CASE
		WHEN a.cor_rommp_directive_type IN ('HD_REL', 'HD_SENT') THEN 'HD'
		WHEN a.cor_rommp_directive_type = 'ELECTRONICALLY MONITORED BAIL' THEN 'REMAND'
		WHEN a.cor_rommp_directive_type = 'EXTENDED SUPERVISION ORDER (INTERIM)' THEN 'EXTENDED SUPERVISION ORDER'
		ELSE a.cor_rommp_directive_type END

-- calculate new patterns
SELECT YEAR(start_date) AS start_year
	,IIF(mm_type IN ('HD_REL', 'HD_SENT'), 'HD', mm_type) AS mm_type
	,COUNT(*) AS num_records
	,COUNT(DISTINCT snz_uid) AS num_people
	,SUM(DATEDIFF(DAY, start_date, end_date)) AS duration
INTO #new
FROM [IDI_Sandpit].[DL-MAA2023-46].[def_COR_major_management_periods]
WHERE end_date <= GETDATE()
AND YEAR(start_date) BETWEEN 2000 AND 2020
GROUP BY YEAR(start_date), IIF(mm_type IN ('HD_REL', 'HD_SENT'), 'HD', mm_type)

-- calculate amount of overlap
SELECT YEAR(new.start_date) AS start_year
	,CASE
		WHEN old.cor_rommp_directive_type IN ('HD_REL', 'HD_SENT') THEN 'HD'
		WHEN old.cor_rommp_directive_type = 'ELECTRONICALLY MONITORED BAIL' THEN 'REMAND'
		WHEN old.cor_rommp_directive_type = 'EXTENDED SUPERVISION ORDER (INTERIM)' THEN 'EXTENDED SUPERVISION ORDER'
		ELSE old.cor_rommp_directive_type END AS cor_mmp_mmc_code
	,COUNT(*) AS num_records
	,COUNT(DISTINCT new.snz_jus_uid) AS num_people
	,SUM(DATEDIFF(DAY,
		IIF(new.start_date <= old.cor_rommp_period_start_date, old.cor_rommp_period_start_date, new.start_date), -- trimmed start date
		IIF(new.end_date <= old.cor_rommp_period_end_date, new.end_date, old.cor_rommp_period_end_date) -- trimmed end date
	)) AS duration
INTO #overlap
FROM [IDI_Sandpit].[DL-MAA2023-46].[def_COR_major_management_periods] AS new
INNER JOIN [IDI_Clean_202503].[cor_clean].[ra_ofndr_major_mgmt_period_a] AS old
ON new.snz_jus_uid = old.snz_jus_uid
AND new.mm_type = old.cor_rommp_directive_type
AND new.start_date <= old.cor_rommp_period_end_date
AND old.cor_rommp_period_start_date <= new.end_date
-- remove duplicate records
INNER JOIN (
	SELECT snz_uid, MAX([cor_rommp_max_period_nbr]) AS [cor_rommp_max_period_nbr]
	FROM [IDI_Clean_202503].[cor_clean].[ra_ofndr_major_mgmt_period_a]
	GROUP BY snz_uid
) AS b
ON old.snz_uid = b.snz_uid
AND old.[cor_rommp_max_period_nbr] = b.[cor_rommp_max_period_nbr]
WHERE IIF(new.end_date <= old.cor_rommp_period_end_date, new.end_date, old.cor_rommp_period_end_date) <= GETDATE()
AND YEAR(new.start_date) BETWEEN 2000 AND 2020
GROUP BY YEAR(new.start_date)
	,CASE
		WHEN old.cor_rommp_directive_type IN ('HD_REL', 'HD_SENT') THEN 'HD'
		WHEN old.cor_rommp_directive_type = 'ELECTRONICALLY MONITORED BAIL' THEN 'REMAND'
		WHEN old.cor_rommp_directive_type = 'EXTENDED SUPERVISION ORDER (INTERIM)' THEN 'EXTENDED SUPERVISION ORDER'
		ELSE old.cor_rommp_directive_type END

-- combine for ease of comparison
SELECT COALESCE(a.start_year, b.start_year, c.start_year) AS start_year
	,COALESCE(a.cor_mmp_mmc_code, c.cor_mmp_mmc_code, b.mm_type) AS code
	,a.num_records AS old_records
	,a.num_people AS old_people
	,a.duration AS old_duration
	,b.num_records AS new_records
	,b.num_people AS new_peole
	,b.duration AS new_duration
	,c.num_records AS match_records
	,c.num_people AS match_people
	,c.duration AS match_duration
FROM #old AS a
FULL OUTER JOIN #new AS b
ON a.start_year = b.start_year
AND a.cor_mmp_mmc_code = b.mm_type
FULL OUTER JOIN #overlap AS c
ON a.start_year = c.start_year
AND a.cor_mmp_mmc_code = c.cor_mmp_mmc_code
WHERE a.cor_mmp_mmc_code NOT IN ('ALIVE', 'AGED_OUT')
*/

