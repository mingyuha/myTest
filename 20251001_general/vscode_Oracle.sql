SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

SELECT TO_CHAR(ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS')                                                                                    AS "srvtime"  -- 배치일시, 30분 간격
     , CASE WHEN BM_NO IN ('1', '2') THEN 'MSP1' WHEN BM_NO = '4' THEN 'MSP2' END || '_V.VIRTUAL.EAF_NO_' || BM_NO || '_LHF_CU_RESULT' AS "tag"      -- 호기
     , CU_RSLT                                                                                                                         AS "value"    -- CU실적
     , HEAT_NO                                                                                                                         AS "heat_no"  -- HEAT NO
     , IRN_NAME                                                                                                                        AS "irn_name" -- 강종명
     , GT_YN                                                                                                                           AS "gt_yn"    -- Greater than 0.18 ?\
     , TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') as "create_dtm" 
  FROM (SELECT ENTRY_TIME
             , HEAT_NO
             , IRN_NAME
             , BM_NO
             , CU_RSLT
             , CASE WHEN CARBON_CONTENT_A = '0' AND CU_RSLT > 0.18  THEN 1
                    WHEN CARBON_CONTENT_A = '1' AND CU_RSLT >= 0.25 THEN 1
                                                                    ELSE 0
               END AS GT_YN
          FROM (SELECT A.HEAT_NO
                     , A.SMPL_ID
                     , A.IRN_NAME
                     , MAX(CASE WHEN SUBSTR(A.HEAT_NO, 1, 1) IN ('1', 'A') THEN '1'
                                WHEN SUBSTR(A.HEAT_NO, 1, 1) IN ('2', 'B') THEN '2'
                                WHEN SUBSTR(A.HEAT_NO, 1, 1) IN ('3', 'C') THEN '3'
                                WHEN SUBSTR(A.HEAT_NO, 1, 1) IN ('0', 'D') THEN '4'
                           END) OVER (PARTITION BY A.HEAT_NO)                                                    AS BM_NO
                     , (SELECT DISTINCT MATR_LARG FROM GMES.SPRA1103_V WHERE HEAT_NO = A.HEAT_NO AND ROWNUM = 1) AS MATR_LARG
                     , A.CU_RSLT
                     , A.ENTRY_TIME
                     , E.CARBON_CONTENT_A
                  FROM GMES.SQAZ2120 B
                     , GMES.SQAZ2110 A
                     , GMES.SPRB3010_V2 C
                     , BESTERP.STCZ1250 D
                     , BESTERP.SSAF1100 E
                 WHERE A.HEAT_NO = B.HEAT_NO(+)
                   AND A.SMPL_ID = B.SMPL_ID(+)
                   AND A.HEAT_NO = C.HEAT_NO
                   AND A.IRN_CODE = D.IRN_CODE(+)
                   AND D.IRN_CODE = E.IRN_CODE(+)
                  --  AND (C.STD_DATE >= TRUNC(CURRENT_DATE - 7, 'DD') OR (C.STD_DATE = '1111-11-11' AND B.TST_DATE >= TRUNC(CURRENT_DATE - 7, 'DD') AND NVL(B.LAST_TY, '*') = 'Y'))
                   AND (C.STD_DATE >= TRUNC(to_date('20251101','YYYYMMDD')-7, 'DD') OR (C.STD_DATE = '1111-11-11' AND B.TST_DATE >= TRUNC(to_date('20251101','YYYYMMDD')-7, 'DD') AND NVL(B.LAST_TY, '*') = 'Y'))
                   AND NVL(D.USE_YN, 'N') = 'Y'
                   AND D.PROD_PLNT IN ('00', '29')
               ) SRC

         WHERE MATR_LARG IN ('B', 'T')
           AND SMPL_ID IN ('131', '231', '431')
       ) RSLT
where trunc(ENTRY_TIME) = to_date('20251101','YYYYMMDD')
order by ENTRY_TIME desc
;

SELECT 
  CLAIM_NO as "claim_no" 
  , CLAIM_SEQ as "claim_seq" 
  , DECODE(PLNT_CODE
  , 'C001', '대형압연'
  , 'D001', '대형정정'
  , 'F001', '소형압연'
  , 'F002', '창녕)소형압연'
  , 'G001', '소형정정'
  , 'G002', '창녕)소형정정'
  , 'H001', '2차가공'
  , 'I001', '열처리'
  , 'I002', '열처리(창녕)'
  , 'J001', '일반단조'
  , 'B001', '1제강'
  , 'B002', '2제강'
  , 'Y001', 'QA'
  , 'R001', '연구'
  , 'Z001', '기타부서'
  , 'ZZ01', ' '
  , PLNT_CODE) AS "plnt_code"
  , RAT as "rat"
  , PROC_AMT as "proc_amt"
  , TO_CHAR(ACT_DATE, 'YYYY-MM-DD') as "act_date"
  , TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS')  AS "create_dtm"
FROM 
  GMES.SQAZ7340
WHERE 
  -- ACT_DATE >= TRUNC(ADD_MONTHS(SYSDATE, -36), 'YYYY')
  ACT_DATE >= TO_DATE('2024-01-01', 'YYYY-MM-DD') and ACT_DATE < TO_DATE('2024-01-01', 'YYYY-MM-DD') + interval '1' year
 order by ACT_DATE desc
 ;

SELECT 
    DECODE(X.PLNT_CODE, 'S', '특수강', 'F', '대형단조', '기타') AS "plnt_code"
    ,X.CO_TY as "co_ty"
    ,X.CLAIM_NO as "claim_no"
    ,X.ING_STS as "ing_sts"
    ,X.ACCEPT_YM as "accept_ym"
    ,X.ACCEPT_TYPE as "accept_type"
    ,TO_CHAR(X.ACCEPT_DATE, 'YYYY-MM-DD') as "accept_date"
    ,X.BUSI_EMP as "busi_emp"
    ,X.BUSI_DEPT as "busi_dept"
    ,X.CUST_CODE as "cust_code"
    ,X.CUST_NAME as "cust_name"
    ,X.ARIV_CUST_CODE as "ariv_cust_code"
    ,X.ARIV_CUST_NAME as "ariv_cust_name"
    ,X.IRN_CODE as "irn_code"
    ,X.IRN_NAME as "irn_name"
    ,X.HEAT_NO as "heat_no"
    ,X.ORD_IRN_NAME as "ord_irn_name"
    ,X.ITM_SIZE as "itm_size"
    ,X.ITM_KIND as "itm_kind"
    ,X.HEAT_PATRN as "heat_patrn"
    ,X.SHAP_TY as "shap_ty"
    ,X.PROD_GBN as "prod_gbn"
    ,X.SURF_STAT as "surf_stat"
    ,X.QA_EMP as "qa_emp"
    ,X.OFF_NOTE_YN as "off_note_yn"
    ,X.KEY_PON as "key_pon"
    ,TO_CHAR(X.IBGO_DATE, 'YYYY-MM-DD') as "ibgo_date"
    ,TO_CHAR(X.CHUL_DATE, 'YYYY-MM-DD') as "chul_date"
    ,X.TITLE as "title"
    ,TO_CHAR(X.PRODC_DATE, 'YYYY-MM-DD') as "prodc_date"
    ,X.ANAL_RSLT as "anal_rslt"
    ,X.GRIPE_CAUS as "gripe_caus"
    ,X.GRIPE_MEAS as "gripe_meas"
    ,X.PROC_CONTS as "proc_conts"
    ,ROUND(X.PROC_AMT_IN) as "proc_amt_in"
    ,ROUND(X.PROC_AMT_OUT) as "proc_amt_out"
    ,X.BAD_L_CLASS as "bad_l_class"
    ,X.BAD_M_CLASS as "bad_m_class"
    ,X.BAD_CLASS as "bad_class"
    ,X.BUS_TRIP_YN as "bus_trip_yn"
    ,TO_CHAR(X.DATE_904, 'YYYY-MM-DD') as "date_904"
    ,TO_CHAR(X.DATE_906, 'YYYY-MM-DD') as "date_906"
    ,TO_CHAR(X.DATE_905, 'YYYY-MM-DD') as "date_905"
    ,TO_CHAR(X.DATE_903, 'YYYY-MM-DD') as "date_903"
    ,TO_CHAR(X.DATE_902, 'YYYY-MM-DD') as "date_902"
    ,TO_CHAR(X.DATE_901, 'YYYY-MM-DD') as "date_901"
    ,X.DAY_CNT as "day_cnt"
    ,X.MATR_LARG as "matr_larg"
    ,X.ORD_IRN_STD as "ord_irn_std"
    ,TO_CHAR(X.SND_DATE_FR, 'YYYY-MM-DD') as "snd_date_fr"
    ,TO_CHAR(X.SND_DATE_TO, 'YYYY-MM-DD') as "snd_date_to"
    ,X.SND_WGT as "snd_wgt"
    ,X.SND_AMT as "snd_amt"
    ,TO_CHAR(X.GRIPE_DATE, 'YYYY-MM-DD') as "gripe_date"
    ,X.GRIPE_WGT as "gripe_wgt"
    ,X.GRIPE_AMT as "gripe_amt"
    ,X.GRIPE_CONTS as "gripe_conts"
    ,X.BAD_CODE as "bad_code"
    ,X.PROC_TY as "proc_ty"
    ,TO_CHAR(X.DATE_907, 'YYYY-MM-DD') as "date_907"
    ,X.RETURN_YN as "return_yn"
    ,X.RETURN_WGT as "return_wgt"
    ,TO_CHAR(X.RETURN_DATE, 'YYYY-MM-DD') as "return_date"                                                                                                                                            -- 반품일자
    ,(SELECT CASE WHEN IBGO_PLAC = 'J' THEN
                            (SELECT DECODE(UP_USER, NULL, IN_USER, UP_USER) FROM GMES.SQAZ1080 WHERE PON = X.KEY_PON AND ROWNUM = 1)
               END
          FROM GMES.SGDZ5100 A
         WHERE PON = X.KEY_PON
           AND ROWNUM = 1
       ) as "tst_emp"
     , NVL((SELECT CASE WHEN IBGO_PLAC = 'G' THEN (SELECT MAX(LINE_TY) FROM GMES.SPRG3011 WHERE PON = X.KEY_PON)
                        WHEN IBGO_PLAC = 'D' THEN (SELECT MAX((SELECT TO_CHAR(MGT_NUM4) FROM BESTERP.CM_CODEDETAIL WHERE CODE_TYPE = 'SD02' AND code = A.EQUIP_CD)) FROM GMES.SPRD3110 A WHERE PON = X.KEY_PON)
                   END
              FROM GMES.SGDZ5100 A
             WHERE PON = X.KEY_PON
               AND ROWNUM = 1
           ), 'N') as "off_work"
     , TO_CHAR((SELECT PRODC_DATE FROM GMES.SPRB4010 WHERE HEAT_NO = X.HEAT_NO AND ROWNUM = 1), 'YYYY-MM-DD') as "prb_date"
     , CASE WHEN NVL(X.PROC_AMT_IN, 0) < 5000000                       THEN 'CS 팀장 전결'
            WHEN X.PROC_AMT_IN >= 5000000 AND X.PROC_AMT_IN < 10000000 THEN '센터장 전결'
                                                                       ELSE '대표이사 전결'
       END as "proc_amt_gbn"
     , DECODE(GMES.SF_SPRA_PON_USE_TY(X.KEY_PON), 'A', 'Axle Shaft용', 'B', '흑피용', 'C', '냉간단조용', 'D', '인발가공용', 'E', '이형단조재용', 'F', '열간단조용', 'G', '연마용', 'H', '열처리용', 'I', 'Induction Quenching용', 'J', '강관 원재용', 'M', '선재가공용', 'O', 'Tie Rod용', 'P', 'Seamless pipe용', 'Q', '냉간압조용', 'R', '재압연용', 'S', '교정용',
              'T', '박판단조용', 'U', '열간Upseting(내수와협의)', 'V', '우주항공용', 'W', '용접구조용', 'X', '용도불분명', 'Y', '가공용', GMES.SF_SPRA_PON_USE_TY(X.KEY_PON)) as "use_ty"
     , TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS')  AS "create_dtm"
  FROM (SELECT A.CLAIM_NO
             , A.PLNT_CODE
             , TO_CHAR(A.ACCEPT_DATE, 'YYYYMM')                                                    AS ACCEPT_YM
             , A.ACCEPT_SEQ
             , A.ACCEPT_TYPE
             , A.ACCEPT_DATE
             , A.BUSI_EMP
             , A.BUSI_DEPT
             , A.CUST_CODE
             , GMES.SF_CUSTOMER_NAME(A.CUST_CODE)                                                  AS CUST_NAME
             , A.IRN_LARG_CODE
             , A.ARIV_CUST_CODE
             , GMES.SF_CUSTOMER_NAME(A.ARIV_CUST_CODE)                                             AS ARIV_CUST_NAME
             , A.IRN_CODE
             , GMES.SF_IRN_NAME(A.IRN_CODE)                                                        AS IRN_NAME
             , A.ORD_IRN_NAME
             , A.ITM_SIZE
             , A.ITM_KIND
             , A.SHAP_TY
             , A.SURF_STAT
             , A.QA_EMP
             , A.OFF_NOTE_YN
             , A.KEY_PON
             , A.CO_TY
             , A.HEAT_PATRN
             , A.PROD_GBN
             , A.TITLE
             , A.BAD_L_CLASS
             , A.BAD_CLASS
             , A.BAD_M_CLASS
             , A.APP_DOC
             , A.APP_IMG
             , A.HEAT_NO
             , A.MATR_LARG
             , A.ORD_IRN_STD
             , B.PROD_IRN
             , B.SND_DATE_FR
             , B.SND_DATE_TO
             , B.SND_WGT
             , B.SND_AMT
             , B.SND_DIS_WGT
             , B.GRIPE_DATE
             , B.GRIPE_WGT
             , B.GRIPE_AMT
             , B.GRIPE_DIS_WGT
             , B.USE_CONTS
             , B.PRODC_RTN
             , B.GRIPE_CONTS
             , B.BAD_CODE
             , B.VISIT_DATE
             , (SELECT MAX(IBGO_DATE) FROM GMES.TGDZ5100 WHERE PON = A.KEY_PON AND IBGO_TY = '1A') AS IBGO_DATE
             , (SELECT MAX(SND_DATE) FROM GMES.TGDZ5100 WHERE PON = A.KEY_PON)  AS CHUL_DATE
             , MAX(C.PRODC_DATE)                                                                   AS PRODC_DATE
             , MAX(C.ANAL_RSLT)                                                                    AS ANAL_RSLT
             , MAX(C.DETL_CONTS)                                                                   AS DETL_CONTS
             , MAX(C.GRIPE_CAUS)                                                                   AS GRIPE_CAUS
             , MAX(C.GRIPE_MEAS)                                                                   AS GRIPE_MEAS
             , MAX(C.PROC_CONTS)                                                                   AS PROC_CONTS
             , SUM(C.PROC_AMT_IN)                                                                  AS PROC_AMT_IN
             , SUM(C.PROC_AMT_OUT)                                                                 AS PROC_AMT_OUT
             , MAX(D.DATE_801)                                                                     AS DATE_901
             , MAX(D.DATE_802)                                                                     AS DATE_902
             , MAX(D.DATE_803)                                                                     AS DATE_903
             , MAX(D.DATE_804)                                                                     AS DATE_904
             , MAX(D.DATE_805)                                                                     AS DATE_905
             , MAX(D.DATE_806)                                                                     AS DATE_906
             , MAX(D.DATE_807)                                                                     AS DATE_907
             , SUM(D.CHA_801) + SUM(D.CHA_803) + SUM(D.CHA_804) + SUM(D.CHA_806) + SUM(D.CHA_807)  AS DAY_CNT
             , NVL(MAX(D.ING_STS), 'A')                                                            AS ING_STS
             , 1                                                                                   AS EA
             , CASE WHEN MAX(NVL(C.PRODC_DATE, '1111-11-11')) = '1111-11-11' THEN 'N' ELSE 'Y' END AS PRODC_YN
             , MAX(C.PROC_TY)                                                                      AS PROC_TY
             , MAX(C.BUS_TRIP_YN)                                                                  AS BUS_TRIP_YN
             , MAX(C.RETURN_DATE)                                                                  AS RETURN_DATE
             , MAX(C.RETURN_YN)                                                                    AS RETURN_YN
             , SUM(C.RETURN_WGT)                                                                   AS RETURN_WGT
             , '1'                                                                                 AS CLAIM_SEQ
          FROM GMES.SQAZ7300 A
              LEFT OUTER JOIN GMES.SQAZ7320 B
              ON A.CLAIM_NO = B.CLAIM_NO
              LEFT OUTER JOIN GMES.SQAZ7330 C
              ON A.CLAIM_NO = C.CLAIM_NO
              LEFT OUTER JOIN GMES.SQAZ7341_V D
              ON A.CLAIM_NO = D.CLAIM_NO
                  AND C.CLAIM_SEQ = D.CLAIM_SEQ
         WHERE 
            -- A.ACCEPT_DATE >= TRUNC(ADD_MONTHS(SYSDATE, -36), 'YYYY')
            A.ACCEPT_DATE >= TO_DATE('2024-01-01', 'YYYY-MM-DD') and A.ACCEPT_DATE < TO_DATE('2024-01-01', 'YYYY-MM-DD') + interval '1' year
           AND NVL(A.PROD_GBN, '%') LIKE '%'
           AND NVL(A.CO_TY, '%') LIKE '%'
         GROUP BY A.CLAIM_NO
                , A.PLNT_CODE
                , A.ACCEPT_SEQ
                , A.ACCEPT_TYPE
                , A.ACCEPT_DATE
                , A.BUSI_EMP
                , A.BUSI_DEPT
                , A.CUST_CODE
                , A.IRN_LARG_CODE
                , A.ARIV_CUST_CODE
                , A.IRN_CODE
                , A.ORD_IRN_NAME
                , A.ITM_SIZE
                , A.ITM_KIND
                , A.SHAP_TY
                , A.SURF_STAT
                , A.QA_EMP
                , A.OFF_NOTE_YN
                , A.KEY_PON
                , A.CO_TY
                , A.HEAT_PATRN
                , A.PROD_GBN
                , A.TITLE
                , A.BAD_L_CLASS
                , A.BAD_CLASS
                , A.BAD_M_CLASS
                , A.APP_DOC
                , A.APP_IMG
                , A.HEAT_NO
                , A.MATR_LARG
                , A.ORD_IRN_STD
                , B.PROD_IRN
                , B.SND_DATE_FR
                , B.SND_DATE_TO
                , B.SND_WGT
                , B.SND_AMT
                , B.SND_DIS_WGT
                , B.GRIPE_DATE
                , B.GRIPE_WGT
                , B.GRIPE_AMT
                , B.GRIPE_DIS_WGT
                , B.USE_CONTS
                , B.PRODC_RTN
                , B.GRIPE_CONTS
                , B.BAD_CODE
                , B.VISIT_DATE
       ) X
order by accept_date desc
;      

SELECT COUNT(*)
FROM GMES.SQAZ7300 A
WHERE TO_CHAR(ACCEPT_DATE, 'YYYY') = '2025'
  AND A.ACCEPT_DATE >= TO_DATE('2024', 'YYYY') 
  AND A.ACCEPT_DATE < TO_DATE('2025', 'YYYY');

SELECT DATA_TYPE, DATA_LENGTH
FROM USER_TAB_COLUMNS
WHERE TABLE_NAME = SQAZ7300
  AND COLUMN_NAME = 'ACCEPT_DATE';
SELECT SESSIONTIMEZONE, DBTIMEZONE FROM DUAL;

select IN_DATE, TO_CHAR(UP_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "up_date" FROM BESTERP.CM_CODEDETAIL cc WHERE UP_DATE is not null ORDER BY UP_DATE DESC, IN_DATE DESC;

SELECT
  cc.CODE,
  cc.CODE_TYPE,
  count(*) as cnt
FROM
  BESTERP.CM_CODEDETAIL cc
GROUP BY cc.CODE,cc.CODE_TYPE
ORDER BY cnt desc
  ;

SELECT
  to_char(a.UP_DATE,'YYYY-MM-DD') as up_date, count(a.UP_DATE) as cnt
from
(SELECT 
  trunc(UP_DATE, 'DD') as UP_DATE
FROM BESTERP.CM_CODEDETAIL cc
WHERE
  UP_DATE is not null
) a
group by a.UP_DATE
order by up_date DESC
;



select * from ALL_TAB_COLUMNS where table_name='SPRD03015';
-- 오라클 컬럼 이름 과 속성 얻기 ( postgresql )
-- SELECT
--   lower(c.COLUMN_NAME), 
--   cc.COMMENTS, 
--   case 
--     when c.DATA_TYPE = 'VARCHAR2' then 'varchar'
--     when c.DATA_TYPE = 'NUMBER' then 'numeric'
--     when c.DATA_TYPE = 'DATE' then 'timestamptz'
--     else c.DATA_TYPE
--   end as dt, 
--   case 
--     when c.DATA_TYPE = 'VARCHAR2' then to_char(c.DATA_LENGTH)
--     when c.DATA_TYPE = 'NUMBER' then to_char(c.DATA_LENGTH) || ' , ' || case when to_char(c.DATA_SCALE) is null then '0' else to_char(c.DATA_SCALE) end
--     when c.DATA_TYPE = 'DATE' then ''
--     else c.DATA_TYPE
--   end as data_len,
--   c.DATA_LENGTH, c.DATA_SCALE, c.DATA_PRECISION

-- 오라클 컬럼 이름 과 속성 얻기 ( bigquery )
SELECT
  lower(c.COLUMN_NAME), 
  cc.COMMENTS, 
  case 
    when c.DATA_TYPE = 'VARCHAR2' then 'string'
    when c.DATA_TYPE = 'NUMBER' then 'numeric'
    when c.DATA_TYPE = 'DATE' then 'datetime'
    else c.DATA_TYPE
  end as dt, 
  case 
    when c.DATA_TYPE = 'VARCHAR2' then '("' || to_char(c.DATA_LENGTH) || '")'
    when c.DATA_TYPE = 'NUMBER' then '(' || to_char(c.DATA_LENGTH) || ' , ' || case when to_char(c.DATA_SCALE) is null then '0' else to_char(c.DATA_SCALE) end || ')'
    when c.DATA_TYPE = 'DATE' then ''
    else c.DATA_TYPE
  end as data_len  

FROM
  ALL_TAB_COLUMNS c
  left join 
  ALL_COL_COMMENTS cc on c.TABLE_NAME = cc.TABLE_NAME and c.COLUMN_NAME = cc.COLUMN_NAME
WHERE
  c.TABLE_NAME='CM_CODEDETAIL'
  AND c.COLUMN_NAME in (
    'CODE',
'CODE_NAME',
'USE_YN',
'CODE_TYPE',
'MGT_CHAR1',
'MGT_CHAR2',
'MGT_CHAR3',
'MGT_CHAR4',
'MGT_CHAR5',
'MGT_CHAR6',
'MGT_CHAR7',
'MGT_CHAR8',
'MGT_CHAR9',
'MGT_CHAR10'
    )
;

SELECT
  C.AFTER_PROCESS_CODE as "after_process_code",
  B.PROCESS_RANK as "process_rank",
  B.LOT_NO as "lot_no",
  B.PROCESS_CODE as "process_code",
  B.EQUIP_CODE as "equip_code",
  B.CUT_SCRAP as "cut_scrap",
  B.INPUT_ED as "input_ed",
  B.INPUT_WGT as "input_wgt",
  B.PRODUCTION_ED as "production_ed",
  B.PRODUCTION_QTY as "production_qty",
  B.PRODUCTION_WGT as "production_wgt",  
  TO_CHAR(B.WORK_START_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "work_start_date",
  TO_CHAR(B.WORK_END_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "work_end_date",
  TO_CHAR(B.IN_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "in_date",
  TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "create_dtm"
FROM
  CMES.SPRC02002 A JOIN 
  (
    SELECT
      *
    FROM
      CMES.SPRC03009
    WHERE
      WORK_START_DATE >= TO_DATE('2025-06-10', 'YYYY-MM-DD') - INTERVAL '5' DAY and WORK_START_DATE < TO_DATE('2025-06-11', 'YYYY-MM-DD') + INTERVAL '1' DAY
      AND PROCESS_CODE = 'AB03'
  ) B ON B.LOT_NO = A.LOT_NO
  LEFT JOIN CMES.SPRC02003 C ON C.LOT_NO = B.LOT_NO AND C.PROCESS_RANK = B.PROCESS_RANK
WHERE 
  B.IN_DATE >= TO_DATE('2025-06-11', 'YYYY-MM-DD') and B.IN_DATE < TO_DATE('2025-06-11', 'YYYY-MM-DD') + INTERVAL '1' DAY
-- order by B.IN_DATE
-- ;  

-- ;  

-- ;
-- -- explain plan for 
-- SELECT
--   a.LOT_NO as "lot_no",
--   a.PROCESS_CODE as "process_code",
--   a.PROCESS_RANK as "process_rank",
--   a.EQUIP_CODE as "equip_code",
--   a.MATERIAL_LENGTH as "material_length",
--   a.SQUARENESS as "squareness",
--   TO_CHAR(a.IN_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "in_date",
--   TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "create_dtm"
-- FROM
--   (
--   SELECT
--     *
--   FROM 
--     CMES.SPRD03015
--   WHERE
--     WORK_DATE >= TO_DATE('2025-06-10', 'YYYY-MM-DD') - INTERVAL '5' DAY and WORK_DATE < TO_DATE('2025-06-10', 'YYYY-MM-DD') + INTERVAL '1' DAY
--   ) a
-- WHERE
--   a.IN_DATE >= TO_DATE('2025-06-10', 'YYYY-MM-DD') and a.IN_DATE < TO_DATE('2025-06-10', 'YYYY-MM-DD') + INTERVAL '1' DAY
-- ;  
-- group by heat_no

