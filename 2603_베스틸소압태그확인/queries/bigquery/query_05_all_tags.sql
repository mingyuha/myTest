-- ====================================================================
-- [쿼리 05-ALL] 수집 유형 및 지연 분석 - 전체 태그 대상
-- 분석 항목:
--   (A) 비정상 구간 내 sub 데이터 소실 여부
--   (B) 수집 지연(lag = opc_srv_dtm - opc_src_dtm) 정상/비정상 상태별 비교
--
-- [날짜 변경] start_dt / end_dt 부분을 수정하세요.
--   동적 설정 (기본값):
--     DATETIME_TRUNC(DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 1 DAY), DAY) -- 어제 0시
--     DATETIME_ADD(DATETIME_TRUNC(CURRENT_DATETIME(), DAY), INTERVAL 8 HOUR) -- 오늘 8시
--   수동 설정 예시:
--     DATETIME '2026-03-18 00:00:00'
--     DATETIME '2026-03-19 08:00:00'
-- ====================================================================

WITH params AS (
  SELECT
    DATETIME_TRUNC(DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 1 DAY), DAY) AS start_dt,
    DATETIME_ADD(DATETIME_TRUNC(CURRENT_DATETIME(), DAY), INTERVAL 8 HOUR) AS end_dt
),

raw_get1m AS (
  SELECT disp_tag_nm, opc_srv_dtm, opc_src_dtm, tag_value
  FROM `dataforge-seahbst.sbm_tag.acm_tag_mt`
  WHERE clct_type_cd = 'get1m'
    AND opc_srv_dtm >= (SELECT start_dt FROM params)
    AND opc_srv_dtm <= (SELECT end_dt FROM params)
),

with_prev AS (
  SELECT *,
    LAG(opc_src_dtm) OVER (PARTITION BY disp_tag_nm ORDER BY opc_srv_dtm) AS prev_src_dtm
  FROM raw_get1m
),

flagged AS (
  SELECT *,
    CASE
      WHEN prev_src_dtm IS NULL THEN 'normal'
      WHEN opc_src_dtm = prev_src_dtm THEN 'abnormal'
      ELSE 'normal'
    END AS state
  FROM with_prev
),

with_state_change AS (
  SELECT *,
    CASE
      WHEN state <> LAG(state, 1, 'normal') OVER (PARTITION BY disp_tag_nm ORDER BY opc_srv_dtm)
      THEN 1 ELSE 0
    END AS is_new_seg
  FROM flagged
),

segmented AS (
  SELECT *,
    SUM(is_new_seg) OVER (PARTITION BY disp_tag_nm ORDER BY opc_srv_dtm ROWS UNBOUNDED PRECEDING) AS seg_id
  FROM with_state_change
),

seg_bounds AS (
  SELECT disp_tag_nm, seg_id, state,
    MIN(opc_srv_dtm) AS seg_start,
    MAX(opc_srv_dtm) AS seg_end
  FROM segmented
  GROUP BY disp_tag_nm, seg_id, state
),

raw_all AS (
  SELECT disp_tag_nm, opc_srv_dtm, opc_src_dtm, tag_value, clct_type_cd,
    DATETIME_DIFF(opc_srv_dtm, opc_src_dtm, SECOND) AS lag_sec
  FROM `dataforge-seahbst.sbm_tag.acm_tag_mt`
  WHERE opc_srv_dtm >= (SELECT start_dt FROM params)
    AND opc_srv_dtm <= (SELECT end_dt FROM params)
),

all_with_state AS (
  SELECT
    r.*,
    COALESCE(s.state, 'normal') AS state,
    s.seg_id
  FROM raw_all r
  LEFT JOIN seg_bounds s
    ON r.disp_tag_nm = s.disp_tag_nm
    AND r.opc_srv_dtm BETWEEN s.seg_start AND s.seg_end
)

SELECT
  disp_tag_nm,
  clct_type_cd,
  state,
  COUNT(*) AS row_count,
  ROUND(AVG(lag_sec), 1) AS lag_avg_sec,
  MIN(lag_sec) AS lag_min_sec,
  MAX(lag_sec) AS lag_max_sec,
  ROUND(APPROX_QUANTILES(lag_sec, 4)[OFFSET(1)], 1) AS lag_p25_sec,
  ROUND(APPROX_QUANTILES(lag_sec, 4)[OFFSET(2)], 1) AS lag_p50_sec,
  ROUND(APPROX_QUANTILES(lag_sec, 4)[OFFSET(3)], 1) AS lag_p75_sec
FROM all_with_state
WHERE lag_sec >= 0
GROUP BY disp_tag_nm, clct_type_cd, state
ORDER BY disp_tag_nm, clct_type_cd, state
;
