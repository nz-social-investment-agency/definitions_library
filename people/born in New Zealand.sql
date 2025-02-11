/**************************************************************************************************
Title: Country of Birth
Author: Craig Wright
Modified: P Mok

Acknowledgements:
Informatics for Social Services and Wellbeing (terourou.org) supported the publishing of these definitions

Inputs & Dependencies:
- [IDI_Clean].[cen_clean].[census_individual_2018]
- [IDI_Clean].[cen_clean].[census_individual_2013]
- [IDI_Clean].[dia_clean].[births]
- [IDI_Clean].[cus_clean].[journey]
- [IDI_Clean].[nzta_clean].[dlr_historic]
- [IDI_Clean].[nzta_clean].[drivers_licence_register]
- [IDI_Clean].[dol_clean].[movement_identities]
Outputs:
- [IDI_Sandpit].[DL-MAA2023-46].[2020403_born_in_NZ]

Description:
Country of birth

Intended purpose:
Supplement ethnicity and identity information by including Country of Birth (COB).

Notes:
1) Multiple sources contain COB information.
	Consistent with how SNZ makes the personal details table, the different sources
	are ranked and the highest quality source is kept.

2) The ranking of the sources are as follows (1 = best):
	1. census 2018
	2. census 2013
	3. DIA births - NZ birth
	4. CUS customs
	5. NZTA drivers license
	6. DOL

3) The codes that indicate born in New Zealand are:
	Census:			1201
	Customs:		 NZ
	DOL:			 NZ
	NZTA:		 NEW ZEALAND

Issues:

Parameters & Present values:
  Current refresh = 202403
  Prefix = defn_
  Project schema = DL-MAA2023-46

History (reverse order):
2024-09-11 PM Changed refresh 
2024-08-06 SA reduce to born in NZ indicator
2021-11-26 SA restructure and tidy
2021-10-31 CW
**************************************************************************************************/

/* create table of all COB */
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[tmp_COB_list]
GO

CREATE TABLE [IDI_Sandpit].[DL-MAA2023-46].[tmp_COB_list](
    snz_uid INT
        , born_in_NZ SMALLINT
        , source_rank INT
        , 
);
GO

/***************************************************************************************************************
append records from each source into the table
***************************************************************************************************************/

/********************************************************
Census 2018
'V14.1' as code_sys
********************************************************/
INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[tmp_COB_list](
    snz_uid
        , born_in_NZ
        , source_rank
)
SELECT [snz_uid]
    , IIF([cen_ind_birth_country_code] = '1201', 1, 0)AS born_in_NZ
    , 1 AS source_rank
FROM [IDI_Clean_202403].[cen_clean].[census_individual_2018]
WHERE [cen_ind_birth_country_impt_ind] IN('11','12')
GO

/********************************************************
Census 2013 
'V14.1' as code_sys
********************************************************/
INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[tmp_COB_list](
    snz_uid
        , born_in_NZ
        , source_rank
)
SELECT [snz_uid]
    , IIF([cen_ind_birth_country_code] = '1201', 1, 0)AS born_in_NZ
    , 2 AS source_rank
FROM [IDI_Clean_202403].[cen_clean].[census_individual_2013]
GO

/********************************************************
DIA births - NZ birth 
'1999 4N V14.0.0' as code_sys
********************************************************/
INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[tmp_COB_list](
    snz_uid
        , born_in_NZ
        , source_rank
)
SELECT DISTINCT snz_uid
    , 1 AS born_in_NZ
    , 3 AS source_rank
FROM [IDI_Clean_202403].[dia_clean].[births]
GO

/********************************************************
CUS customs 
'1999 4A V15.0.0' as raw_code_sys
'1999 4N V14.0.0' as code_sys
********************************************************/
INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[tmp_COB_list](
    snz_uid
        , born_in_NZ
        , source_rank
)
SELECT [snz_uid]
    , IIF([cus_jou_country_of_birth_code] = 'NZ', 1, 0)AS born_in_NZ
    , 4 AS source_rank
FROM [IDI_Clean_202403].[cus_clean].[journey]
WHERE [cus_jou_country_of_birth_code] IS NOT NULL
AND [cus_jou_country_of_birth_code] ! = 'XX'
GO

/********************************************************
NZTA drivers license 
'1999 4N V14.0.0' as code_sys
********************************************************/
INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[tmp_COB_list](
    snz_uid
        , born_in_NZ
        , source_rank
)
SELECT DISTINCT snz_uid
    , IIF(raw_text = 'NEW ZEALAND', 1, 0)AS born_in_NZ
    , 5 AS source_rank
FROM(
    SELECT snz_uid
        , nzta_hist_birth_country_text AS raw_text
    FROM [IDI_Clean_202403].[nzta_clean].[dlr_historic]

    UNION ALL

    SELECT snz_uid
        , nzta_dlr_birth_country_text AS raw_text
    FROM [IDI_Clean_202403].[nzta_clean].[drivers_licence_register]
)AS a
GO

/********************************************************
DOL 
'1999 4A V15.0.0' as raw_code_sys
'1999 4N V14.0.0' as code_sys
********************************************************/
INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[tmp_COB_list](
    snz_uid
        , born_in_NZ
        , source_rank
)
SELECT DISTINCT [snz_uid]
    , IIF([dol_mid_birth_country_code] = 'NZ', 1, 0)AS born_in_NZ
    , 6 AS source_rank
FROM [IDI_Clean_202403].[dol_clean].[movement_identities]
GO

/***************************************************************************************************************
Keep best rank for each person
***************************************************************************************************************/

CREATE NONCLUSTERED INDEX my_index ON [IDI_Sandpit].[DL-MAA2023-46].[tmp_COB_list] (snz_uid)
GO

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[202403_born_in_NZ]
GO

WITH source_ranked AS(
    SELECT *
        , RANK()OVER(
        PARTITION BY [snz_uid]
        ORDER BY source_rank
    )AS ranked
    FROM [IDI_Sandpit].[DL-MAA2023-46].[tmp_COB_list]
)
SELECT snz_uid
    , born_in_NZ
    , source_rank
INTO [IDI_Sandpit].[DL-MAA2023-46].[202403_born_in_NZ]
FROM source_ranked
WHERE ranked = 1
GO

CREATE NONCLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-46].[202403_born_in_NZ] (snz_uid);
GO 
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-46].[202403_born_in_NZ] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
GO

/***************************************************************************************************************
Delete templorary tables
***************************************************************************************************************/
DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[tmp_COB_list]
GO
