/**************************************************************************************************
Title: Learning Supports
Author: Charlotte Rose
Peer review: Simon Anastasiadis

Inputs & Dependencies:
- [IDI_Clean_202506].[moe_clean].[student_interventions]
- [IDI_Metadata_202506].[moe_school].[se_service_category_code]
- [IDI_Metadata_202506].[moe_school].[intervention_type_code]
- [IDI_Clean_202506].[moe_clean].[student_enrol]
- [IDI_Metadata].[clean_read_CLASSIFICATIONS].[moe_provider]
- [IDI_Metadata_202506].[moe_school].[provider_type_code]

Description: 
This defines learning supports received. Included are:
- Reading Recovery
- High Health Students identified in Enrol 
- Resource Teachers: Literacy
- Interim Response Fund 
- Special Education 
- Resource Teacher: Learning and Behaviour 
- Special Education (Behaviour Service, Communication Service, Early Intervention Service)

Additonally, enrolment in a specialist school is included as is ORS (ongoing resourcing scheme)

Intended purpose:
Indicator for cohort analysis which shows if someone has higher educational needs AND is getting support
Not suitable for duration calculations in its present form.

Notes:
- This is an indicator of support received only, not a comprehensive indicator of childrens educational needs.

- While not all learning supports will be of interest for every cohort, it has been decided to include all those listed above under the umbrella of learning support
	to provide a general idea of the extra support a child is receiving, regardless of the reason.

- Special Education however has still been limited to Behaviour Service, Communication Service and the Early Intervention Service to capture those supports targeting
	 behavioural or developmental challenges rather than longer term/serious disability (Vision/hearing/mobility, intellectual disability, etc)

Parameters & Present values:
  Current refresh = 202506
  Project schema = [DL-MAA2023-46]
 
Issues:
 
History (reverse order):
2025-06-12 CR
**************************************************************************************************/

USE IDI_UserCode
GO

DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_learning_supports_202506]
GO

CREATE VIEW [DL-MAA2023-46].[defn_learning_supports_202506] AS

-- from student intervention
SELECT i.[snz_uid]
	  ,IIF([moe_inv_intrvtn_code] = 39,[moe_inv_se_service_category_code],[moe_inv_intrvtn_code]) as type_code
	  ,IIF([moe_inv_intrvtn_code] = 39,CONCAT(t.InterventionName,': ',se.SEServiceCategoryDescription),t.InterventionName) AS type
      ,[moe_inv_start_date] AS start_date
      ,[moe_inv_end_date] AS end_date
	  ,e.moe_esi_provider_code
FROM [IDI_Clean_202506].[moe_clean].[student_interventions] AS i
LEFT JOIN [IDI_Metadata_202506].[moe_school].[se_service_category_code] AS se
ON se.[SEServiceCategoryId] = i.[moe_inv_se_service_category_code]
INNER JOIN [IDI_Metadata_202506].[moe_school].[intervention_type_code] AS t 
ON t.InterventionID = i.moe_inv_intrvtn_code
INNER JOIN [IDI_Clean_202506].[moe_clean].[student_enrol] AS e 
ON e.snz_uid = i.snz_uid
AND e.moe_esi_start_date < i.[moe_inv_end_date]
AND i.[moe_inv_start_date] < e.moe_esi_end_date
WHERE [moe_inv_intrvtn_code] IN (
	16,	-- Reading Recovery
	27, -- High Health Students identified in Enrol
	31, -- Resource Teachers: Literacy
	37, -- Interim Response Fund
	48 -- Resource Teacher: Learning and Behaviour
)
OR (
	[moe_inv_intrvtn_code] = 39 -- Special Education
	AND [moe_inv_se_service_category_code] IN (2,3,5) -- Behaviour Service, Communication Service, Early Intervention Service
) 

UNION ALL

-- specialist school
SELECT DISTINCT e.[snz_uid]
	  ,p.moe_provider_type_code AS type_code
	  ,pc.ProviderTypeDescription AS type
      ,e.moe_esi_start_date as start_date
      ,e.moe_esi_end_date as end_date
	  ,e.moe_esi_provider_code
FROM [IDI_Clean_202506].[moe_clean].[student_enrol] e 
INNER JOIN [IDI_Metadata].[clean_read_CLASSIFICATIONS].[moe_provider] AS p
ON p.moe_provider_code = e.moe_esi_provider_code
INNER JOIN [IDI_Metadata_202506].[moe_school].[provider_type_code] AS pc
ON pc.ProviderTypeID = p.moe_provider_type_code
WHERE p.moe_provider_type_code = 10026 -- Specialist school

UNION ALL

-- ORS: ongoing resourcing scheme
SELECT e.snz_uid
	,'ORS' AS type_code
	,'ORS' AS type
    ,ors.AssessmentDate as start_date
    ,ors.ExitDate as end_date
	,e.moe_esi_provider_code
FROM [IDI_Clean_202506].[moe_clean].[student_enrol] AS e
INNER JOIN [IDI_Adhoc].[clean_read_MOE].[Student_ORS_Criterion_202409] AS ors
ON ors.snz_moe_uid = e.snz_moe_uid
AND ors.AssessmentDate < e.moe_esi_start_date
AND e.moe_esi_end_date < ors.ExitDate
GO
