-- ====================================================================
-- [쿼리 03-ALL] 시간대별 / 요일별 발생 패턴 - 전체 태그 대상
-- 분석 항목: 시간대별 발생 패턴, 요일별 발생 패턴, 일별 추이, 재발 주기
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

abnormal_segs AS (
  SELECT
    disp_tag_nm,
    MIN(opc_srv_dtm) AS seg_start,
    ROUND((DATETIME_DIFF(MAX(opc_srv_dtm), MIN(opc_srv_dtm), MINUTE) + 1) / 60.0, 2) AS duration_hour
  FROM segmented
  WHERE state = 'abnormal'
  GROUP BY disp_tag_nm, seg_id
)

SELECT
  disp_tag_nm,
  DATE(seg_start) AS seg_date,
  FORMAT_DATETIME('%A', seg_start) AS day_of_week,
  EXTRACT(HOUR FROM seg_start) AS hour_of_day,
  COUNT(*) AS abnormal_start_count,
  ROUND(SUM(duration_hour), 2) AS total_abnormal_hour,
  ROUND(AVG(duration_hour), 2) AS avg_duration_hour
FROM abnormal_segs
GROUP BY disp_tag_nm, seg_date, day_of_week, hour_of_day
ORDER BY disp_tag_nm, seg_date, hour_of_day
;
