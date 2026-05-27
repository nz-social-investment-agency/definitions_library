/**************************************************************************************************
# Title: ASH and PAH 

## Module Output
**SQL:** [IDI_Community].[cm_read_ASH_PAH_ind].ASH_PAH_YYYYMM
**SAS:** libname ashpah ODBC dsn=idi_community_srvprd schema=cm_read_ASH_PAH; proc print data = ashpah.cm_read_ASH_PAH_YYYYMM; run ;

## Context:
This code defines spells where clients have had a publicly funded hospital event which is considered to be an Ambulatory Sensitive Care Hospitalisation (ASH) event or Potentially Avoidable Hospitalisation (PAH). This includes the diagnosis (ICD10 code) and the relevant ages for which it is considered an ASH/PAH event.
Ambulatory Sensitive Care Hospitalisation (ASH) conditions are health conditions for which adequate management, treatment and interventions delivered in the ambulatory care setting could potentially prevent hospitalisation. Ambulatory care refers to medical services performed on an outpatient basis, without admission to a hospital or other facility. 
A child specific PAH indicator was created under the Child Youth Wellbeing Strategy and include distinct ICD10 codes which are separate from the main ASH definition.
Potentially Avoidable Hospitalisations (PAH) is an indicator of health-related outcomes under the Child Youth Wellbeing Strategy and a Child Poverty related indicator (CPRI) required by the Child Poverty Reduction Act 2018. The Ministry of Health is required to provide PAH data as a part of ongoing annual reporting for the Strategy and the CPRI. PAH was designed to be used solely for children and there is no corresponding PAH indicator for adults.
The PAH definition includes hospitalisations that can be potentially avoided by:
* The provision of appropriate health care interventions and early disease management, usually delivered in primary care and community-based care settings
* Public health interventions, such as injury prevention, health promotion and immunisation
* Social policy interventions (such as income support and housing policy).
The expected business key for this spell dataset is one row per ASH event or PAH hospital stay, ICD10 code and version of ASH or PAH. For example, if a single hospitalisation includes 2 diagnoses (ICD10s) and there are two version of ASH, one of child ASH and one of child PAH there can be as many as 8 rows in the output data.

## Key Concepts
Both ASH and PAH are measures of the performance of the health system. They are NOT intended as indicators of whether treatment was appropriate or hospitalisations could have been prevented in any individual case. We expect some hospitalisations for each ASH/PAH condition even if the system is working optimally. For instance, of children with asthma, some may need hospitalisation even if they receive timely and appropriate diagnosis and care in the community. 
However, if the proportion increases over time, this may be an indicator that there is an issue with the availability of asthma management in primary and community care. (It may also indicate a change in other factors affecting asthma such as poor housing, circulating respiratory illness etc).
It should also be noted that a child who has several ASH/PAH events is not necessarily in poorer health than a child who has none. There are many serious childhood illnesses that are not part of the ASH definition.

## Community of Interest
|Who				|Agency					|Involvement|
|-------------------|-----------------------|---------------------------------|
|Lynley Povey |Ministry of Health	 |Steward.|				
|					|						||
|Lauren Brinck |Ministry of Health	 |SME review.|		
|					|						||
|Fiona Wild |Ministry of Health	 |SME review.|
|					|						||
|Laura Cleary |Ministry of Health	 |SME review.|				
|					|						||
|Barry Milne |Auckland University |Contributor.|
|					|						||
|Steven Johnson |Ministry of Health	 |Contributor.|				
|					|						||
|Todd Nicholson |Nicholson Consulting |Module Coder.|		

## Key Business Rules

### ASH Definition
* The main ASH definition for ages 0-4 and 45-64 has been constructed from the description used by Ministry of Health as at 2024. This includes a list of diagnosis and procedure codes and the recommended age bracket for each condition. To get this list go to: (https://www.health.govt.nz/new-zealand-health-system/accountability-and-funding/planning-and-performance-data/ambulatory-sensitive-avoidable-hospital-admissions) and download one of the excel workbooks then go to the sheet 'List of ASH Conditions'.

### PAH Definition
* The child PAH definition for ages 0-14 has been constructed using the codes provided in Table 2 and 3 of The New Zealand Medical Journal article: Anderson P, Craig E, Jackson G, Jackson C. Developing a tool to monitor potentially avoidable and ambulatory care sensitive hospitalisations in New Zealand children. NZ Med J. 2012 Nov 23;125(1366):25-37. PMID: 23254524 (pubmed.ncbi.nlm.nih.gov/23254524/)
 + Ministry of Health have supplied an updated version.

### End Date
* The [end_date] in this table is the end of the hospital visit when diagnosis took place, NOT the date that the chronic condition ended.

### Data Consistency
* Consistent counts start in July 1999. 
* As at the June 2022 refresh the data for 2019 - 2021 are incomplete.
* Advice from MoH is that the hospitalisation data in NMDS generally has a one year lag. It is recommended that you look at the count of events over time to get a clear picture of the likely completeness at any point in time.
* It is likely that the end date of the reliable period will extend as the data is updated.

### Age
* Linking the [snz_uid] to [personal.detail] resulted in a number of individuals with missing birth dates. For this reason, the age of each individual was determined using the [moh_evt_birth_year_nbr] and [moh_evt_birth_month_nbr] from [pub_fund_hosp_discharges_event]. This resulted in no undefined ages. 

### Hospitalisation
* An individual can be associated with more than one ICD10 code in a single event. This may result in two or more rows for the same hospitalisation. 
* Note that a single stay may also include two events if they happen very closely together in time.

### Child ASH/PAH
* Most Child ASH and PAH codes correspond to children aged 1 month to 14 years (pg. 28, www.journal.nzma.org.nz/journal-articles/developing-a-tool-to-monitor-potentially-avoidable-and-ambulatory-care-sensitive-hosptilisations-in-new-zealand-children), however certain vaccine preventable diseases correspond to different age groups.
* In engaging with MoH they asked that we exclude anyone born in the month of the hospitalisation or the month before that. Note that it will exclude slightly too many people because the baby will be between 30 and 60 days old before they start counting. 

### Diagnosis Definition
* In some cases you may wish to limit the definition to only include the principle (primary) diagnosis. This is done in the where clause of the first query. Official stats only include the primary diagnosis.

### Exclusions/Inclusions
* Data limited to acute and arranged admitted events, and in some cases elective is included. 
* Non-casemix events excluded.
* Note that the numbers published by Ministry of Health exclude transfers so will be lower than the numbers in the module. There is ongoing investigation into this issue to see if it can be resolved.

### Import lookup tables:
1. Expand Databases in Object Explorer. 
2. Right click on SIA_Sandpit > Tasks > Import Flat File...
3. Find location of lookup table to be imported.
4. Provide a new table name (must be identical to names above). Choose the table schema (project).
5. Modify columns
* change data type for diagnosis_code and applicable_ages to varchar(50).
* change data type for start_age_mnths, end_age_mnths, and code_char_len to int.
Note that this will require the correct permissions for this table and user. If this does not work then another alternative is a BULK INSERT.

## Parameters
The following parameters should be supplied to this module to run it in the database:
1. {targetdb}: The SQL database on which the spell dataset is to be created.
2. {targetschema}: The project schema under the target database into which the spell datasets are to be created.
3. {idicleanrefresh}: The refresh version database that you want to use.
4. {targetprefix}: Prefix

## Dependencies
```{dependencies}
{idicleanrefresh}.[moh_clean].[pub_fund_hosp_discharges_diag]
{idicleanrefresh}.[moh_clean].[pub_fund_hosp_discharges_event]
{targetdb}.{targetschema}.[moh_ASH_PAH_lookup]
```

## Outputs
```{outputs}
{targetdb}.{targetschema}.[{targetprefix}_ASH_PAH]
```

## Variable Descriptions
The business key for this spell table is one row per snz_uid, moh_dia_event_id_nbr, start_date and end_date.
|Aspect				|Variables					 |Description|
|-------------------|--------------------------------|----------------------------------------------------------|
|Entity				|snz_uid					 |A global unique identifier created by Statistics NZ. There is a snz_uid for each distinct identity in the IDI. This identifier is changed and reassigned each refresh.|
|					|							 ||
| |moh_dia_event_id_nbr	 |A Ministry of Health generated internal reference number that uniquely identifies a health event. Notes: Can be used as a key to link publicly funded hospital tables. Therefore Event ID can be used to link between this dataset and the previous one (Publicly funded hospital discharges â€“ event information). Event ID is assigned by NMDS on load, so if an event is deleted and then reloaded, a new Event ID will be assigned.|
|					|							 ||
|Source				|source_type				 |Description of the source for the ASH/PAH codes.|
|					|							 ||
|Period				|start_date				 |The date on which a healthcare event began. Notes: For more information about event start date refer to the data dictionary: http://www.health.govt.nz/publication/national-minimum-dataset-hospital-events-data-mart-data-dictionary.|
|					|							 ||
| |end_date				 |The date on which a healthcare user was discharged from a facility (i.e., the date the healthcare event ended). Notes: The event end date is also known as the discharge date. The [end_date] in this table is the end of the hospital visit when diagnosis took place, NOT the date that the chronic condition ended. For information about event end date, refer to the data dictionary: http://www.health.govt.nz/publication/national-minimum-dataset-hospital-events-data-mart-data-dictionary.|
|					|							 ||
|Event information	|moh_dia_clinical_code	 |A code used to classify the clinical description of a condition. Notes: Clinical codes are reported in NMDS using the International Statistical Classification of Diseases and Related Health Problems, Australian modification. For more information about this code refer to the data dictionary: http://www.health.govt.nz/publication/national-minimum-dataset-hospital-events-data-mart-data-dictionary.|
|					|							 ||
|					|moh_dia_diagnosis_type_code |"A" is "Principle diagnosis" and "B" is "Other relevant diagnosis". The official counts only include events based on their Principle Diagnosis.|
|					|							 ||
|					|age_mnths	 |The patients age in months.|
|					|							 ||
|					|moh_evt_dhb_dom_code |The code of the district health board responsible for the domicile.|
|					|							 ||
|					|ASH_Chapter |Categorisation used in the detailed breakdown of ASH events into diagnosis groups.|
|					|						 	 ||
|					|ASH_Condition |More detailed categorisation used in the detailed breakdown of ASH events into diagnosis groups.|
|					|						 	 ||
|					|PAH_Chapter |Categorisation used in the detailed breakdown of PAH stays into diagnosis groups.|
|					|						 	 ||
|					|PAH_Condition |More detailed categorisation used in the detailed breakdown of PAH stays into diagnosis groups.|
|					|						 	 ||
|					|moh_evt_pur_unit_text |Purchase unit indicates which contract the event was funded under. Some events have a purchase unit of 'EXCLU' (i.e., not eligible).|
|					|						 	 ||
|					|moh_evt_acc_flag_code |A flag that denotes whether a person is receiving care or treatment as the result of an accident.|
|					|						 	 ||
|					|moh_evt_adm_src_code |A code used to describe the nature of admission (routine or transfer) for a hospital inpatient health event.|
|					|						 	 ||
|					|moh_evt_facility_xfer_from_code |For transfers, the facility that the healthcare user was transferred from.|
-----------------------------------------------------------------------------------------------------------------------

### Variable Descriptions - Lookup Table
|Variables	 |Description|
|-------------------|----------------------------------------------------------|
|source_type		|Description of the source for the ASH/PAH codes.|
|					||
|diagnosis_code		|A code used to classify the clinical description of a condition.|
|					||
|applicable_ages	|The age band defined for the particular ASH/PAH code.|
|					||
|start_age_mnths	|The starting age in months.|
|					||
|end_age_mnths		|The ending age in months.|
|					||
|code_char_len		|The length of characters of the diagnosis_code.|
|					||
|include_elective	|Indicator to identify codes that include elective admitted patients.|

## Module Version & Change History
|Date		 |Version Comments|
|---------------|--------------------------------------------------------------------|
|September 2024 |TN - Add logic to match to the MoH PAH numbers.|
|				||
|June 2024		|TN - updated the header based on feedback from MoH.|
|				||
|September 2023 |TN	- change the moh_dia_clinical_sys_code exclusion to allow any number 10 or greater, add to where clause to remove 1-2 month old babies, and update the PAH part of the lookup to match list supplied by MoH.|
|				||
|June 2023		|TN - Update lookup table, exclusions, and add in more columns.|
|				||
|January 2023	|TN - Add comment about primary diagnosis.|
|				||
|October 2022	|TN - Add ASH events from 2013 NSFL dataset.|
|				||
|September 2022	|TN - Include lookup tables.|
|				||
|September 2022	|TN - Version without lookup tables.|

## Code
***********************************************************************************/

