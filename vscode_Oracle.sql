
-- explain plan for 


SELECT 
  -- count(*)
  LOT_NO AS "lot_no",
  EQUIP_CODE AS "equip_code",
  ED_MIN AS "ed_min",
  ED_MAX AS "ed_max",
  LENGTH_MIN AS "length_min",
  LENGTH_MAX as "length_max",
  DIA_VAR as "dia_var",
  TO_CHAR(IN_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "in_date",
  TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "create_dtm"
FROM
(
  SELECT * from CMES.sprc04001 WHERE WORK_DATE >= TO_DATE('2023-01-01', 'YYYY-MM-DD') - INTERVAL '5' DAY and WORK_DATE < TO_DATE('2023-12-31', 'YYYY-MM-DD') + INTERVAL '1' DAY
) AA
where
  AA.IN_DATE >= TO_DATE('2023-01-01', 'YYYY-MM-DD') and AA.IN_DATE < TO_DATE('2025-05-19', 'YYYY-MM-DD') + INTERVAL '1' DAY
;

SELECT *
from  besterp.CM_CODEDETAIL
where 
  code_type = 'PA45';

select 
  -- count(EQUIP_CODE) cnt
  EQUIP_CODE, 
  LOT_NO, 
  TO_CHAR(IN_DATE, 'YYYY-MM-DD HH24:MI:SS') "in_date", 
  TO_CHAR(WORK_DATE, 'YYYY-MM-DD HH24:MI:SS') "work_date"
from 
  cmes.SPRC03009
where
  TRUNC(IN_DATE) BETWEEN TO_DATE('2025-05-14', 'YYYY-MM-DD') and  TO_DATE('2025-05-16', 'YYYY-MM-DD')
  -- TRUNC(WORK_DATE) BETWEEN TO_DATE('2025-05-15', 'YYYY-MM-DD') and  TO_DATE('2025-05-16', 'YYYY-MM-DD')
order by lot_no
;

select TO_DATE('2024-05-19', 'YYYY-MM-DD') from dual;

explain plan for 
SELECT
  LOT_NO, EQUIP_CODE
FROM
  CMES.SPRC03009
WHERE
  (
    WORK_END_DATE >= TO_DATE('2025-05-01', 'YYYY-MM-DD') and WORK_END_DATE < TO_DATE('2025-05-19', 'YYYY-MM-DD') + INTERVAL '1' DAY
  )
  -- OR
  -- (
  --   WORK_END_DATE IS NULL
  -- ) 
;

SELECT CODE FROM BESTERP.CM_CODEDETAIL WHERE CODE_TYPE='PA45';
  -- TO_CHAR(B.WORK_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "work_date",  
  -- TO_CHAR(B.WORK_END_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "work_end_date",
  -- TO_CHAR(B.WORK_START_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "work_start_date"

-- explain plan for 
SELECT   
  B.LOT_NO as "lot_no", 
  B.EQUIP_CODE as "equip_code",
  C.CODE_NAME as "code_name", 
  TO_CHAR(B.IN_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "in_date",
  TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "create_dtm"
FROM 
  CMES.SPRC02002 A JOIN 
  (
    SELECT 
      LOT_NO, EQUIP_CODE, IN_DATE
    FROM 
      CMES.SPRC03009
    WHERE
      WORK_START_DATE >= TO_DATE('2025-01-01', 'YYYY-MM-DD') - INTERVAL '5' DAY and WORK_START_DATE < TO_DATE('2025-05-20', 'YYYY-MM-DD') + INTERVAL '1' DAY
  ) B
   ON B.LOT_NO = A.LOT_NO
  LEFT JOIN BESTERP.CM_CODEDETAIL C ON C.CODE_TYPE = 'PA45' AND C.CODE = B.EQUIP_CODE
WHERE
  B.IN_DATE >= TO_DATE('2025-01-01', 'YYYY-MM-DD') and B.IN_DATE < TO_DATE('2025-05-20', 'YYYY-MM-DD') + INTERVAL '1' DAY
;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

select
    a, b, COUNT(*)
from (
select 
--   FACTORY_CODE, LOT_NO, EQUIP_CODE, PRODUCTION_ED, PRODUCTION_WIDTH, IN_DATE, WORK_DATE
-- FACTORY_CODE, count(FACTORY_CODE) cnt
 to_char(IN_DATE,'YYYY-MM-DD') a, to_char(WORK_DATE,'YYYY-MM-DD') b
from 
  cmes.sprc03033
where
  TRUNC(WORK_DATE) BETWEEN TO_DATE('2025-05-10', 'YYYY-MM-DD') and  TO_DATE('2025-05-14', 'YYYY-MM-DD')
) aa
group by aa.a,aa.b
order by aa.a, aa.b
;
SELECT
    IN_DATE, WORK_DATE
from 
  cmes.sprc03033
where
  TRUNC(IN_DATE) BETWEEN TO_DATE('2025-01-01', 'YYYY-MM-DD') and  TO_DATE('2025-05-14', 'YYYY-MM-DD')
  and WORK_DATE is NULL
;

select 
 LOT_NO                                         "heat_no", 
 EQUIP_CODE                                     "equip_code", 
 PRODUCTION_ED                                  "production_ed", 
 PRODUCTION_WIDTH                               "production_width", 
 TO_CHAR(IN_DATE, 'YYYY-MM-DD HH24:MI:SS')      "in_date",
 TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD HH24:MI:SS') "create_dtm"
from 
  cmes.sprc03033
where
  IN_DATE >= TO_DATE('2025-05-19', 'YYYY-MM-DD') and IN_DATE < TO_DATE('2025-05-19', 'YYYY-MM-DD') + INTERVAL '1' DAY
order by in_date
;

SELECT 
    HEAT_NO AS "heat_no", 
	STIR_END_VACUUM_DEGR AS "stir_end_vacuum_degr", 
  SOLID_WRK_TIMES as "solid_wrk_times",
	TO_CHAR(IN_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "in_date",
    TO_CHAR(UP_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "up_date",
    TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "create_dtm"
FROM 
    CMES.sprb3810
WHERE 
    IN_DATE IS NOT NULL 
    AND TRUNC(IN_DATE) >= TO_DATE('2025-04-01', 'YYYY-MM-DD')
ORDER by HEAT_NO
;

select TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') from dual;

select 
count(*)
-- HEAT_NO                                      AS "heat_no"
--      , RTN_TYPE                                     AS "rtn_type"
--      , WRK_SEQ                                      AS "wrk_seq"
--      , TO_CHAR(TMPRT_TIME, 'YYYY-MM-DD HH24:MI:SS') AS "tmprt_time"
--      , TMPRT                                        AS "tmprt"
--      , TO_CHAR(IN_DATE, 'YYYY-MM-DD HH24:MI:SS')    AS "in_date"
--      , TO_CHAR(UP_DATE, 'YYYY-MM-DD HH24:MI:SS')    AS "up_date"
--      , TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS')    AS "create_dtm" 
from cmes.SPRB3160
where 
    IN_DATE >= TO_DATE('20240101','YYYYMMDD')
    and HEAT_NO is null
order by IN_DATE;