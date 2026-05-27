
USE IDI_UserCode

DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_emergency_department_202506]
GO

CREATE VIEW [DL-MAA2023-46].[defn_emergency_department_202506] AS

SELECT DISTINCT [snz_uid]
      ,[moh_nnp_service_datetime] AS [start_date]
	  ,[moh_nnp_service_datetime] AS [end_date]
	 -- ,[moh_nnp_purchase_unit_code]
	  ,'ED visit' AS [description]
	  ,'moh nnpac' as [source]
FROM [IDI_Clean_202506].[moh_clean].[nnpac]
WHERE [moh_nnp_event_type_code] = 'ED'
AND [moh_nnp_purchase_unit_code] IN ('ED02001', 'ED02001A', 'ED03001', 'ED03001A',
									 'ED04001', 'ED04001A', 'ED05001', 'ED05001A',
									 'ED06001', 'ED06001A')
AND [moh_nnp_service_date] IS NOT NULL
AND [moh_nnp_service_type_code] <> 'FU' /*do not include "follow-up" (FU) appointments. 
--See 'inclusion criteria' on page 34 of: www.health.govt.nz/publication/emergency-department-use-2014-15*/
AND [moh_nnp_attendence_code] <> 'DNA' /*Remove cases when health care user "Did not attend"*/
AND [moh_nnp_attendence_code] <> 'DNW' /*Remove cases when health care user arrived but "did not wait" to use service.
--See 'inclusion criteria' on page 34 of: www.health.govt.nz/publication/emergency-department-use-2014-15*/
GO
