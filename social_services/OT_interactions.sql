/**************************************************************************************************
Title: OT interactions
Author: Dan Young
Peer review: 

Inputs & Dependencies:
	[IDI_Clean_202506].[cyf_clean].[cyf_intakes_event] 
	[IDI_Clean_202506].[cyf_clean].[cyf_intakes_details]
	[IDI_Clean_202506].[cyf_clean].[cyf_investgtns_event]
	[IDI_Clean_202506].[cyf_clean].[cyf_investgtns_details]
	[IDI_Clean_202506].[cyf_clean].[cyf_ev_cli_fgc_cys_f]
	[IDI_Clean_202506].[cyf_clean].[cyf_dt_cli_fgc_cys_d]
	[IDI_Clean_202506].[cyf_clean].[cyf_ev_cli_fwas_cys_f]
	[IDI_Clean_202506].[cyf_clean].[cyf_dt_cli_fwas_cys_d]
	[IDI_Clean_202506].[cyf_clean].[cyf_placements_event]
	[IDI_Clean_202506].[cyf_clean].[cyf_placements_details]

Description:
Interactions with OT of four types:
Report of concern (CNP only), investigations, family group conferences, and placements.


Notes:
1) These types of interactions are in escalating levels of seriousness.
	Reports of concern are recived by OT and either escalated to an investigation, added to a current file as additional information or no action is taken.
	Investigations occur before Family Group Conferences.
	Family Group Conferences occur before Placements.
	Not every investigation leads to a FGC.
	Not every FGC leads to a placement.

Parameters & Present values:
  Current refresh = 202506
  Project schema = MAA2023-46

Issues: 


History (reverse order):
2025-08-01 DY Added FWA to the FGC as a FGC equivalent
2025-06-13 CR Added ROC based on OT logic from (upcoming) code module
2025-03-17 SA version 1 based on Dan Young's code
**************************************************************************************************/

USE [IDI_UserCode]
GO

DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_OT_interactions_202506]
GO

CREATE VIEW [DL-MAA2023-46].[defn_OT_interactions_202506]
AS 

SELECT i.[snz_uid]
	,i.[snz_composite_event_uid]
	,CAST([cyf_ine_event_from_datetime] as DATE) as [start_date]
	,CAST([cyf_ine_event_to_datetime] as DATE) as [end_date]
	,[cyf_ind_business_area_type_code] as [reason]
	,'ROC' as type
FROM [IDI_Clean_202506].[cyf_clean].[cyf_intakes_event] i
LEFT JOIN [IDI_Clean_202506].[cyf_clean].[cyf_intakes_details] d
ON i.[snz_composite_event_uid] = d.[snz_composite_event_uid]
WHERE [cyf_ind_cnp_notification_ind] = 'Y' -- this does not apply to YJ notifications


UNION ALL

SELECT [snz_uid]
    ,inv.[snz_composite_event_uid]
    ,[cyf_ive_event_from_date_wid_date] as [start_date]
    ,[cyf_ive_event_to_date_wid_date] as [end_date]
	,ind.cyf_ivd_business_area_type_code as [reason]
	,'INV' as type
FROM [IDI_Clean_202506].[cyf_clean].[cyf_investgtns_event] inv
INNER JOIN [IDI_Clean_202506].[cyf_clean].[cyf_investgtns_details] ind
ON ind.snz_composite_event_uid = inv.snz_composite_event_uid

UNION ALL

SELECT [snz_uid]
    ,fgc.snz_composite_event_uid
    ,fgc.cyf_fge_event_from_date_wid_date as [start_date]
    ,fgc.cyf_fge_event_to_date_wid_date as [end_date]
	,ind.cyf_fgd_business_area_type_code as [reason]
	,'FGC' as type
FROM [IDI_Clean_202506].[cyf_clean].[cyf_ev_cli_fgc_cys_f] fgc
INNER JOIN [IDI_Clean_202506].[cyf_clean].[cyf_dt_cli_fgc_cys_d] ind
ON ind.snz_composite_event_uid = fgc.snz_composite_event_uid
  
UNION ALL

-- The FWA table records Hui-a-Whanau (FWA: Family-Whanau Agreement, which may be 
-- the result of such a hui). Previously a researcher from OT advised that this is
-- effectively a FGC in a Maori cultural context. 
-- OT combine these with FGCs in the CWM, treating these as equivalent.
SELECT [snz_uid]
    ,fwa.snz_composite_event_uid
    ,fwa.cyf_fwe_event_from_date_wid_date as [start_date]
    ,fwa.cyf_fwe_event_to_date_wid_date as [end_date]
	,ind.cyf_fwd_business_area_type_code as [reason]
	,'FGC' as type -- labelled this as FGC, rather than change all the templates.
FROM [IDI_Clean_202506].[cyf_clean].[cyf_ev_cli_fwas_cys_f] fwa
INNER JOIN [IDI_Clean_202506].[cyf_clean].[cyf_dt_cli_fwas_cys_d] ind
ON ind.snz_composite_event_uid = fwa.snz_composite_event_uid
  
UNION ALL

SELECT[snz_uid]
    ,plc.snz_composite_event_uid
    ,plc.cyf_ple_event_from_date_wid_date as [start_date]
    ,plc.cyf_ple_event_to_date_wid_date as [end_date]
	,ind.cyf_pld_business_area_type_code as [reason]
	,'PLC' as type
FROM [IDI_Clean_202506].[cyf_clean].[cyf_placements_event] plc
INNER JOIN [IDI_Clean_202506].[cyf_clean].[cyf_placements_details] ind 
ON ind.snz_composite_event_uid = plc.snz_composite_event_uid
  

