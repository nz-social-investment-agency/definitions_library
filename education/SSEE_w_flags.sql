 /**************************************************************************************************
Title: Stand downs, Suspensions, Exclusions and Expulsions
Author: Charlotte Rose
Peer review: Simon Anastasiadis

Inputs & Dependencies:
- [IDI_Clean_202506].[moe_clean].[student_interventions] 
- [IDI_Metadata_202506].[moe_school].[intervention_type_code]
- [IDI_Metadata_202506].[moe_school].[sds_type_code]
- [IDI_Clean_202506].[moe_clean].[student_enrol]

Description: 
Identifies stand down, suspension, exclusion and expulsion events. These events mean a child is not allowed at school usually due to rule breaking
or behaviour issues. The child can either return to school with agreements, or be removed from the roll.
- Stand downs are 'cooling off periods'. They tend to be short periods of time where a student not allowed at school. Whanau and teachers will work together to
	manage behaviour
- Suspensions are longer periods where a child is not allowed at school and requires the board to meet to dicuss next steps.
	The outcome of a suspension can include returning to school with or without conditions. More serious outcomes mean a child is removed from the school roll
		-Exclusions are when a child under the age of 16 is removed from the school roll
		-Expulsions are when a young person over the age of 16 is removed from hte school roll

Intended purpose:
Indicator for cohort analysis to identified those students with challenges which are effecting their educational engagement

Notes:
- Because exclusions and explusions are outcomes of suspensions rather than a seperate intervention type, a flag has been included as to  
	whether a suspension resulted in either an exlusion or an explusion.


Parameters & Present values:
  Current refresh = 202506
  Project schema = [DL-MAA2023-46]
 
Issues:
 
History (reverse order):
2025-06-12 CR
**************************************************************************************************/

USE IDI_UserCode
GO

DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_SSEE_w_flag_202506]
GO

CREATE VIEW [DL-MAA2023-46].[defn_SSEE_w_flag_202506] AS
SELECT DISTINCT i.snz_uid
	,i.moe_inv_start_date
	,i.moe_inv_end_date
	,i.moe_inv_intrvtn_code
	,t.InterventionName
	,IIF(i.moe_inv_intrvtn_code = 8, 1, NULL) AS standdown_flag
	,IIF(i.moe_inv_intrvtn_code = 7, 1, NULL) AS suspension_flag
	,IIF(i.moe_inv_intrvtn_code = 7 AND s.sDSTypeCode IN (13,5,6,7),1,NULL) AS exp_flag -- expulsion or exclusion
	,e.moe_esi_provider_code
FROM [IDI_Clean_202506].[moe_clean].[student_interventions] i
INNER JOIN [IDI_Metadata_202506].[moe_school].[intervention_type_code] t
ON t.InterventionID = i.moe_inv_intrvtn_code
LEFT JOIN [IDI_Metadata_202506].[moe_school].[sds_type_code] s
ON s.SDSTypeCode = i.moe_inv_standwn_susp_type_code
INNER JOIN [IDI_Clean_202506].[moe_clean].[student_enrol] e
ON e.snz_uid = i.snz_uid
AND e.moe_esi_start_date < i.[moe_inv_end_date]
AND i.[moe_inv_start_date] < e.moe_esi_end_date
WHERE i.moe_inv_intrvtn_code IN (7,8)
GO
