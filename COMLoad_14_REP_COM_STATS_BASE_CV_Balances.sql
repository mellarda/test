-- BEGIN HEADER
----------------------------------------------------------------------------------------------------
-- NAME		: COMLoadREP_COM_STATS_BASE.sql
-- TYPE		: Data loading sql script
-- AUTHOR	: Craig Young	
-- CREATED	: 28/06/2013		
-- VERSION	: 1.0
-- PURPOSE	: 
-- NOTES	: Tables Amended:  	
--		: Tables Used	:   
---------------------------------------------------------------------------------------------------
-- DATE			DEVELOPER			DESCRIPTION
---------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------
-- END HEADER


-- Creating temporary table to store dash data
CREATE SET VOLATILE  TABLE #VT_STATS_BASE_BALANCE ,NO FALLBACK ,
     CHECKSUM = DEFAULT,
     NO LOG
     (
     STATS_DATE_CH CHAR(6)    CHARACTER SET LATIN CASESPECIFIC NOT NULL,
     VIEW_TYPE     CHAR(2)    CHARACTER SET LATIN CASESPECIFIC NOT NULL,
     UNIT_CODE     VARCHAR(8) CHARACTER SET LATIN CASESPECIFIC NOT NULL,
     STATS_CODE    CHAR(8)    CHARACTER SET LATIN CASESPECIFIC NOT NULL,
     CUST_STATUS   CHAR(1)    CHARACTER SET LATIN CASESPECIFIC NOT NULL,
     CUST_TYPE     CHAR(1)    CHARACTER SET LATIN CASESPECIFIC NOT NULL,
     RM_TYPE       CHAR(1)    CHARACTER SET LATIN CASESPECIFIC NOT NULL,
     PROD_GROUP    CHAR(4)    CHARACTER SET LATIN CASESPECIFIC NOT NULL,                             
     XVALUE        FLOAT
     )
UNIQUE PRIMARY INDEX ( STATS_DATE_CH, UNIT_CODE, STATS_CODE, CUST_STATUS, CUST_TYPE, RM_TYPE, PROD_GROUP)
ON COMMIT PRESERVE ROWS;


------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE SET VOLATILE  TABLE #VT_DATES ,NO FALLBACK ,
     CHECKSUM = DEFAULT,
     NO LOG
     (
     MONTH_NUM     INTEGER,
     PROD_DATE_CH  CHAR(6) CHARACTER SET LATIN CASESPECIFIC,
     PROD_DATE     DATE FORMAT 'YYYY/MM/DD'
     )
PRIMARY INDEX (PROD_DATE_CH)
ON COMMIT PRESERVE ROWS;


-- First step, insert numeric values 0 to 35 into dates table so we can calculate months from it
INSERT INTO
  #VT_DATES (MONTH_NUM)
WITH RECURSIVE RecTable (xStart) AS
  (
  SELECT
    1
  FROM
    REP_COM_CONTROL
  UNION ALL
  SELECT
    xStart+1
  FROM
    RecTable, 
    REP_COM_CONTROL
  WHERE
    xStart < 36
  )
SELECT
  xStart - 1
FROM
  RecTable;


-- Now update month value based on subtracting the number of months in the first column from the current control date
UPDATE
  #VT_DATES
SET
  PROD_DATE = ADD_MONTHS((SELECT PROD_DATE FROM REP_COM_CONTROL),-MONTH_NUM+1) - EXTRACT(DAY FROM ADD_MONTHS((SELECT PROD_DATE FROM REP_COM_CONTROL),-MONTH_NUM+1));


-- Now update month_ch value based on converting the date field into a char in YYYYMM format
UPDATE
  #VT_DATES
SET
  PROD_DATE_CH = CAST(EXTRACT(YEAR FROM PROD_DATE) AS CHAR(4)) || CASE WHEN CHARACTER_LENGTH(CAST(EXTRACT(MONTH FROM PROD_DATE) AS VARCHAR(2))) = 1 THEN '0' || CAST(EXTRACT(MONTH FROM PROD_DATE) AS VARCHAR(2))
                                                                       ELSE CAST(EXTRACT(MONTH FROM PROD_DATE) AS VARCHAR(2))
                                                                       END;


COLLECT STATS ON #VT_DATES COLUMN (PROD_DATE_CH);
COLLECT STATS ON #VT_DATES COLUMN (PROD_DATE);


------------------------------------------------------------------------------------------------------------------------------------------------------------