USE SIA_Sandpit
GO

DROP TABLE IF EXISTS #ASH_PAH_1 
GO

SELECT b.[snz_uid]
	 ,a.[moh_dia_event_id_nbr]
	 ,b.[moh_evt_evst_date] AS [start_date]
	 ,b.[moh_evt_even_date] AS [end_date]
	 ,a.[moh_dia_clinical_code]
	 ,b.[moh_evt_birth_month_nbr]
	 ,b.[moh_evt_birth_year_nbr]
	 ,a.[moh_dia_diagnosis_type_code] /* to identify if principle diagnosis or other relevant diagnosis - in practice, the principle diagnosis is usually the initial diagnosis on the discharge. */
	 ,case	when b.moh_evt_adm_type_code in ('AP','WN','WP','ZW') then 1 else 0 end as elective_ind /* elective admission type */
	 ,case when b.moh_evt_adm_type_code in ('AA','AC','ZA','WU','RL','ZC') then 1 else 0 end as acute_ind /* this is both acute and arranged admission type */
	 ,b.moh_evt_purchaser_code /* how the event is funded - district, MOH, accredited employers, ACC, etc. District/MOH funded is 20, 34 and 35 */
	 ,b.[moh_evt_dhb_dom_code] /* to identify the domicile of the patient (domicile of residence) - overseas and unknown for ASH / PAH definition is excluded */
	 ,case when b.[moh_evt_hlth_spec_code] in ('M80','M81') then 1 else 0 end as palliative_care_ind /* identify events where the health specialty is palliative care - part of the 2013 ASH definition */
	 ,case when b.[moh_evt_hlth_spec_code] in ('M05','M06','M07','M08') and b.moh_evt_los_nbr <= 1 then 1 else 0 end as ed_shortstay /* identify events where health specialty is ED and length of stay is less than 1 (short stay) - part of the 2013 ASH definition */
	 /*Determine the age (in months) of the individual at time of event*/
	 ,DATEDIFF(month, (DATEFROMPARTS(b.[moh_evt_birth_year_nbr], b.[moh_evt_birth_month_nbr], 15)), b.[moh_evt_evst_date]) AS age_mnths
	 ,b.[moh_evt_pur_unit_text]
	 ,b.[moh_evt_acc_flag_code]
	 ,b.[moh_evt_adm_src_code]
	 ,b.[moh_evt_facility_xfer_from_code]
