/**************************************************************************************************
Title: Fiscal costs - National non-admitted patient services
Author: Craig Wright

Inputs & Dependencies:
	[IDI_Sandpit].[DL-MAA2023-46].[ref_MoH_purchase_unit_pricing]
	[IDI_Clean_202410].[moh_clean].[nnpac]
	[IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods]
Outputs:
	[IDI_Sandpit].[DL-MAA2023-46].[defn_cost_nonadmitted_hospital]

Description:
The purpose of this cost is to estimate costs incurred in hospitals delivering national non-admitted patient services to individuals.

Notes:
- Non-admitted patient services includes
	- Emergency department admissions (ED)
	- Outpatient services (OP)
	- Community outreach (eg nursing outreach) undertaken by hospital staff (CR). 
	The cost of each of these activities (ED/OP/CR) are split out in the final table, via the 'source' field.

- This relies on information collected in the nnpac table, combined with the purchase unit prices that were separately sourced
	from MoH (in previous work to populate the Social Investment Analytical Layer). This has the substantial limitation that the
	latest purchase unit prices in this data are for 2017.  

- Costs are adjusted to 2024 values using CPI data
	Ideally we would use the pu price relating to the year the service was actually undertaken (ie 2019-2023), and then
	inflate the cost from that year to 2024 dollars. However, we only currently have access to 2017 prices.

Parameters & Present values:
	Refresh = 202410
	Prefix = defn_cost_
	Project schema = [DL-MAA2023-46]
 
Issues:

History (reverse order):
2024-11-13	AW	Adding documentation
2024-11-11	CW	Initial creation
**************************************************************************************************/

---------------------------------------------------------------------
-- Prepare unit pricing

DROP TABLE IF EXISTS #epu_price
GO

--Some pu codes have values of 0 for the 2016/17 year. To fill these in, extract the maximum value across the whole time series:
WITH epu_price_2017 AS(

    SELECT [pu_code], [pu_price] AS pu_price_2017
    FROM [IDI_Sandpit].[DL-MAA2023-46].[ref_MoH_purchase_unit_pricing]
    WHERE fin_year = '2016/17'

), 
epu_price_max AS(
    
    SELECT [pu_code]
        , MAX([pu_price])pu_price_max
    FROM [IDI_Sandpit].[DL-MAA2023-46].[moh_primhd_pu_pricing]
    GROUP BY [pu_code]

)
--Combine both tables, preferring the 2017 value where it is non-zero and taking the max price otherwise
SELECT a.pu_code
    , IIF(b.pu_price_2017 = 0 OR b.pu_price_2017 IS NULL, a.pu_price_max, b.pu_price_2017) AS pu_price
INTO #epu_price
FROM epu_price_max AS a
LEFT JOIN epu_price_2017 AS b
ON a.pu_code = b.pu_code

---------------------------------------------------------------------
-- Cost NNPAC

DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_nonadmitted_hospital]
GO

WITH setup AS (

SELECT [snz_uid]
    , [moh_nnp_attendence_code]
    , [moh_nnp_event_type_code] AS source
    , YEAR([moh_nnp_service_date])AS cal_year
    , [moh_nnp_service_date] AS date
    , [moh_nnp_purchase_unit_code]
    , [moh_nnp_volume_amt] AS volume
    , b.pu_price AS pu_price_2017
    , [moh_nnp_volume_amt]*b.pu_price AS cost
	  /* Where the PU contains "ED" and "A" (eg "ED00002A"), this denotes instances where someone is admitted to hospital via ED
	  These events are separately costed in the public hospital table (WEIS casemix method) and the cost should not be counted
	  here because that would double count. We have left them in this table, but there are no ED-A codes in the pricing table, so 
	  these events are assigned NULL costs in this table. This allows us to count the events (as ED admissions), but not double
	  count the expenditure. We can differentiate these events in this table using the below method field. */
    , CASE WHEN [moh_nnp_purchase_unit_code] LIKE '%ED%' AND [moh_nnp_purchase_unit_code] LIKE '%A%' THEN 'WIES' ELSE 'NNP' END method
FROM [IDI_Clean_202410].[moh_clean].[nnpac] AS a
LEFT JOIN #epu_price AS b
ON a.[moh_nnp_purchase_unit_code] = b.[pu_code]
WHERE YEAR([moh_nnp_service_date]) IN (2019,2020,2021,2022,2023)

)
--Adjust nominal costs to real (2024 dollars) based on CPI
SELECT a.snz_uid
    , a.source
    , a.cal_year
    , COUNT(*) AS value
    , SUM(cost*cpi_adj_2024) AS cost_real
INTO [IDI_Sandpit].[DL-MAA2023-46].[defn_cost_nonadmitted_hospital]
FROM setup a
LEFT JOIN [IDI_Sandpit].[DL-MAA2023-46].[ref_cpi_all_goods] AS b
ON b.cal_year = 2017
GROUP BY snz_uid
    , source
    , a.cal_year
