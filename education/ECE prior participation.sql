/**************************************************************************************************
Title: Early Childhood Education Prior Participation
Author: Charlotte Rose

Inputs & Dependencies:
	[IDI_Clean_202406].[moe_clean].[ece_duration]
	[IDI_Metadata_202406].[moe_school].[ece_classif23_code]
	[IDI_Metadata_202406].[moe_school].[ece_duration23_code]
	[IDI_Clean_202406].[moe_clean].[student_enrol]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-55].[defn_ece_prior_participation]

Description:
	ECE participation in the six months prior to starting school for children who turned 5
	For identifying children (who turned five in the 12 months prior to the end of the yr) who attended any ECE prior to starting school.

Notes: 
1)The benefit of this code is that the ECE_duration table includes Kohanga Reo attendance
	where ELI does not (currently, Kohanga Reo turst have said they will begin providing data for ELI ~October 2024)
2) Option to also break down into categories of type of ECE or how many years ECE was attended
3) Checks against published MOE participation figures shows ~99% agreement.
	Example of published MOE numbers:
		Qtr	   | Attended | Did not attend | Unknown |
		----------------------------------------------
		2021Q1 |    57233 |          1900  |    1943 |
		2022Q1 |    55093 |          1749  |    1921 |
		2023Q1 |    55756 |          2559  |    2334 |
		2024Q1 |    55063 |          2552  |    2564 |
4) Some children have the ECE classification as 'did not attend' or 'unknown', but have an ECE duration.
	However for the whole ece_duration dataset this is a very small % of cases 
	and none have hours listed, so these have still been counted as 'did not attend' or 'unkonwn'
5) Some children attend more than one type of ECE. When this occurs, the different ECE type and hours are recorded seperately.
	So summing across events is required to produce total hours attended.
6) Regarding entity counts: The data from [ece_duration] is collected from a form that the parents fill out.
	This information is not collected direct from ECEs, but surveyed from parents.
	This means the information will be incompelte due to imperfect recall.
	It also means that this information may combine multiple ECEs for the same child.
	It also means that entity counts for this data do not exist / apply.

Parameters & Present values:
  Current refresh = 202406
  Prefix = _
  Project schema = [DL-MAA2023-55]

Issues:
- Data appears to be complete only from 2011

History (reverse order)
2024-07-29 CRose: version 1
**************************************************************************************************/

-- Education: ECE participation prior to starting school

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-55].[defn_ece_prior_participation]

SELECT a.[snz_uid]
    , a.[snz_moe_uid]
    , MIN(c.moe_esi_start_date) AS date --  first started school i.e. the approx date the data was collected
    , b.[ECEClassification]
    , CASE WHEN b.ECEClassificationID = 20630 THEN 'NA' -- Not did not attend
			WHEN b.ECEClassificationID = 20637 THEN 'Unknown' -- Unknown attendance
			WHEN d.ECEDuration IS NULL THEN 'Duration NOT specified' 
			ELSE d.ECEDuration END AS ECEDuration
    , CASE WHEN b.ECEClassificationID = 20630 THEN 0.00 -- Not did not attend
			WHEN b.ECEClassificationID = 20637 
			OR a.moe_sed_hours_nbr IS NULL THEN -99.00 -- Unknown attendance/unknown hours 
			ELSE a.moe_sed_hours_nbr 
			END AS average_weekly_hours_attended
INTO [IDI_Sandpit].[DL-MAA2023-55].[defn_ece_prior_participation]
FROM [IDI_Clean_202406].[moe_clean].[ece_duration] a
LEFT JOIN [IDI_Metadata_202406].[moe_school].[ece_classif23_code] b
ON b.ECEClassificationID = A.moe_sed_ece_classification_code
LEFT JOIN [IDI_Metadata_202406].[moe_school].[ece_duration23_code] d
ON d.ECEDurationID = a.moe_sed_ece_duration_code
INNER JOIN [IDI_Clean_202406].[moe_clean].[student_enrol] c
ON a.snz_uid = c.snz_uid
GROUP BY a.[snz_uid]
    , a.[snz_moe_uid]
    , a.[moe_sed_snz_unique_nbr]
    , a.[moe_sed_extrtn_date]
    , b.[ECEClassification] -- one row for each type of ECE attended
    , b.ECEClassificationID
    , d.ECEDuration
    , a.moe_sed_hours_nbr
