/**************************************************************************************************
Title: Potential child caregivers
Author: Penny Mok & Ashleigh Arendt

Inputs & Dependencies:
	[IDI_Clean_202406].[dia_clean].[births]
	[IDI_Clean_202406].[msd_clean].[msd_child]
	[IDI_Clean_202406].[msd_clean].[msd_partner]
	[IDI_Clean_202406].[wff_clean].[fam_children]
	[IDI_Clean_202406].[wff_clean].[fam_return_parents]
	
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_potential_caregivers]

Description:
	Identify adults who might have a caregiving role for a child

Notes:
1) Original code part of a definition that sought to identify sole parents. But this code was too
	specific to original application for ease of reuse. Key steps for considering sole parents:
	- Use source-rank to keep most relevant adults for each child
	- Use address notification table to estimate cohabitation
	- Filter to children with only one adult
2) source_rank column takes three values:
	0 = biological parent
	1 = recorded as caregiver in government interaction (MSD or WFF)
	2 = recorded as partner of caregiver in government interaction (MSD or WFF)

Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2025-01-24 SAnastasiadis: extracted caregivers component
2024-09-24 AArendt: created SQL version of Penny's Stata code
PMok: original version in Stata for sole parents
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_potential_caregivers]

CREATE TABLE [IDI_Sandpit].[DL-MAA2023-46].[defn_potential_caregivers] (
	caregiver_snz_uid INT NOT NULL
    , child_snz_uid INT NOT NULL
    , start_date DATE NOT NULL
    , end_date DATE NOT NULL
    , source_rank TINYINT NOT NULL
)

---------------------------------------------------------------------
-- Biological parent from DIA

INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_potential_caregivers]
SELECT [parent1_snz_uid] AS caregiver_snz_uid
    , [snz_uid] AS child_snz_uid
	, DATEFROMPARTS([dia_bir_birth_year_nbr],[dia_bir_birth_month_nbr],15) AS start_date
    , '9999-01-01' AS end_date
	, 0 AS source_rank
FROM [IDI_Clean_202406].[dia_clean].[births]
WHERE snz_uid IS NOT NULL
AND parent1_snz_uid IS NOT NULL
AND dia_bir_birth_year_nbr IS NOT NULL
AND dia_bir_birth_year_nbr > 1990 -- restrict to births in last ~35 years

INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_potential_caregivers]
SELECT [parent2_snz_uid] AS caregiver_snz_uid
    , [snz_uid] AS child_snz_uid
	, DATEFROMPARTS([dia_bir_birth_year_nbr],[dia_bir_birth_month_nbr],15) AS start_date
    , '9999-01-01' AS end_date
	, 0 AS source_rank
FROM [IDI_Clean_202406].[dia_clean].[births]
WHERE [parent1_snz_uid] <> [parent2_snz_uid]
AND snz_uid IS NOT NULL
AND parent1_snz_uid IS NOT NULL
AND dia_bir_birth_year_nbr IS NOT NULL
AND dia_bir_birth_year_nbr > 1990 -- restrict to births in last ~35 years

---------------------------------------------------------------------
-- Parenting status from MSD

INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_potential_caregivers]
SELECT [snz_uid] AS caregiver_snz_uid
    , [child_snz_uid]
    , [msd_chld_child_from_date] AS start_date
    , COALESCE([msd_chld_child_to_date], '9999-01-01') AS end_date
	, 1 AS source_rank
FROM [IDI_Clean_202406].[msd_clean].[msd_child]

INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_potential_caregivers]
SELECT a.partner_snz_uid AS caregiver_snz_uid
    , b.child_snz_uid
    , IIF(a.msd_ptnr_ptnr_from_date <= b.msd_chld_child_from_date, b.msd_chld_child_from_date, a.msd_ptnr_ptnr_from_date) AS start_date -- latest start
    , IIF(
		COALESCE(a.msd_ptnr_ptnr_to_date, '9999-01-01') <= COALESCE(b.msd_chld_child_to_date, '9999-01-01'),
		COALESCE(a.msd_ptnr_ptnr_to_date, '9999-01-01'),
		COALESCE(b.msd_chld_child_to_date, '9999-01-01')
		) AS end_date -- earliest end
	, 2 AS source_rank
FROM [IDI_Clean_202406].[msd_clean].[msd_partner] AS a
INNER JOIN [IDI_Clean_202406].[msd_clean].[msd_child] AS b
ON a.snz_uid = b.snz_uid
-- overlap
AND a.msd_ptnr_ptnr_from_date <= COALESCE(b.msd_chld_child_to_date, '9999-01-01')
AND b.msd_chld_child_from_date <= COALESCE(a.msd_ptnr_ptnr_to_date, '9999-01-01')

---------------------------------------------------------------------
-- Working for families - primary caregiver spells and parent's partners

INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_potential_caregivers]
SELECT [snz_uid] AS caregiver_snz_uid
    , [child_snz_uid]
    , [wff_chi_start_date] AS start_date
	, COALESCE([wff_chi_end_date], '9999-01-01') AS end_date
	, 1 AS source_rank
FROM [IDI_Clean_202406].[wff_clean].[fam_children]
WHERE child_snz_uid ! = -11  --remove children with missing snz_uids

INSERT INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_potential_caregivers]
SELECT a.partner_snz_uid AS caregiver_snz_uid
    , b.child_snz_uid
    , IIF(a.wff_frp_start_date <= b.wff_chi_start_date, b.wff_chi_start_date, a.wff_frp_start_date) AS start_date -- latest start
    , IIF(
		COALESCE(a.wff_frp_end_date, '9999-01-01') <= COALESCE(b.wff_chi_end_date, '9999-01-01'),
		COALESCE(a.wff_frp_end_date, '9999-01-01'),
		COALESCE(b.wff_chi_end_date, '9999-01-01')
		) AS end_date -- earliest end
	, 2 AS source_rank
FROM [IDI_Clean_202406].[wff_clean].[fam_return_parents] AS a
INNER JOIN [IDI_Clean_202406].[wff_clean].[fam_children] AS b
ON a.snz_uid = b.snz_uid
-- overlap
AND a.wff_frp_start_date <= COALESCE(b.wff_frp_end_date, '9999-01-01')
AND b.wff_chi_start_date <= COALESCE(a.wff_frp_end_date, '9999-01-01')
WHERE b.child_snz_uid ! = -11  --remove children with missing snz_uids