INTO #ASH_PAH_1	 
FROM [IDI_Clean_202506].[moh_clean].[pub_fund_hosp_discharges_diag] a
/*Join to discharges_events to determine snz_uid and age of each individual.*/
	INNER JOIN [IDI_Clean_202506].[moh_clean].[pub_fund_hosp_discharges_event] as b
		ON a.[moh_dia_event_id_nbr] = b.[moh_evt_event_id_nbr]
WHERE a.[moh_dia_submitted_system_code] = a.[moh_dia_clinical_sys_code] /* higher accuracy when systems match */
/* diagnosis in ICD10 */
	AND (a.[moh_dia_diagnosis_type_code] IN ('A', 'B') /*"A" is "Principle diagnosis" and "B" is "Other relevant diagnosis" */
	AND CAST(a.[moh_dia_clinical_sys_code] AS INTEGER) >= 10 /* ICD-10-AM - First, second, third, sixth, eighth etc edition*/
	AND DATEDIFF(month, (DATEFROMPARTS(b.[moh_evt_birth_year_nbr], b.[moh_evt_birth_month_nbr], 15)), b.[moh_evt_evst_date]) >= 2) /*The official counts exclude people less than 28 days old. We cant do exactly the same exclusion but MoH have decided on this approximation*/
	AND b.moh_evt_pur_unit_text <> 'EXCLU'
	AND b.[moh_evt_dhb_dom_code] < 999
