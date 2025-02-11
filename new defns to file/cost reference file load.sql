/**************************************************************************************************
Title: Load reference tables for cost calculations
Author: Simon Anastasiadis

Description:
Load into Sandpit, reference files for cost calculation.
Includes year & date table, CPI table, and event cost tables.

Inputs & Dependencies:
	cost_ref_calendar_years.csv
	cost_ref_MoJ_offense_cat_pricing.csv
	cost_ref_MoJ_offense_to_category_mapping.csv
	cost_ref_MoH_PRIMHD_purchase_unit_pricing.csv
	cost_ref_ file.csv
	cost_ref_cpi_all_goods_2024.csv

Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[ref_calendar_years]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_MoJ_offense_cat_pricing]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_MoJ_offense_to_category_map]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_MoH_purchase_unit_pricing]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_life_expectancy]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]

Notes:
1) BULK LOAD can require some fiddling to get right. The below code is based on
	previous working code, but if it does not work then one alternative is the Import Tool:
	Right-click on the database > Tasks > Import Data or Import Flat File
2) Full file paths are required for SQL Server to access the files. At time of writing this
	should take the form \\prtprdsasnas01\DataLab\MAA\MAA20XX-YY\...
3) Some users have not have permission to run the BULK INSERT command. This can be requested
	from access2microdata.
4) Be careful editting/openning & saving these files in Excel. Excel may rearrange the dates
	into a different layout. For best loading keep dates in YYYY-MM-DD layout.

Parameters & Present values:
  Folder path = \\prtprdsasnas01\DataLab\MAA\project folder\subfolder\
  Prefix = ref_
  Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2025-01-22 SAnastasiadis: reference load script created
2024-11-01 CWright: original cost files created
**************************************************************************************************/

---------------------------------------------------------------------
-- Year date ranges

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[ref_calendar_years]

CREATE TABLE [IDI_Sandpit].[DL-MAA2023-46].[ref_calendar_years] (
	cal_year INT NOT NULL,
	start_date DATE NOT NULL,
	end_date DATE NOT NULL
)

BULK INSERT [IDI_Sandpit].[DL-MAA2023-46].[ref_calendar_years]
FROM '\\prtprdsasnas01\DataLab\MAA\project folder\subfolder\cost_ref_calendar_years.csv'
WITH (
	DATAFILETYPE = 'char',
	CODEPAGE = 'RAW',
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n',
	TABLOCK
)

---------------------------------------------------------------------
-- MoJ offence category pricing

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[ref_MoJ_offense_cat_pricing]

CREATE TABLE [IDI_Sandpit].[DL-MAA2023-46].[ref_MoJ_offense_cat_pricing] (
	offence_category VARCHAR(50) NULL,
	court_type VARCHAR(50) NULL,
	start_date VARCHAR(50) NULL,
	end_date VARCHAR(50) NULL,
	price VARCHAR(50) NULL
)

BULK INSERT [IDI_Sandpit].[DL-MAA2023-46].[ref_MoJ_offense_cat_pricing]
FROM '\\prtprdsasnas01\DataLab\MAA\project folder\subfolder\cost_ref_MoJ_offense_cat_pricing.csv'
WITH (
	DATAFILETYPE = 'char',
	CODEPAGE = 'RAW',
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n',
	TABLOCK
)

---------------------------------------------------------------------
-- MoJ offense to category mapping

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[ref_MoJ_offense_to_category_map]

CREATE TABLE [IDI_Sandpit].[DL-MAA2023-46].[ref_MoJ_offense_to_category_map] (
	offence_code VARCHAR(50) NULL,
	offence_category VARCHAR(50) NULL
)

BULK INSERT [IDI_Sandpit].[DL-MAA2023-46].[ref_MoJ_offense_to_category_map]
FROM '\\prtprdsasnas01\DataLab\MAA\project folder\subfolder\cost_ref_MoJ_offense_to_category_mapping.csv'
WITH (
	DATAFILETYPE = 'char',
	CODEPAGE = 'RAW',
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n',
	TABLOCK
)

---------------------------------------------------------------------
-- PRIMHD pricing

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[ref_MoH_purchase_unit_pricing]

CREATE TABLE [IDI_Sandpit].[DL-MAA2023-46].[ref_MoH_purchase_unit_pricing] (
	pi_code NVARCHAR(50) NOT NULL,
	fin_year NVARCHAR(50) NOT NULL,
	pu_price FLOAT NOT NULL,
	start_date DATE NOT NULL,
	end_date DATE NOT NULL
)

BULK INSERT [IDI_Sandpit].[DL-MAA2023-46].[ref_MoH_purchase_unit_pricing]
FROM '\\prtprdsasnas01\DataLab\MAA\project folder\subfolder\cost_ref_MoH_purchase_unit_pricing.csv'
WITH (
	DATAFILETYPE = 'char',
	CODEPAGE = 'RAW',
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n',
	TABLOCK
)

---------------------------------------------------------------------
-- Life Expectancy

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[ref_life_expectancy]

CREATE TABLE [IDI_Sandpit].[DL-MAA2023-46].[ref_life_expectancy] (
	age INT,
	life_expectancy FLOAT
)

BULK INSERT [IDI_Sandpit].[DL-MAA2023-46].[ref_life_expectancy]
FROM '\\prtprdsasnas01\DataLab\MAA\project folder\subfolder\cost_ref_ file.csv'
WITH (
	DATAFILETYPE = 'char',
	CODEPAGE = 'RAW',
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n',
	TABLOCK
)

---------------------------------------------------------------------
-- CPI adjustment

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]

CREATE TABLE [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] (
	cal_year INT NOT NULL,
	cpi_adj_2024 NUMERIC(38,28) NULL,
	cpi_adj DECIMAL(38,6) NULL,
	cpi_2024 NUMERIC(10,6) NOT NULL
)

BULK INSERT [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
FROM '\\prtprdsasnas01\DataLab\MAA\project folder\subfolder\cost_ref_cpi_all_goods_2024.csv'
WITH (
	DATAFILETYPE = 'char',
	CODEPAGE = 'RAW',
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n',
	TABLOCK
)