-- Inserting Balance on Assets 
INSERT INTO
  #VT_STATS_BASE_BALANCE 
SELECT
  D.PROD_DATE_CH,
  'CV',
  COALESCE(B.STAF_NO,B.COST_CTR_CDE,'NONE'),
  'BALOASST',
  CUST_STA,
  INTL_DMST_CST_FLAG,
  CASE WHEN LSD_SPSA_OTH_FLAG = 'L' THEN 'I' ELSE 'R' END,
  'XXXX',
  SUM(AVG_FUNDS_USE_RSE * EXTRACT(DAY FROM D.PROD_DATE))
FROM
  INA_COM_CUST_DETL A
INNER JOIN 
  INA_COM_CUST_SEG B 
ON 
  A.IP_ID = B.IP_ID 
INNER JOIN
  REP_CMB_PROD_HIER E
ON
  A.PROD_CDE = E.PROD_CDE
INNER JOIN
  REP_CMB_PROD_GRP F
ON
  E.PROD_GROUP_CODE = F.PROD_GROUP_CODE,
  #VT_DATES D,
  REP_COM_CONTROL G
WHERE
  A.SMRY_PRD_ENDT = D.PROD_DATE
AND
  B.SMRY_PRD_ENDT = G.PROD_DATE
AND
  B.CUST_STA IN ('N','C','E')
AND
  B.INTL_DMST_CST_FLAG IN ('I','D')
-- changes for BID2855
--AND
--  E.REC_EDT > D.PROD_DATE
--AND
--  F.REC_EDT > D.PROD_DATE
--AND
--  E.REC_ACDT <= D.PROD_DATE
--AND
--  F.REC_ACDT <= D.PROD_DATE
AND
  E.REC_EDT = '9999-12-31'
AND
  F.REC_EDT = '9999-12-31'
--end of changes for bid2855
AND
  F.ASET_FLAG_IND = 'Y'
AND
  B.SEG_GROUP_CDE <> 'A00003'
GROUP BY
  D.PROD_DATE_CH,
  COALESCE(B.STAF_NO,B.COST_CTR_CDE,'NONE'),
  CUST_STA,
  INTL_DMST_CST_FLAG,
  CASE WHEN LSD_SPSA_OTH_FLAG = 'L' THEN 'I' ELSE 'R' END;
  

-- Inserting Balance on Liabilities 
INSERT INTO
  #VT_STATS_BASE_BALANCE 
SELECT
  D.PROD_DATE_CH,
  'CV',
  COALESCE(B.STAF_NO,B.COST_CTR_CDE,'NONE'),
  'BALOLIAB',
  CUST_STA,
  INTL_DMST_CST_FLAG,
  CASE WHEN LSD_SPSA_OTH_FLAG = 'L' THEN 'I' ELSE 'R' END,
  'XXXX',
  SUM(AVG_FUNDS_USE_RSE * EXTRACT(DAY FROM D.PROD_DATE))
FROM
  INA_COM_CUST_DETL A
INNER JOIN 
  INA_COM_CUST_SEG B 
ON 
  A.IP_ID = B.IP_ID 
INNER JOIN
  REP_CMB_PROD_HIER E
ON
  A.PROD_CDE = E.PROD_CDE
INNER JOIN
  REP_CMB_PROD_GRP F
ON
  E.PROD_GROUP_CODE = F.PROD_GROUP_CODE,
  #VT_DATES D,
  REP_COM_CONTROL G
WHERE
  A.SMRY_PRD_ENDT = D.PROD_DATE
AND
  B.CUST_STA IN ('N','C','E')
AND
  B.INTL_DMST_CST_FLAG IN ('I','D')
AND
  B.SMRY_PRD_ENDT = G.PROD_DATE
-- changes for BID2855
--AND
--  E.REC_EDT > D.PROD_DATE
--AND
--  F.REC_EDT > D.PROD_DATE
--AND
--  E.REC_ACDT <= D.PROD_DATE
--AND
--  F.REC_ACDT <= D.PROD_DATE
AND
  E.REC_EDT = '9999-12-31'
AND
  F.REC_EDT = '9999-12-31'
--end of changes for bid2855
AND
  F.LIAB_FLAG_IND = 'Y'
AND
  B.SEG_GROUP_CDE <> 'A00003'
GROUP BY
  D.PROD_DATE_CH,
  COALESCE(B.STAF_NO,B.COST_CTR_CDE,'NONE'),
  CUST_STA,
  INTL_DMST_CST_FLAG,
  CASE WHEN LSD_SPSA_OTH_FLAG = 'L' THEN 'I' ELSE 'R' END;


