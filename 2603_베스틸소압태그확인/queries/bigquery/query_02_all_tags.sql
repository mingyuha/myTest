-- ====================================================================
-- [쿼리 02-ALL] 요약 통계 - 전체 태그 대상
-- 분석 항목: 비정상 구간 빈도, MTTR(평균 복구 시간), MTBF(평균 정상 유지 시간),
--            지속 시간 분포 (min / avg / max / p25 / p50 / p75)
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

seg_summary AS (
  SELECT
    disp_tag_nm, seg_id, state,
    MIN(opc_srv_dtm) AS seg_start,
    MAX(opc_srv_dtm) AS seg_end,
    ROUND((DATETIME_DIFF(MAX(opc_srv_dtm), MIN(opc_srv_dtm), MINUTE) + 1) / 60.0, 2) AS duration_hour
  FROM segmented
  GROUP BY disp_tag_nm, seg_id, state
),

abnormal_segs AS (
  SELECT *,
    LEAD(seg_start) OVER (PARTITION BY disp_tag_nm ORDER BY seg_start) AS next_abnormal_start
  FROM seg_summary
  WHERE state = 'abnormal'
)

SELECT
  disp_tag_nm,
  COUNT(*) AS abnormal_count,
  ROUND(SUM(duration_hour) / 24.0 * 100, 1) AS abnormal_pct,
  ROUND(AVG(duration_hour), 2) AS mttr_avg_hour,
  MIN(duration_hour) AS mttr_min_hour,
  MAX(duration_hour) AS mttr_max_hour,
  ROUND(APPROX_QUANTILES(duration_hour, 4)[OFFSET(1)], 2) AS mttr_p25_hour,
  ROUND(APPROX_QUANTILES(duration_hour, 4)[OFFSET(2)], 2) AS mttr_p50_hour,
  ROUND(APPROX_QUANTILES(duration_hour, 4)[OFFSET(3)], 2) AS mttr_p75_hour,
  ROUND(AVG(DATETIME_DIFF(next_abnormal_start, seg_end, MINUTE)) / 60.0, 2) AS mtbf_avg_hour
FROM abnormal_segs
GROUP BY disp_tag_nm
ORDER BY disp_tag_nm
;
