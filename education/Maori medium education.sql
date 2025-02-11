/**************************************************************************************************
Title: Maori medium participation by age
Author: Andrew Webber

Description:
Enrollment at school with indication that education is Maori medium.

Inputs & Dependencies:
	[IDI_Adhoc].[clean_read_MOE].[School_Roll_Return_20**]
Outputs:
	{none}

Notes:
1) Definition originally part of Alternative Education analysis

Parameters & Present values:
  Current refresh = {adhoc only}
  Prefix = 
  Project schema = 
 
Issues:

History (reverse order):
2025-01-21 SA: extracted from surrounding project
2023-03-06 AW: version 1
**************************************************************************************************/

SELECT snz_moe_uid
    , school_year
    , MAX(providernumber) AS srr_providernumber
    , MAX(currentyearlevel) AS currentyearlevel
    , MAX(IIF(MaoriLanguageLearning IN ('F','G','H'), 1, 0)) AS maori_medium_education
FROM(
    SELECT snz_moe_uid
        , YEAR(collectiondate) AS school_year
        , currentyearlevel
        , providernumber
        , MaoriLanguageLearning
    FROM [IDI_Adhoc].[clean_read_MOE].[School_Roll_Return_2012]

    UNION ALL
    
	SELECT snz_moe_uid
        , YEAR(collectiondate) AS school_year
        , currentyearlevel
        , providernumber
        , MaoriLanguageLearning
    FROM [IDI_Adhoc].[clean_read_MOE].[School_Roll_Return_2013]
    
	UNION ALL
    
	SELECT snz_moe_uid
        , YEAR(collectiondate) AS school_year
        , currentyearlevel
        , providernumber
        , MaoriLanguageLearning
    FROM [IDI_Adhoc].[clean_read_MOE].[School_Roll_Return_2014]
    
	UNION ALL
    
	SELECT snz_moe_uid
        , YEAR(collectiondate) AS school_year
        , currentyearlevel
        , providernumber
        , MaoriLanguageLearning
    FROM [IDI_Adhoc].[clean_read_MOE].[School_Roll_Return_2015]
    
	UNION ALL
    
	SELECT snz_moe_uid
        , YEAR(collectiondate) AS school_year
        , currentyearlevel
        , providernumber
        , MaoriLanguageLearning
    FROM [IDI_Adhoc].[clean_read_MOE].[School_Roll_Return_2016]
    
	UNION ALL
    
	SELECT snz_moe_uid
        , YEAR(collectiondate) AS school_year
        , currentyearlevel
        , providernumber
        , MaoriLanguageLearning
    FROM [IDI_Adhoc].[clean_read_MOE].[School_Roll_Return_2017]
    
	UNION ALL
    
	SELECT snz_moe_uid
        , YEAR(collectiondate) AS school_year
        , currentyearlevel
        , providernumber
        , MaoriLanguageLearning
    FROM [IDI_Adhoc].[clean_read_MOE].[School_Roll_Return_2018]
    
	UNION ALL
    
	SELECT snz_moe_uid
        , YEAR(collectiondate) AS school_year
        , currentyearlevel
        , providernumber
        , MaoriLanguageLearning
    FROM [IDI_Adhoc].[clean_read_MOE].[School_Roll_Return_2019]
    
	UNION ALL
    
	SELECT snz_moe_uid
        , YEAR(collectiondate) AS school_year
        , currentyearlevel
        , providernumber
        , MaoriLanguageLearning
    FROM [IDI_Adhoc].[clean_read_MOE].[School_Roll_Return_2020]
    
	UNION ALL
    
	SELECT snz_moe_uid
        , YEAR(collectiondate) AS school_year
        , currentyearlevel
        , providernumber
        , MaoriLanguageLearning
    FROM [IDI_Adhoc].[clean_read_MOE].[School_Roll_Return_2021]
    
	UNION ALL
    
	SELECT snz_moe_uid
        , YEAR(collectiondate) AS school_year
        , currentyearlevel
        , providernumber
        , MaoriLanguageLearning
    FROM [IDI_Adhoc].[clean_read_MOE].[School_Roll_Return_2022]
)a
GROUP BY snz_moe_uid, school_year