-- AD Ratio - Uses above two values, derived in COMLoadREP_COM_SUMMARY.sql
-- Insert RWAs, require period end and prior period end


--RWAs for CURRENT PERIOD END
INSERT INTO
  #VT_STATS_BASE_BALANCE 
SELECT
  D.PROD_DATE_CH,
  'CV',
  COALESCE(B.STAF_NO,B.COST_CTR_CDE,'NONE'),
  'RWACURRG',
  CUST_STA,
  INTL_DMST_CST_FLAG,
  CASE WHEN LSD_SPSA_OTH_FLAG = 'L' THEN 'I' ELSE 'R' END,
  'XXXX',
  SUM(RWA_AMT) * EXTRACT(DAY FROM D.PROD_DATE)
FROM
  INA_COM_CUST_SEG B 
INNER JOIN
  DMI_COM_IP_MANUAL E
ON
  B.IP_ID = E.IP_ID,
  #VT_DATES D,
  REP_COM_CONTROL G
WHERE
  B.SMRY_PRD_ENDT = G.PROD_DATE
AND
  B.CUST_STA IN ('N','C','E')
AND
  B.INTL_DMST_CST_FLAG IN ('I','D')
AND
  E.SMRY_PRD_ENDT = D.PROD_DATE
AND
  E.SMRY_PRD_ENDT >= '2013-01-31'
AND
  B.SEG_GROUP_CDE <> 'A00003'
GROUP BY
  D.PROD_DATE_CH,
  COALESCE(B.STAF_NO,B.COST_CTR_CDE,'NONE'),
  CUST_STA,
  INTL_DMST_CST_FLAG,
  CASE WHEN LSD_SPSA_OTH_FLAG = 'L' THEN 'I' ELSE 'R' END,
  D.PROD_DATE;


--RWAs for PRIOR PERIOD END
-- derive a method for previous period - see dates calcs in REP_COM_SUMMARY
INSERT INTO
  #VT_STATS_BASE_BALANCE 
SELECT
  D.PROD_DATE_CH,
  'CV',
  COALESCE(B.STAF_NO,B.COST_CTR_CDE,'NONE'),
  'RWAPREVG',
  CUST_STA,
  INTL_DMST_CST_FLAG,
  CASE WHEN LSD_SPSA_OTH_FLAG = 'L' THEN 'I' ELSE 'R' END,
  'XXXX',
  SUM(RWA_AMT) * EXTRACT(DAY FROM (ADD_MONTHS(D.PROD_DATE - EXTRACT(DAY FROM D.PROD_DATE),-0)))
FROM
  INA_COM_CUST_SEG B 
INNER JOIN
  DMI_COM_IP_MANUAL E
ON
  B.IP_ID = E.IP_ID,
  #VT_DATES D,
  REP_COM_CONTROL G
WHERE
  B.SMRY_PRD_ENDT = G.PROD_DATE
AND
  B.CUST_STA IN ('N','C','E')
AND
  B.INTL_DMST_CST_FLAG IN ('I','D')
AND
  E.SMRY_PRD_ENDT = ADD_MONTHS(D.PROD_DATE - EXTRACT(DAY FROM D.PROD_DATE),-0)
AND
  E.SMRY_PRD_ENDT >= '2013-01-31'
AND
  B.SEG_GROUP_CDE <> 'A00003'
GROUP BY
  D.PROD_DATE_CH,
  COALESCE(B.STAF_NO,B.COST_CTR_CDE,'NONE'),
  CUST_STA,
  INTL_DMST_CST_FLAG,
  CASE WHEN LSD_SPSA_OTH_FLAG = 'L' THEN 'I' ELSE 'R' END,
  D.PROD_DATE;

  
-- Derive average RWAs
INSERT INTO
  #VT_STATS_BASE_BALANCE 
SELECT
  A.STATS_DATE_CH,
  'CV',
  A.UNIT_CODE,
  'AVGRWAS2',
  A.CUST_STATUS,
  A.CUST_TYPE,
  A.RM_TYPE,
  A.PROD_GROUP,
  (A.XVALUE + COALESCE(B.XVALUE,0)) / (EXTRACT(DAY FROM D.PROD_DATE) + CASE WHEN B.XVALUE IS NULL THEN 0 ELSE EXTRACT(DAY FROM (ADD_MONTHS(D.PROD_DATE - EXTRACT(DAY FROM D.PROD_DATE),-0))) END) * EXTRACT(DAY FROM D.PROD_DATE)
