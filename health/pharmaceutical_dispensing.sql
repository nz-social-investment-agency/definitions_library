/**************************************************************************************************
Title: Despensing of prescriptions
Author: Simon Anastasiadis
Peer review: 

Inputs & Dependencies:
- [IDI_Clean_202506].[moh_clean].[pharmaceutical]

Description:
Pharmaceutical dispensing filtered to personal dispensing for use in analysis


Notes:
1) Pharma is a huge table (> 90 million rows)
	For performance, use View to benefit from base indexes.
2) A single dispensing can involve multiple rows (e.g. 4 trays of 8 tablets + 1 half-tray
	might be recorded in two rows).
	For inclusion in analysis recommend either:
	- Count distinct dispensed_date
	- Join to metadata and count distinct drugs

Parameters & Present values:
  Current refresh = 202506

Issues: 


History (reverse order):
2025-03-14 SA
**************************************************************************************************/

USE IDI_UserCode
GO

DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_pharma_dispensing_202506]
GO

CREATE VIEW [DL-MAA2023-46].[defn_pharma_dispensing_202506] AS
SELECT [snz_uid]
    ,[moh_pha_dispensed_date]
    ,[moh_pha_dim_form_pack_code] -- can join to metadata for drug name
    ,[moh_pha_uniq_disp_id_nbr]
FROM [IDI_Clean_202506].[moh_clean].[pharmaceutical]
-- exclude administrative records
WHERE [moh_pha_admin_record_ind] = 0 -- (like brand switches)
AND [moh_pha_order_type_code] NOT IN (3,4,5) -- (like bulk and wholesale orders)
AND snz_uid != -1 -- (like non-linked snz_uid)
GO


