--WITH bbb AS (
SELECT
    AA.*
    -- TO_CHAR(TRUNC(CURRENT_DATE), 'YYYY-MM-DD HH24:MI:SS') "std_date",
	-- TO_CHAR(PREQ_DATE, 'YYYY-MM-DD HH24:MI:SS') as "preq_date",
	-- GBN as "gbn",
	-- PREQ_NO as "preq_no",
	-- TO_CHAR(IN_DATE, 'YYYY-MM-DD HH24:MI:SS') as "in_date",
	-- TO_CHAR(ROLL_REQ_DATE, 'YYYY-MM-DD HH24:MI:SS') as "roll_req_date",
	-- PREQ_WGT as "preq_wgt",
	-- PRC_WGT as "prc_wgt",
	-- PRK_WGT as "prk_wgt",
	-- CUST_NM as "cust_nm",
	-- END_TY as "end_ty",
	-- SURF_STAT as "surf_stat",
	-- HEAT_PATRN as "heat_patrn",
	-- PRC_ROL as "prc_rol",
	-- ITM_SZ as "itm_sz",
	-- IRN_NAME as "irn_name",
	-- ORD_IRN_STD as "ord_irn_std",
	-- QLTY_GRD as "qlty_grd",
	-- LTH_TY as "lth_ty",
	-- CHR_WGT as "chr_wgt",
	-- COLD_STAT_WGT as "cold_stat_wgt",
	-- TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "created_dtm"
FROM 
(
SELECT /*+ USE_NL(C E) USE_NL(C F) */
     '대형압연'                                                                                      AS GBN
     , A.PREQ_NO                                                                                              -- 생산의뢰번호
     , E.IRN_NAME                                                                                             --강종명
     , CASE WHEN B.PRC_ROL_TYPE IN ('SB', 'IG') THEN C.ITM_SZ
                                                ELSE CASE WHEN B.PRC_ROL_TYPE = 'LT' THEN B.PRC_ROL_TYPE || B.PRC_ROL_SZ || B.PRC_ROL_SZ
                                                                                     ELSE B.PRC_ROL_TYPE || SUBSTR(TO_CHAR(B.PRC_ROL_SZ, '000.00'), 2, 6)
                                                     END
       END                                                                                         AS PRC_ROL --(2018.10.10)함형석 대리, LT 표현식 변경.
     , C.ITM_SZ
     , C.LTH_TY                                                                                    AS LTH_CODE
     , CASE WHEN C.LTH_TY = '1' THEN '준정척'
            WHEN C.LTH_TY = '2' THEN '준척'
            WHEN C.LTH_TY = '3' THEN '혼척'
            WHEN C.LTH_TY = '4' THEN '준혼척'
            WHEN C.LTH_TY = '5' THEN '정척'
            WHEN C.LTH_TY = '6' THEN '관리척'
            WHEN C.LTH_TY = '9' THEN '기타'
            WHEN C.LTH_TY = 'A' THEN '절단척(준척)'
       END                                                                                         AS LTH_TY
     , C.SURF_STAT
     , C.HEAT_PATRN
     , C.PREQ_QTY
     , C.PREQ_WGT
     , NVL(C.PREQ_WGT, C.PREQ_WGT)                                                                 AS ORG_PREQ_WGT
     , C.PLSH_YN
     , C.MATR_LARG
     , CASE WHEN C.LAST_END_EMP = 'AUTO' THEN '자동종결'
                                         ELSE
                                             CASE WHEN C.PROD_REQ_END_YN = 'Y' THEN '생산종결'
                                                                               ELSE
                                                                                   CASE WHEN C.REQ_END_YN = 'Y' THEN '영업종결' ELSE NULL END
                                             END
       END                                                                                         AS END_TY
     , F.CUST_NM
     , C.LTH
     , C.SHAP_TY || C.USE_TY || C.USE_GRD || CASE WHEN C.MATR_LARG = 'T' THEN ' T' ELSE NULL END   AS QLTY_GRD
     , CASE WHEN C.PREQ_WGT = 0 THEN 0
                                ELSE ROUND((SELECT NVL(SUM(GMES.SF_SPRC_PRODC_WGT(PON)), 0)
                                              FROM GMES.SPRA1103
                                             WHERE PREQ_NO = A.PREQ_NO
                                           ) / C.PREQ_WGT, 2) * 100
       END                                                                                         AS PRODC_PER
     --, CASE WHEN C.PREQ_WGT = 0 THEN 0 ELSE  ROUND(A.PRODC_PER_WGT / C.PREQ_WGT, 2) * 100 END  AS PRODC_PER_2
     , GMES.SF_SPRA_CAST_SPEED_PATRN(C.PREQ_NO, C.MATR_LARG, E.IRN_NAME)                           AS CAST_SPEED_PATRN
     , CASE C.MATR_LARG
    WHEN 'B' THEN B.BM_QTY
    WHEN 'I' THEN B.IG_QTY
    WHEN 'T' THEN B.BT_QTY
       END                                                                                         AS MATR_QTY
     , CASE C.MATR_LARG
    WHEN 'B' THEN B.BM_LTH
    WHEN 'I' THEN 0
    WHEN 'T' THEN B.BT_LTH
       END                                                                                         AS MATR_LTH
     , CASE C.MATR_LARG
    WHEN 'B' THEN B.BM_WGT
    WHEN 'I' THEN B.IG_WGT
    WHEN 'T' THEN B.BT_WGT
       END                                                                                         AS MATR_WGT
     , C.CREATE_TY
     , B.UNI_YN
     , C.ORD_IRN_STD
     , C.CUST_CODE
     , CASE WHEN C.SHAP_TY = 'BM' THEN 0 ELSE C.ROLL_LTH END                                       AS ROLL_LTH
     , CASE WHEN NVL(C.HZTL_TOL_MIN, 0) = 0 THEN '+' ELSE '±' END                                  AS HZTL_TOL
     , C.ORD_IRN_NAME
     , GMES.SF_SPRA_COMP_METAL_DATA(C.IRN_CODE)                                                    AS COMP_METAL
     , GMES.SF_SPRA_COMP_METAL_WGT(C.IRN_CODE)                                                     AS C_REVIS_METAL
     , B.CHODO_YN
     , C.S_TAL_SPEC
     , CASE WHEN C.CUST_CODE IN ('21958') THEN 'Y' ELSE 'N' END                                    AS CUST_CD_CHK
     , C.IN_DATE                                                                                   AS IN_DATE
     , C.HZTL_TOL_MAX
     , C.HZTL_TOL_MIN
     , C.VTCL_TOL_MAX
     , C.VTCL_TOL_MIN
     , C.LTH_TOL_MAX
     , C.LTH_TOL_MIN
     , C.LTH_TOL_MAX                                                                               AS LTH_TOL_MAX2
     , C.PROD_LTH_MULT
     , GMES.SF_SPRA_EXPIRED_DATE(C.PREQ_NO)                                                        AS EXPIRED_DATE
     , GMES.SF_SPRA_PLNT_PATH_DESC(C.ITM_CODE, B.PLNT_GRP)                                         AS PLNT_PATH_DESC
     , B.BM_LTH
     , NULL                                                                                        AS MGT_HEAT_NO
     , (SELECT GMES.SF_STCZ_JY_ITEM(S.JY_ITEM_CD)
          FROM BESTERP.SSAZ4000 S
         WHERE S.ITM_CODE = C.ITM_CODE
           AND ROWNUM = 1
       )                                                                                           AS JY_ITEM_NM
     , SUBSTR(C.PREQ_NO, 1, 1)                                                                     AS SUJU_GBN
     , GMES.SF_SPRA_PRB_INDI_WGT('1', A.PREQ_NO)                                                   AS PRB_INDI_WGT
     , NVL(GMES.SF_SPRA_SPRB_JISI_PROD_WGT(A.PREQ_NO), 0)                                          AS SPRB_JISI_PROD_WGT
     , (SELECT NVL(SUM(GMES.SF_SPRC_INDI_WGT(PON)), 0)
          FROM GMES.SPRA1103
         WHERE PREQ_NO = A.PREQ_NO
           AND USE_YN = 'Y'
       )                                                                                           AS PRC_INDI_WGT
     , GMES.SF_SPRA_INDI_TARGET_WGT(A.PREQ_NO)                                                     AS PRC_TARGET_WGT
     , A.CHR_WGT
     , A.TOT_CHR_WGT
     , A.PRC_WGT
     , A.PRC_BT_WGT
     , A.PRK_PRODC_QTY
     , (SELECT NVL(SUM(GMES.SF_SPRK_PRODC_WGT2(PON)), 0)
          FROM GMES.SPRA1103
         WHERE PREQ_NO = A.PREQ_NO
       )                                                                                           AS PRK_WGT
     , A.CHNG_WGT
     , A.BAD_WGT
     , A.BORYU_WGT
     , A.ONPROC_WGT
     , (SELECT NVL(SUM(GMES.SF_SPRI_PRODC_WGT(PON)), 0)
          FROM GMES.SPRA1103
         WHERE PREQ_NO = A.PREQ_NO
       )                                                                                           AS PRI_WGT
     , A.PRB_COLD_WGT
     , A.PRW_WGT
     , (SELECT NVL(SUM(GMES.SF_SPRF_PRODC_WGT(PON)), 0)
          FROM GMES.SPRA1103
         WHERE PREQ_NO = A.PREQ_NO
       )                                                                                           AS PRF_WGT
     , B.CYCLE_TY                                                                                  AS ROLL_CYCLE_TY
     , B.SPEC_CONTS
     , A.CUR_PRC_INDI_WGT
     , CASE WHEN GMES.SF_SPRA_HS_YN('PREQ', 'C', '*', '*', A.PREQ_NO, C.MATR_LARG, E.IRN_NAME) = 'Y' THEN 'Y'
                                                                                                     ELSE
                                                                                                         CASE WHEN C.SHAP_TY IN ('BM', 'BT', 'IG', 'WR') THEN
                                                                                                                  ' '
                                                                                                                                                         ELSE
                                                                                                                  CASE WHEN C.SHAP_TY = 'RB' AND C.HZTL > 135 AND NVL(GMES.SF_SPRA_HSCF_YN(E.IRN_NAME), ' ') = 'Y' THEN
                                                                                                                           'T'
                                                                                                                                                                                                                   ELSE
                                                                                                                           CASE WHEN C.SHAP_TY = 'SB' AND C.HZTL >= 139 AND NVL(GMES.SF_SPRA_HSCF_YN(E.IRN_NAME), ' ') = 'Y' THEN
                                                                                                                                    'T'
                                                                                                                                                                                                                             ELSE
                                                                                                                                    GMES.SF_SPRA_HSCF_YN(E.IRN_NAME)
                                                                                                                           END
                                                                                                                  END
                                                                                                         END
       END                                                                                         AS HS_YN
     , A.COLD_STAT_WGT
     , C.REQ_DELI_DATE
     , C.TOLL_SND_GBN
     , NVL((SELECT 'Y'
              FROM GMES.SPRA6070
             WHERE PREQ_NO = A.PREQ_NO
           ), 'N')                                                                                 AS SHORT_TY
     , (SELECT REMARK
          FROM GMES.SPRA6070
         WHERE PREQ_NO = A.PREQ_NO
       )                                                                                           AS SHORT_REMARK
     , (SELECT SPEC_CONTS FROM GMES.SPRA1416 WHERE IRN_NAME = E.IRN_NAME AND BIT_TY = C.MATR_LARG) AS IRN_REMARK
     , C.PREQ_YM
     , LAST_DAY(C.PREQ_YM || '01')                                                                 AS PREQ_DATE
     , CASE WHEN C.MATR_LARG <> 'T' THEN
                LAST_DAY(C.PREQ_YM || '01') - GMES.SF_SPRA_HEAT_LEADTIME('B', C.SURF_STAT, C.HEAT_PATRN) -- 대형압연에서 진행하는 소형재는 대형재로 봐야함 ('B')
       END                                                                                         AS ROLL_REQ_DATE
  FROM (
      --PON항목 더이상 사용하지 않으므로 GroupBY에서 제외함.
      --열처리 제품재공량(SF_SPRI_ONPROC_WGT)
      SELECT /*+ USE_NL(A B) */
          A.PREQ_NO
           , NVL(SUM(A.PRB_INDI_WGT), 0)                                       AS PRB_INDI_WGT
           , NVL(SUM(A.SPRB_JISI_PROD_WGT), 0)                                 AS SPRB_JISI_PROD_WGT
           , NVL(SUM(A.PRC_INDI_WGT), 0)                                       AS PRC_INDI_WGT
           , NVL(SUM(A.PRC_TARGET_WGT), 0)                                     AS PRC_TARGET_WGT
           , NVL(SUM(A.CHR_WGT), 0)                                            AS CHR_WGT
           , NVL(SUM(A.TOT_CHR_WGT), 0)                                        AS TOT_CHR_WGT
           , NVL(SUM(A.PRODC_PER_WGT), 0)                                      AS PRODC_PER_WGT
           , NVL(SUM(A.PRC_WGT), 0)                                            AS PRC_WGT
           , NVL(SUM(A.PRC_BT_WGT), 0)                                         AS PRC_BT_WGT
           , NVL(SUM(A.CUR_PRC_INDI_WGT), 0)                                   AS CUR_PRC_INDI_WGT
           , NVL(SUM(A.PRK_PRODC_QTY), 0)                                      AS PRK_PRODC_QTY
           , NVL(SUM(A.PRK_WGT), 0)                                            AS PRK_WGT
           , NVL(SUM(A.CHNG_WGT), 0)                                           AS CHNG_WGT
           , NVL(SUM(A.BAD_WGT), 0)                                            AS BAD_WGT
           , NVL(SUM(A.BORYU_WGT), 0)                                          AS BORYU_WGT
           , NVL(SUM(A.ONPROC_WGT), 0)                                         AS ONPROC_WGT
           , NVL(SUM(A.PRI_WGT), 0)                                            AS PRI_WGT
           , NVL(SUM(A.PRB_COLD_WGT), 0)                                       AS PRB_COLD_WGT
           , NVL(SUM(A.COLD_STAT_WGT), 0)                                      AS COLD_STAT_WGT
           , NVL(SUM(A.PRW_WGT), 0)                                            AS PRW_WGT
           , NVL(SUM(A.PRF_WGT), 0)                                            AS PRF_WGT
           , NVL(SUM(A.PRI_ONPROC_WGT_1), 0) + NVL(SUM(A.PRI_ONPROC_WGT_2), 0) AS PRI_ONPROC_WGT
        FROM (
            --열처리 제품재공량(SF_SPRI_ONPROC_WGT)
            SELECT /*+ USE_NL(A B) */
                A.PREQ_NO
                 , A.PON
                 , A.PRB_INDI_WGT
                 , A.SPRB_JISI_PROD_WGT
                 , A.PRC_INDI_WGT
                 , A.PRC_TARGET_WGT
                 , A.CHR_WGT
                 , A.TOT_CHR_WGT
                 , A.PRODC_PER_WGT
                 , A.PRC_WGT
                 , A.PRC_BT_WGT
                 , A.CUR_PRC_INDI_WGT
                 , A.PRK_PRODC_QTY
                 , A.PRK_WGT
                 , A.CHNG_WGT
                 , A.BAD_WGT
                 , A.BORYU_WGT
                 , A.ONPROC_WGT
                 , A.PRI_WGT
                 , A.PRB_COLD_WGT
                 , A.COLD_STAT_WGT
                 , A.PRW_WGT
                 , A.PRF_WGT
                 , A.PRI_ONPROC_WGT_1
                 , SUM(B.BNDL_WGT) AS PRI_ONPROC_WGT_2
              FROM (
                  --열처리 소재재공량(SF_SPRI_ONPROC_WGT)
                  SELECT /*+ USE_NL(A B) */
                      A.PREQ_NO
                       , A.PON
                       , A.PRB_INDI_WGT
                       , A.SPRB_JISI_PROD_WGT
                       , A.PRC_INDI_WGT
                       , A.PRC_TARGET_WGT
                       , A.CHR_WGT
                       , A.TOT_CHR_WGT
                       , A.PRODC_PER_WGT
                       , A.PRC_WGT
                       , A.PRC_BT_WGT
                       , A.CUR_PRC_INDI_WGT
                       , A.PRK_PRODC_QTY
                       , A.PRK_WGT
                       , A.CHNG_WGT
                       , A.BAD_WGT
                       , A.BORYU_WGT
                       , A.ONPROC_WGT
                       , A.PRI_WGT
                       , A.PRB_COLD_WGT
                       , A.COLD_STAT_WGT
                       , A.PRW_WGT
                       , A.PRF_WGT
                       , SUM(B.BNDL_WGT) AS PRI_ONPROC_WGT_1
                    FROM (
                        --소압생산량(GMES.SF_SPRF_PRODC_WGT)
                        SELECT /*+ USE_NL(A B) */
                            A.PREQ_NO
                             , A.PON
                             , A.PRB_INDI_WGT
                             , A.SPRB_JISI_PROD_WGT
                             , A.PRC_INDI_WGT
                             , A.PRC_TARGET_WGT
                             , A.CHR_WGT
                             , A.TOT_CHR_WGT
                             , A.PRODC_PER_WGT
                             , A.PRC_WGT
                             , A.PRC_BT_WGT
                             , A.CUR_PRC_INDI_WGT
                             , A.PRK_PRODC_QTY
                             , A.PRK_WGT
                             , A.CHNG_WGT
                             , A.BAD_WGT
                             , A.BORYU_WGT
                             , A.ONPROC_WGT
                             , A.PRI_WGT
                             , A.PRB_COLD_WGT
                             , A.COLD_STAT_WGT
                             , A.PRW_WGT
                             , SUM(B.WGT) AS PRF_WGT
                          FROM (
                              --BT생산량(SF_SPRW_PRODC_WGT)
                              SELECT /*+ USE_NL(A B) */
                                  A.PREQ_NO
                                   , A.PON
                                   , A.PRB_INDI_WGT
                                   , A.SPRB_JISI_PROD_WGT
                                   , A.PRC_INDI_WGT
                                   , A.PRC_TARGET_WGT
                                   , A.CHR_WGT
                                   , A.TOT_CHR_WGT
                                   , A.PRODC_PER_WGT
                                   , A.PRC_WGT
                                   , A.PRC_BT_WGT
                                   , A.CUR_PRC_INDI_WGT
                                   , A.PRK_PRODC_QTY
                                   , A.PRK_WGT
                                   , A.CHNG_WGT
                                   , A.BAD_WGT
                                   , A.BORYU_WGT
                                   , A.ONPROC_WGT
                                   , A.PRI_WGT
                                   , A.PRB_COLD_WGT
                                   , A.COLD_STAT_WGT
                                   , SUM(B.WRK_WGT) AS PRW_WGT
                                FROM (
                                    --제강냉재대상량(GMES.SF_SPRA_PRB_COLD_WGT)
                                    SELECT A.PREQ_NO
                                         , A.PON
                                         , A.PRB_INDI_WGT
                                         , A.SPRB_JISI_PROD_WGT
                                         , A.PRC_INDI_WGT
                                         , A.PRC_TARGET_WGT
                                         , A.CHR_WGT
                                         , A.TOT_CHR_WGT
                                         , A.PRODC_PER_WGT
                                         , A.PRC_WGT
                                         , A.PRC_BT_WGT
                                         , A.CUR_PRC_INDI_WGT
                                         , A.PRK_PRODC_QTY
                                         , A.PRK_WGT
                                         , A.CHNG_WGT
                                         , A.BAD_WGT
                                         , A.BORYU_WGT
                                         , A.ONPROC_WGT
                                         , A.PRI_WGT
                                         , A.PRB_COLD_WGT
                                         , SUM(B.PRODC_WGT) AS COLD_STAT_WGT
                                      FROM (
                                          --제강냉재대상량(GMES.SF_SPRA_PRB_COLD_WGT)
                                          SELECT A.PREQ_NO
                                               , A.PON
                                               , A.PRB_INDI_WGT
                                               , A.SPRB_JISI_PROD_WGT
                                               , A.PRC_INDI_WGT
                                               , A.PRC_TARGET_WGT
                                               , A.CHR_WGT
                                               , A.TOT_CHR_WGT
                                               , A.PRODC_PER_WGT
                                               , A.PRC_WGT
                                               , A.PRC_BT_WGT
                                               , A.CUR_PRC_INDI_WGT
                                               , A.PRK_PRODC_QTY
                                               , A.PRK_WGT
                                               , A.CHNG_WGT
                                               , A.BAD_WGT
                                               , A.BORYU_WGT
                                               , A.ONPROC_WGT
                                               , A.PRI_WGT
                                               , SUM(B.PRODC_WGT) AS PRB_COLD_WGT
                                            FROM (
                                                --열처리생산량(GMES.SF_SPRI_PRODC_WGT)
                                                SELECT /*+ USE_NL(A B) */
                                                    A.PREQ_NO
                                                     , A.PON
                                                     , A.PRB_INDI_WGT
                                                     , A.SPRB_JISI_PROD_WGT
                                                     , A.PRC_INDI_WGT
                                                     , A.PRC_TARGET_WGT
                                                     , A.CHR_WGT
                                                     , A.TOT_CHR_WGT
                                                     , A.PRODC_PER_WGT
                                                     , A.PRC_WGT
                                                     , A.PRC_BT_WGT
                                                     , A.CUR_PRC_INDI_WGT
                                                     , A.PRK_PRODC_QTY
                                                     , A.PRK_WGT
                                                     , A.CHNG_WGT
                                                     , A.BAD_WGT
                                                     , A.BORYU_WGT
                                                     , A.ONPROC_WGT
                                                     , SUM(B.BNDL_WGT) AS PRI_WGT
                                                  FROM (
                                                      --대형정정재공량(GMES.SF_SPRD_ONPROC_WGT)
                                                      SELECT /*+ USE_NL(A B) */
                                                          A.PREQ_NO
                                                           , A.PON
                                                           , A.PRB_INDI_WGT
                                                           , A.SPRB_JISI_PROD_WGT
                                                           , A.PRC_INDI_WGT
                                                           , A.PRC_TARGET_WGT
                                                           , A.CHR_WGT
                                                           , A.TOT_CHR_WGT
                                                           , A.PRODC_PER_WGT
                                                           , A.PRC_WGT
                                                           , A.PRC_BT_WGT
                                                           , A.CUR_PRC_INDI_WGT
                                                           , A.PRK_PRODC_QTY
                                                           , A.PRK_WGT
                                                           , A.CHNG_WGT
                                                           , A.BAD_WGT
                                                           , A.BORYU_WGT
                                                           , SUM(B.UT_WGT) AS ONPROC_WGT
                                                        FROM (
                                                            --전용량/ 폐기량/ 보류량
                                                            SELECT /*+ USE_NL(A B) */
                                                                A.PREQ_NO
                                                                 , A.PON
                                                                 , A.PRB_INDI_WGT
                                                                 , A.SPRB_JISI_PROD_WGT
                                                                 , A.PRC_INDI_WGT
                                                                 , A.PRC_TARGET_WGT
                                                                 , A.CHR_WGT
                                                                 , A.TOT_CHR_WGT
                                                                 , A.PRODC_PER_WGT
                                                                 , A.PRC_WGT
                                                                 , A.PRC_BT_WGT
                                                                 , A.CUR_PRC_INDI_WGT
                                                                 , A.PRK_PRODC_QTY
                                                                 , A.PRK_WGT
                                                                 , SUM(CASE WHEN B.ACT_CODE IN ('DU', 'DC', 'SE', 'SP', 'JD') THEN B.ACT_WGT ELSE 0 END) AS CHNG_WGT
                                                                 , SUM(CASE WHEN B.ACT_CODE IN (SELECT CODE FROM BESTERP.CM_CODEDETAIL WHERE CODE_TYPE = 'SQ03' AND USE_YN = 'Y' AND MGT_CHAR7 = 'Y') --= 'JR'
                                                                AND B.PLNT_TY <> 'C' THEN B.ACT_WGT
                                                                                     ELSE 0
                                                                       END)                                                                              AS BAD_WGT
                                                                 , SUM(CASE WHEN B.ACT_CODE = 'JH' AND B.PLNT_TY = 'D' THEN B.ACT_WGT ELSE 0 END)        AS BORYU_WGT
                                                              FROM (
                                                                  --입고수량 / 제품입고중량(SF_SPRK_PRODC_QTY, GMES.SF_SPRK_PRODC_WGT2)
                                                                  SELECT /*+ USE_NL(A B) */
                                                                      A.PREQ_NO
                                                                       , A.PON
                                                                       , A.PRB_INDI_WGT
                                                                       , A.SPRB_JISI_PROD_WGT
                                                                       , A.PRC_INDI_WGT
                                                                       , A.PRC_TARGET_WGT
                                                                       , A.CHR_WGT
                                                                       , A.TOT_CHR_WGT
                                                                       , A.PRODC_PER_WGT
                                                                       , A.PRC_WGT
                                                                       , A.PRC_BT_WGT
                                                                       , A.CUR_PRC_INDI_WGT
                                                                       -- , SUM(CASE WHEN B.PON IS NOT NULL THEN 1 ELSE 0 END)  AS PRK_PRODC_QTY  --(2017.10.25 주석처리) 번들수량
                                                                       , SUM(B.INVT_QTY) AS PRK_PRODC_QTY --(2017.10.25) Bar수량
                                                                       , SUM(B.INVT_WGT) AS PRK_WGT
                                                                    FROM (
                                                                        --대압생산량(GMES.SF_SPRC_PRODC_WGT, GMES.SF_SPRC_PRODC_WGT_TY, GMES.SF_SPRC_PRODC_WGT_TY2)
                                                                        SELECT /*+ USE_NL(A B) */
                                                                            A.PREQ_NO
                                                                             , A.PON
                                                                             , A.PRB_INDI_WGT
                                                                             , A.SPRB_JISI_PROD_WGT
                                                                             , A.PRC_INDI_WGT
                                                                             , A.PRC_TARGET_WGT
                                                                             , A.CHR_WGT
                                                                             , A.TOT_CHR_WGT
                                                                             , SUM(CASE WHEN SUBSTR(B.PRC_PROD_CD, 1, 2) <> 'BT' THEN B.WGT ELSE 0 END)                                         AS PRODC_PER_WGT
                                                                             , SUM(CASE WHEN SUBSTR(B.PRC_PROD_CD, 1, 2) IN ('RB', 'SB', 'LT') THEN
                                                                                            -- 현재시점 기준
                                                                                            CASE WHEN '1' = '1' THEN
                                                                                                     B.WGT
                                                                                                                ELSE
                                                                                                     -- 입력받은 기준일자 기준
                                                                                                     CASE WHEN B.CM_STD_DATE <= TO_CHAR(SYSDATE, 'YYYY-MM-DD') THEN
                                                                                                              B.WGT
                                                                                                                                                               ELSE 0
                                                                                                     END
                                                                                            END
                                                                                                                                               ELSE 0
                                                                                   END)                                                                                                         AS PRC_WGT
                                                                             , SUM(CASE WHEN SUBSTR(B.PRC_PROD_CD, 1, 2) = 'BT' THEN B.WGT ELSE 0 END)                                          AS PRC_BT_WGT
                                                                             , CASE WHEN (SUBSTR(B.PRC_PROD_CD, 1, 2) IN ('RB', 'SB') AND A.PON IS NOT NULL) THEN 0 ELSE A.CUR_PRC_INDI_WGT END AS CUR_PRC_INDI_WGT --(2016.12.19),임종현 과장 요청(현 대압 작업지시량)
                                                                          FROM (
                                                                              --가열로장입량/대압총장입량(SF_SPRA_CHR_WGT)
                                                                              SELECT /*+ USE_NL(A B) */
                                                                                  A.PREQ_NO
                                                                                   , A.PON
                                                                                   , A.PRB_INDI_WGT
                                                                                   , A.SPRB_JISI_PROD_WGT
                                                                                   , A.PRC_INDI_WGT
                                                                                   , A.CUR_PRC_INDI_WGT
                                                                                   , A.PRC_TARGET_WGT
                                                                                   , SUM(B.WGT)
                                                                                  - SUM(CASE WHEN EXISTS(SELECT 'X'
                                                                                                           FROM GMES.SPRC3006 X
                                                                                                          WHERE X.PON = B.PON
                                                                                                            AND X.HEAT_NO = B.HEAT_NO
                                                                                                            AND X.MATR_NO = B.MATR_NO
                                                                                                            AND X.WGT > 0
                                                                                                            AND ROWNUM = 1
                                                                                                        )
                                                                                                 THEN B.WGT
                                                                                                 ELSE 0
                                                                                        END)    AS CHR_WGT
                                                                                   , SUM(B.WGT) AS TOT_CHR_WGT
                                                                                FROM (
                                                                                    -- 대압작업지시량/ 대압대상분량(GMES.SF_SPRC_INDI_WGT, GMES.SF_SPRA_INDI_TARGET_WGT)
                                                                                    SELECT /*+ USE_NL(A B) */
                                                                                        A.PREQ_NO
                                                                                         , A.PON
                                                                                         , A.PRB_INDI_WGT
                                                                                         , A.SPRB_JISI_PROD_WGT
                                                                                         , SUM(CASE WHEN B.BIT_TY IN ('B', 'I')
                                                                                        AND B.INDI_SEQ > 0
                                                                                        AND B.PRGRS_STAT IN ('2', '3', '4', '5', 'D')
                                                                                        AND TRUNC(B.WRK_STRT_TIME) < TO_DATE('9999-12-31', 'YYYY-MM-DD')
                                                                                        AND (A.HC_TY IN ('H', 'W')
                                                                                            OR (A.HC_TY = 'C' AND B.NO_TY IN ('B', 'C', 'J'))
                                                                                                             )
                                                                                        AND A.PON NOT IN (SELECT PON
                                                                                                            FROM GMES.SPRC3006
                                                                                                           WHERE PON = A.PON
                                                                                                             AND 'D' = B.PRGRS_STAT
                                                                                                             AND ROWNUM = 1
                                                                                                         )
                                                                                                        THEN B.INDI_WGT
                                                                                                        ELSE 0
                                                                                               END) AS PRC_INDI_WGT
                                                                                         , SUM(CASE WHEN B.BIT_TY IN ('B', 'I')
                                                                                        AND B.INDI_SEQ > 0
                                                                                        AND B.PRGRS_STAT IN ('1', '2', '3', '4', '5') --대상분선정(1) 코드 추가
                                                                                        --AND TRUNC(B.WRK_STRT_TIME) < TO_DATE('9999-12-31', 'YYYY-MM-DD')   --(대압)관제실 작업지시 미처리 상태.
                                                                                        AND (A.HC_TY IN ('H', 'W')
                                                                                            OR (A.HC_TY = 'C' AND B.NO_TY IN ('B', 'C', 'J'))
                                                                                                             )
                                                                                                        THEN B.INDI_WGT
                                                                                                        ELSE 0
                                                                                               END) AS CUR_PRC_INDI_WGT
                                                                                         , SUM(CASE WHEN A.HC_TY IN ('H', 'W')
                                                                                        AND B.PRGRS_STAT = '1'
                                                                                                        THEN B.INDI_WGT
                                                                                                        ELSE 0
                                                                                               END) AS PRC_TARGET_WGT
                                                                                      FROM (
                                                                                          --제강지시실적량(GMES.SF_SPRA_SPRB_JISI_PROD_WGT)
                                                                                          SELECT A.PREQ_NO
                                                                                               , A.PON
                                                                                               , A.HC_TY
                                                                                               , A.PRB_INDI_WGT
                                                                                               , SUM(B.PRODC_WGT) AS SPRB_JISI_PROD_WGT
                                                                                            FROM (
                                                                                                --==========================================================================
                                                                                                --제강지시량(HEAT_NO사용유무에 따라 100_MASTER_1, 100_MASTER_2쿼리를 대입함.
                                                                                                --==========================================================================
                                                                                                /* 100_MASTER_1  - HEAT_NO 없이 조회   */
                                                                                                --제강지시량(GMES.SF_SPRA_PRB_INDI_WGT)
                                                                                                SELECT A.PREQ_NO
                                                                                                     , B.PON
                                                                                                     , B.HC_TY
                                                                                                     , SUM(C.INDI_WGT) AS PRB_INDI_WGT
                                                                                                  FROM GMES.SPRA1102 A
                                                                                                      LEFT OUTER JOIN GMES.SPRA1103 B
                                                                                                      ON B.PREQ_NO = A.PREQ_NO
                                                                                                          AND B.USE_YN = 'Y'
                                                                                                      JOIN BESTERP.SSAZ5100 F
                                                                                                      ON F.PREQ_NO = A.PREQ_NO
                                                                                                      LEFT OUTER JOIN GMES.SPRA2003 C
                                                                                                      ON C.PON = B.PON
                                                                                                          AND C.DETL_NO > '010000'
                                                                                                          AND TRIM(C.PLNT_CODE) = 'B'
                                                                                                          AND C.PRGRS_STAT IN ('1', '2', '3', '4', '5')
                                                                                                 WHERE 
                                                                                                 	A.PREQ_YM BETWEEN TO_CHAR(ADD_MONTHS(SYSDATE, -3), 'YYYYMM') AND TO_CHAR(ADD_MONTHS(SYSDATE, 2), 'YYYYMM')
--                                                                                                 	A.PREQ_YM BETWEEN TO_CHAR(SYSDATE, 'YYYYMM') AND TO_CHAR(SYSDATE, 'YYYYMM')
                                                                                                   AND A.PROD_USE IN ('A', 'B', 'Z')
                                                                                                   AND (('Y' = 'Y' AND ((F.CO_TY IN ('D', 'E') AND NVL(F.TOLL_PROCESS_GBN, '*') = '*')) --(2016-01-05), 관제실 요청으로 P, R 오더 제외, (20220527) 임가공수주 제외
                                                                                                     OR (NVL(F.TOLL_PROCESS_GBN, '*') = 'H') -- (2022.12.28), 임가공절단 추가, 조용씨 요청
                                                                                                            )
                                                                                                     OR ('Y' = 'N' AND ((('%' = 'H' AND F.TOLL_PROCESS_GBN LIKE '%')
                                                                                                         OR ('%' = 'K' AND F.TOLL_PROCESS_GBN NOT IN ('*', 'H'))
                                                                                                                            )
                                                                                                         OR ('%' NOT IN ('H', 'K') AND F.CO_TY LIKE '%')
                                                                                                         )
                                                                                                            )
                                                                                                     )
                                                                                                 GROUP BY A.PREQ_NO
                                                                                                        , B.PON
                                                                                                        , B.HC_TY
                                                                                                 ) A
                                                                                                LEFT OUTER JOIN GMES.SPRB3080 B
                                                                                                ON B.PON = A.PON
                                                                                           GROUP BY A.PREQ_NO
                                                                                                  , A.PON
                                                                                                  , A.HC_TY
                                                                                                  , A.PRB_INDI_WGT
                                                                                           ) A
                                                                                          LEFT OUTER JOIN GMES.SPRA2003 B
                                                                                          ON B.PON = A.PON
                                                                                              AND TRIM(B.PLNT_CODE) = 'C'
                                                                                     GROUP BY A.PREQ_NO
                                                                                            , A.PON
                                                                                            , A.PRB_INDI_WGT
                                                                                            , A.SPRB_JISI_PROD_WGT
                                                                                     ) A
                                                                                    LEFT OUTER JOIN GMES.SPRC3001 B
                                                                                    ON B.PON = A.PON
                                                                                        AND SUBSTR(B.MATR_NO, 1, 1) IN ('1', '2', '3', '4')
                                                                               GROUP BY A.PREQ_NO
                                                                                      , A.PON
                                                                                      , A.PRB_INDI_WGT
                                                                                      , A.SPRB_JISI_PROD_WGT
                                                                                      , A.PRC_INDI_WGT
                                                                                      , A.CUR_PRC_INDI_WGT
                                                                                      , A.PRC_TARGET_WGT
                                                                               ) A
                                                                              LEFT OUTER JOIN GMES.SPRC3006 B
                                                                              ON B.PON = A.PON
                                                                                  AND TRUNC(B.CM_STD_DATE) > TO_DATE('1111-11-11', 'YYYY-MM-DD')
                                                                         GROUP BY A.PREQ_NO
                                                                                , A.PON
                                                                                , A.PRB_INDI_WGT
                                                                                , A.SPRB_JISI_PROD_WGT
                                                                                , A.PRC_INDI_WGT
                                                                                , A.PRC_TARGET_WGT
                                                                                , A.CHR_WGT
                                                                                , A.TOT_CHR_WGT
                                                                                , CASE WHEN (SUBSTR(B.PRC_PROD_CD, 1, 2) IN ('RB', 'SB') AND A.PON IS NOT NULL) THEN 0 ELSE A.CUR_PRC_INDI_WGT END --(2016.12.19),임종현 과장 요청(현 대압 작업지시량)
                                                                         ) A
                                                                        LEFT OUTER JOIN GMES.SGDZ5100 B
                                                                        ON B.PON = A.PON
                                                                            AND TRUNC(B.IBGO_DATE) > TO_DATE('1111-11-11', 'YYYY-MM-DD')
                                      -- 정상입고뿐만 아니라 모든 입고를 보여줌(20160509)
                                      --                           AND B.IBGO_TY = '1A'
                                                                   GROUP BY A.PREQ_NO
                                                                          , A.PON
                                                                          , A.PRB_INDI_WGT
                                                                          , A.SPRB_JISI_PROD_WGT
                                                                          , A.PRC_INDI_WGT
                                                                          , A.PRC_TARGET_WGT
                                                                          , A.CHR_WGT
                                                                          , A.TOT_CHR_WGT
                                                                          , A.PRODC_PER_WGT
                                                                          , A.PRC_WGT
                                                                          , A.PRC_BT_WGT
                                                                          , A.CUR_PRC_INDI_WGT
                                                                   ) A
                                                                  LEFT OUTER JOIN GMES.SQAZ1210 B
                                                                  ON B.PON = A.PON
                                                                      AND B.MATR_PROD_TY IN ('1', '2')
                                                                      AND B.PLNT_TY IN ('C', 'D', 'H')
                                                                      AND (B.ACT_CODE IN ('DU', 'DC', 'SE', 'SP', 'JD', 'JR', 'JH')
                                                                          OR B.ACT_CODE IN (SELECT CODE FROM BESTERP.CM_CODEDETAIL WHERE CODE_TYPE = 'SQ03' AND USE_YN = 'Y' AND MGT_CHAR7 = 'Y')
                                                                         )
                                                             GROUP BY A.PREQ_NO
                                                                    , A.PON
                                                                    , A.PRB_INDI_WGT
                                                                    , A.SPRB_JISI_PROD_WGT
                                                                    , A.PRC_INDI_WGT
                                                                    , A.PRC_TARGET_WGT
                                                                    , A.CHR_WGT
                                                                    , A.TOT_CHR_WGT
                                                                    , A.PRODC_PER_WGT
                                                                    , A.PRC_WGT
                                                                    , A.PRC_BT_WGT
                                                                    , A.CUR_PRC_INDI_WGT
                                                                    , A.PRK_PRODC_QTY
                                                                    , A.PRK_WGT
                                                             ) A
                                                            LEFT OUTER JOIN GMES.SPRD4060 B
                                                            ON B.PON = A.PON
                                                                AND TRUNC(B.CHUL_DATE) = TO_DATE('1111-11-11', 'YYYY-MM-DD')
                                                       GROUP BY A.PREQ_NO
                                                              , A.PON
                                                              , A.PRB_INDI_WGT
                                                              , A.SPRB_JISI_PROD_WGT
                                                              , A.PRC_INDI_WGT
                                                              , A.PRC_TARGET_WGT
                                                              , A.CHR_WGT
                                                              , A.TOT_CHR_WGT
                                                              , A.PRODC_PER_WGT
                                                              , A.PRC_WGT
                                                              , A.PRC_BT_WGT
                                                              , A.CUR_PRC_INDI_WGT
                                                              , A.PRK_PRODC_QTY
                                                              , A.PRK_WGT
                                                              , A.CHNG_WGT
                                                              , A.BAD_WGT
                                                              , A.BORYU_WGT
                                                       ) A
                                                      LEFT OUTER JOIN GMES.SPRI4111 B
                                                      ON B.PON = A.PON
                                                          AND B.WRK_LAST_TY = 'Y'
                                                 GROUP BY A.PREQ_NO
                                                        , A.PON
                                                        , A.PRB_INDI_WGT
                                                        , A.SPRB_JISI_PROD_WGT
                                                        , A.PRC_INDI_WGT
                                                        , A.PRC_TARGET_WGT
                                                        , A.CHR_WGT
                                                        , A.TOT_CHR_WGT
                                                        , A.PRODC_PER_WGT
                                                        , A.PRC_WGT
                                                        , A.PRC_BT_WGT
                                                        , A.CUR_PRC_INDI_WGT
                                                        , A.PRK_PRODC_QTY
                                                        , A.PRK_WGT
                                                        , A.CHNG_WGT
                                                        , A.BAD_WGT
                                                        , A.BORYU_WGT
                                                        , A.ONPROC_WGT
                                                 ) A
                                                LEFT OUTER JOIN GMES.SPRB4010 B
                                                ON B.ASGN_PON = A.PON
                                                    AND TRUNC(B.CHUL_DATE) = TO_DATE('1111-11-11', 'YYYY-MM-DD')
                                                    AND TRUNC(B.IBGO_DATE) > TO_DATE('1111-11-11', 'YYYY-MM-DD')
                                                    AND B.BIT_TY IN ('B', 'I')
                                                    AND NVL(B.TOT_DCISN, '*') <> 'N'
                                                    AND NOT EXISTS(SELECT 'X'
                                                                     FROM GMES.SPRC3001 X
                                                                    WHERE X.PON = B.ASGN_PON
                                                                      AND X.MATR_NO = B.MATR_NO
                                                                      AND ROWNUM = 1
                                                                  )
                                           GROUP BY A.PREQ_NO
                                                  , A.PON
                                                  , A.PRB_INDI_WGT
                                                  , A.SPRB_JISI_PROD_WGT
                                                  , A.PRC_INDI_WGT
                                                  , A.PRC_TARGET_WGT
                                                  , A.CHR_WGT
                                                  , A.TOT_CHR_WGT
                                                  , A.PRODC_PER_WGT
                                                  , A.PRC_WGT
                                                  , A.PRC_BT_WGT
                                                  , A.CUR_PRC_INDI_WGT
                                                  , A.PRK_PRODC_QTY
                                                  , A.PRK_WGT
                                                  , A.CHNG_WGT
                                                  , A.BAD_WGT
                                                  , A.BORYU_WGT
                                                  , A.ONPROC_WGT
                                                  , A.PRI_WGT
                                           ) A
                                          LEFT OUTER JOIN GMES.SPRB4010 B
                                          ON B.ASGN_PON = A.PON --(2018.09.14)임종현 과장, 냉재할당 상태 중량
                                              AND TRUNC(B.CHUL_DATE) = TO_DATE('1111-11-11', 'YYYY-MM-DD')
                                              AND TRUNC(B.IBGO_DATE) > TO_DATE('1111-11-11', 'YYYY-MM-DD')
                                              AND B.ASGN_PON = B.PON
                                     GROUP BY A.PREQ_NO
                                            , A.PON
                                            , A.PRB_INDI_WGT
                                            , A.SPRB_JISI_PROD_WGT
                                            , A.PRC_INDI_WGT
                                            , A.PRC_TARGET_WGT
                                            , A.CHR_WGT
                                            , A.TOT_CHR_WGT
                                            , A.PRODC_PER_WGT
                                            , A.PRC_WGT
                                            , A.PRC_BT_WGT
                                            , A.CUR_PRC_INDI_WGT
                                            , A.PRK_PRODC_QTY
                                            , A.PRK_WGT
                                            , A.CHNG_WGT
                                            , A.BAD_WGT
                                            , A.BORYU_WGT
                                            , A.ONPROC_WGT
                                            , A.PRI_WGT
                                            , A.PRB_COLD_WGT
                                     ) A
                                    LEFT OUTER JOIN GMES.SPRW4210 B
                                    ON B.PON = A.PON
                                        AND TRUNC(B.IBGO_DATE) > TO_DATE('1111-11-11', 'YYYY-MM-DD')
                                        AND TRUNC(B.WRK_DATE) > TO_DATE('1111-11-11', 'YYYY-MM-DD')
                               GROUP BY A.PREQ_NO
                                      , A.PON
                                      , A.PRB_INDI_WGT
                                      , A.SPRB_JISI_PROD_WGT
                                      , A.PRC_INDI_WGT
                                      , A.PRC_TARGET_WGT
                                      , A.CHR_WGT
                                      , A.TOT_CHR_WGT
                                      , A.PRODC_PER_WGT
                                      , A.PRC_WGT
                                      , A.PRC_BT_WGT
                                      , A.CUR_PRC_INDI_WGT
                                      , A.PRK_PRODC_QTY
                                      , A.PRK_WGT
                                      , A.CHNG_WGT
                                      , A.BAD_WGT
                                      , A.BORYU_WGT
                                      , A.ONPROC_WGT
                                      , A.PRI_WGT
                                      , A.PRB_COLD_WGT
                                      , A.COLD_STAT_WGT
                               ) A
                              LEFT OUTER JOIN GMES.SPRF4110 B
                              ON B.PON = A.PON
                                  AND TRUNC(B.IBGO_DATE) > '1111-11-11'
                         GROUP BY A.PREQ_NO
                                , A.PON
                                , A.PRB_INDI_WGT
                                , A.SPRB_JISI_PROD_WGT
                                , A.PRC_INDI_WGT
                                , A.PRC_TARGET_WGT
                                , A.CHR_WGT
                                , A.TOT_CHR_WGT
                                , A.PRODC_PER_WGT
                                , A.PRC_WGT
                                , A.PRC_BT_WGT
                                , A.CUR_PRC_INDI_WGT
                                , A.PRK_PRODC_QTY
                                , A.PRK_WGT
                                , A.CHNG_WGT
                                , A.BAD_WGT
                                , A.BORYU_WGT
                                , A.ONPROC_WGT
                                , A.PRI_WGT
                                , A.PRB_COLD_WGT
                                , A.COLD_STAT_WGT
                                , A.PRW_WGT
                         ) A
                        LEFT OUTER JOIN GMES.SPRI4011 B
                        ON B.PON = A.PON
                            AND TRUNC(B.CHUL_DATE) = TO_DATE('1111-11-11', 'YYYY-MM-DD')
                   GROUP BY A.PREQ_NO
                          , A.PON
                          , A.PRB_INDI_WGT
                          , A.SPRB_JISI_PROD_WGT
                          , A.PRC_INDI_WGT
                          , A.PRC_TARGET_WGT
                          , A.CHR_WGT
                          , A.TOT_CHR_WGT
                          , A.PRODC_PER_WGT
                          , A.PRC_WGT
                          , A.PRC_BT_WGT
                          , A.CUR_PRC_INDI_WGT
                          , A.PRK_PRODC_QTY
                          , A.PRK_WGT
                          , A.CHNG_WGT
                          , A.BAD_WGT
                          , A.BORYU_WGT
                          , A.ONPROC_WGT
                          , A.PRI_WGT
                          , A.PRB_COLD_WGT
                          , A.COLD_STAT_WGT
                          , A.PRW_WGT
                          , A.PRF_WGT
                   ) A
                  LEFT OUTER JOIN GMES.SPRI4111 B
                  ON B.PON = A.PON
                      AND TRUNC(B.CHUL_DATE) = TO_DATE('1111-11-11', 'YYYY-MM-DD')
             GROUP BY A.PREQ_NO
                    , A.PON
                    , A.PRB_INDI_WGT
                    , A.SPRB_JISI_PROD_WGT
                    , A.PRC_INDI_WGT
                    , A.PRC_TARGET_WGT
                    , A.CHR_WGT
                    , A.TOT_CHR_WGT
                    , A.PRODC_PER_WGT
                    , A.PRC_WGT
                    , A.PRC_BT_WGT
                    , A.CUR_PRC_INDI_WGT
                    , A.PRK_PRODC_QTY
                    , A.PRK_WGT
                    , A.CHNG_WGT
                    , A.BAD_WGT
                    , A.BORYU_WGT
                    , A.ONPROC_WGT
                    , A.PRI_WGT
                    , A.PRB_COLD_WGT
                    , A.COLD_STAT_WGT
                    , A.PRW_WGT
                    , A.PRF_WGT
                    , A.PRI_ONPROC_WGT_1
             ) A
       GROUP BY A.PREQ_NO
       ) A
      JOIN GMES.SPRA1102 B
      ON B.PREQ_NO = A.PREQ_NO
      JOIN BESTERP.SSAZ5100 C
      ON C.PREQ_NO = A.PREQ_NO
      --LEFT OUTER JOIN BESTERP.SSAZ5120 D ON  D.PREQ_NO = C.PREQ_NO
--                                   AND D.MODIFY_GBN = '1'
      LEFT OUTER JOIN BESTERP.STCZ1250 E
      ON E.IRN_CODE = C.IRN_CODE
      LEFT OUTER JOIN BESTERP.SSAZ2100 F
      ON F.CUST_CODE = C.CUST_CODE
) AA
UNION ALL
SELECT 
    AA.*
    -- TO_CHAR(TRUNC(CURRENT_DATE), 'YYYY-MM-DD HH24:MI:SS') "std_date",
	-- TO_CHAR(PREQ_DATE, 'YYYY-MM-DD HH24:MI:SS') as "preq_date",
	-- GBN as "gbn",
	-- PREQ_NO as "preq_no",
	-- TO_CHAR(IN_DATE, 'YYYY-MM-DD HH24:MI:SS') as "in_date",
	-- TO_CHAR(ROLL_REQ_DATE, 'YYYY-MM-DD HH24:MI:SS') as "roll_req_date",
	-- PREQ_WGT as "preq_wgt",
	-- PRC_WGT as "prc_wgt",
	-- PRK_WGT as "prk_wgt",
	-- CUST_NM as "cust_nm",
	-- END_TY as "end_ty",
	-- SURF_STAT as "surf_stat",
	-- HEAT_PATRN as "heat_patrn",
	-- PRC_ROL as "prc_rol",
	-- ITM_SZ as "itm_sz",
	-- IRN_NAME as "irn_name",
	-- ORD_IRN_STD as "ord_irn_std",
	-- QLTY_GRD as "qlty_grd",
	-- LTH_TY as "lth_ty",
	-- 0 as "chr_wgt",
	-- 0 as "cold_stat_wgt",
	-- TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "created_dtm"
FROM
(
SELECT /*+ USE_NL(C E) USE_NL(C F) USE_NL(C L) */
	 '소형압연'                                                                                                                                                         AS GBN
     , A.PREQ_NO
     , E.IRN_NAME
     , C.ITM_SZ
     --GMES.SF_SPRA_CUST_PRF_SZ(C.IRN_CODE, C.ORD_IRN_STD, C.SURF_STAT, C.CUST_CODE, C.HZTL) 대체
     , CASE WHEN M.IRN_CODE IS NOT NULL AND C.TOLL_PROCESS_GBN NOT IN ('P', 'J') THEN 'RB' || SUBSTR(TO_CHAR(M.ROLL_HZTL, '000.00'), 2, 6)
                                                                                 ELSE B.PRF_ROL_TYPE || SUBSTR(TO_CHAR(B.PRF_ROL_SZ, '000.00'), 2, 6)
       END                                                                                                                                                            AS PRC_ROL
     , C.SURF_STAT
     , C.HEAT_PATRN
     , C.PREQ_QTY
     , C.PREQ_WGT
     --최초의뢰량(SF_SSAZ5120_WGT)
     , CASE WHEN 'N' = 'Y' THEN NVL(G.HEAT_TARGET_WGT, NVL(C.PREQ_WGT, C.PREQ_WGT))
                           ELSE NVL(C.PREQ_WGT, C.PREQ_WGT)
       END                                                                                                                                                            AS ORG_PREQ_WGT
     , C.PLSH_YN
     , C.MATR_LARG
     , CASE WHEN C.LAST_END_EMP = 'AUTO' THEN '자동종결'
                                         ELSE CASE WHEN C.PROD_REQ_END_YN = 'Y' THEN '생산종결'
                                                                                ELSE CASE WHEN C.REQ_END_YN = 'Y' THEN '영업종결' ELSE NULL END
                                              END
       END                                                                                                                                                            AS END_TY
     , C.SHAP_TY || C.USE_TY || C.USE_GRD || CASE WHEN C.MATR_LARG = 'T' THEN ' T' END                                                                                AS QLTY_GRD
     , C.CUST_CODE
     , F.CUST_NM
     , C.LTH
     , C.LTH_TY                                                                                                                                                       AS LTH_CODE
     , CASE WHEN C.LTH_TY = '1' THEN '준정척'
            WHEN C.LTH_TY = '2' THEN '준척'
            WHEN C.LTH_TY = '3' THEN '혼척'
            WHEN C.LTH_TY = '4' THEN '준혼척'
            WHEN C.LTH_TY = '5' THEN '정척'
            WHEN C.LTH_TY = '6' THEN '관리척'
            WHEN C.LTH_TY = '9' THEN '기타'
            WHEN C.LTH_TY = 'A' THEN '절단척(준척)'
       END                                                                                                                                                            AS LTH_TY
     , C.ORD_IRN_STD
     , CASE C.MATR_LARG
    WHEN 'B' THEN H.CAST_SPEED_PATRN
    WHEN 'I' THEN NULL
    WHEN 'T' THEN (SELECT S.CAST_SPEED_PATRN
                     FROM GMES.SPRB1060 S
                    WHERE S.IRN_NAME = E.IRN_NAME
                      AND ROWNUM = 1
                  )
       END                                                                                                                                                            AS CAST_SPEED_PATRN
     , C.CREATE_TY
     , B.UNI_YN
     , GMES.SF_SPRA_PLNT_PATH_DESC(C.ITM_CODE, CASE WHEN C.PRODC_INDI_YN = 'N' THEN GMES.SF_SPRA_PLNT_PATH_CHOICE(C.ITM_CODE, A.PREQ_NO) ELSE NVL(B.PLNT_GRP, 0) END) AS PLNT_PATH_DESC
     , CASE WHEN C.PREQ_WGT > 0 THEN CASE WHEN C.SURF_STAT = 'BS'                      THEN ROUND(ROUND(C.PREQ_WGT / 1000) / 0.95)
                                          WHEN C.SURF_STAT IN ('PM', 'CP', 'PD', 'RT') THEN ROUND(ROUND(C.PREQ_WGT / 1000) / 0.95 / 0.9)
                                          WHEN C.SURF_STAT = 'CD'                      THEN ROUND(ROUND(C.PREQ_WGT / 1000) / 0.95 / 0.95)
                                                                                       ELSE 0
                                     END
                                ELSE 0
       END                                                                                                                                                            AS PRF_NEED_WGT
     , C.S_TAL_SPEC
     , B.CHODO_YN
     , J.SPEC_CONTS
     , GMES.SF_SPRA_TST_STD('1', A.PREQ_NO)                                                                                                                           AS TST_STD
     , GMES.SF_SPRA_PON_TST_DCISN('1', A.PREQ_NO, GMES.SF_SPRA_TST_STD('1', A.PREQ_NO))                                                                               AS PON_DCISN
     , C.HZTL_TOL_MAX
     , C.HZTL_TOL_MIN
     , C.VTCL_TOL_MAX
     , C.VTCL_TOL_MIN
     , C.LTH_TOL_MAX
     , C.LTH_TOL_MIN
     , NULL                                                                                                                                                           AS UNT_PREQ_NO
     , GMES.SF_STCZ_JY_ITEM(K.JY_ITEM_CD)                                                                                                                             AS JY_ITEM_NM
     , C.IN_DATE                                                                                                                                                      AS IN_DATE
--    , GMES.SF_SPRA_CUST_CODE_CHK(C.CUST_CODE)  AS CUST_CHK
     , CASE WHEN L.CODE IS NULL THEN 'N' ELSE 'Y' END                                                                                                                 AS CUST_CHK
     , C.ITM_CODE
     , GMES.SF_SPRA_ECT_CHK(A.PREQ_NO)                                                                                                                                AS ECT_CHK
     , GMES.SF_SPRA_EXPIRED_DATE(A.PREQ_NO)                                                                                                                           AS EXPIRED_DATE
     , C.DO_EX
     , GMES.SF_KPRA_MLFT_COND(A.PREQ_NO)                                                                                                                              AS PRG_MLFT_COND
     , GMES.SF_KPRA_UTLA_COND(A.PREQ_NO)                                                                                                                              AS PRG_UT_COND
     -- GMES.SF_SPRA_PREQ_HEAT_MGT_YN 대체
     , (SELECT CASE WHEN COUNT(*) > 0 THEN 'Y' ELSE 'N' END AS CHK
          FROM GMES.STCZ4502 S
         WHERE S.IRN_CODE = C.IRN_CODE
           AND S.ORD_IRN_STD = C.ORD_IRN_STD
           AND S.CUST_CODE = C.CUST_CODE
           AND S.USE_YN = 'Y'
           AND ROWNUM = 1
       )                                                                                                                                                              AS HEAT_MGT_YN
     , A.PRC_WGT                                                                                                                                                      AS PRCA_WGT
     , A.KPRF_WGT
     , A.PRF_WGT                                                                                                                                                      AS PRC_WGT
     , A.PRI_WGT
     , A.PRH_WGT
     , A.PRG_WGT
     , A.ONPROC_WGT
     , A.PRK_WGT
     , A.BAD_WGT
     , A.CHNG_WGT
     , A.ASGN_WGT
     --, GMES.SF_SPRA_PRW_ASGN_WGT(A.PREQ_NO) AS PRW_ASGN_WGT   --기존 Function(함수)
     , A.PRW_ASGN_WGT
     , A.PRW_INDI_ASGN_WGT
     , CASE WHEN '%' = '9' THEN GMES.SF_KPRA_ASGN_POSS_WGT(A.PREQ_NO) --(2017.05.10),김기호 과장, 창녕 수주분일 경우 창녕 할당가능량 함수 적용
                           ELSE GMES.SF_PRA_ASGN_POSS_WGT(A.PREQ_NO)
       END                                                                                                                                                            AS ASGN_POSS_WGT --기존 Function(함수)
     , A.FGH_ASGN_WGT + A.FGH_ACT_WGT                                                                                                                                 AS ACT_PROSS_WGT
     , C.TOLL_PROCESS_GBN
     , CASE WHEN N.CUST_CODE IS NOT NULL AND C.SURF_STAT NOT IN ('PM') THEN 'Y' ELSE 'N' END                                                                          AS ATTEND_TY     -- 2022.05.31, 오병준과장 요청, PM재 제외
     , C.TOLL_SND_GBN
     , C.ROLL_LTH
     , GMES.SF_SPRA_ROL_LTH_CALC(A.PREQ_NO)                                                                                                                           AS ROLL_LTH_2
     --, GMES.SF_SPRA_CSS_WORK_GBN(A.PREQ_NO) AS WORK_GBN
     --, CASE WHEN J.PRH_PM_EQUIP_CD  IS NULL THEN GMES.SF_SPRA_PRH_PM_EQUIP_CD(A.PREQ_NO)
     --           ELSE J.PRH_PM_EQUIP_CD
     --  END AS PM_EQUIP_CD
     , J.PRH_PM_EQUIP_CD
     , LAST_DAY(C.PREQ_YM || '01')                                                                                                                                    AS PREQ_DATE
     , LAST_DAY(C.PREQ_YM || '01') - GMES.SF_SPRA_HEAT_LEADTIME('S', C.SURF_STAT, C.HEAT_PATRN) -- 소형압연에서 진행하는 대형재는 소형재로 봐야함 ('S')
                                                                                                                                                                      AS ROLL_REQ_DATE
--==========================================================
--품목코드별 재공량 자료 포함
--==========================================================
  FROM (
      --ASGN_PON 더이상 사용하지 않으므로, GROUP BY에서 제외
      --소형정정, 2차가공 사내출고 할당(GMES.SF_SPRA_FGH_SANAE_WGT)
      SELECT /*+ USE_NL(A B) */
          A.PREQ_NO
           , A.PRC_WGT
           , A.KPRF_WGT
           , A.PRF_WGT
           , A.PRI_WGT
           , A.PRH_WGT
           , A.PRG_WGT
           , A.ONPROC_WGT
           , A.FGH_ASGN_WGT
           , A.FWGH_ASGN_WGT
           , A.PRK_WGT
           , A.BAD_WGT
           , A.CHNG_WGT
           , A.ASGN_WGT
           , A.PRF_PRODC_WGT
           , A.PRW_ASGN_WGT
           , A.PRW_INDI_ASGN_WGT
           , A.FGH_ACT_WGT
           , NVL(SUM(A.FGH_SANAE_WGT), 0) + NVL(SUM(C.IBGO_WGT), 0) AS FGH_SANAE_WGT
        FROM (
            --ASGN_PON 별 집계
            --소형정정, 2차가공 사내출고 할당(GMES.SF_SPRA_FGH_SANAE_WGT)
            SELECT /*+ USE_NL(A B) */
                A.PREQ_NO
                 , A.PRC_WGT
                 , A.KPRF_WGT
                 , A.PRF_WGT
                 , A.PRI_WGT
                 , A.PRH_WGT
                 , A.PRG_WGT
                 , A.ONPROC_WGT
                 , A.FGH_ASGN_WGT
                 , A.FWGH_ASGN_WGT
                 , A.PRK_WGT
                 , A.BAD_WGT
                 , A.CHNG_WGT
                 , A.ASGN_WGT
                 , A.PRF_PRODC_WGT
                 , A.PRW_ASGN_WGT
                 , A.PRW_INDI_ASGN_WGT
                 , A.FGH_ACT_WGT
                 , B.ASGN_PON
                 , SUM(C.WEI_WGT) AS FGH_SANAE_WGT
              FROM (
                  --PON항목 더이상 사용하지 않으므로 GroupBY에서 제외함.
                  --소형압연 수주 이상재 처리 조치량(GMES.SF_SPRA_FGH_ACT_WGT)
                  SELECT /*+ USE_NL(A B) */
                      A.PREQ_NO
                       , NVL(SUM(A.PRC_WGT), 0)           AS PRC_WGT
                       , NVL(SUM(A.KPRF_WGT), 0)          AS KPRF_WGT
                       , NVL(SUM(A.PRF_PRODC_WGT), 0)     AS PRF_WGT
                       , NVL(SUM(A.PRI_WGT), 0)           AS PRI_WGT
                       , NVL(SUM(A.PRH_WGT), 0)           AS PRH_WGT
                       , NVL(SUM(A.PRG_WGT), 0)           AS PRG_WGT
                       , NVL(SUM(A.ONPROC_WGT), 0)        AS ONPROC_WGT
                       , NVL(SUM(A.FGH_ASGN_WGT), 0)      AS FGH_ASGN_WGT
                       , NVL(SUM(A.FWGH_ASGN_WGT), 0)     AS FWGH_ASGN_WGT
                       , NVL(SUM(A.PRK_WGT), 0)           AS PRK_WGT
                       , NVL(SUM(A.BAD_WGT), 0)           AS BAD_WGT
                       , NVL(SUM(A.CHNG_WGT), 0)          AS CHNG_WGT
                       , NVL(SUM(A.ASGN_WGT), 0)          AS ASGN_WGT
                       , NVL(SUM(A.PRF_PRODC_WGT), 0)     AS PRF_PRODC_WGT
                       , NVL(SUM(A.PRW_ASGN_WGT), 0)      AS PRW_ASGN_WGT
                       , NVL(SUM(A.PRW_INDI_ASGN_WGT), 0) AS PRW_INDI_ASGN_WGT
                       , NVL(SUM(B.ACT_WGT), 0)           AS FGH_ACT_WGT
                    FROM (
                        --BT정정 투입대기 정상할당 집계(GMES.SF_SPRA_PRW_ASGN_WGT, GMES.SF_SPRA_PRW_INDI_ASGN_WGT), 소형압연 수주 정상할당(GMES.SF_SPRA_FWGH_ASGN_WGT) 최종계산
                        SELECT /*+ USE_NL(A B) */
                            A.PREQ_NO
                             , A.PON
                             , A.PRC_WGT
                             , A.KPRF_WGT
                             , A.PRI_WGT
                             , A.PRH_WGT
                             , A.PRG_WGT
                             , A.ONPROC_WGT
                             , A.FGH_ASGN_WGT
                             , A.FGH_ASGN_WGT + NVL(SUM(B.UNTK_WGT), 0) AS FWGH_ASGN_WGT
                             , A.PRK_WGT
                             , A.BAD_WGT
                             , A.CHNG_WGT
                             , A.ASGN_WGT
                             , A.PRF_PRODC_WGT
                             , SUM(CASE WHEN NOT EXISTS(SELECT 'Y'
                                                          FROM GMES.SPRF4210 Y
                                                         WHERE Y.PON = B.PON
                                                           AND Y.CHUL_TY IS NOT NULL --(2016.12.19) 주석처리, (박종석 대리)
                                                           AND ROWNUM = 1
                                                       )
                                            THEN B.UNTK_WGT
                                            ELSE 0
                                   END)                                 AS PRW_ASGN_WGT --(2016.10.22) 할당 가능량 계산식 변경에 따른 주석처리
                             --, SUM(B.UNTK_WGT) AS PRW_ASGN_WGT
                             , SUM(B.UNTK_WGT)                          AS PRW_INDI_ASGN_WGT
                          FROM (
                              --전공정생산실적중량(SF_PRODC_WGT)
                              SELECT /*+ USE_NL(A B) */
                                  A.PREQ_NO
                                   , A.PON
                                   , A.PRC_WGT
                                   , A.KPRF_WGT
                                   , A.PRI_WGT
                                   , A.PRH_WGT
                                   , A.PRG_WGT
                                   , A.ONPROC_WGT
                                   , A.FGH_ASGN_WGT
                                   , A.PRK_WGT
                                   , A.BAD_WGT
                                   , A.CHNG_WGT
                                   , A.ASGN_WGT
                                   , SUM(B.PRODC_WGT) AS PRF_PRODC_WGT
                                FROM (
                                    --소형압연 할당량(GMES.SF_SPRA_PRF_ASGN_WGT)
                                    SELECT /*+ USE_NL(A B) */
                                        A.PREQ_NO
                                         , A.PON
                                         , A.PRC_WGT
                                         , A.KPRF_WGT
                                         , A.PRI_WGT
                                         , A.PRH_WGT
                                         , A.PRG_WGT
                                         , A.ONPROC_WGT
                                         , A.FGH_ASGN_WGT
                                         , A.PRK_WGT
                                         , A.BAD_WGT
                                         , A.CHNG_WGT
                                         , SUM(B.IBGO_WGT) AS ASGN_WGT
                                      FROM (
                                          --폐기량/전용량 (GMES.SF_SPRA_FGH_CHNG_WGT)
                                          SELECT /*+ USE_NL(A B) */
                                              A.PREQ_NO
                                               , A.PON
                                               , A.PRC_WGT
                                               , A.KPRF_WGT
                                               , A.PRI_WGT
                                               , A.PRH_WGT
                                               , A.PRG_WGT
                                               , A.ONPROC_WGT
                                               , A.FGH_ASGN_WGT
                                               , A.PRK_WGT
                                               , NVL(SUM(CASE WHEN B.ACT_CODE IN (SELECT CODE FROM BESTERP.CM_CODEDETAIL WHERE CODE_TYPE = 'SQ03' AND USE_YN = 'Y' AND MGT_CHAR7 = 'Y') --= 'JR'
                                                                  THEN B.ACT_WGT
                                                                  ELSE 0
                                                         END), 0)                                                                        AS BAD_WGT
                                               , NVL(SUM(CASE WHEN B.ACT_CODE IN ('DU', 'DC', 'SE', 'SP') THEN B.ACT_WGT ELSE 0 END), 0) AS CHNG_WGT
                                            FROM (
                                                --제품입고중량(GMES.SF_SPRK_PRODC_WGT2)
                                                SELECT /*+ USE_NL(A B) */
                                                    A.PREQ_NO
                                                     , A.PON
                                                     , A.PRC_WGT
                                                     , A.KPRF_WGT
                                                     , A.PRI_WGT
                                                     , A.PRH_WGT
                                                     , A.PRG_WGT
                                                     , A.ONPROC_WGT
                                                     , A.FGH_ASGN_WGT
                                                     , SUM(B.INVT_WGT) AS PRK_WGT
                                                  FROM (
                                                      --소형압연 수주 정상할당(GMES.SF_SPRA_FGH_ASGN_WGT)
                                                      SELECT /*+ USE_NL(A B) */
                                                          A.PREQ_NO
                                                           , A.PON
                                                           , A.PRC_WGT
                                                           , A.KPRF_WGT
                                                           , A.PRI_WGT
                                                           , A.PRH_WGT
                                                           , A.PRG_WGT
                                                           , A.ONPROC_WGT
                                                           , NVL(A.FGH_ASGN_WGT, 0) + NVL(SUM(B.IBGO_WGT), 0) AS FGH_ASGN_WGT
                                                        FROM (
                                                            --소형정정 재공량 / 소형압연 수주 정상할당(GMES.SF_SPRG_ONPROC_WGT, GMES.GMES.SF_SPRA_FGH_ASGN_WGT)
                                                            SELECT /*+ USE_NL(A B) */
                                                                A.PREQ_NO
                                                                 , A.PON
                                                                 , A.PRC_WGT
                                                                 , A.KPRF_WGT
                                                                 , A.PRI_WGT
                                                                 , A.PRH_WGT
                                                                 , A.PRG_WGT
                                                                 , NVL(A.PRG_ONPROC_WGT, 0) + NVL(SUM(CASE WHEN B.INPT_TIME = TO_DATE('1111-11-11', 'YYYY-MM-DD') THEN B.WEI_WGT ELSE 0 END), 0) AS ONPROC_WGT
                                                                 , SUM(CASE WHEN B.IBGO_TY = '11' THEN B.WEI_WGT ELSE 0 END)                                                                     AS FGH_ASGN_WGT
                                                              FROM (
                                                                  --소형정정 생산량/재공량(GMES.SF_SPRG_PRODC_WGT, GMES.SF_SPRG_ONPROC_WGT)
                                                                  SELECT /*+ USE_NL(A B) */
                                                                      A.PREQ_NO
                                                                       , A.PON
                                                                       , A.PRC_WGT
                                                                       , A.KPRF_WGT
                                                                       , A.PRI_WGT
                                                                       , A.PRH_WGT
                                                                       , SUM(CASE WHEN B.WRK_END_TIME > TO_DATE('1111-11-11', 'YYYY-MM-DD') THEN B.WEI_WGT ELSE 0 END) AS PRG_WGT
                                                                       , SUM(CASE WHEN B.PROD_IBGO_DATE = TO_DATE('1111-11-11', 'YYYY-MM-DD') AND
                                                                                       B.CHNG_DATE = TO_DATE('1111-11-11', 'YYYY-MM-DD') AND NVL(B.ACT_CD, '') NOT IN (SELECT CODE FROM BESTERP.CM_CODEDETAIL WHERE CODE_TYPE = 'SQ03' AND USE_YN = 'Y' AND MGT_CHAR7 = 'Y') --<> 'JR'
                                                                                      THEN B.WEI_WGT
                                                                                      ELSE 0
                                                                             END)                                                                                      AS PRG_ONPROC_WGT
                                                                    FROM (
                                                                        --2차가공 생산량(GMES.SF_SPRH_PRODC_WGT)
                                                                        SELECT /*+ USE_NL(A B) */
                                                                            A.PREQ_NO
                                                                             , A.PON
                                                                             , A.PRC_WGT
                                                                             , A.KPRF_WGT
                                                                             , A.PRI_WGT
                                                                             , SUM(B.BNDL_WGT) AS PRH_WGT
                                                                          FROM (
                                                                              --열처리생산량(GMES.SF_SPRI_PRODC_WGT)
                                                                              SELECT /*+ USE_NL(A B) */
                                                                                  A.PREQ_NO
                                                                                   , A.PON
                                                                                   , A.PRC_WGT
                                                                                   , A.KPRF_WGT
                                                                                   , SUM(B.BNDL_WGT) AS PRI_WGT
                                                                                FROM (
                                                                                    -- 창녕 소형압연 생산량(GMES.SF_SPRF_PRODC_WGT)
                                                                                    SELECT /*+ USE_NL(A B) */
                                                                                        A.PREQ_NO
                                                                                         , A.PON
                                                                                         , A.PRC_WGT
                                                                                         , SUM(B.WGT) AS KPRF_WGT
                                                                                      FROM (
                                                                                          --대형압연 생산량(GMES.SF_SPRC_PRODC_WGT)
                                                                                          SELECT /*+ USE_NL(A B) */
                                                                                              A.PREQ_NO
                                                                                               , A.PON
                                                                                               , SUM(B.WGT) AS PRC_WGT
                                                                                            FROM (SELECT /*+ LEADING(A) */
                                                                                                A.PREQ_NO
                                                                                                       , C.PON
                                                                                                    FROM GMES.SPRA1102 A
                                                                                                        JOIN BESTERP.SSAZ5100 B
                                                                                                        ON B.PREQ_NO = A.PREQ_NO
                                                                                                        LEFT OUTER JOIN GMES.SPRA1103 C
                                                                                                        ON C.PREQ_NO = A.PREQ_NO
                                                                                                            AND C.USE_YN = 'Y'
                                                                                                   WHERE 
                                                                                                     A.PREQ_YM BETWEEN TO_CHAR(ADD_MONTHS(SYSDATE, -3), 'YYYYMM') AND TO_CHAR(ADD_MONTHS(SYSDATE, 2), 'YYYYMM')
                                                                                                   	 --A.PREQ_YM BETWEEN TO_CHAR(SYSDATE, 'YYYYMM') AND TO_CHAR(SYSDATE, 'YYYYMM')
                                                                                                     AND A.PROD_USE IN ('C', 'S')
                                                                                                     --(2011.05.09),생산관리 통합수주 선택 시
                                                                                                     AND ('N' = 'N'
                                                                                                       OR ('N' = 'Y' AND NOT EXISTS(SELECT 'X'
                                                                                                                                      FROM GMES.SPRA1102_UNT X
                                                                                                                                     WHERE X.PREQ_NO = A.PREQ_NO
                                                                                                                                       AND X.UNT_SEQ = 1
                                                                                                                                       AND ROWNUM = 1
                                                                                                                                   )
                                                                                                              )
                                                                                                       )
                                                                                                     AND (('Y' = 'Y' AND (B.CO_TY IN ('D', 'E', 'P', 'R')
                                                                                                       AND B.TOLL_PROCESS_GBN NOT IN ('J', 'S', 'P', 'L', 'B', 'E', 'F')
                                                                                                       -- (2013.09.02),김기호대리,영업수주 선택 시 창녕수주분 제외
                                                                                                       AND A.PREQ_TY <> 'N'
                                                                                                       --(2019.07.04),최중선 대리,강종(PO-AE1055LS, 군산생관 수주처 제외)
                                                                                                       AND (B.IRN_CODE <> 'AAC133' AND B.CUST_CODE <> '21114')
                                                                                                       )
                                                                                                              )
                                                                                                       OR ('Y' = 'N' AND (('%' = '%' AND A.PREQ_TY = 'K') --(2016.10.31),군산수주만 조회 함.
                                                                                                           OR ('%' = 'K' AND B.CO_TY = 'D'
                                                                                                               AND B.TOLL_PROCESS_GBN IN ('J', 'S', 'P', 'L', 'B', 'E', 'F')
                                                                                                                              )
                                                                                                           OR ('%' = 'S' AND B.CO_TY = '%'
                                                                                                               AND B.TOLL_PROCESS_GBN IN ('J', 'S', 'P', 'L', 'B', 'E', 'F')
                                                                                                                              )
                                                                                                           --(2013.06.19),창녕수주분(생산의뢰 주문접수 변경처리(GMES.SPRA1E09)에서 변경된 수주분)
                                                                                                           OR ('%' = '9' AND A.PREQ_TY = (CASE WHEN '%' = '9' THEN 'N' END)
                                                                                                               AND B.TOLL_PROCESS_GBN NOT IN ('J', 'S', 'P', 'L', 'B', 'E', 'F')
                                                                                                                              )
                                                                                                           OR ('%' NOT IN ('%', 'K', 'S', '9') AND B.CO_TY = '%'
                                                                                                               AND B.TOLL_PROCESS_GBN NOT IN ('J', 'S', 'P', 'L', 'B', 'E', 'F')
                                                                                                               AND A.PREQ_TY = 'K'
                                                                                                                              )
                                                                                                           )
                                                                                                              )
                                                                                                       )
                                                                                                     AND (('%' = '%' AND (NVL(A.PRC_ROL_SZ, 0) BETWEEN 0 AND 999999
                                                                                                       OR NVL(A.PRF_ROL_SZ, 0) BETWEEN 0 AND 999999
                                                                                                       )
                                                                                                              )
                                                                                                       OR ((A.PRC_ROL_TYPE = '%' AND NVL(A.PRC_ROL_SZ, 0) BETWEEN 0 AND 999999)
                                                                                                           OR (A.PRF_ROL_TYPE = '%' AND NVL(A.PRF_ROL_SZ, 0) BETWEEN 0 AND 999999)
                                                                                                              )
                                                                                                       )
                                                                                                     AND B.IRN_CODE LIKE '%'
                                                                                                     AND ('%' = '%' OR ('%' <> '%' AND B.HEAT_PATRN LIKE '%'))
                                                                                                     AND ('%' = '%' OR ('%' <> '%' AND B.SURF_STAT LIKE '%'))
                                                                                                     AND A.PREQ_NO LIKE '%'
                                                                                                     AND B.MATR_LARG LIKE '%'
                                                                                                     AND B.LTH_TY LIKE '%'
                                                                                                     AND ('N' <> 'Y' OR ('N' = 'Y' AND B.HEAT_PATRN IS NOT NULL))
                                                                                                     AND ('%' = '%'
                                                                                                       OR ('%' = 'Y' AND (B.LAST_END_EMP = 'AUTO'
                                                                                                           OR B.LAST_END_DATE IS NOT NULL
                                                                                                           )
                                                                                                              )
                                                                                                       OR ('%' = 'N' AND (B.LAST_END_EMP IS NULL AND NVL(B.PROD_REQ_END_YN, 'N') = 'N' AND NVL(B.REQ_END_YN, 'N') = 'N'
                                                                                                           )
                                                                                                              )
                                                                                                       )
                                                                                                 ) A
                                                                                                LEFT OUTER JOIN GMES.SPRC3006 B
                                                                                                ON B.PON = A.PON
                                                                                                    AND TRUNC(B.CM_STD_DATE) > TO_DATE('1111-11-11', 'YYYY-MM-DD')
                                                                                                    AND SUBSTR(B.PRC_PROD_CD, 1, 2) <> 'BT'
                                                                                           GROUP BY A.PREQ_NO
                                                                                                  , A.PON
                                                                                           ) A
                                                                                          LEFT OUTER JOIN GMES.KPRF4110 B
                                                                                          ON B.PON = A.PON
                                                                                              AND TRUNC(B.IBGO_DATE) > TO_DATE('1111-11-11', 'YYYY-MM-DD')
                                                                                     GROUP BY A.PREQ_NO
                                                                                            , A.PON
                                                                                            , A.PRC_WGT
                                                                                     ) A
                                                                                    LEFT OUTER JOIN GMES.SPRI4111 B
                                                                                    ON B.PON = A.PON
                                                                                        AND B.WRK_LAST_TY = 'Y'
                                                                               GROUP BY A.PREQ_NO
                                                                                      , A.PON
                                                                                      , A.PRC_WGT
                                                                                      , A.KPRF_WGT
                                                                               ) A
                                                                              LEFT OUTER JOIN GMES.SPRH4110 B
                                                                              ON B.PON = A.PON
                                                                                  AND TRUNC(B.IBGO_DATE) > TO_DATE('1111-11-11', 'YYYY-MM-DD')
                                                                         GROUP BY A.PREQ_NO
                                                                                , A.PON
                                                                                , A.PRC_WGT
                                                                                , A.KPRF_WGT
                                                                                , A.PRI_WGT
                                                                         ) A
                                                                        LEFT OUTER JOIN GMES.SPRG3011 B
                                                                        ON B.PON = A.PON
                                                                   GROUP BY A.PREQ_NO
                                                                          , A.PON
                                                                          , A.PRC_WGT
                                                                          , A.KPRF_WGT
                                                                          , A.PRI_WGT
                                                                          , A.PRH_WGT
                                                                   ) A
                                                                  LEFT OUTER JOIN GMES.SPRG4070 B
                                                                  ON B.PON = A.PON
                                                                      AND TRUNC(B.CHUL_DATE) = TO_DATE('1111-11-11', 'YYYY-MM-DD')
                                                             GROUP BY A.PREQ_NO
                                                                    , A.PON
                                                                    , A.PRC_WGT
                                                                    , A.KPRF_WGT
                                                                    , A.PRI_WGT
                                                                    , A.PRH_WGT
                                                                    , A.PRG_WGT
                                                                    , NVL(A.PRG_ONPROC_WGT, 0)
                                                             ) A
                                                            LEFT OUTER JOIN GMES.SPRH4010 B
                                                            ON B.PON = A.PON
                                                                AND B.IBGO_TY = '11'
                                                                AND TRUNC(B.CHUL_DATE) = TO_DATE('1111-11-11', 'YYYY-MM-DD')
                                                       GROUP BY A.PREQ_NO
                                                              , A.PON
                                                              , A.PRC_WGT
                                                              , A.KPRF_WGT
                                                              , A.PRI_WGT
                                                              , A.PRH_WGT
                                                              , A.PRG_WGT
                                                              , A.ONPROC_WGT
                                                              , NVL(A.FGH_ASGN_WGT, 0)
                                                       ) A
                                                      LEFT OUTER JOIN GMES.SGDZ5100 B
                                                      ON B.PON = A.PON
                                                          AND TRUNC(B.IBGO_DATE) > TO_DATE('1111-11-11', 'YYYY-MM-DD')
                    -- 정상입고뿐만 아니라 모든 입고를 보여줌(20160509)
                    -- AND B.IBGO_TY = '1A'
                                                 GROUP BY A.PREQ_NO
                                                        , A.PON
                                                        , A.PRC_WGT
                                                        , A.KPRF_WGT
                                                        , A.PRI_WGT
                                                        , A.PRH_WGT
                                                        , A.PRG_WGT
                                                        , A.ONPROC_WGT
                                                        , A.FGH_ASGN_WGT
                                                 ) A
                                                LEFT OUTER JOIN GMES.SQAZ1210 B
                                                ON B.PON = A.PON
                                                    AND B.PLNT_TY IN ('F', 'G', 'H')
                                                    AND (B.ACT_CODE IN ('JR', 'DU', 'DC', 'SE', 'SP')
                                                        OR B.ACT_CODE IN (SELECT CODE FROM BESTERP.CM_CODEDETAIL WHERE CODE_TYPE = 'SQ03' AND USE_YN = 'Y' AND MGT_CHAR7 = 'Y')
                                                       )
                                           GROUP BY A.PREQ_NO
                                                  , A.PON
                                                  , A.PRC_WGT
                                                  , A.KPRF_WGT
                                                  , A.PRI_WGT
                                                  , A.PRH_WGT
                                                  , A.PRG_WGT
                                                  , A.ONPROC_WGT
                                                  , A.FGH_ASGN_WGT
                                                  , A.PRK_WGT
                                           ) A
                                          LEFT OUTER JOIN GMES.SPRF4210 B
                                          ON B.PON = A.PON
                                              AND B.IBGO_TY = '11'
                                              AND NVL(B.CHUL_TY, '*') <> '21'
                                              AND TRUNC(B.CHUL_DATE) = TO_DATE('1111-11-11', 'YYYY-MM-DD')
                                              AND TRUNC(B.REJECT_DATE) = TO_DATE('1111-11-11', 'YYYY-MM-DD')
                                     GROUP BY A.PREQ_NO
                                            , A.PON
                                            , A.PRC_WGT
                                            , A.KPRF_WGT
                                            , A.PRI_WGT
                                            , A.PRH_WGT
                                            , A.PRG_WGT
                                            , A.ONPROC_WGT
                                            , A.FGH_ASGN_WGT
                                            , A.PRK_WGT
                                            , A.BAD_WGT
                                            , A.CHNG_WGT
                                     ) A
                                    LEFT OUTER JOIN GMES.SPRF3060 B
                                    ON B.PON = A.PON
--LEFT OUTER JOIN SPRF4110 B ON  B.PON = A.PON    --(2019.02.21) 최병기 요청, 압연실적 → 번들실적 변경 요청.
--                           AND TRUNC(B.IBGO_DATE) > TO_DATE('1111-11-11', 'YYYY-MM-DD')
                               GROUP BY A.PREQ_NO
                                      , A.PON
                                      , A.PRC_WGT
                                      , A.KPRF_WGT
                                      , A.PRI_WGT
                                      , A.PRH_WGT
                                      , A.PRG_WGT
                                      , A.ONPROC_WGT
                                      , A.FGH_ASGN_WGT
                                      , A.PRK_WGT
                                      , A.BAD_WGT
                                      , A.CHNG_WGT
                                      , A.ASGN_WGT
                               ) A
                              LEFT OUTER JOIN GMES.SPRW4210 B
                              ON B.PON = A.PON
                                  AND B.IBGO_TY = '11'
                                  AND NVL(B.CHUL_TY, '*') <> '21'
                                  AND B.CHA_PLNT = 'F'
                         GROUP BY A.PREQ_NO
                                , A.PON
                                , A.PRC_WGT
                                , A.KPRF_WGT
                                , A.PRI_WGT
                                , A.PRH_WGT
                                , A.PRG_WGT
                                , A.ONPROC_WGT
                                , A.FGH_ASGN_WGT
                                , A.PRK_WGT
                                , A.BAD_WGT
                                , A.CHNG_WGT
                                , A.ASGN_WGT
                                , A.PRF_PRODC_WGT
                         ) A
                        LEFT OUTER JOIN GMES.SQAZ1210 B
                        ON B.ASGN_PON = A.PON
                            AND B.PLNT_TY IN ('F', 'G', 'H')
                            AND B.MATR_PROD_TY IN ('1', '2')
                            AND TRUNC(B.ASGN_DATE) > TO_DATE('1111-11-11', 'YYYY-MM-DD')
                   GROUP BY A.PREQ_NO
                   ) A
                  LEFT OUTER JOIN GMES.SPRA3001 B
                  ON B.ASGN_PREQ_NO = A.PREQ_NO
                      AND TRIM(B.CHUL_PLAC_TY) = 'G'
                  LEFT OUTER JOIN GMES.SPRG4070 C
                  ON C.PON = B.ASGN_PON
                      AND TRUNC(C.CHUL_DATE) = TO_DATE('1111-11-11', 'YYYY-MM-DD')
                      AND C.IBGO_TY = '1A'
             GROUP BY A.PREQ_NO
                    , A.PRC_WGT
                    , A.KPRF_WGT
                    , A.PRI_WGT
                    , A.PRH_WGT
                    , A.PRG_WGT
                    , A.ONPROC_WGT
                    , A.FGH_ASGN_WGT
                    , A.FWGH_ASGN_WGT
                    , A.PRK_WGT
                    , A.BAD_WGT
                    , A.CHNG_WGT
                    , A.ASGN_WGT
                    , A.PRF_PRODC_WGT
                    , A.PRW_ASGN_WGT
                    , A.PRW_INDI_ASGN_WGT
                    , A.FGH_ACT_WGT
                    , B.ASGN_PON
             ) A
            LEFT OUTER JOIN GMES.SPRH4010 C
            ON C.PON = A.ASGN_PON
                AND TRUNC(C.CHUL_DATE) = TO_DATE('1111-11-11', 'YYYY-MM-DD')
                AND C.IBGO_TY = '1A'
       GROUP BY A.PREQ_NO
              , A.PRC_WGT
              , A.KPRF_WGT
              , A.PRI_WGT
              , A.PRH_WGT
              , A.PRG_WGT
              , A.ONPROC_WGT
              , A.FGH_ASGN_WGT
              , A.FWGH_ASGN_WGT
              , A.PRK_WGT
              , A.BAD_WGT
              , A.CHNG_WGT
              , A.ASGN_WGT
              , A.PRF_PRODC_WGT
              , A.PRW_ASGN_WGT
              , A.PRW_INDI_ASGN_WGT
              , A.FGH_ACT_WGT
       ) A
      JOIN GMES.SPRA1102 B
      ON B.PREQ_NO = A.PREQ_NO
      JOIN BESTERP.SSAZ5100 C
      ON C.PREQ_NO = A.PREQ_NO
      --LEFT OUTER JOIN BESTERP.SSAZ5120 D ON  D.PREQ_NO = C.PREQ_NO
--                                   AND D.MODIFY_GBN = '1'
      LEFT OUTER JOIN BESTERP.STCZ1250 E
      ON E.IRN_CODE = C.IRN_CODE
      LEFT OUTER JOIN BESTERP.SSAZ2100 F
      ON F.CUST_CODE = C.CUST_CODE
      LEFT OUTER JOIN GMES.SPRA1102_UNT G
      ON G.PREQ_NO = A.PREQ_NO
      LEFT OUTER JOIN GMES.SPRB1140 H
      ON H.IRN_NAME = E.IRN_NAME
      LEFT OUTER JOIN GMES.SPRA1109 J
      ON J.PREQ_NO = A.PREQ_NO
      LEFT OUTER JOIN BESTERP.SSAZ4000 K
      ON K.ITM_CODE = C.ITM_CODE
      LEFT OUTER JOIN BESTERP.CM_CODEDETAIL L
      ON L.CODE_TYPE = 'SPZJ'
          AND L.CODE = C.CUST_CODE
          AND L.USE_YN = 'Y'
      LEFT OUTER JOIN GMES.STCZ4355 M
      ON M.IRN_CODE = C.IRN_CODE
          AND M.ORD_IRN_STD = C.ORD_IRN_STD
          AND M.SURF_STAT = C.SURF_STAT
          AND M.CUST_CODE = C.CUST_CODE
          AND M.HZTL = C.HZTL
          AND M.USE_YN = 'Y'
      LEFT OUTER JOIN GMES.STCZ4511 N
      ON N.CUST_CODE = C.CUST_CODE
          AND N.IRN_CODE = C.IRN_CODE
          AND C.HZTL BETWEEN N.SIZE_FR AND N.SIZE_TO
          AND N.ANTI_YN = 'Y'
          AND ROWNUM = 1
) AA

-- )
--SELECT
--	"gbn", "preq_no", count(*) cnt
--FROM
--	bbb
--GROUP BY "gbn", "preq_no"
--ORDER BY cnt DESC
;