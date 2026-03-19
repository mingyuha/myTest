-- ====================================================================
-- [쿼리 01-ALL] 비정상 구간 목록 - 전체 태그 대상 (PostgreSQL)
-- 분석 항목: 테이블 내 모든 태그에 대해 비정상 구간 탐지
--
-- [날짜 변경] srvtime >= / <= 부분을 수정하세요.
--   동적 설정 (기본값):
--     srvtime >= (CURRENT_DATE - INTERVAL '1 day')::timestamp   -- 어제 0시
--     srvtime <= (CURRENT_DATE + INTERVAL '8 hours')::timestamp -- 오늘 8시
--   수동 설정 예시:
--     srvtime >= '2026-03-18 00:00:00'::timestamp
--     srvtime <= '2026-03-19 08:00:00'::timestamp
-- [시간 필터] duration_hour >= / <= 부분을 수정하세요 (기본값: 2시간 이상)
-- ====================================================================

SELECT
  tag,
  seg_start,
  seg_end,
  duration_hour,
  row_count,
  frozen_src_dtm,
  frozen_tag_value
FROM (
  SELECT
    tag,
    seg_id,
    MIN(srvtime) AS seg_start,
    MAX(srvtime) AS seg_end,
    ROUND(((EXTRACT(EPOCH FROM (MAX(srvtime) - MIN(srvtime))) / 60) + 1) / 60.0, 2) AS duration_hour,
    COUNT(*) AS row_count,
    MIN(srctime) AS frozen_src_dtm,
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
  WHERE state = 'abnormal'
  GROUP BY tag, seg_id
) result
WHERE duration_hour >= 2    -- ← 최소 지속 시간 (시간)
  AND duration_hour <= 999  -- ← 최대 지속 시간 (시간)
ORDER BY tag, seg_start
;
