/**************************************************************************************************
Title: Parent/caregiver-child realationships
Author: Charlotte Rose
Peer review 2025: Penny Mok
Peer review 2026 additions: Simon Anastasiadis

Inputs & Dependencies:

- [IDI_Clean_$(REFRESH)].[data].[personal_detail]
- [IDI_Clean_$(REFRESH)].[dia_clean].[marriages]
- [IDI_Clean_$(REFRESH)].[dia_clean].[civil_unions]
- [IDI_Clean_$(REFRESH)].[msd_clean].[msd_child]
- [IDI_Clean_$(REFRESH)].[msd_clean].[msd_partner]
- [IDI_Clean_$(REFRESH)].[wff_clean].[fam_children]
- [IDI_Clean_$(REFRESH)].[wff_clean].[fam_return_parents]

Outputs:

- [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)]

Description:

This script links people across child and parent/caregiver type relationships

The table looks at an individuals birth parents, birth parents' spouses and partners as well as any caregivers registered with MSD or WFF.

Intended purpose:

This table is intended to be used as a reference for indicators related to 'parents' i.e parent incarcerated, parental income, parent on benefit etc.
By including step-parents and caregivers we will get greater coverage of a child's whanau and current living situation than by using birth parents alone.

Notes:
1) Because the DIA data has inconsistant use of end dates, we use imputed proxy end dates for former marriages.
	This assumes someone can only have one partner at a time which seems reasonable.

2) Some parents have NULL end dates on marriages/civil unions (to people other than the other birth parent) 
	which occurred prior to the childs birth (with no subsequent marriage/civil union). 
	This may be true in edge cases, where is child is born to a partner who is not the spouse, however the 
	decision has been made to ensure marriage/civil union (to people other than the other birth parent) 
	start dates occur after a childs birth. It was found reasonable to assume that these spouses would be
	most likely to be in the role of 'step parent'.
	We also worked on the assumption that in the cases of donor and surrogate births, the 'intended' parents
	are likely going to be recorded with DIA in birth records rather than the donor/surrogate.

3) Some children many different parents/caregivers across their lifetimes. These children appear to
	be those who have had at least some involvement with Oranga Tamariki. 

4) Relationships are in spell format, start dates are the first record of the relationship, and end dates are
	either at the last record, the childs 18th birthday if they are now an adult, or left open. 
	Birth parents are always included as we have no way of knowing custody agreements etc. Any sole parent indicators
	must cross reference with other indications of singularity. 
	Future work could cross reference court ruling from OT data around custody.

5) End dates of '9999-12-31' are considered current

6) There will be cases where the birth parent is only listed as a partner for example: their partner is on a a benefit
	but they are not. For this reason, each relationship is queried both ways, looking at the birth parent as either
	the 'primary' person i.e. MSD benefit receipient and the partner
	of the 'primary' person, to ensure full coverage.
	
	
Parameters & Present values:
  Current refresh = $(REFRESH)
  Prefix = defn_
  Project schema = MAA2023-46

 
Issues: 

1) WFF start and end dates fall accross 5 different potential columns and as at Aug 2025 there was no clear indication
	of which was 'most valid'. The timestamp date is always filled so it is used as a fall back where the others are null.
	This is described in code comments when it occurs

2) We take the earliest start and latest end dates for DIA, MSD, and WFF. This means that there can be cases where administrative data
	shows a gap in connection between a child and adult but our resulting table shows no gap. For example, suppose Alice has Bob recorded
	as a dependent in MSD data in 2020 and in 2025, but not in 2021-2024. Our current method will report a relationship between Alice
	and Bob from 2020 to 2025.
	This approach is used because we seek to capture enduring relationships between children and caregivers, and it is reasonable to
	assume that relationships persist even if they are not observed in administrative records.
	One consequence of this is that children who shift between various caregivers over a long period may appear to have large numbers
	of concurrent caregivers.

3) Because people can be registered as a parent or caregiver across multiple agencies, there may be some parents with multiple relationship
	spells i.e. step-parents and caregivers. Future work could rank and merge these spells but in the interest of time and 
	taking into account current use cases, multiple rows of different spell types for the same parent/caregiver have been left in.

4) There are cases where dates are unreasonable e.g. parent died before birth, MSD start dates are before birth etc. these have been
	filtered out or otherwise controlled for.

History (reverse order):
2026-03-05 - CR Redesign
2026-03-04 - CR Added WFF partners & tidied
2026-02-27 - WL Added MSD partners
2025-08-11 - CR 
**************************************************************************************************/

