/****************************************
Budget 25 initiaves

Cohort: Children who are stood down / suspended (before age 12)

Outcomes: Improve attendance, transience, youth crime

NOTES
- Numbers plateau around 2006, but extend further back, choosing year 2000 as the first cohort of 12 year olds to look at
- Creating one table to reduce size
- CR updated refresh to 202510 -> 2026/01/12
- CF updated to refresh 202603 -> 2026/04/01


*****************************************/

-- :SETVAR PROJECT_DB "SIA_Sandpit"
-- :SETVAR PROJECT_SCHEMA "DL-MAA2026-04"
-- :SETVAR REFRESH "202603"

/* DEFINITION */

USE IDI_USERCODE;
GO

DROP VIEW IF EXISTS [$(PROJECT_SCHEMA)].[cohort_SSEE_$(REFRESH)]; -- stand-downs, suspensions, exclusions & expulsions
GO

CREATE VIEW [$(PROJECT_SCHEMA)].[cohort_SSEE_$(REFRESH)] AS 
WITH first_ssee AS (

	SELECT a.snz_uid
		, a.moe_inv_start_date as [start_date]
		, CAST (a.moe_inv_inst_num_code AS INT) AS moe_inv_inst_num_code 
		, CASE
			WHEN a.moe_inv_end_date > GETDATE() THEN GETDATE() 
			ELSE a.moe_inv_end_date
			END AS enddate
		, 1 AS sd_sus
		, ROW_NUMBER() OVER (PARTITION BY snz_uid ORDER BY moe_inv_start_date) AS n
	FROM [IDI_Clean_$(REFRESH)].[moe_clean].[student_interventions] AS a
	WHERE a.moe_inv_intrvtn_code IN (7,8) -- code standdown = 8, suspension = 7

)
SELECT s.snz_uid	
	, s.start_date as cohort_start
	, DATEADD(YEAR,18,pd.snz_birth_date_proxy) as cohort_end
	, moe_inv_inst_num_code
FROM first_ssee AS s
LEFT JOIN [IDI_Clean_$(REFRESH)].[data].[personal_detail] AS pd
	ON pd.snz_uid = s.snz_uid
WHERE n = 1
	AND s.[start_date] < DATEADD(YEAR, 13, pd.snz_birth_date_proxy);
