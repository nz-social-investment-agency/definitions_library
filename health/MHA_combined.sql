/**************************************************************************************************
Title: MHA combined
Author: Charlotte Rose
Reviewer: Lexi Xu


Citation:
Social Investment Agency. Definitions library. Source code. https://github.com/nz-social-investment-agency/definitions_library

Description:


Intended purpose:
Combines mental health and addiction definitions into broad definitions of 'substance abuse' and 'mental illness'

Inputs & Dependencies:
- [IDI_Sandpit].[DL-MAA2023-46].[defn_mha_alcohol_abuse_or_dependence_202506]
- [IDI_Sandpit].[DL-MAA2023-46].[defn_mha_drug_abuse_or_dependence_202506]
- [IDI_Sandpit].[DL-MAA2023-46].[defn_mha_major_depressive_disorder_202506]
- [IDI_Sandpit].[DL-MAA2023-46].[defn_mha_bipolar_202506]
- [IDI_Sandpit].[DL-MAA2023-46].[defn_mha_dysthymia_202506]
- [IDI_Sandpit].[DL-MAA2023-46].[defn_mha_generalised_anxiety_disorder_202506]
- [IDI_Sandpit].[DL-MAA2023-46].[defn_mha_schizophrenia_202506]

Outputs:
- [IDI_UserCode].[DL-MAA2023-46].[substance_abuse_202506]
- [IDI_UserCode].[DL-MAA2023-46].[mental_illness_202506]


Notes:
1) All definitions above must be run for the current refresh before running this script

Issues:
1) 
	
Parameters & Present values:
  Current refresh = 202506
  Prefix = defn_
  Project schema = [DL-MAA2023-46]
 
History (reverse order):
2025-07-22 CR
*************************************************************************************************************************/


USE IDI_UserCode
GO

--Substance abuse--

DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_substance_abuse_202506]
GO

CREATE VIEW [DL-MAA2023-46].[defn_substance_abuse_202506] AS
	(
		SELECT snz_uid
			, event_date 
		FROM [IDI_Sandpit].[DL-MAA2023-46].[defn_mha_alcohol_abuse_or_dependence_202506]

		UNION 

		SELECT snz_uid
			, event_date 
		FROM [IDI_Sandpit].[DL-MAA2023-46].[defn_mha_drug_abuse_or_dependence_202506]
	)
GO

--Mental illness--
DROP VIEW IF EXISTS [DL-MAA2023-46].[defn_mental_illness_202506]
GO

CREATE VIEW [DL-MAA2023-46].[defn_mental_illness_202506] AS
	(

		SELECT snz_uid
		, event_date
		FROM [IDI_Sandpit].[DL-MAA2023-46].[defn_mha_major_depressive_disorder_202506]

		UNION 

		SELECT snz_uid 
			, event_date
		FROM [IDI_Sandpit].[DL-MAA2023-46].[defn_mha_bipolar_202506]

		UNION 

		SELECT snz_uid 
			, event_date
		FROM [IDI_Sandpit].[DL-MAA2023-46].[defn_mha_dysthymia_202506]

		UNION 

		SELECT snz_uid 
			, event_date
		FROM [IDI_Sandpit].[DL-MAA2023-46].[defn_mha_generalised_anxiety_disorder_202506]

		UNION 

		SELECT snz_uid 
			, event_date
		FROM [IDI_Sandpit].[DL-MAA2023-46].[defn_mha_schizophrenia_202506]
	)
GO