-- :SETVAR PROJECT_DB "SIA_Sandpit"
-- :SETVAR PROJECT_SCHEMA "DL-MAA2026-04"
-- :SETVAR REFRESH "202603"

/****** NOTE:  Cross apply clauses are taking the MAX or the MIN accross a number of columns, we do this in the WFF data and in the final tidy up to make sure deaths end relationships
				This is essentially a LEAST type clause *****/


/***************************Children and Parents****************************/

DROP TABLE IF EXISTS #children

---list of people with parents (called 'children' but not nessesarily of child age in 2026, however including everyone allows for time series analysis)---

;WITH birthparents AS (

SELECT p.snz_uid
	, p.snz_birth_date_proxy
	, DATEFROMPARTS(p.snz_deceased_year_nbr,p.snz_deceased_month_nbr,15) AS death_date_proxy -- for use later when tidying end dates
	, p.snz_parent1_uid AS birth_parent
	, p.snz_parent2_uid AS birth_parent2
FROM [IDI_Clean_$(REFRESH)].[data].[personal_detail] p
LEFT JOIN [IDI_Clean_$(REFRESH)].[data].[personal_detail] p1 -- parent's details - left join to pick up people with no birth parents, but a caregiver down the line
ON p1.snz_uid = p.snz_parent1_uid 
AND p1.snz_spine_ind = 1 -- parent is on the spine
AND p1.snz_person_ind = 1 -- parent is a person

UNION 

SELECT p.snz_uid
	, p.snz_birth_date_proxy
	, DATEFROMPARTS(p.snz_deceased_year_nbr,p.snz_deceased_month_nbr,15) AS death_date_proxy
	, p.snz_parent2_uid AS birth_parent
	, p.snz_parent1_uid AS birth_parent2
FROM [IDI_Clean_$(REFRESH)].[data].[personal_detail] p
LEFT JOIN [IDI_Clean_$(REFRESH)].[data].[personal_detail] p1 -- parent's details
ON p1.snz_uid = p.snz_parent2_uid 
AND p1.snz_spine_ind = 1 -- parent is on the spine
AND p1.snz_person_ind = 1 -- parent is a person

)

SELECT c.snz_uid
	, c.snz_birth_date_proxy
	, c.death_date_proxy
	, c.birth_parent
	, c.birth_parent2
INTO #children
FROM birthparents c
INNER JOIN [IDI_Clean_$(REFRESH)].[data].[personal_detail] p
ON c.snz_uid = p.snz_uid
AND p.snz_spine_ind = 1 -- child is on the spine
AND p.snz_person_ind = 1 -- child is a person
AND (c.birth_parent <> c.birth_parent2 OR c.birth_parent IS NULL OR c.birth_parent2 IS NULL)


CREATE NONCLUSTERED INDEX snz_uid ON #children (snz_uid)
GO


/***************************Final table creation****************************/

DROP TABLE IF EXISTS [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)]

CREATE TABLE [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)] (
	snz_uid INT
	, snz_birth_date_proxy DATE
	, death_date_proxy DATE
	, snz_associated_uid INT
	, start_date DATE
	, end_date DATE
	, source VARCHAR(7)
	, relationship VARCHAR(12)
)

-- compress table at creation before filling
ALTER TABLE [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)

/***************************Get max WFF dates****************************/


SELECT MAX(wff_ftc_timestamp_date) AS max_date
INTO #maxwff
FROM [IDI_Clean_$(REFRESH)].[wff_clean].[fam_tax_credits]
WHERE wff_ftc_timestamp_date < GETDATE()


SELECT MAX(wff_chi_timestamp_date) AS max_date
INTO #maxwfc
FROM [IDI_Clean_$(REFRESH)].[wff_clean].[fam_children]
WHERE wff_chi_timestamp_date < GETDATE()
	
/***************************Parent/caregiver links****************************/ 

--Birth parents--

