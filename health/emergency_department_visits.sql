/**************************************************************************************************
Title: Emergency department visit
Author: Hubert Zal

Acknowledgements:
Informatics for Social Services and Wellbeing (terourou.org) supported the publishing of these definitions

Disclaimer:
The definitions provided in this library were determined by the Social Wellbeing Agency to be suitable in the 
context of a specific project. Whether or not these definitions are suitable for other projects depends on the 
context of those projects. Researchers using definitions from this library will need to determine for themselves 
to what extent the definitions provided here are suitable for reuse in their projects. While the Agency provides 
this library as a resource to support IDI research, it provides no guarantee that these definitions are fit for reuse.

Citation:
Social Investment Agency. Definitions library. Source code. https://github.com/nz-social-investment-agency/definitions_library

Description:
ED visits as recorded in the National Non-admitted Patient Collection.

Intended use: 
Identify ED visit events

Inputs & Dependencies:
- [IDI_Clean].[moh_clean].[nnpac]
Outputs:
- [IDI_Sandpit].[DL-MAA20XX-YY].[SIA_emergency_department]


Notes: 

In New Zealand, emergency departments (EDs) provide care and treatment for patients with real or perceived, serious injuries or illness.
We use ED visits as recorded in the National Non-admitted Patient Collection (NNPAC).

Results have been tested against Te Whatu Ora's clinical performance metrics, noting slight differences as the published measure looks at ED presentations (includes DNW, DNA), where
this code looks at ED visits (only those who attended).

Inclusion Criteria

The Ministry of Health has defined an inclusion criteria which defines an emergency department visit
which is recorded with the National Non-admitted Patient Collection (NNPAC).
Inclusion criteria as described in: www.health.govt.nz/publication/emergency-department-use-2014-15
See page 34.
•	had one of the ED codes specified as the purchase unit code (version 30, 2025)
•	were completed (ie, excludes events where the patient did not wait to complete)
•	do not include follow-up appointments

Purchase order codes included are listed in: www.tewhatuora.govt.nz/health-services-and-programmes/nationwide-service-framework-library/purchase-units#current-purchase-unit-data-dictionary
Version 30 as at May 2025
Major service group = ED

As per Craig Wright's advice:
because we are only interested in counting events, we do not need to
combine with admitted patient ED events.
Events where the person Did Not Attend (DNA) and Did Not Wait (DNW) are excluded.

-------------------------------------------------------------------------------------------------------
Variable definitions

moh_nnp_purchase_unit_code: A purchase unit code is part of a classification system used to consistently measure, quantify and value a service.
The definition for each purchase unit code can be found in the Purchase unit dictionary at:
https://www.tewhatuora.govt.nz/health-services-and-programmes/nationwide-service-framework-library/purchase-units#current-purchase-unit-data-dictionary
Version 30 as at May 2025
Major service group = ED

moh_nnp_attendence_code: Attendance code for the outpatient event. Notes: 
ATT (Attended) - An attendance is where the healthcare user is assessed by a registered medical 
practitioner or nurse practitioner. The healthcare user received treatment, therapy, advice, 
diagnostic or investigatory procedures.
DNA (Did Not Attend) - Where healthcare user did not arrive, this is classed as did not attend.
DNW (Did Not Wait) - Used for ED where the healthcare user did not wait. Also for use where healthcare
user arrives but does not wait to receive service.

moh_nnp_event_type_code: Code identifying the type of outpatient event. Notes: From 1 Jul 2008 to 31 June 2010,
the event type was determined from the submitted purchase unit code. However, from July 2010
it became mandatory to report the event type directly.

moh_nnp_service_date: The date and time that the triaged patient's treatment starts by a suitable ED medical professional
(could be the same time as the datetime of service if treatment begins immediately).


Parameters & Present values:
  Current refresh = $(IDIREF)
  Prefix = $(TBLPREF)
  Project schema = [$(PROJSCH)]
 
Issues:


History (reverse order):
Simon Anastasiadis: 2019-01-08
Charlotte Rose: 2025-05-22 - Update for 2025 Version 30 purcahde unit codes. Added purchase unit code MS02019 and ED% to allow for future ED purchase order codes to be added

**************************************************************************************************/
--PARAMETERS##################################################################################################
--SQLCMD only (Activate by clicking Query->SQLCMD Mode)
--Already in master.sql; Uncomment when running individually
:setvar TBLPREF "SWA_" 
:setvar IDIREF "IDI_Clean_YYYYMM" 
:setvar PROJSCH "DL-MAA20XX-YY"
GO

USE IDI_UserCode;

DROP VIEW IF EXISTS [$(PROJSCH)].[$(TBLPREF)emergency_department];
GO

CREATE VIEW [$(PROJSCH)].[$(TBLPREF)emergency_department] AS

SELECT DISTINCT [snz_uid]
      ,[moh_nnp_service_datetime] AS [start_date]
	  ,[moh_nnp_service_datetime] AS [end_date]
	 -- ,[moh_nnp_purchase_unit_code]
	  ,'ED visit' AS [description]
	  ,'moh nnpac' as [source]
FROM [$(IDIREF)].[moh_clean].[nnpac]
WHERE [moh_nnp_event_type_code] = 'ED'
AND ([moh_nnp_purchase_unit_code] LIKE 'ED%'
	OR = 'MS02019')					 
AND [moh_nnp_service_date] IS NOT NULL
AND [moh_nnp_service_type_code] <> 'FU' /*do not include "follow-up" (FU) appointments. 
--See 'inclusion criteria' on page 34 of: www.health.govt.nz/publication/emergency-department-use-2014-15*/
AND [moh_nnp_attendence_code] <> 'DNA' /*Remove cases when health care user "Did not attend"*/
AND [moh_nnp_attendence_code] <> 'DNW'; /*Remove cases when health care user arrived but "did not wait" to use service.
--See 'inclusion criteria' on page 34 of: www.health.govt.nz/publication/emergency-department-use-2014-15*/
GO
