/**************************************************************************************************
Title: OT_interactions
Author: Dan Young

Inputs & Dependencies:
- [IDI_Clean].[cyf_clean].[cyf_investgtns_event]
- [IDI_Clean].[cyf_clean].[cyf_investgtns_details]
- [IDI_Clean].[cyf_clean].[cyf_ev_cli_fgc_cys_f]
- [IDI_Clean].[cyf_clean].[cyf_placements_event]
- [IDI_Clean].[cyf_clean].[cyf_placements_details]

Outputs:
- [IDI_UserCode].[DL-MAA2020-37].[defn_OT_investigation]
- [IDI_UserCode].[DL-MAA2020-37].[defn_OT_conference]
- [IDI_UserCode].[DL-MAA2020-37].[defn_OT_placement]

Description:
Indicators of whether a young person (under 18) has previous had, at any point in their life to date:
- an investigation following from a report of concern to OT
- a family group conference (following investigation of a RoC, or following a Youth Justice interaction)
- a placement (including where placed with whanau, or remaining in current residence but while under legal custody of OT)

Intended purpose:
Understanding whether tamariki and rangatahi have experienced trauma

Notes:
	-	We have been advised that there are different approaches to recording reports of concern between different regions, which 
		results in some areas reporting more/less than others. Thus we are not collecting data for ROCs for RDP.
	-	While this indicator looks over the lifetime, overall numbers are still relatively low. This may 
		prevent granular breakdowns by demographic/region or other indicator
	-	Data quality:
			- not all persons in OT data have a birthday in the personal_detail table. We lose about 2% of uids (accounting for <0.5% of the data) from these
			- we then lose a further ~2% of uids and rows where the start date of the event predates the persons birthday (after accounting for birthday being a mid-month proxy)
			- joining the data onto our dataset then produces a ~9.5% loss due to a number of people in the OT dataset are not on the spine (only reference in pd table is MSD)
			- Further ~5% loss due to the people not being in our population definition (overseas or deceased mostly)

	- Looking at records compared to published figures (eg, by OT) for a comparable period (12mo < 30/03/2023):			
		Investigations -	are a bit lower (7-10%) compared to OT published figures for Referred for Assessment or Investigation. The difference is currently assumed to be
							due to the mismatch in what is being measured. Investigation-only figures could not be found at the time of review.
		FGC -				FGCs can come through the Youth Justice or the Care and Protection stream. When published figures for both are summed our redults are 2% higher than published figueres

		Placements -		numbers with a placement spell overlapping the end of a final year are a close match to the published figures. Differences might be based on data 
							available at the time of reporting.

		Note that this code does not make all the distinctions discussed above, as the interest is in ANY interactions with the OT system above ROC to date as a binary indicator.

Parameters & Present values:
  Current refresh = 202303
  Prefix = defn_
  Project schema = [DL-MAA2020-37]

Issues:

History (reverse order):
2023-08-02 DY - removed RoC based on conversation with Steve Murray at OT
2023-06-30 DY - v1
**************************************************************************************************/

USE IDI_UserCode
GO

---------------------------------------------------------------------
-- Investigation events (following a RoC)

DROP VIEW IF EXISTS [DL-MAA2020-37].[defn_OT_investigation]
GO

CREATE VIEW [DL-MAA2020-37].[defn_OT_investigation] AS
SELECT a.[snz_uid]
    , MIN(a.[cyf_ive_event_from_date_wid_date])AS startdate
    , 'Inv' AS ot_event_type
FROM [IDI_Clean_202303].[cyf_clean].[cyf_investgtns_event] a
INNER JOIN [IDI_Clean_202303].[cyf_clean].[cyf_investgtns_details] b
ON a.[snz_composite_event_uid] = b.[snz_composite_event_uid]
GROUP BY a.snz_uid
GO

---------------------------------------------------------------------
-- Family group conference
-- (may be from YJ or investigation following RoC...)

DROP VIEW IF EXISTS [DL-MAA2020-37].[defn_OT_conference]
GO

CREATE VIEW [DL-MAA2020-37].[defn_OT_conference] AS
SELECT [snz_uid]
    , MIN([cyf_fge_event_from_date_wid_date]) AS startdate
    , 'FGC' AS ot_event_type
FROM [IDI_Clean_202303].[cyf_clean].[cyf_ev_cli_fgc_cys_f]
GROUP BY snz_uid
GO

---------------------------------------------------------------------
-- Placement (following FGC)
-- There are a range of reasons for a placement, including justice system-related (eg, held at a Corrections Youth Unit)
-- Placements can also include 'remain home' placements where the family retain physical custody, but legally the tamaiti is in the care of the CE.
-- These may all still be a good signal?

DROP VIEW IF EXISTS [DL-MAA2020-37].[defn_OT_placement]
GO

CREATE VIEW [DL-MAA2020-37].[defn_OT_placement] AS
SELECT a.[snz_uid]
    , MIN(a.[cyf_ple_event_from_date_wid_date])AS startdate
    , 'Pla' AS ot_event_type
FROM [IDI_Clean_202303].[cyf_clean].[cyf_placements_event] a
INNER JOIN [IDI_Clean_202303].[cyf_clean].[cyf_placements_details] b
ON a.[snz_composite_event_uid] = b.[snz_composite_event_uid]
GROUP BY a.snz_uid
GO
