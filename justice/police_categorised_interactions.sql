/**************************************************************************************************
Title: Categorised offenses and victimisations recorded by Police
Author: Simon Anastasiadis
Peer review:

Inputs & Dependencies:
- [IDI_Clean].[pol_clean].[pre_count_offenders]
- [IDI_Clean].[pol_clean].[pre_count_victimisations]
- offences_categorised.csv

Description:
Offences and victimisations as recorded by Police with flags for violence, non-violence,
alcohol, and drug offences.
For use provided more nuance about what kind of crime has occurred.


Notes:
- Original table used for classification is the metadata table:
	[IDI_Metadata_202506].[moj].[offence_code]
- Classification done by SIA staff based on ANZSOC code descriptions.
	Seriousness score, Offence typology description, and ANZSOC categories
	were used to guide the classification.
- Most alcohol events are drink driving related.
- There is some overlap between alcohol and drug events, so it may be worth considering a combined category.

Parameters & Present values:
  Current refresh = 202506
  Project schema = [DL-MAA2023-46]
 
Issues:
 
History (reverse order):
2025-03-14 SA
2024-11-12 CW original reference
**************************************************************************************************/

-------------------------------------------------
-- Load offence table
-------------------------------------------------

DROP TABLE IF EXISTS [SIA_Sandpit].[DL-MAA2023-46].[offence_categories]
GO

CREATE TABLE [SIA_Sandpit].[DL-MAA2023-46].[offence_categories] (
	OFFENCE_CODE VARCHAR(4)
	,OFFENCE_DESCRIPTION VARCHAR(250)
	,anzsoc VARCHAR(4)
	,anzsoc_group_code_name VARCHAR(250)
	,IS_DRIVING_UNDER_INFLUENCE_FLG CHAR(1)
	,violent TINYINT
	,alcohol TINYINT
	,drug TINYINT
)
GO

BULK INSERT [SIA_Sandpit].[DL-MAA2023-46].[offence_categories]
FROM '\\prtprdsasnas01\DataLab\MAA\MAA2023-46\projects\Test&Learn\01 Shared definitions\offences_categorised.csv'
WITH (
	FIRSTROW = 2,
	FORMAT = 'CSV'
)
GO

CREATE NONCLUSTERED INDEX i_code ON [SIA_Sandpit].[DL-MAA2023-46].[offence_categories] (OFFENCE_CODE)
GO

-------------------------------------------------
-- Offences and Victimisations
-------------------------------------------------

USE IDI_UserCode
GO

DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_police_offence_categorised_202506]
GO

CREATE VIEW [DL-MAA2023-46].[defn_police_offence_categorised_202506] AS
SELECT [snz_uid]
	,[snz_pol_occurrence_uid]
	,[snz_pol_offence_uid]

	,a.pol_pro_proceeding_date
	,a.pol_pro_offence_code
	,a.pol_pro_anzsoc_offence_code

	,b.IS_DRIVING_UNDER_INFLUENCE_FLG
	,b.violent
	,b.alcohol
	,b.drug
FROM [IDI_Clean_202506].[pol_clean].[pre_count_offenders] as a
INNER JOIN [SIA_Sandpit].[DL-MAA2023-46].[offence_categories] as b
ON a.pol_pro_offence_code = b.OFFENCE_CODE

GO


DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_police_victim_categorised_202506]
GO

CREATE VIEW [DL-MAA2023-46].[defn_police_victim_categorised_202506] AS
SELECT [snz_uid]
	,[snz_pol_occurrence_uid]
	,[snz_pol_offence_uid]

	,a.pol_prv_reported_date
	,a.pol_prv_offence_code
	,a.pol_prv_anzsoc_offence_code
	
	,b.IS_DRIVING_UNDER_INFLUENCE_FLG
	,b.violent
	,b.alcohol
	,b.drug
FROM [IDI_Clean_202506].[pol_clean].[pre_count_victimisations] as a
INNER JOIN [SIA_Sandpit].[DL-MAA2023-46].[offence_categories] as b
ON a.pol_prv_offence_code = b.OFFENCE_CODE		
GO
