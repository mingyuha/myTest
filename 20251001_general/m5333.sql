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