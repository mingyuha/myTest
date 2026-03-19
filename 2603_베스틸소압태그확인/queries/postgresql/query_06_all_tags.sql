-- ====================================================================
-- [쿼리 06-ALL] 다중 태그 분석 - 전체 태그 대상 (PostgreSQL)
-- 분석 항목:
--   (A) 동시 비정상 발생 여부 - 여러 태그가 동일 시점에 함께 비정상이 되는지
--   (B) 태그별 비정상 빈도 비교 - 태그 간 비정상 발생 빈도 및 지속 시간 비교
--
-- [날짜 변경] srvtime >= / <= 부분을 수정하세요.
--   동적 설정 (기본값):
--     srvtime >= (CURRENT_DATE - INTERVAL '1 day')::timestamp   -- 어제 0시
--     srvtime <= (CURRENT_DATE + INTERVAL '8 hours')::timestamp -- 오늘 8시
--   수동 설정 예시:
--     srvtime >= '2026-03-18 00:00:00'::timestamp
--     srvtime <= '2026-03-19 08:00:00'::timestamp
-- ====================================================================

-- ============================================================
-- [Part A] 동시 비정상 발생 분석 (주석 해제하여 실행)
-- ============================================================
/*
SELECT
  DATE_TRUNC('minute', srvtime) AS time_minute,
  COUNT(DISTINCT tag) AS abnormal_tag_count,
  STRING_AGG(DISTINCT tag, ', ' ORDER BY tag) AS abnormal_tags
FROM (
  SELECT tag, srvtime, state
  FROM (
    SELECT
      tag, srvtime, state,
      SUM(is_new_seg) OVER (PARTITION BY tag ORDER BY srvtime ROWS UNBOUNDED PRECEDING) AS seg_id
    FROM (
      SELECT
        tag, srvtime, state,
        CASE
          WHEN state <> LAG(state, 1, 'normal') OVER (PARTITION BY tag ORDER BY srvtime)
          THEN 1 ELSE 0
        END AS is_new_seg
      FROM (
        SELECT
          tag, srvtime,
          CASE
            WHEN LAG(srctime) OVER (PARTITION BY tag ORDER BY srvtime) IS NULL THEN 'normal'
            WHEN srctime = LAG(srctime) OVER (PARTITION BY tag ORDER BY srvtime) THEN 'abnormal'
            ELSE 'normal'
          END AS state
        FROM sbmplc.acm_plc
        WHERE coltype = 'get1m'
          AND srvtime >= (CURRENT_DATE - INTERVAL '1 day')::timestamp
          AND srvtime <= (CURRENT_DATE + INTERVAL '8 hours')::timestamp
      ) t1
    ) t2
  ) t3
  WHERE state = 'abnormal'
) abnormal_data
GROUP BY time_minute
HAVING COUNT(DISTINCT tag) >= 2
ORDER BY abnormal_tag_count DESC, time_minute
LIMIT 100
;
*/

-- ============================================================
-- [Part B] 태그별 비정상 빈도 비교
-- ============================================================
SELECT
  tag,
  COUNT(*)                                      AS abnormal_count,
  ROUND(SUM(duration_hour)::numeric, 2)         AS total_abnormal_hour,
  ROUND(AVG(duration_hour)::numeric, 2)         AS avg_duration_hour,
  MIN(duration_hour)                            AS min_duration_hour,
  MAX(duration_hour)                            AS max_duration_hour,
  MIN(seg_start)                                AS first_abnormal_start,
  MAX(seg_end)                                  AS last_abnormal_end
FROM (
  SELECT
    tag,
    seg_id,
    MIN(srvtime) AS seg_start,
    MAX(srvtime) AS seg_end,
    ROUND(((EXTRACT(EPOCH FROM (MAX(srvtime) - MIN(srvtime))) / 60) + 1) / 60.0, 2) AS duration_hour
  FROM (
    SELECT
      tag, srvtime, state,
      SUM(is_new_seg) OVER (PARTITION BY tag ORDER BY srvtime ROWS UNBOUNDED PRECEDING) AS seg_id
    FROM (
      SELECT
        tag, srvtime, state,
        CASE
          WHEN state <> LAG(state, 1, 'normal') OVER (PARTITION BY tag ORDER BY srvtime)
          THEN 1 ELSE 0
        END AS is_new_seg
      FROM (
        SELECT
          tag, srvtime,
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
  WHERE state = 'abnormal'
  GROUP BY tag, seg_id
) seg_summary
GROUP BY tag
ORDER BY total_abnormal_hour DESC, abnormal_count DESC
;
