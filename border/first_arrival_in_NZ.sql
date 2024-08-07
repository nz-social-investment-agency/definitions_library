/**************************************************************************************************
Title: First arrival in New Zealand
Author: Luke Scullion
Reviewer: Shaan Badenhorst

Superseded by Code Module: https://idcommons.discourse.group/pub/migration-spells

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
Best estimate of first arrival in New Zealand across sources.

Intended purpose:
When a person first entered NZ, how long a person has been in NZ.

Inputs & Dependencies:
- [IDI_Clean].[cen_clean].[census_individual_2018]
- [IDI_Clean].[cen_clean].[census_individual_2013]
- [IDI_Clean].[data].[person_overseas_spell]
Outputs:
- [IDI_UserCode].[DL-MAA20XX-YY].[vacc_Cen2018_Occupation]

Notes:
1) The definition synthesizes across Census 2018, Census 2013, and Overseas spells data.
2) May not accurately identify beginning of residence in NZ if a person visited
	New Zealand before migrating here.

Parameters & Present values:
  Current refresh = YYYYMM
  Prefix = vacc_
  Project schema = DL-MAA20XX-YY
 
Issues:

History (reverse order):
2021-11-10 SB review
2021-10-31 LC
**************************************************************************************************/

/*****************************
create table of all possible entries
*****************************/
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA20XX-YY].[tmp_NZ_arrival]
GO

CREATE TABLE [IDI_Sandpit].[DL-MAA20XX-YY].[tmp_NZ_arrival] (
	snz_uid INT,
	arrival_year INT,
	arrival_month INT,
);
GO

/* Census 2018 */
INSERT INTO [IDI_Sandpit].[DL-MAA20XX-YY].[tmp_NZ_arrival] (snz_uid, arrival_year, arrival_month)
SELECT snz_uid
	,CAST([cen_ind_arrv_in_nz_year_code] AS INT) AS arrival_year
	,CAST([cen_ind_arrv_in_nz_month_code] AS INT) AS arrival_month
FROM [IDI_Clean_YYYYMM].[cen_clean].[census_individual_2018]
WHERE snz_uid IS NOT NULL

/* Census 2013 */
INSERT INTO [IDI_Sandpit].[DL-MAA20XX-YY].[tmp_NZ_arrival] (snz_uid, arrival_year, arrival_month)
SELECT snz_uid
	,CAST([cen_ind_arrival_in_nz_yr_code] AS INT) AS arrival_year
	,CAST([cen_ind_arrival_in_nz_mnth_code] AS INT) AS arrival_month
FROM [IDI_Clean_YYYYMM].[cen_clean].[census_individual_2013]
WHERE snz_uid IS NOT NULL

/* Overseas spells */
INSERT INTO [IDI_Sandpit].[DL-MAA20XX-YY].[tmp_NZ_arrival] (snz_uid, arrival_year, arrival_month)
SELECT snz_uid
	,YEAR([pos_ceased_date]) AS arrival_year
	,MONTH([pos_ceased_date]) AS arrival_month
FROM [IDI_Clean_YYYYMM].[data].[person_overseas_spell]
WHERE [pos_first_arrival_ind] = 'y'
AND snz_uid IS NOT NULL

CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA20XX-YY].[tmp_NZ_arrival] (snz_uid);
GO

/*****************************
filter and conclude
*****************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA20XX-YY].[vacc_arrival_in_NZ];
GO

WITH tidied_variables AS (

	SELECT snz_uid
		,IIF(arrival_year >= 2025, NULL, arrival_year) AS arrival_year
		,IIF(arrival_month NOT IN (1,2,3,4,5,6,7,8,9,10,11,12), NULL, arrival_month) AS arrival_month
	FROM [IDI_Sandpit].[DL-MAA20XX-YY].[tmp_NZ_arrival]

)
SELECT snz_uid
	,MIN(arrival_year) AS arrival_year
	,MIN(arrival_month) AS arrival_month
INTO [IDI_Sandpit].[DL-MAA20XX-YY].[vacc_arrival_in_NZ]
FROM tidied_variables
GROUP BY snz_uid
GO

CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA20XX-YY].[vacc_arrival_in_NZ] (snz_uid);
GO


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA20XX-YY].[tmp_NZ_arrival]
GO
