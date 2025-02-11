/**************************************************************************************************
Title: School attendance
Author: Andrew Webber

Description:
School attendance divided into three categories: Present, Justified absence, Unjustified absence

Inputs & Dependencies:
	[IDI_Clean_202410].[moe_clean].[school_student_attendance]
	[IDI_Metadata].[clean_read_CLASSIFICATIONS].[moe_attendance_codes]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_school_days_attendance]

Notes:
1) Definition was originally part of Alternative Education analysis.
2) Definition sums minutes of school attended across the Term 2 dates from 2011-2021.
	Term 2 dates are used because in some years only Term 2 is reported for all schools.
3) Attendance is split into three categories (all as defined by a table in IDI metadata):
	P: Student is attending school (on-site or off-site)
	J: Student is absent for a justified reason
	U; Student is absent for an unjustified reason
	Exam leave (code X) is not included by MoE in attendance calculations. It is also not included here.
4) Attendance table moved from Adhoc to Clean databases between original project and publication
	of this definition. Original table also included ECE attendance that was filtered out.

Parameters & Present values:
  Current refresh = 202410
  Prefix = defn_
  Project schema = MAA2023-46
 
Issues:

History (reverse order):
2025-01-21 SA: extraction from surrounding analysis
2023-03-06 AW: version 1
**************************************************************************************************/

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_school_days_attendance]

SELECT b.snz_uid
    , YEAR(b.moe_ssa_attendance_date) AS school_year
    , SUM(IIF(c.reporting_category = 'P', b.moe_ssa_duration, NULL)) AS attendance_p
    , SUM(IIF(c.reporting_category = 'J', b.moe_ssa_duration, NULL)) AS attendance_j
    , SUM(IIF(c.reporting_category = 'U', b.moe_ssa_duration, NULL)) AS attendance_u
    , SUM(IIF(c.reporting_category IN ('P','J','U'), b.moe_ssa_duration, NULL)) AS attendance_total
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_school_days_attendance]
FROM [IDI_Clean_202410].[moe_clean].[school_student_attendance] b
INNER JOIN [IDI_Metadata].[clean_read_CLASSIFICATIONS].[moe_attendance_codes] c
ON b.moe_ssa_schl_attendance_code = c.school_code
-- at least one Term 2 date
WHERE b.moe_ssa_attendance_date BETWEEN '2011-05-02' AND '2011-07-15'
    OR b.moe_ssa_attendance_date BETWEEN '2012-04-23' AND '2012-06-29'
    OR b.moe_ssa_attendance_date BETWEEN '2013-05-06' AND '2013-07-12'
    OR b.moe_ssa_attendance_date BETWEEN '2014-05-05' AND '2014-07-04'
    OR b.moe_ssa_attendance_date BETWEEN '2015-04-20' AND '2015-07-03'
    OR b.moe_ssa_attendance_date BETWEEN '2016-05-02' AND '2016-07-08'
    OR b.moe_ssa_attendance_date BETWEEN '2017-05-01' AND '2017-07-07'
    OR b.moe_ssa_attendance_date BETWEEN '2018-04-30' AND '2018-07-06'
    OR b.moe_ssa_attendance_date BETWEEN '2019-04-29' AND '2019-07-05'
    OR b.moe_ssa_attendance_date BETWEEN '2020-05-17' AND '2020-07-03'
    OR b.moe_ssa_attendance_date BETWEEN '2021-05-03' AND '2021-07-09'
GROUP BY b.snz_uid
    , YEAR(b.moe_ssa_attendance_date)
