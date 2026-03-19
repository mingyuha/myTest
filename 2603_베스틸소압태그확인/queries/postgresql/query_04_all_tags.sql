-- ====================================================================
-- [쿼리 04-ALL] 값 분석 - 전체 태그 대상 (PostgreSQL)
-- 분석 항목:
--   (A) 비정상 시 고착 값 분포
--   (B) 비정상 진입 직전 마지막 정상 tag value
--   (C) 정상 복귀 직후 첫 번째 tag value
--
-- [날짜 변경] srvtime >= / <= 부분을 수정하세요.
--   동적 설정 (기본값):
--     srvtime >= (CURRENT_DATE - INTERVAL '1 day')::timestamp   -- 어제 0시
--     srvtime <= (CURRENT_DATE + INTERVAL '8 hours')::timestamp -- 오늘 8시
--   수동 설정 예시:
--     srvtime >= '2026-03-18 00:00:00'::timestamp
--     srvtime <= '2026-03-19 08:00:00'::timestamp
-- ====================================================================

SELECT
  a.tag,
  a.seg_start,
  a.seg_end,
  a.duration_hour,
  a.frozen_tag_value,
  nlr.last_value   AS last_normal_value_before,
  nfr.first_value  AS first_normal_value_after
FROM (
  SELECT
    tag, seg_id, state,
    MIN(srvtime) AS seg_start,
    MAX(srvtime) AS seg_end,
    ROUND(((EXTRACT(EPOCH FROM (MAX(srvtime) - MIN(srvtime))) / 60) + 1) / 60.0, 2) AS duration_hour,
    MIN(value) AS frozen_tag_value
  FROM (
    SELECT
      tag, srvtime, srctime, value, state,
      SUM(is_new_seg) OVER (PARTITION BY tag ORDER BY srvtime ROWS UNBOUNDED PRECEDING) AS seg_id
    FROM (
      SELECT
        tag, srvtime, srctime, value, state,
        CASE
          WHEN state <> LAG(state, 1, 'normal') OVER (PARTITION BY tag ORDER BY srvtime)
          THEN 1 ELSE 0
        END AS is_new_seg
      FROM (
        SELECT
          tag, srvtime, srctime, value,
          CASE
            WHEN LAG(srctime) OVER (PARTITION BY tag ORDER BY srvtime) IS NULL THEN 'normal'
            WHEN srctime = LAG(srctime) OVER (PARTITION BY tag ORDER BY srvtime) THEN 'abnormal'
            ELSE 'normal'
          END AS state
        FROM sbmplc.acm_plc
        WHERE coltype = 'get1m'
          AND srvtime >= (CURRENT_DATE - INTERVAL '1 day')::timestamp    -- ← 어제 0시
          AND srvtime <= (CURRENT_DATE + INTERVAL '8 hours')::timestamp  -- ← 오늘 8시
          -- 태그 필터 없음: 전체 태그 대상
      ) t1
    ) t2
  ) t3
  GROUP BY tag, seg_id, state
) a
LEFT JOIN (
  SELECT DISTINCT ON (tag, seg_id)
    tag, seg_id, value AS last_value
  FROM (
    SELECT
      tag, srvtime, value,
      SUM(is_new_seg) OVER (PARTITION BY tag ORDER BY srvtime ROWS UNBOUNDED PRECEDING) AS seg_id,
      state
    FROM (
      SELECT
        tag, srvtime, value, state,
        CASE
          WHEN state <> LAG(state, 1, 'normal') OVER (PARTITION BY tag ORDER BY srvtime)
          THEN 1 ELSE 0
        END AS is_new_seg
      FROM (
        SELECT
          tag, srvtime, value,
          CASE
            WHEN LAG(srctime) OVER (PARTITION BY tag ORDER BY srvtime) IS NULL THEN 'normal'
            WHEN srctime = LAG(srctime) OVER (PARTITION BY tag ORDER BY srvtime) THEN 'abnormal'
            ELSE 'normal'
          END AS state
        FROM sbmplc.acm_plc
        WHERE coltype = 'get1m'
          AND srvtime >= (CURRENT_DATE - INTERVAL '1 day')::timestamp
          AND srvtime <= (CURRENT_DATE + INTERVAL '8 hours')::timestamp
      ) x1
    ) x2
  ) x3
  WHERE state = 'normal'
  ORDER BY tag, seg_id, srvtime DESC
) nlr ON nlr.tag = a.tag AND nlr.seg_id = a.seg_id - 1
LEFT JOIN (
  SELECT DISTINCT ON (tag, seg_id)
    tag, seg_id, value AS first_value
  FROM (
    SELECT
      tag, srvtime, value,
      SUM(is_new_seg) OVER (PARTITION BY tag ORDER BY srvtime ROWS UNBOUNDED PRECEDING) AS seg_id,
      state
    FROM (
      SELECT
        tag, srvtime, value, state,
        CASE
          WHEN state <> LAG(state, 1, 'normal') OVER (PARTITION BY tag ORDER BY srvtime)
          THEN 1 ELSE 0
        END AS is_new_seg
      FROM (
        SELECT
          tag, srvtime, value,
          CASE
            WHEN LAG(srctime) OVER (PARTITION BY tag ORDER BY srvtime) IS NULL THEN 'normal'
            WHEN srctime = LAG(srctime) OVER (PARTITION BY tag ORDER BY srvtime) THEN 'abnormal'
            ELSE 'normal'
          END AS state
        FROM sbmplc.acm_plc
        WHERE coltype = 'get1m'
          AND srvtime >= (CURRENT_DATE - INTERVAL '1 day')::timestamp
          AND srvtime <= (CURRENT_DATE + INTERVAL '8 hours')::timestamp
      ) y1
    ) y2
  ) y3
  WHERE state = 'normal'
  ORDER BY tag, seg_id, srvtime ASC
) nfr ON nfr.tag = a.tag AND nfr.seg_id = a.seg_id + 1
WHERE a.state = 'abnormal'
ORDER BY a.tag, a.seg_start
;
