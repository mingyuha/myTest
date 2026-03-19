-- ====================================================================
-- [쿼리 03-ALL] 시간대별 / 요일별 발생 패턴 - 전체 태그 대상 (PostgreSQL)
-- 분석 항목: 시간대별 발생 패턴, 요일별 발생 패턴, 일별 추이, 재발 주기
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
  tag,
  seg_start::date                    AS seg_date,
  TO_CHAR(seg_start, 'Day')          AS day_of_week,
  EXTRACT(HOUR FROM seg_start)::int  AS hour_of_day,
  COUNT(*)                           AS abnormal_start_count,
  ROUND(SUM(duration_hour)::numeric, 2)   AS total_abnormal_hour,
  ROUND(AVG(duration_hour)::numeric, 2)   AS avg_duration_hour
FROM (
  SELECT
    tag,
    MIN(srvtime) AS seg_start,
    ROUND(((EXTRACT(EPOCH FROM (MAX(srvtime) - MIN(srvtime))) / 60) + 1) / 60.0, 2) AS duration_hour
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
) abnormal_segs
GROUP BY tag, seg_date, day_of_week, hour_of_day
ORDER BY tag, seg_date, hour_of_day
;
