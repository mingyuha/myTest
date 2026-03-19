-- ====================================================================
-- [쿼리 05-ALL] 수집 유형 및 지연 분석 - 전체 태그 대상 (PostgreSQL)
-- 분석 항목:
--   (A) 비정상 구간 내 sub 데이터 소실 여부
--   (B) 수집 지연(lag = srvtime - srctime) 정상/비정상 상태별 비교
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
  r.tag,
  r.coltype,
  COALESCE(s.state, 'normal') AS state,
  COUNT(*) AS row_count,
  ROUND(AVG(r.lag_sec)::numeric, 1) AS lag_avg_sec,
  MIN(r.lag_sec) AS lag_min_sec,
  MAX(r.lag_sec) AS lag_max_sec,
  ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY r.lag_sec)::numeric, 1) AS lag_p25_sec,
  ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY r.lag_sec)::numeric, 1) AS lag_p50_sec,
  ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY r.lag_sec)::numeric, 1) AS lag_p75_sec
FROM (
  SELECT tag, srvtime, coltype,
    EXTRACT(EPOCH FROM (srvtime - srctime))::int AS lag_sec
  FROM sbmplc.acm_plc
  WHERE srvtime >= (CURRENT_DATE - INTERVAL '1 day')::timestamp    -- ← 어제 0시
    AND srvtime <= (CURRENT_DATE + INTERVAL '8 hours')::timestamp  -- ← 오늘 8시
    -- 태그 필터 없음: 전체 태그 대상
) r
LEFT JOIN (
  SELECT tag, seg_id, state, MIN(srvtime) AS seg_start, MAX(srvtime) AS seg_end
  FROM (
    SELECT tag, srvtime, state,
      SUM(is_new_seg) OVER (PARTITION BY tag ORDER BY srvtime ROWS UNBOUNDED PRECEDING) AS seg_id
    FROM (
      SELECT tag, srvtime, state,
        CASE WHEN state <> LAG(state, 1, 'normal') OVER (PARTITION BY tag ORDER BY srvtime) THEN 1 ELSE 0 END AS is_new_seg
      FROM (
        SELECT tag, srvtime,
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
  GROUP BY tag, seg_id, state
) s ON r.tag = s.tag AND r.srvtime BETWEEN s.seg_start AND s.seg_end
WHERE r.lag_sec >= 0
GROUP BY r.tag, r.coltype, state
ORDER BY r.tag, r.coltype, state
;
