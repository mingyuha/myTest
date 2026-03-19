-- ====================================================================
-- [쿼리 01-ALL] 비정상 구간 목록 - 전체 태그 대상
-- 분석 항목: 테이블 내 모든 태그에 대해 비정상 구간 탐지
--
-- [날짜 변경] start_dt / end_dt 부분을 수정하세요.
--   동적 설정 (기본값):
--     DATETIME_TRUNC(DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 1 DAY), DAY) -- 어제 0시
--     DATETIME_ADD(DATETIME_TRUNC(CURRENT_DATETIME(), DAY), INTERVAL 8 HOUR) -- 오늘 8시
--   수동 설정 예시:
--     DATETIME '2026-03-18 00:00:00'
--     DATETIME '2026-03-19 08:00:00'
-- [시간 필터] min_duration_hour / max_duration_hour로 구간 길이 필터링
-- ====================================================================

WITH params AS (
  SELECT
    DATETIME_TRUNC(DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 1 DAY), DAY) AS start_dt,  -- ← 어제 0시
    DATETIME_ADD(DATETIME_TRUNC(CURRENT_DATETIME(), DAY), INTERVAL 8 HOUR) AS end_dt,   -- ← 오늘 8시
    2                              AS min_duration_hour,  -- ← 최소 지속 시간 (이상, 필터 없으면 0)
    999                            AS max_duration_hour   -- ← 최대 지속 시간 (이하, 필터 없으면 999)
),

-- 전체 태그 대상 (IN 절 없음)
raw_get1m AS (
  SELECT disp_tag_nm, opc_srv_dtm, opc_src_dtm, tag_value
  FROM `dataforge-seahbst.sbm_tag.acm_tag_mt`
  WHERE clct_type_cd = 'get1m'
    AND opc_srv_dtm >= (SELECT start_dt FROM params)
    AND opc_srv_dtm <= (SELECT end_dt FROM params)
    -- 태그 필터 없음: 전체 태그 대상
),

with_prev AS (
  SELECT *,
    LAG(opc_src_dtm) OVER (PARTITION BY disp_tag_nm ORDER BY opc_srv_dtm) AS prev_src_dtm
  FROM raw_get1m
),

flagged AS (
  SELECT *,
    CASE
      WHEN prev_src_dtm IS NULL           THEN 'normal'
      WHEN opc_src_dtm = prev_src_dtm     THEN 'abnormal'
      ELSE                                     'normal'
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
)

SELECT
  disp_tag_nm,
  MIN(opc_srv_dtm)                                                  AS seg_start,
  MAX(opc_srv_dtm)                                                  AS seg_end,
  ROUND((DATETIME_DIFF(MAX(opc_srv_dtm), MIN(opc_srv_dtm), MINUTE) + 1) / 60.0, 2)  AS duration_hour,
  COUNT(*)                                                          AS row_count,
  ANY_VALUE(opc_src_dtm)                                            AS frozen_src_dtm,
  ANY_VALUE(tag_value)                                              AS frozen_tag_value
FROM segmented
WHERE state = 'abnormal'
GROUP BY disp_tag_nm, seg_id
HAVING
  ROUND((DATETIME_DIFF(MAX(opc_srv_dtm), MIN(opc_srv_dtm), MINUTE) + 1) / 60.0, 2)
    BETWEEN (SELECT min_duration_hour FROM params)
        AND (SELECT max_duration_hour FROM params)
ORDER BY disp_tag_nm, seg_start
;