GO

/* Clear before creation */
DROP TABLE IF EXISTS #ASH_PAH
GO

SELECT [snz_uid]
	 ,[moh_dia_event_id_nbr]
	 ,[start_date]
	 ,[end_date]
	 ,[moh_dia_clinical_code]
	 ,[moh_dia_diagnosis_type_code]
	 ,[source_type]
	 ,[age_mnths]
	 ,[moh_evt_dhb_dom_code]
	 ,ASH_Chapter
	 ,ASH_Condition
	 ,PAH_Category
	 ,PAH_SubCategory
	 ,[moh_evt_pur_unit_text]
	 ,[moh_evt_acc_flag_code]
	 ,[moh_evt_adm_src_code]
	 ,[moh_evt_facility_xfer_from_code]
INTO #ASH_PAH
/* The following table is a lookup table.*/
FROM (
	SELECT a.[snz_uid]
		 ,a.[moh_dia_event_id_nbr]
		 ,a.[start_date]
		 ,a.[end_date]
		 ,a.[moh_dia_clinical_code]
		 ,b.[source_type] as source_type
		 ,b.[include_elective]
		 ,a.elective_ind
		 ,a.acute_ind
		 ,a.moh_evt_purchaser_code
		 ,a.age_mnths
		,a.[moh_dia_diagnosis_type_code]
		,a.[moh_evt_dhb_dom_code]
		,case when b.include_elective = 0 and a.elective_ind = 1 then 1 else 0 end as remove_evts /* Purpose of this is to include dental events that are elective as per the definition. All other events are acutely admitted into hospital. */
		,case when a.palliative_care_ind = 1 then 1 else 0 end as pallcare_2013_excl
		,case when a.ed_shortstay = 1 then 1 else 0 end as edstay_2013_excl
		,b.ASH_Chapter
		,b.ASH_Condition
		,b.PAH_Category
		,b.PAH_SubCategory
		,a.[moh_evt_pur_unit_text]
		,a.[moh_evt_acc_flag_code]
		,a.[moh_evt_adm_src_code]
		,a.[moh_evt_facility_xfer_from_code]
	FROM #ASH_PAH_1 a
	LEFT JOIN [IDI_Metadata].[clean_read_CLASSIFICATIONS].[moh_ASH_PAH_lookup] b 
			ON SUBSTRING(a.[moh_dia_clinical_code], 1, 3) = b.[diagnosis_code]
			AND b.code_char_len = 3
			AND a.age_mnths between b.start_age_mnths and b.end_age_mnths
	WHERE SUBSTRING(a.[moh_dia_clinical_code], 1, 3) = b.[diagnosis_code]
) y
WHERE remove_evts = 0 
GO

