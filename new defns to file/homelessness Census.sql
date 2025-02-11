/**************************************************************************************************
Title: Homelessness from Census
Author: Craig Wright

Description:
Homelessness, including temporary accomodation

Inputs & Dependencies:
	[IDI_METADATA].[CLEAN_READ_CLASSIFICATIONS].[CEN_OCCDWELTYPE]
	[IDI_CLEAN_202403].[CEN_CLEAN].[CENSUS_DWELLING_2018]
	[IDI_CLEAN_202403].[DATA].[ADDRESS_NOTIFICATION_FULL]
	[IDI_METADATA].[CLEAN_READ_CLASSIFICATIONS].[CEN_OCCDWELTYPE]
	[IDI_CLEAN_20211020].[CEN_CLEAN].[CENSUS_DWELLING_2018]
	[IDI_METADATA].[CLEAN_READ_CLASSIFICATIONS].[BR_ANZSIC06]
Outputs:
	#add_type
	

Notes:
- NOTE: this indicator is built mainly off the address type classification table
	this maps [snz_idi_address_register_uid] to address type
- Key codes
	--census 2018 homelessnes addresses
	--1313	Improvised dwelling or shelter
	--1314	Roofless or rough sleeper
	--2213	Motor camp/camping ground
	--1311	Dwelling in a motor camp
	--1312	Mobile dwelling not in a motor camp
	--2120	Night shelter
	--2211	"Hotel, motel or guest accommodation"
	--2212	Boarding house
	--2218	Marae complex

Parameters & Present values:
  Current refresh = 202403
  Prefix = 
  Project schema = 
 
Issues:
- For people living at motel or hotel, need to check that they are not working there
	ie motel or hotel owners. This is done by matching employment at date with employers industry

History (reverse order):
2025-01-16 Simon A: tidy file and remove duplicates
2025-05-29 CWright: Initial creation
**************************************************************************************************/

--GEO - address table - address dwellingt types from census 2018
SELECT *
FROM [IDI_Metadata].[clean_read_CLASSIFICATIONS].[CEN_OCCDWELTYPE]

--create address type table ie motel, campground, residential institution, hospital etc
DROP TABLE IF EXISTS #add_type

SELECT DISTINCT [cen_dwl_record_type_code]
    , [cen_dwl_type_code]
      --,[cen_dwl_type_code_impt_ind]
    , [snz_idi_address_register_uid]
    , b.descriptor
INTO #add_type
FROM [IDI_Clean_202403].[cen_clean].[census_dwelling_2018] AS a
    , [IDI_Metadata].[clean_read_CLASSIFICATIONS].[CEN_OCCDWELTYPE] AS b
WHERE a.cen_dwl_type_code = b.code
AND b.code IN ('1311', '1312', '1313', '1314', '2120', '2211', '2212','2213', '2218')
AND [snz_idi_address_register_uid] IS NOT NULL


DROP TABLE IF EXISTS #address

SELECT a.*
    , b.cen_dwl_type_code
    , b.Descriptor
INTO #address
FROM(
    SELECT a.[snz_uid]
        , [ant_address_source_code]
        , [ant_notification_date]
      --,[ant_replacement_date]
        , [snz_idi_address_register_uid]
        , b.snz_birth_date_proxy
        , b.snz_sex_gender_code
        , FLOOR(DATEDIFF(DAY,b.snz_birth_date_proxy,[ant_notification_date])/365.24)age
        , b.snz_spine_ind
    FROM [IDI_Clean_202403].[data].[address_notification_full] AS a
        , IDI_Clean_202403.data.personal_detail AS b
    WHERE a.snz_uid = b.snz_uid
    AND [snz_idi_address_register_uid] IS NOT NULL
)AS a
    , #add_type AS b
WHERE a.snz_idi_address_register_uid = b.snz_idi_address_register_uid

