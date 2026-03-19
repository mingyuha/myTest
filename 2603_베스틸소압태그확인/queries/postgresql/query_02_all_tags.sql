-- ====================================================================
-- [쿼리 02-ALL] 요약 통계 - 전체 태그 대상 (PostgreSQL)
-- 분석 항목: 비정상 구간 빈도, MTTR(평균 복구 시간), MTBF(평균 정상 유지 시간),
--            지속 시간 분포 (min / avg / max / p25 / p50 / p75)
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
  COUNT(*)                                                                                AS abnormal_count,
  ROUND((SUM(duration_hour) / 24.0 * 100)::numeric, 1)                                    AS abnormal_pct,
  ROUND(AVG(duration_hour)::numeric, 2)                                                   AS mttr_avg_hour,
  MIN(duration_hour)                                                                      AS mttr_min_hour,
  MAX(duration_hour)                                                                      AS mttr_max_hour,
  ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY duration_hour)::numeric, 2)          AS mttr_p25_hour,
  ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY duration_hour)::numeric, 2)          AS mttr_p50_hour,
  ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY duration_hour)::numeric, 2)          AS mttr_p75_hour,
  ROUND((AVG(EXTRACT(EPOCH FROM (next_abnormal_start - seg_end)) / 60) / 60.0)::numeric, 2) AS mtbf_avg_hour
FROM (
  SELECT
    tag, seg_id, seg_start, seg_end, duration_hour,
    LEAD(seg_start) OVER (PARTITION BY tag ORDER BY seg_start) AS next_abnormal_start
  FROM (
    SELECT
      tag, seg_id,
      MIN(srvtime) AS seg_start,
      MAX(srvtime) AS seg_end,
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
  ) seg_summary
) abnormal_segs
GROUP BY tag
ORDER BY tag
;