/*Required to insert 4 length ICD10 codes seperately from 3. There are identical 3 and 4 letter [diagnosis_code] (ex. B18 and B181) which become single events when doing a LEFT JOIN. */
INSERT INTO #ASH_PAH
SELECT [snz_uid]
	 ,[moh_dia_event_id_nbr]
	 ,[start_date]
	 ,[end_date]
	 ,[moh_dia_clinical_code]
	 ,[moh_dia_diagnosis_type_code]
	 ,[source_type]
	 ,[age_mnths]
	 ,[moh_evt_dhb_dom_code]
	 ,ASH_Chapter
	 ,ASH_Condition
	 ,PAH_Category
	 ,PAH_SubCategory
	 ,[moh_evt_pur_unit_text]
	 ,[moh_evt_acc_flag_code]
	 ,[moh_evt_adm_src_code]
	 ,[moh_evt_facility_xfer_from_code]
FROM (
	SELECT a.[snz_uid]
		,a.[moh_dia_event_id_nbr]
		,a.[start_date]
		,a.[end_date]
		,a.[moh_dia_clinical_code]
		,c.[source_type] as source_type
		,c.[include_elective]
		,a.elective_ind
		,a.acute_ind
		,a.moh_evt_purchaser_code
		,a.age_mnths
		,a.[moh_dia_diagnosis_type_code]
		,a.[moh_evt_dhb_dom_code]
		,case when c.include_elective = 0 and a.elective_ind = 1 then 1 else 0 end as remove_evts	/* Purpose of this is to include dental events that are elective as per the definition. All other events are acutely admitted into hospital. */
		,case when a.palliative_care_ind = 1 then 1 else 0 end as pallcare_2013_excl 
		,case when a.ed_shortstay = 1 then 1 else 0 end as edstay_2013_excl
		,c.ASH_Chapter
		,c.ASH_Condition
		,c.PAH_Category
		,c.PAH_SubCategory
		,a.[moh_evt_pur_unit_text]
		,a.[moh_evt_acc_flag_code]
		,a.[moh_evt_adm_src_code]
		,a.[moh_evt_facility_xfer_from_code]
	FROM #ASH_PAH_1 a
		LEFT JOIN [IDI_Metadata].[clean_read_CLASSIFICATIONS].[moh_ASH_PAH_lookup] c
			ON SUBSTRING(a.[moh_dia_clinical_code], 1, 4) = c.[diagnosis_code]
			AND c.code_char_len = 4
			AND a.age_mnths between c.start_age_mnths and c.end_age_mnths
	WHERE SUBSTRING(a.[moh_dia_clinical_code], 1, 4) = c.[diagnosis_code]
) x
WHERE remove_evts = 0 
GO

/* Add index */
--CREATE CLUSTERED INDEX my_index_name ON #ASH_PAH ([snz_uid])
/* Compress final table to save space */
--ALTER TABLE #ASH_PAH REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
/*For PAH we need to do a bit more processing to add injuries and to deal with transfers*/
/*Start by isolating the PAH events we have so far*/
DROP TABLE IF EXISTS #PAH_only
GO

SELECT *
INTO #PAH_only
FROM #ASH_PAH
WHERE source_type = 'child_PAH' and moh_dia_diagnosis_type_code = 'A' and moh_evt_acc_flag_code <> 'Y'
GO

/*Identify the injuries for PAH. These rely on Ecodes so have to be done seperately.*/
DROP TABLE IF EXISTS #ASH_PAH_1_inj	 
GO

