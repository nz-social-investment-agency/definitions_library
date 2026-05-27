
USE IDI_UserCode
GO

DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_hospitalisations_202506]
GO

CREATE VIEW [DL-MAA2023-46].[defn_hospitalisations_202506] AS

SELECT [snz_uid]
      ,[moh_evt_evst_date] as [start_date]
      ,[moh_evt_even_date] as [end_date]
	  ,'PUBLIC' as [type]
FROM [IDI_Clean_202506].[moh_clean].[pub_fund_hosp_discharges_event]

UNION ALL

SELECT [snz_uid]
      ,[moh_pri_evt_start_date]
      ,[moh_pri_evt_end_date]
	  ,'PRIVATE' as [type]
FROM [IDI_Clean_202506].[moh_clean].[priv_fund_hosp_discharges_event]
GO
