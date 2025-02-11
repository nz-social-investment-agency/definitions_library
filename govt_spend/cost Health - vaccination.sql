/**************************************************************************************************
Title: GP visit & vaccine costs
Author: Craig Wright 

Inputs & Dependencies:
	[IDI_Clean_202410].[moh_clean].[nir_event]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_vaccination]

Description:
	Estimate cost of gp vists and vaccine costs

Notes:
- Due ot eletronic submission erros there are many duplicate event uids
- Prices were sourced from practice websites for 2024 and include the visit subsidy of around $40
	As could not find prices for HIB , BCG, ROTAVIRUS, these are priced at $50

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-26 CWright: add price estiamtes for  vaccines
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_vaccination]
GO

WITH vaccinations AS (

SELECT [snz_uid]
    , [snz_moh_uid]
    , [moh_nir_evt_event_id_nbr]
    , [moh_nir_evt_vaccine_date]
    , [moh_nir_evt_vaccine_text]
    , [moh_nir_evt_vaccine_dose_nbr]
    , [moh_nir_evt_indication_text]
    , [moh_nir_evt_indication_desc_text]
    , [moh_nir_evt_status_desc_text]
    , [moh_nir_evt_sub_status_desc_text]
    , [moh_nir_evt_pho_name_text]
    , [moh_nir_evt_clinic_name_text]
    , COUNT(*) AS duplicates
FROM [IDI_Clean_202410].[moh_clean].[nir_event]
WHERE YEAR([moh_nir_evt_vaccine_date]) BETWEEN 2019 AND 2023
AND [moh_nir_evt_vaccine_text] IN ('BCG','PCV13','ZOSTER','HIB','VARICELLA','ROTAVIRUS','HPV','PCV10','DTAP-IPV','MMR','TDAP','INFLUENZA','DTAP-IPV-HEP B/HIB')
AND [moh_nir_evt_indication_text] IN ('1','2','3','5','6','10','16','11Y','12M','15M','3M ','45Y','4Y ','5M ','65Y','6W ','STN','TPW')
GROUP BY [snz_uid]
    , [snz_moh_uid]
    , [moh_nir_evt_event_id_nbr]
    , [moh_nir_evt_vaccine_date]
    , [moh_nir_evt_vaccine_text]
    , [moh_nir_evt_vaccine_dose_nbr]
    , [moh_nir_evt_indication_text]
    , [moh_nir_evt_indication_desc_text]
    , [moh_nir_evt_status_desc_text]
    , [moh_nir_evt_sub_status_desc_text]
    , [moh_nir_evt_pho_name_text]
    , [moh_nir_evt_clinic_name_text]

),
vaccine_cost AS (

SELECT *
    , CASE
		WHEN moh_nir_evt_status_desc_text <> 'COMPLETED'		THEN NULL
		WHEN 	[moh_nir_evt_vaccine_text]	 = 		'BCG'		THEN 	 50 
		WHEN 	[moh_nir_evt_vaccine_text]	 = 		'DTAP-IPV'	THEN 	 202 
		WHEN 	[moh_nir_evt_vaccine_text]	 = 		'DTAP-IPV-HEP B/HIB'	 THEN 	 357 
		WHEN 	[moh_nir_evt_vaccine_text]	 = 		'HIB'		THEN 	 50 
		WHEN 	[moh_nir_evt_vaccine_text]	 = 		'HPV'		THEN 	 248 
		WHEN 	[moh_nir_evt_vaccine_text]	 = 		'INFLUENZA'	THEN 	 30 
		WHEN 	[moh_nir_evt_vaccine_text]	 = 		'MMR'		THEN 	 109 
		WHEN 	[moh_nir_evt_vaccine_text]	 = 		'PCV10'		THEN 	 215 
		WHEN 	[moh_nir_evt_vaccine_text]	 = 		'PCV13'		THEN 	 215 
		WHEN 	[moh_nir_evt_vaccine_text]	 = 		'ROTAVIRUS'	THEN 	 50 
		WHEN 	[moh_nir_evt_vaccine_text]	 = 		'TDAP'		THEN 	 70 
		WHEN 	[moh_nir_evt_vaccine_text]	 = 		'VARICELLA'	THEN 	 95 
		WHEN 	[moh_nir_evt_vaccine_text]	 = 		'ZOSTER'	THEN 	 365 
		WHEN 	[moh_nir_evt_vaccine_text]	 = 		'HEP B'		THEN 	 105 
		WHEN 	[moh_nir_evt_vaccine_text]	 = 		'Polio'		THEN 	 132 
		END AS cost
    , YEAR(a.moh_nir_evt_vaccine_date) AS cal_year
FROM vaccinations AS a

)
-- Convert cost estimates to $NZ 2024
SELECT a.snz_uid
    , 'NIR' AS source
    , a.cal_year
    , COUNT(*) AS value
    , SUM(cost*cpi_adj_2024) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_vaccination]
FROM vaccine_cost AS a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON b.cal_year = 2024
GROUP BY snz_uid
    , a.cal_year