SELECT b.[snz_uid]
	,a.[moh_dia_event_id_nbr]
	,b.[moh_evt_evst_date] AS [start_date]
	,b.[moh_evt_even_date] AS [end_date]
	,a.[moh_dia_clinical_code]
	,b.[moh_evt_birth_month_nbr]
	,b.[moh_evt_birth_year_nbr]
	,a.[moh_dia_diagnosis_type_code] /* to identify if principle diagnosis or other relevant diagnosis - in practice, the principle diagnosis is usually the initial diagnosis on the discharge. */
	,case	when b.moh_evt_adm_type_code in ('AP','WN','WP','ZW') then 1 else 0 end as elective_ind /* elective admission type */
	,case when b.moh_evt_adm_type_code in ('AA','AC','ZA','WU','RL','ZC') then 1 else 0 end as acute_ind /* this is both acute and arranged admission type */
	,b.moh_evt_purchaser_code /* how the event is funded - district, MOH, accredited employers, ACC, etc. District/MOH funded is 20, 34 and 35 */
	,b.[moh_evt_dhb_dom_code] /* to identify the domicile of the patient (domicile of residence) - overseas and unknown for ASH / PAH definition is excluded */
	,case when b.[moh_evt_hlth_spec_code] in ('M80','M81') then 1 else 0 end as palliative_care_ind /* identify events where the health specialty is palliative care - part of the 2013 ASH definition */
	,case when b.[moh_evt_hlth_spec_code] in ('M05','M06','M07','M08') and b.moh_evt_los_nbr <= 1 then 1 else 0 end as ed_shortstay /* identify events where health specialty is ED and length of stay is less than 1 (short stay) - part of the 2013 ASH definition */
	/*Determine the age (in months) of the individual at time of event*/
	,DATEDIFF(month, (DATEFROMPARTS(b.[moh_evt_birth_year_nbr], b.[moh_evt_birth_month_nbr], 15)), b.[moh_evt_evst_date]) AS age_mnths
	,b.[moh_evt_pur_unit_text]
	,b.[moh_evt_acc_flag_code]
	,b.[moh_evt_adm_src_code]
	,b.[moh_evt_facility_xfer_from_code]
INTO #ASH_PAH_1_inj
FROM [IDI_Clean_202506].[moh_clean].[pub_fund_hosp_discharges_diag] a
	INNER JOIN [IDI_Clean_202506].[moh_clean].[pub_fund_hosp_discharges_event] as b
		ON a.[moh_dia_event_id_nbr] = b.[moh_evt_event_id_nbr]
WHERE a.[moh_dia_submitted_system_code] = a.[moh_dia_clinical_sys_code] /* higher accuracy when systems match */
/* diagnosis in ICD10 */
	AND (a.[moh_dia_diagnosis_type_code] IN ('E') /*"A" is "Principle diagnosis" and "B" is "Other relevant diagnosis" */
	AND CAST(a.[moh_dia_clinical_sys_code] AS INTEGER) >= 10 /* ICD-10-AM - First, second, third, sixth, eighth etc edition*/
	AND DATEDIFF(month, (DATEFROMPARTS(b.[moh_evt_birth_year_nbr], b.[moh_evt_birth_month_nbr], 15)), b.[moh_evt_evst_date]) >= 2) /*The official counts exclude people less than 28 days old. We cant do exactly the same exclusion but MoH have decided on this approximation*/
	AND b.moh_evt_pur_unit_text <> 'EXCLU'
	AND b.[moh_evt_dhb_dom_code] < 990
GO

/*Add in the Injuries and classify them as Intentional or Unintentional*/
INSERT INTO #PAH_only
SELECT [snz_uid]
	 ,[moh_dia_event_id_nbr]
	 ,[start_date]
	 ,[end_date]
	 ,[moh_dia_clinical_code]
	 ,[moh_dia_diagnosis_type_code]
	 ,[source_type]
	 ,[age_mnths]
	 ,[moh_evt_dhb_dom_code]
	 ,ASH_Chapter
	 ,ASH_Condition
	 ,PAH_Category
	 ,PAH_SubCategory
	 ,[moh_evt_pur_unit_text]
	 ,[moh_evt_acc_flag_code]
	 ,[moh_evt_adm_src_code]
	 ,[moh_evt_facility_xfer_from_code]