INSERT INTO [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)]
SELECT DISTINCT c.snz_uid
	, c.snz_birth_date_proxy
	, c.death_date_proxy
	, c.birth_parent AS snz_associated_uid
	, c.snz_birth_date_proxy AS start_date
	, '9999-12-31' AS end_date
	, 'DIA-BIR' AS source
	, CASE WHEN p.snz_sex_gender_code = 2 THEN 'birth_mother'
		WHEN p.snz_sex_gender_code = 1 THEN 'birth_father'
		WHEN p.snz_sex_gender_code NOT IN (1,2) THEN 'birth_parent'
		ELSE NULL
		END AS relationship
FROM #children c 
INNER JOIN [IDI_Clean_$(REFRESH)].[data].[personal_detail] p
ON c.birth_parent = p.snz_uid -- parent's details for sex/gender

/***************************Step parent by marriage set up****************************/

--Dealing with complexity of missing end dates where subsequent marriages exist

DROP TABLE IF EXISTS #DIA

;WITH partners as (

	SELECT DISTINCT m.partnr1_snz_uid
	, m.partnr2_snz_uid
	, m.dia_mar_marriage_date AS start_date
	, m.dia_mar_disolv_order_date AS end_date
	FROM [IDI_Clean_$(REFRESH)].[dia_clean].[marriages] m
	WHERE m.dia_mar_marriage_date > '1940-12-31' -- trimming to reasonable times

	UNION

	SELECT DISTINCT c.partnr1_snz_uid
	, c.partnr2_snz_uid
	, c.dia_civ_civil_union_date AS start_date
	, c.dia_civ_disolv_order_date AS end_date
	FROM [IDI_Clean_$(REFRESH)].[dia_clean].[civil_unions] c
	WHERE c.dia_civ_civil_union_date > '1940-12-31'

)
SELECT partnr1_snz_uid
	,partnr2_snz_uid
	, start_date
	, COALESCE(end_date, DATEADD(DAY,-1,LEAD(start_date) OVER (PARTITION BY partnr1_snz_uid ORDER BY start_date))) AS end_date
INTO #DIA
FROM partners 

UNION 

SELECT partnr2_snz_uid AS partnr1_snz_uid
	, partnr1_snz_uid AS partnr2_snz_uid
	, start_date
	, COALESCE(end_date, DATEADD(DAY,-1,LEAD(start_date) OVER (PARTITION BY partnr2_snz_uid ORDER BY start_date))) AS end_date
FROM partners 

CREATE NONCLUSTERED INDEX snz_uid ON #DIA (partnr1_snz_uid)

-------------------------------------------------Parents spouses---------------------------------------------

INSERT INTO [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)]
SELECT DISTINCT c.snz_uid
	, c.snz_birth_date_proxy
	, c.death_date_proxy
	, d.partnr1_snz_uid AS snz_associated_uid
	, d.start_date as start_date
	, COALESCE(d.end_date,'9999-12-31') AS end_date -- divorce or current
	, 'DIA-MAR' AS source
	, 'step-parent' AS relationship
FROM #children c
INNER JOIN #DIA d
ON c.birth_parent = d.partnr2_snz_uid -- joining parent


------------------------------------------------Parents MSD partners---------------------------------------------

;WITH msd AS (
	SELECT msd.snz_uid
		, msd.partner_snz_uid
		, msd.msd_ptnr_ptnr_from_date
		, msd.msd_ptnr_ptnr_to_date
	FROM [IDI_Clean_$(REFRESH)].[msd_clean].[msd_partner] msd

	UNION 

	SELECT msd.partner_snz_uid AS snz_uid
		, msd.snz_uid AS partner_snz_uid
		, msd.msd_ptnr_ptnr_from_date
		, msd.msd_ptnr_ptnr_to_date
	FROM [IDI_Clean_$(REFRESH)].[msd_clean].[msd_partner] msd
)
--step-parent as partner--
INSERT INTO [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)]
SELECT c.snz_uid AS snz_uid
	, c.snz_birth_date_proxy
	, c.death_date_proxy
	, msd.partner_snz_uid AS snz_associated_uid
	, MIN(msd_ptnr_ptnr_from_date) AS start_date --earliest record of relationship
	, COALESCE(MAX(msd_ptnr_ptnr_to_date),'9999-12-31') AS end_date --current or last record of relationship
	, 'MSD-PRT' as source
	, 'step-parent' AS relationship