FROM
  #VT_STATS_BASE_BALANCE A
LEFT JOIN 
  #VT_STATS_BASE_BALANCE B
ON
  A.STATS_DATE_CH = B.STATS_DATE_CH
AND
  A.UNIT_CODE = B.UNIT_CODE
AND
  A.CUST_STATUS = B.CUST_STATUS
AND
  A.CUST_TYPE = B.CUST_TYPE
AND
  A.RM_TYPE = B.RM_TYPE
AND
  A.PROD_GROUP = B.PROD_GROUP
AND
  B.STATS_CODE = 'RWAPREVG'
INNER JOIN
  #VT_DATES D
ON
  A.STATS_DATE_CH = D.PROD_DATE_CH
WHERE
  A.STATS_CODE = 'RWACURRG';

  
------------------------------------------------------------------------------------------------------------------------------------------------------------


--#     # ####### #######
--##    # #          #
--# #   # #          #
--#  #  # #####      #
--#   # # #          #
--#    ## #          #
--#     # #######    #
 

-- for Balances this is the same as the above.
-- Removing errant cost codes which are not non-rm'd

DELETE FROM
  #VT_STATS_BASE_BALANCE
WHERE
  UNIT_CODE
IN
  (SELECT UNIT_CDE FROM REP_COM_MAN_HIER WHERE SB_SEG_CDE <> (SELECT LIST_VALUE FROM REP_GEN_LISTS WHERE LIST_KEY = 'NON_RM_SEG') AND UNIT_CDE NOT LIKE 'OT%' AND REC_EDT = '9999-12-31' AND CHARACTER_LENGTH(TRIM(UNIT_CDE)) = 6)
AND
  STATS_CODE 
NOT IN
  (SELECT LIST_VALUE FROM REP_GEN_LISTS WHERE LIST_KEY ='CMB_COST_STAT');


------------------------------------------------------------------------------------------------------------------------------------------------------------


-- Making an exception for Direct RMs! (deleting more errant data in direct RM division which is an RM'd division in the non-RM'd segment(!))
--DELETE FROM
--  #VT_STATS_BASE_BALANCE
--WHERE
--  UNIT_CODE
--IN
--  (SELECT UNIT_CDE FROM REP_COM_MAN_HIER WHERE DVSN_CDE IN (SELECT LIST_VALUE FROM REP_GEN_LISTS WHERE LIST_KEY = 'DIRECT_RM') AND RM_CDE IS NULL AND REC_EDT = '9999-12-31')
--AND
--  STATS_CODE 
--NOT IN
--  (SELECT LIST_VALUE FROM REP_GEN_LISTS WHERE LIST_KEY ='CMB_COST_STAT');
 

------------------------------------------------------------------------------------------------------------------------------------------------------------


-- Remove current months data in case of re-run
DELETE FROM
  REP_COM_STATS_BASE
WHERE
  VIEW_TYPE = 'CV';
--  STATS_DATE_CH IN (SELECT PROD_DATE_CH FROM #VT_DATES)
--AND
--  STATS_CODE IN (SELECT DISTINCT STATS_CODE FROM #VT_STATS_BASE_BALANCE)
--AND
--  CUST_STATUS IN ('N','C','E')
--AND
--  CUST_TYPE IN ('I','D')
--AND
--  RM_TYPE IN ('I','R')
--AND
--  VIEW_TYPE = 'CV';


-- Remove data older than start of previous year (this should only have an effect at the start of the year)
--DELETE FROM
--  REP_COM_STATS_BASE
--WHERE
--  STATS_DATE_CH < (SELECT CAST(EXTRACT(YEAR FROM LAST_YEAR_START_DATE) AS CHAR(4)) || '01' FROM REP_COM_CONTROL)
--AND
--  VIEW_TYPE = 'CV';


-- Now insert data from volatile table into main table
INSERT INTO
  REP_COM_STATS_BASE
SELECT
  *
FROM
  #VT_STATS_BASE_BALANCE;


------------------------------------------------------------------------------------------------------------------------------------------------------------


-- Drop volatile table
DROP TABLE #VT_STATS_BASE_BALANCE;


DROP TABLE #VT_DATES;


--DROP TABLE #VT_INA_FDS_CUST_RDIM_MO;


--DROP TABLE #VT_REP_COM_SEG_DECODE;