FROM (
	SELECT [snz_uid]
		,[moh_dia_event_id_nbr]
		,[start_date]
		,[end_date]
		,[moh_dia_clinical_code]
		,'child_PAH ' as source_type
		,1 as [include_elective]
		,elective_ind
		,acute_ind
		,moh_evt_purchaser_code
		,age_mnths
		,[moh_dia_diagnosis_type_code]
		,[moh_evt_dhb_dom_code]
		,0 as remove_evts	
		,0 as pallcare_2013_excl 
		,0 as edstay_2013_excl
		,'' as ASH_Chapter
		,'' as ASH_Condition
		,[moh_evt_adm_src_code]
		,[moh_evt_facility_xfer_from_code]
		,case 
			when (moh_dia_clinical_code between 'X60' and 'X84' or
				(SUBSTRING([moh_dia_clinical_code], 1, 4) = 'Y870') or
				moh_dia_clinical_code between 'X85' and 'X99' or
				moh_dia_clinical_code between 'Y0000' and 'Y0909' or
				(SUBSTRING([moh_dia_clinical_code], 1, 3) = 'Y871') or
				moh_dia_clinical_code between 'X9900' and 'X9999' or
				moh_dia_clinical_code between 'Y3501' and 'Y3699' or
				(SUBSTRING([moh_dia_clinical_code], 1, 3) = 'Y890') or
				(SUBSTRING([moh_dia_clinical_code], 1, 3) = 'Y891')) then 'Intentional injuries'
			when (SUBSTRING([moh_dia_clinical_code], 1, 4) = 'Y870') then 'Intentional injuries'
			else 'Unintentional injuries'
			end as PAH_Category
		,case 
			when (moh_dia_clinical_code between 'X60' and 'X84' or
				(SUBSTRING([moh_dia_clinical_code], 1, 4) = 'Y870') or
				moh_dia_clinical_code between 'X85' and 'X99' or
				moh_dia_clinical_code between 'Y0000' and 'Y0909' or
				(SUBSTRING([moh_dia_clinical_code], 1, 3) = 'Y871') or
				moh_dia_clinical_code between 'X9900' and 'X9999' or
				moh_dia_clinical_code between 'Y3501' and 'Y3699' or
				(SUBSTRING([moh_dia_clinical_code], 1, 3) = 'Y890') or
				(SUBSTRING([moh_dia_clinical_code], 1, 3) = 'Y891')) then 'Intentional injuries'
			else 'Unintentional injuries'
			end as PAH_SubCategory
		,[moh_evt_pur_unit_text]
		,[moh_evt_acc_flag_code]
	FROM #ASH_PAH_1_inj	 
	WHERE (
		(moh_dia_clinical_code between 'V010' and 'V899') or 
		(moh_dia_clinical_code between 'V910' and 'V919') or 
		(moh_dia_clinical_code between 'V930' and 'V978') or 
		(SUBSTRING([moh_dia_clinical_code], 1, 3) = 'V98') or 
		(SUBSTRING([moh_dia_clinical_code], 1, 3) = 'V99') or
		(SUBSTRING([moh_dia_clinical_code], 1, 4) = 'Y850') or 
		(SUBSTRING([moh_dia_clinical_code], 1, 4) = 'Y859') or 
		(moh_dia_clinical_code between 'W00' and 'W19') or 
		(moh_dia_clinical_code between 'X00' and 'X19') or 
		(moh_dia_clinical_code between 'W65' and 'W74') or 
		(moh_dia_clinical_code between 'V900' and 'V909') or 
		(moh_dia_clinical_code between 'V920' and 'V929') or 
		(moh_dia_clinical_code between 'X40' and 'X49') or 
		(moh_dia_clinical_code between 'W200' and 'W490') or 
		(moh_dia_clinical_code between 'W530' and 'W598') or 
		(moh_dia_clinical_code between 'W610' and 'W619') or 
		(moh_dia_clinical_code between 'X200' and 'X278') or 
		(SUBSTRING([moh_dia_clinical_code], 1, 3) = 'X29') or
		(SUBSTRING([moh_dia_clinical_code], 1, 3) = 'X50') or
		(SUBSTRING([moh_dia_clinical_code], 1, 3) = 'X58') or
		(SUBSTRING([moh_dia_clinical_code], 1, 3) = 'X59') or
		(SUBSTRING([moh_dia_clinical_code], 1, 3) = 'Y86') or
		(SUBSTRING([moh_dia_clinical_code], 1, 4) = 'Y899') or
		(moh_dia_clinical_code between 'X60' and 'X84') or 
		(SUBSTRING([moh_dia_clinical_code], 1, 4) = 'Y870') or
		(moh_dia_clinical_code between 'X85' and 'X99') or 
		(moh_dia_clinical_code between 'Y0000' and 'Y0909') or 
		(SUBSTRING([moh_dia_clinical_code], 1, 4) = 'Y871') or
		(moh_dia_clinical_code between 'X9900' and 'X9999') or 
		(moh_dia_clinical_code between 'Y3501' and 'Y369') or 
		(SUBSTRING([moh_dia_clinical_code], 1, 4) = 'Y890') or
		(SUBSTRING([moh_dia_clinical_code], 1, 4) = 'Y891') or
		(moh_dia_clinical_code between 'Y400' and 'Y849') or 
		(moh_dia_clinical_code between 'Y880' and 'Y883') or
		(SUBSTRING([moh_dia_clinical_code], 1, 3) = 'Y95') or 
		(SUBSTRING([moh_dia_clinical_code], 1, 4) = 'U900') or
		(moh_dia_clinical_code between 'Y10' and 'Y34') or
		(SUBSTRING([moh_dia_clinical_code], 1, 4) = 'Y872')
	)
	and [moh_evt_acc_flag_code] = 'Y'
) as a
GO

/*Identify transfers by look for events that are in the same PAH_Category and start on the same day the previous one ended*/
/*Firstly lag the variables required*/
DROP TABLE IF EXISTS #PAH_lag
GO

