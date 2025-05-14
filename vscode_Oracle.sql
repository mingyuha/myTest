


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
  TRUNC(IN_DATE) BETWEEN TO_DATE('2025-05-13', 'YYYY-MM-DD') and  TO_DATE('2025-05-13', 'YYYY-MM-DD')
order by in_date
;

SELECT 
    HEAT_NO AS "heat_no", 
	STIR_END_VACUUM_DEGR AS "stir_end_vacuum_degr", 
	TO_CHAR(IN_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "in_date",
    TO_CHAR(UP_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "up_date",
    TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "create_dtm"
FROM 
    CMES.sprb3810
WHERE 
    IN_DATE IS NOT NULL 
    AND TRUNC(IN_DATE) >= TO_DATE('2025-05-10', 'YYYY-MM-DD')
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