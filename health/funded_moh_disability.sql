/**************************************************************************************************
Title: Recent funded MOH disability client
Author: Craig Wright

Acknowledgements:
Informatics for Social Services and Wellbeing (terourou.org) supported the publishing of these definitions

Disclaimer:
The definitions provided in this library were determined by the Social Wellbeing Agency to be suitable in the 
context of a specific project. Whether or not these definitions are suitable for other projects depends on the 
context of those projects. Researchers using definitions from this library will need to determine for themselves 
to what extent the definitions provided here are suitable for reuse in their projects. While the Agency provides 
this library as a resource to support IDI research, it provides no guarantee that these definitions are fit for reuse.

Citation:
Social Wellbeing Agency. Definitions library. Source code. https://github.com/nz-social-wellbeing-agency/definitions_library

Description:
Recent funded MOH disability client in SOCRATES

Intended purpose:
Identifying people receiving funding via SOCRATES (MOH) for a disability.

## Purpose of the MOH Funded Disability indicator:
This code defines spells where clients are eligible to receive MoH disability funding.  It is based on having a needs assessment done by a Needs Assessment and Service Coordination (NASC) provider where the outcome was “Requires Service Coordination” (see www.health.govt.nz/your-health/services-and-support/disability-services/getting-support-disability/needs-assessment-and-service-coordination-services).
Note that this does not mean that the client actually received any services, it simply means that they were assessed as being eligible.  

## Key concepts
Access to MoH Disability funding is managed via service needs assessments that are facilitated by NASC organizations that are contracted by Disability Support Services, Ministry of Health.  
Full details can be found here:
www.health.govt.nz/your-health/services-and-support/disability-services/getting-support-disability/needs-assessment-and-service-coordination-services
The Ministry funds services for people with a physical, intellectual and/or sensory impairment or disability that is:
•	Likely to continue for a minimum of 6 months
•	Reduces your ability to function independently, to the extent that ongoing support is required.
In addition, a person with Autism Spectrum Disorder may also be eligible for a needs assessment.  These are usually for people under the age of 65.  Disability support services for people with mental health needs are generally funded by DHBs.    
Before a needs assessment can take place the clients need a written referral (e.g. by GPs, Family, DHBs, service providers or self-referrals). 
A service needs assessment has a DateAssessmentCompleted and ReassessmentRequestedDate which count as the start and end date of a spell.  A spell will often last for 3 years, however, shorter spells are possible. 

## Practical notes
There are some issues with the data:
•	This indicator is only reliable from 01/01/2008 to 31/03/2021.  It is likely that the end date of the reliable period will extend as the data is updated.
•	The AssessmentOutcome is only reliable after 2008, before that the outcome is usually “Migrated by Socrates Project”.  The assessments themselves go back to the early 2000’s.  Currently the data only includes up to assessments up to 31/03/2021.  
•	There are some payments that happen outside the spell period defined by the DateAssessmentCompleted and ReassessmentRequestedDate.  Including people who are getting support outside a spell changes the total count of clients eligible at any given time by 1 to 2 percentage. 
•	The data includes a flag for CurrentNA, which indicates the most recent needs assessment.  However, the CurrentNA maybe up to 20 years old. 
•	There may be a bias towards clients who live in poorer regions because anecdotally those who have sufficient income to manage their disability without requiring MOH support are less likely to engage with the system. 
Note that this DOES NOT mean:
•	The client actually received funding for the whole spell
•	The client actually received funding at all during the spell
•	These clients (or other clients) didn't receive funding from other sources.  This could be indirectly from MoH too (e.g. via DHBs) 
•	The list includes all the clients who were eligible since it only includes those who went through a needs assessment 

## References and contacts
The Ministry of Health publishes statistics on disability support funding approximately every 3 years (e.g. www.health.govt.nz/system/files/documents/publications/demographic-report-for-client-allocated-ministry-of-health-disability-support-services-2018-update14nov2019.pdf).  This includes a total number of Disability Support Services for 2018 of 38,342 (1 Oct 2017 to 30 Sept 2018) and is a publicly available number from outside of the IDI.  The equivalent count from the indicator is of the order of 38,000 and within 100 of the published count (based on those that have a spell that includes either 1 Oct 2017 or 30 Sept 2018).   

## Module business rules
### Key rules applied
A service needs assessment has a DateAssessmentCompleted and ReassessmentRequestedDate which count as the start and end date of a spell.  A spell will often last for 3 years, however, shorter spells are possible.   
Only assessments with an outcome of “Requires Service Coordination” are included.  Other options include “No Action Required - Exit Services” and “Eligible for Service but No Action Required”.
The start date of the spell is the DateAssessmentCompleted from the service needs assessment.
The end date of the spell is the ReassessmentRequestedDate from the service needs assessment.
Spells that have less than 60 days between the end of one spell and the start of the next are merged (i.e. they count as a continuous spell in the final dataset). 

## Parameters
The following parameters should be supplied to this module to run it in the database:
1. {idicleanversion}: The IDI Clean version that the spell datasets need to be based on.
2. {targetschema}: The project schema under the target database into which the spell datasets are to be created.
3. {projprefix}: A (short) prefix that enables you to identify the spell dataset easily in the schema, and prevent overwriting any existing datasets that have the same name.
4. IDI_UserCode: The SQL database on which the spell datasets are to be created. 

Inputs & Dependencies:
- [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_needs_assessment_202110]
- [IDI_Clean].[security].[concordance]
Outputs:
- [IDI_Sandpit].[DL-MAA20XX-YY].[defn_moh_dis_assess_elig]


Linking between the two is done on snz_moh_uid.  No rows are lost via this linking.


## Variable Descriptions

Column name                     Description
------------------------------ --------------------------------------------------------------------------------------------
snz_uid                        The unique STATSNZ person identifier for the student 
snz_moh_uid                    The unique STATSNZ MOH person identifier for the disabled
start_date				       The start date of the spell (the DateAssessmentCompleted from the needs assessment)
end_date					   The end date of the spell (the ReassessmentRequestedDate from the needs assessment)


Parameters & Present values:
  Current refresh = YYYYMM
  Prefix = defn_
  Project schema = DL-MAA20XX-YY
 

History (reverse order):
2022-06-01 Consultant version
2021-10-31 CW v1

**************************************************************************************************/