SELECT *,
	lag([snz_uid]) over(order by [snz_uid], [PAH_Category], [start_date]) as prev_snz_uid, 
	lag([PAH_Category]) over(order by [snz_uid], [PAH_Category], [start_date]) as prev_PAH_Category,
	lag([end_date]) over(order by [snz_uid], [PAH_Category], [start_date]) as prev_end_date
INTO #PAH_lag
FROM #PAH_only
GO

/*Identify the transfer and flag it*/
DROP TABLE IF EXISTS #PAH_lag_trans
GO

SELECT *
	, case when snz_uid = prev_snz_uid
		and PAH_Category = prev_PAH_Category
			and start_date <= [prev_end_date]
			and moh_evt_adm_src_code = 'T'
			and moh_evt_facility_xfer_from_code is not NULL
		then 1
		else 0
	end as trans
INTO #PAH_lag_trans
FROM #PAH_lag
GO

/*Remove the transfers*/
DROP TABLE IF EXISTS #PAH_final
GO

SELECT *
INTO #PAH_final 
FROM #PAH_lag_trans
WHERE trans = 0
GO

/*Write the proper table*/
DROP TABLE IF EXISTS #final_ASH_PAH
GO

SELECT [snz_uid]
	 ,[moh_dia_event_id_nbr]
	 ,[start_date]
	 ,[end_date]
	 ,[moh_dia_clinical_code]
	 ,[moh_dia_diagnosis_type_code]
	 ,CAST('child_PAH' as varchar(19)) as source_type
	 ,[age_mnths]
	 ,[moh_evt_dhb_dom_code]
	 ,ASH_Chapter
	 ,ASH_Condition
	 ,PAH_Category
	 ,PAH_SubCategory
	 ,[moh_evt_pur_unit_text]
	 ,[moh_evt_acc_flag_code]
	 ,[moh_evt_adm_src_code]
	 ,[moh_evt_facility_xfer_from_code]
INTO #final_ASH_PAH
FROM #PAH_final
GO

/*Put the ASH ones in too*/
INSERT INTO #final_ASH_PAH
SELECT [snz_uid]
	 ,[moh_dia_event_id_nbr]
	 ,[start_date]
	 ,[end_date]
	 ,[moh_dia_clinical_code]
	 ,[moh_dia_diagnosis_type_code]
	 ,[source_type]
	 ,[age_mnths]
	 ,[moh_evt_dhb_dom_code]
	 ,ASH_Chapter
	 ,ASH_Condition
	 ,PAH_Category
	 ,PAH_SubCategory
	 ,[moh_evt_pur_unit_text]
	 ,[moh_evt_acc_flag_code]
	 ,[moh_evt_adm_src_code]
	 ,[moh_evt_facility_xfer_from_code]
FROM #ASH_PAH
WHERE source_type <> 'child_PAH'
GO

DROP TABLE IF EXISTS [SIA_Sandpit].[DL-MAA2023-46].[defn_ASH_PAH_202506]
GO
 
CREATE TABLE [SIA_Sandpit].[DL-MAA2023-46].[defn_ASH_PAH_202506] (
	snz_uid int NOT NULL,
	moh_dia_event_id_nbr int NOT NULL,
	[start_date] date NULL,
	end_date date NULL,
	moh_dia_clinical_code varchar(8) NULL,
	moh_dia_diagnosis_type_code char(1) NULL,
	source_type varchar(19) NOT NULL, 
	age_mnths int NULL,
	moh_evt_dhb_dom_code char(3) NULL,
	ASH_Chapter varchar(100) NULL,
	ASH_Condition varchar(100) NULL,
	PAH_Category varchar(100) NULL,
	PAH_SubCategory varchar(100) NULL,
	moh_evt_pur_unit_text varchar(10) NULL,
	moh_evt_acc_flag_code char(1) NULL,
	moh_evt_adm_src_code char(1) NULL,
	moh_evt_facility_xfer_from_code char(4) NULL
)
GO

INSERT INTO [SIA_Sandpit].[DL-MAA2023-46].[defn_ASH_PAH_202506] (
	snz_uid,
	moh_dia_event_id_nbr,
	[start_date],
	end_date,
	moh_dia_clinical_code,
	moh_dia_diagnosis_type_code,
	source_type, 
	age_mnths,
	moh_evt_dhb_dom_code,
	ASH_Chapter,
	ASH_Condition,
	PAH_Category,
	PAH_SubCategory,
	moh_evt_pur_unit_text,
	moh_evt_acc_flag_code,
	moh_evt_adm_src_code,
	moh_evt_facility_xfer_from_code
)
SELECT *
FROM #final_ASH_PAH
GO

/* Add index */
CREATE NONCLUSTERED INDEX my_index_name ON [SIA_Sandpit].[DL-MAA2023-46].[defn_ASH_PAH_202506] (snz_uid)
GO