FROM #children c
INNER JOIN msd -- MSD partners
ON c.birth_parent = msd.snz_uid -- joining parent
GROUP BY c.snz_uid
	, c.snz_birth_date_proxy
	, c.death_date_proxy
	, msd.partner_snz_uid

------------------------------------------------IRD partners---------------------------------------------

;WITH wff AS (
	SELECT wff.snz_uid
		, wff.partner_snz_uid
		, wff.wff_frp_start_date
		, wff.wff_frp_end_date
		, wff.wff_frp_return_period_date
	FROM [IDI_Clean_$(REFRESH)].[wff_clean].[fam_return_parents] wff
	WHERE wff.partner_snz_uid > 0 --missing is recorded as '-11'

	UNION 

	SELECT wff.partner_snz_uid
		, wff.snz_uid
		, wff.wff_frp_start_date
		, wff.wff_frp_end_date
		, wff.wff_frp_return_period_date
	FROM [IDI_Clean_$(REFRESH)].[wff_clean].[fam_return_parents] wff
	WHERE wff.partner_snz_uid > 0
)
INSERT INTO [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)]
SELECT DISTINCT c.snz_uid AS snz_uid
	, c.snz_birth_date_proxy
	, c.death_date_proxy
	, wff.partner_snz_uid AS snz_associated_uid
	, MIN(wff_frp_start_date) AS start_date
	, IIF(x.earliest_end_date = (SELECT TOP 1 max_date FROM #maxwfc),'9999-12-31', x.earliest_end_date) AS end_date --current or last record of relationship
	, 'WFF-PRT' AS source
	, 'step-parent' AS relationship
FROM #children c 
INNER JOIN [IDI_Clean_$(REFRESH)].[wff_clean].[fam_return_parents] wff -- WFF partners
ON c.birth_parent = wff.snz_uid -- joining parent
CROSS APPLY (
	SELECT MAX(d) AS earliest_end_date -- finding best end dates
	FROM (
		VALUES (NULLIF(wff_frp_end_date, '9999-12-31'))
		, (wff.wff_frp_return_period_date)
		, ((SELECT TOP 1 max_date FROM #maxwff))
	) AS v(d)
) x
GROUP BY c.snz_uid
	, c.snz_birth_date_proxy
	, c.death_date_proxy
	, wff.partner_snz_uid
	, x.earliest_end_date


------------------------------------------------MSD caregivers---------------------------------------------

INSERT INTO [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)]
SELECT DISTINCT c.snz_uid AS snz_uid
	, c.snz_birth_date_proxy
	, c.death_date_proxy
	, msd.snz_uid AS snz_associated_uid
	, MIN(msd_chld_child_from_date) AS start_date
	, COALESCE(MAX(msd_chld_child_to_date),'9999-12-31') AS end_date --current or last record of relationship
	, 'MSD-CRG' AS source
	, 'caregiver'AS relationship
FROM #children c
INNER JOIN [IDI_Clean_$(REFRESH)].[msd_clean].[msd_child] msd -- MSD child
ON c.snz_uid = msd.child_snz_uid
GROUP BY c.snz_uid
	, c.snz_birth_date_proxy
	, c.death_date_proxy
	, msd.snz_uid

------------------------------------------------WFF caregivers---------------------------------------------

INSERT INTO [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)]
SELECT DISTINCT c.snz_uid AS snz_uid
	, c.snz_birth_date_proxy
	, c.death_date_proxy
	, wfc.snz_uid AS snz_associated_uid
	, MIN(wfc.wff_chi_timestamp_date) as start_date
	, IIF(x.earliest_end_date = (SELECT TOP 1 max_date FROM #maxwfc),'9999-12-31', x.earliest_end_date) AS end_date
	, 'WFF-CRG'as source
	, 'caregiver' AS relationship
FROM #children c
INNER JOIN [IDI_Clean_$(REFRESH)].[wff_clean].[fam_children] wfc-- WFF child
ON c.snz_uid = wfc.child_snz_uid
CROSS APPLY (
	SELECT MAX(d) AS earliest_end_date -- finding best end dates
	FROM (
		VALUES
			(NULLIF(wfc.wff_chi_end_date, '9999-12-31'))	
			,(NULLIF(wfc.wff_chi_ceased_date, '9999-12-31'))
			,((SELECT TOP 1 max_date FROM #maxwfc))
	) AS v(d)
) x
GROUP BY c.snz_uid
	, c.snz_birth_date_proxy
	, c.death_date_proxy
	, wfc.snz_uid
	, x.earliest_end_date

------------------------------Final table creation with sanity checks and clean end date------------------

--- Deleting cargivers where they are the birth parent ---

DELETE c 
FROM [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)] AS c
INNER JOIN #children AS ch
ON c.snz_uid = ch.snz_uid
WHERE c.source <> 'DIA-BIR'
AND (c.snz_associated_uid = ch.birth_parent
OR c.snz_associated_uid = ch.birth_parent2) 

--- Sense checks on parents and caregivers---

DELETE c
FROM [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)] AS c
LEFT JOIN [IDI_Clean_$(REFRESH)].[data].[personal_detail] AS p
ON p.snz_uid = c.snz_associated_uid
WHERE DATEFROMPARTS(p.snz_deceased_year_nbr,p.snz_deceased_month_nbr,15) < DATEADD(DAY,-1,c.snz_birth_date_proxy) --parent or cargiver must be alive when child is born
OR c.end_date < c.snz_birth_date_proxy -- relationship must be active during childhood
OR c.start_date > DATEADD(YEAR,18,c.snz_birth_date_proxy)
OR p.snz_spine_ind <> 1
OR p.snz_person_ind <> 1
OR p.snz_uid IS NULL --not in personal details at all i.e. dummy numbers

--Tidying dates---

; WITH tidy_dates AS (

	SELECT c.snz_uid
		, c.snz_associated_uid
		, c.start_date
		, c.end_date
		, c.source
		, IIF(c.start_date < c.snz_birth_date_proxy, c.snz_birth_date_proxy, c.start_date) latest_start_date
		, x.earliest_end_date
	FROM [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)] c
	INNER JOIN [IDI_Clean_$(REFRESH)].[data].[personal_detail] p
	ON p.snz_uid = c.snz_associated_uid
	CROSS APPLY (
		SELECT MIN(d) AS earliest_end_date
		FROM (
			VALUES
				(c.end_date) -- spell end
				,(c.death_date_proxy) -- childs death
				,(IIF(DATEADD(YEAR,18,c.snz_birth_date_proxy) > GETDATE(), '9999-12-31',DATEADD(YEAR,18,c.snz_birth_date_proxy))) -- leave spell open if still a child, close if adult
				,(DATEFROMPARTS(p.snz_deceased_year_nbr,p.snz_deceased_month_nbr,15)) -- parent/ caregiver death
		) AS v(d)
	) x

)
UPDATE [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)]
SET start_date = x.latest_start_date
	, end_date = x.earliest_end_date
FROM [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)] AS c
INNER JOIN tidy_dates AS x
ON c.snz_uid = x.snz_uid
AND c.snz_associated_uid = x.snz_associated_uid
AND c.start_date = x.start_date
AND c.end_date = x.end_date
AND c.source = x.source


ALTER TABLE [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)]
DROP COLUMN death_date_proxy

-- Removing duplicates --

;WITH dups AS (
	SELECT *
		, ROW_NUMBER() OVER (
			PARTITION BY snz_uid, snz_birth_date_proxy, snz_associated_uid, start_date, end_date, source, relationship
			ORDER BY(SELECT NULL)
			) as rn
	FROM [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)]
)
DELETE c
FROM [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)] c
INNER JOIN dups b
ON b.snz_uid = c.snz_uid
AND b.rn > 1

-- Index --

CREATE NONCLUSTERED INDEX child_uid ON [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)]  (snz_uid, snz_associated_uid)
GO

CREATE NONCLUSTERED INDEX parent_uid ON [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[defn_child_parent_$(REFRESH)]  (snz_associated_uid, snz_uid)
GO

--Tidy up--

DROP TABLE IF EXISTS #children
DROP TABLE IF EXISTS #DIA

	 

