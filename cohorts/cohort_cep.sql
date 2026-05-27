/*** Children of care experienced parents

This code builds a cohort that is the children of care experienced parents

It is comprised of the following steps:

(1) Identify people who have experienced care from the OT data
(2) Identify people who have one or more of the the care-experienced people as a parent
(3) Join this cohort onto the master table

A significant limitation with this is that the OT data only goes back to the early-mid 1990s. Theoretically, by 2023, the oldest person in the care-experienced group 
should be about 45, but most will be younger - much younger. That means that most care-experienced people will be far too young to have had children whose later life 
outcomes can be observed. 
-	For example, we have fewer than 500 children of care-experienced parents in the data, who are 25 years old or older in 2023.
-	However, we have relatively few observations of early life events for this group, as many datasets are only available from ~2010 onwards. This older cohort would 
	be aged 13 or older - ie, we could not observe things like (primary/intermediate) school attendance, ECE attendance, and so on. 

Of the possible indicators, NCEA level 3 at age 18 provided an approximately 85%-15% split (bad track-good track). This has been selected as
(1) it allows for later life observations of as many people as feasilbe;
(2) it is expected to be an indication of doing something, and is somewhat strengths based (achieving something, not avoiding a bad thing)
(3) it provides the approximate desired partition size of the group.

This is now created by a separate indicator in the master table

Note that there are still very few people who will be observed at 25 or older by the end of the data series, which raises potential issues about minimum counts, linkage 
errors, and extrapolating from very small numbers.

Assuming that the costs work suggests that this group experiences better outcomes in later life, further work would be needed to understand the differences between 
the group that gets this outcome, and those who do not (ie, what caused them to get here).

***/


/*** Step 1: Identify care-experienced people
We use the placement type code to identify who is care experienced, and who is not.
There are a small number of codes excluded, including YJ (commented out below). 
There are additional codes, on top of those below. The main ones of these are REG (regular payment - an 
administrative code either for caregivers who do not fit other categories, or to pay pocket money directly to rangatahi) and DPCY (detention 
in police custody - short term, generally less than 24 hours).

------UPDATE------

March 2026 - We have replaced our definition from the cyf_placements table with the Oranga Tamriki Placement spells code module to align with their deifnition of 'care'

This reducds the size of our cohort by about 14% for 202603 refresh


***/

-- :SETVAR PROJECT_DB "SIA_Sandpit"
-- :SETVAR PROJECT_SCHEMA "DL-MAA2026-04"
-- :SETVAR REFRESH "202603"

USE IDI_USERCODE;
GO

DROP VIEW IF EXISTS [$(PROJECT_SCHEMA)].[care_experienced];
GO

CREATE VIEW [$(PROJECT_SCHEMA)].[care_experienced] AS
SELECT a.snz_uid
	, MIN(a.from_date) AS first_placement_date
	, snz_birth_year_nbr
	, snz_sex_gender_code
FROM [IDI_Community].[chld_placement_spell].[placement_spell_$(REFRESH)] a 
LEFT JOIN [IDI_Clean_$(REFRESH)].[data].[personal_detail] pd
	ON a.snz_uid = pd.snz_uid
AND pd.snz_birth_date_proxy <= EOMONTH(a.from_date)
WHERE business_area_type = 'CNP'
GROUP BY a.snz_uid,pd.snz_birth_year_nbr, snz_sex_gender_code;
GO


/*** Step 2: identify people who have a care-experienced parent ***/
 -- Searching through personal details is **REALLY** slow, so we keep this as a table in order to create an index. We take the data we want, and index it to speed up the join. 
 -- This and the next step take about 15 minutes to run.
DROP TABLE IF EXISTS [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[parent_index];

SELECT pd.snz_uid
	,pd.snz_birth_year_nbr
	,pd.snz_birth_date_proxy
	,pd.snz_sex_gender_code
	,pd.snz_parent1_uid
	,pd.snz_parent2_uid
INTO [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[parent_index]
FROM [IDI_Clean_$(REFRESH)].[data].[personal_detail] pd
WHERE pd.snz_birth_date_proxy < GETDATE();

CREATE NONCLUSTERED INDEX parental_unit_1 ON [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[parent_index] (snz_parent1_uid);
CREATE NONCLUSTERED INDEX parental_unit_2 ON [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[parent_index] (snz_parent2_uid);
GO

-- Take our list of people with care experience and identify anyone who has them as a parent
DROP TABLE IF EXISTS [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[cohort_CEP_$(REFRESH)];
GO 


SELECT DISTINCT pd.snz_uid
		, pd.snz_birth_year_nbr
		, pd.snz_birth_date_proxy as cohort_start
		, DATEADD(YEAR,18,pd.snz_birth_date_proxy) as cohort_end
		, pd.snz_sex_gender_code
		, pd.snz_parent1_uid
		, pd.snz_parent2_uid
		, IIF(COALESCE(ce1.first_placement_date,'9999-01-01')<COALESCE(ce2.first_placement_date,'9999-01-01'),ce1.first_placement_date,ce2.first_placement_date) AS parent_first_in_care
INTO [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[cohort_CEP_$(REFRESH)]
FROM [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[parent_index] pd
LEFT JOIN [$(PROJECT_SCHEMA)].[care_experienced] ce1 
	ON pd.snz_parent1_uid = ce1.snz_uid
LEFT JOIN [$(PROJECT_SCHEMA)].[care_experienced] ce2 
	ON pd.snz_parent2_uid = ce2.snz_uid
WHERE (ce1.snz_uid IS NOT NULL OR ce2.snz_uid IS NOT NULL)
	AND pd.snz_birth_year_nbr >= 1990  -- this is the childs birth year. Using 1990 as a floor to limit processing time (set age restrictions during summarisation)

DROP TABLE IF EXISTS [$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[parent_index]
DROP VIEW IF EXISTS [$(PROJECT_SCHEMA)].[care_experienced]

-- Compression
EXEC [IDI_UserCode].[$(PROJECT_SCHEMA)].[compress_table_$(PROJECT_DB)] @table = '[$(PROJECT_DB)].[$(PROJECT_SCHEMA)].[cohort_CEP_$(REFRESH)]'
