-- ====================================================================
-- [쿼리 04-ALL] 값 분석 - 전체 태그 대상
-- 분석 항목:
--   (A) 비정상 시 고착 값 분포
--   (B) 비정상 진입 직전 마지막 정상 tag_value
--   (C) 정상 복귀 직후 첫 번째 tag_value
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
    ROUND((DATETIME_DIFF(MAX(opc_srv_dtm), MIN(opc_srv_dtm), MINUTE) + 1) / 60.0, 2) AS duration_hour,
    ANY_VALUE(tag_value) AS frozen_tag_value
  FROM segmented
  GROUP BY disp_tag_nm, seg_id, state
),

normal_last_row AS (
  SELECT disp_tag_nm, seg_id, tag_value AS last_value
  FROM segmented
  WHERE state = 'normal'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY disp_tag_nm, seg_id ORDER BY opc_srv_dtm DESC) = 1
),

normal_first_row AS (
  SELECT disp_tag_nm, seg_id, tag_value AS first_value
  FROM segmented
  WHERE state = 'normal'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY disp_tag_nm, seg_id ORDER BY opc_srv_dtm ASC) = 1
)

SELECT
  a.disp_tag_nm,
  a.seg_start,
  a.seg_end,
  a.duration_hour,
  a.frozen_tag_value,
  nlr.last_value AS last_normal_value_before,
  nfr.first_value AS first_normal_value_after
FROM seg_summary a
LEFT JOIN normal_last_row nlr ON nlr.disp_tag_nm = a.disp_tag_nm AND nlr.seg_id = a.seg_id - 1
LEFT JOIN normal_first_row nfr ON nfr.disp_tag_nm = a.disp_tag_nm AND nfr.seg_id = a.seg_id + 1
WHERE a.state = 'abnormal'
ORDER BY a.disp_tag_nm, a.seg_start
;