/* Assign the target database to which all the components need to be created in. */
USE IDI_Sandpit;
GO

/* Delete the database object if it already exists */
DROP TABLE IF EXISTS [DL-MAA20XX-YY].tmp_moh_dis_assess_elig;
GO

/* Create the database object */
SELECT b.snz_uid
	,a.snz_moh_uid
	,CASE
		WHEN SUBSTRING(a.DateAssessmentCompleted,6,1) = '9' THEN CONVERT(date,CONCAT(SUBSTRING(a.DateAssessmentCompleted,1,2),' ',SUBSTRING(a.DateAssessmentCompleted,3,3),' 19',SUBSTRING(a.DateAssessmentCompleted,6,2)),106) 
		ELSE CONVERT(date,CONCAT(SUBSTRING(a.DateAssessmentCompleted,1,2),' ',SUBSTRING(a.DateAssessmentCompleted,3,3),' 20',SUBSTRING(a.DateAssessmentCompleted,6,2)),106) 
	 END AS [start_date]
	,CASE
		WHEN SUBSTRING(a.ReassessmentRequestDate,6,1) = '9' THEN CONVERT(date,CONCAT(SUBSTRING(a.ReassessmentRequestDate,1,2),' ',SUBSTRING(a.ReassessmentRequestDate,3,3),' 19',SUBSTRING(a.ReassessmentRequestDate,6,2)),106) 
		ELSE CONVERT(date,CONCAT(SUBSTRING(a.ReassessmentRequestDate,1,2),' ',SUBSTRING(a.ReassessmentRequestDate,3,3),SUBSTRING(a.ReassessmentRequestDate,6,2)),106) 
	END AS [end_date]
INTO [DL-MAA20XX-YY].tmp_moh_dis_assess_elig
FROM [IDI_Adhoc].[clean_read_MOH_SOCRATES].[moh_needs_assessment] AS a
INNER JOIN [IDI_Clean_202203].[security].[concordance] AS b
ON a.snz_moh_uid = b.snz_moh_uid
WHERE a.assessmentoutcome in ('Requires Service Coordination')

GO

-- Consolidate spells that are near each other into a smaller number of spells
DROP TABLE IF EXISTS [DL-MAA20XX-YY].defn_moh_dis_assess_elig;
GO

WITH
/* start dates that are not within another spell */
input_data AS (
	SELECT [snz_uid]
		,[start_date]
		/* Adds a 60 day threshold between each assessment so that any consecutive assessment made within 60 day thresholds can be joined up together into a single spell. */
		,DATEADD(day, 60, [end_date]) AS [end_date] 
	FROM [DL-MAA20XX-YY].tmp_moh_dis_assess_elig
	GROUP BY snz_uid, [start_date], [end_date]
),

spell_starts AS (
	SELECT [snz_uid]
 	    ,[start_date]
		 ,[end_date]
	FROM input_data AS s1
	WHERE NOT EXISTS (
		SELECT 1
		FROM input_data AS s2
		WHERE s1.snz_uid = s2.snz_uid
		AND s2.[start_date] < s1.[start_date]
		AND s1.[start_date] <= s2.[end_date]
	)
),

/* end dates that are not within another spell */
spell_ends AS (
	SELECT [snz_uid]
		,[start_date]
		,[end_date]
	FROM input_data AS t1
	WHERE NOT EXISTS (
		SELECT 1
		FROM input_data AS t2
		WHERE t2.snz_uid = t1.snz_uid
		AND t2.[start_date] <= t1.[end_date]
		AND t1.[end_date] < t2.[end_date]
	)
)

SELECT s.snz_uid
	,s.[start_date]
	,DATEADD(day, -60, min(e.[end_date])) AS [end_date]
INTO [DL-MAA20XX-YY].defn_moh_dis_assess_elig
FROM spell_starts s
INNER JOIN spell_ends e
ON s.snz_uid = e.snz_uid
AND s.[start_date] <= e.[end_date]
GROUP BY s.snz_uid, s.[start_date]

CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA20XX-YY].[defn_moh_dis_assess_elig] (snz_uid);
GO
ALTER TABLE [IDI_Sandpit].[DL-MAA20XX-YY].[defn_moh_dis_assess_elig] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
GO

/* Clean up any temporary tables or views */
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA20XX-YY].tmp_moh_dis_assess_elig;
GO
