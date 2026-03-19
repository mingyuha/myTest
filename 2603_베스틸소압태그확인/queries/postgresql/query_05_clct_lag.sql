-- ====================================================================
-- [쿼리 05] 수집 유형 및 지연 분석 (PostgreSQL)
-- 분석 항목:
--   (A) 비정상 구간 내 sub 데이터 소실 여부 (구간별 coltype 분포)
--   (B) get1m vs sub 중 비정상 진입/복귀를 어느 쪽이 먼저 감지하는지
--   (C) 수집 지연(lag = srvtime - srctime) 정상/비정상 상태별 비교
--
-- ※ 이 쿼리는 get1m + sub 전체 데이터를 사용합니다.
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
-- [Part A] 비정상 구간 내 sub 데이터 소실 여부
--   → abnormal 구간에서 sub 행이 있는지 없는지 확인
-- ============================================================
-- 아래 주석 해제하여 실행:
/*
SELECT
  r.tag,
  COALESCE(s.state, 'normal') AS state,
  r.coltype,
  COUNT(*) AS row_count
FROM (
  SELECT tag, srvtime, coltype
  FROM sbmplc.acm_plc
  WHERE srvtime >= (CURRENT_DATE - INTERVAL '1 day')::timestamp
    AND srvtime <= (CURRENT_DATE + INTERVAL '8 hours')::timestamp
    AND tag IN (
        'SBM_2.AFT.ACM_1_WHEEL_DIAMETER_TCP_ROTATION_ACTUAL_LENGTH',
        'SBM_5.ACM1.ACM_1_MOTOR_CURRENT_EXPLOREP_ROTATION_ACTUAL_AMPERE'
        -- 필요한 태그 추가
    )
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
          AND tag IN (
              'SBM_2.AFT.ACM_1_WHEEL_DIAMETER_TCP_ROTATION_ACTUAL_LENGTH',
              'SBM_5.ACM1.ACM_1_MOTOR_CURRENT_EXPLOREP_ROTATION_ACTUAL_AMPERE'
          )
      ) t1
    ) t2
  ) t3
  GROUP BY tag, seg_id, state
) s ON r.tag = s.tag AND r.srvtime BETWEEN s.seg_start AND s.seg_end
GROUP BY r.tag, state, r.coltype
ORDER BY r.tag, state, r.coltype
;
*/

-- ============================================================
-- [Part B/C] 수집 지연(lag) 정상 vs 비정상 상태별 통계
--   → 비정상 진입 전후로 lag이 급증하는지 확인
-- ============================================================
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
  -- 전체 데이터 (get1m + sub)
  SELECT tag, srvtime, coltype,
    EXTRACT(EPOCH FROM (srvtime - srctime))::int AS lag_sec
  FROM sbmplc.acm_plc
  WHERE srvtime >= (CURRENT_DATE - INTERVAL '1 day')::timestamp    -- ← 어제 0시
    AND srvtime <= (CURRENT_DATE + INTERVAL '8 hours')::timestamp  -- ← 오늘 8시
    AND tag IN (
        'SBM_2.AFT.ACM_1_WHEEL_DIAMETER_TCP_ROTATION_ACTUAL_LENGTH',
        'SBM_2.AFT.ACM_2_WHEEL_DIAMETER_TCP_ROTATION_ACTUAL_LENGTH',
        'SBM_2.AFT.ACM_3_ENCODER_WHEEL_DIAMETER_TCP_ROTATION_ACTUAL_LENGTH',
        'SBM_2.AFT.ACM_3_FRONT_ACT_PRESSURE_TCP_FORWARD_ACTUAL_PRESSURE',
        'SBM_2.AFT.ACM_3_TOP_ACT_PRESSURE_TCP_UP_ACTUAL_PRESSURE',
        'SBM_2.AFT.ACM_3_WHEEL_WHEEL_MEASURING_SENSOR_TCP_ROTATION_ACTUAL',
        'SBM_5.ACM1.ACM_1_FEEDING_POSITION_EXPLOREP_FORWARD_ACTUAL_POSITION',
        'SBM_5.ACM1.ACM_1_FEEDING_SPEED_ACT_EXPLOREP_FORWARD_ACTUAL_SPEED',
        'SBM_5.ACM1.ACM_1_FEEDING_SPEED_SET_EXPLOREP_FORWARD_SET_POINT_SPEED',
        'SBM_5.ACM1.ACM_1_FRONT_L_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION',
        'SBM_5.ACM1.ACM_1_FRONT_L_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE',
        'SBM_5.ACM1.ACM_1_FRONT_R_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION',
        'SBM_5.ACM1.ACM_1_FRONT_R_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE',
        'SBM_5.ACM1.ACM_1_MOTOR_CURRENT_EXPLOREP_ROTATION_ACTUAL_AMPERE',
        'SBM_5.ACM1.ACM_1_MOTOR_SPEED_EXPLOREP_ROTATION_ACTUAL_SPEED',
        'SBM_5.ACM1.ACM_1_ROCKER_ARM_ENCODER_EXPLOREP_ROTATION_ACTUAL_ANGLE',
        'SBM_5.ACM1.ACM_1_TOP_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION',
        'SBM_5.ACM1.ACM_1_TOP_L_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE',
        'SBM_5.ACM1.ACM_1_TOP_R_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_POSITION',
        'SBM_6.ACM2.ACM_2_EOCR_CURRENT_EXPLOREP_ROTATION_ACTUAL_AMPERE',
        'SBM_6.ACM2.ACM_2_FEEDING_POSITION_EXPLOREP_FORWARD_ACTUAL_POSITION',
        'SBM_6.ACM2.ACM_2_FEEDING_SPEED_ACT_EXPLOREP_FORWARD_ACTUAL_SPEED',
        'SBM_6.ACM2.ACM_2_FEEDING_SPEED_SET_EXPLOREP_FORWARD_SET_POINT_SPEED',
        'SBM_6.ACM2.ACM_2_FRONT_L_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION',
        'SBM_6.ACM2.ACM_2_FRONT_L_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE',
        'SBM_6.ACM2.ACM_2_FRONT_R_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION',
        'SBM_6.ACM2.ACM_2_FRONT_R_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE',
        'SBM_6.ACM2.ACM_2_MOTOR_SPEED_EXPLOREP_ROTATION_ACTUAL_SPEED',
        'SBM_6.ACM2.ACM_2_ROCKER_ARM_ENCODER_EXPLOREP_ROTATION_ACTUAL_ANGLE',
        'SBM_6.ACM2.ACM_2_TOP_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION',
        'SBM_6.ACM2.ACM_2_TOP_L_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE',
        'SBM_6.ACM2.ACM_2_TOP_R_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_POSITION',
        'SBM_7.ACM3.ACM_3_FEEDING_SPEED_ACTUAL',
        'SBM_7.ACM3.ACM_3_FEEDING_SPEED_SET_POINT',
        'SBM_7.ACM3.ACM_3_MOTOR_EOCR_ROTATION_REFERENCE',
        'SBM_7.ACM3.ACM_3_MOTOR_SPEED_ACTUAL'
    )
) r
-- get1m 기준 비정상 구간 매핑
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
          AND tag IN (
              'SBM_2.AFT.ACM_1_WHEEL_DIAMETER_TCP_ROTATION_ACTUAL_LENGTH',
              'SBM_2.AFT.ACM_2_WHEEL_DIAMETER_TCP_ROTATION_ACTUAL_LENGTH',
              'SBM_2.AFT.ACM_3_ENCODER_WHEEL_DIAMETER_TCP_ROTATION_ACTUAL_LENGTH',
              'SBM_2.AFT.ACM_3_FRONT_ACT_PRESSURE_TCP_FORWARD_ACTUAL_PRESSURE',
              'SBM_2.AFT.ACM_3_TOP_ACT_PRESSURE_TCP_UP_ACTUAL_PRESSURE',
              'SBM_2.AFT.ACM_3_WHEEL_WHEEL_MEASURING_SENSOR_TCP_ROTATION_ACTUAL',
              'SBM_5.ACM1.ACM_1_FEEDING_POSITION_EXPLOREP_FORWARD_ACTUAL_POSITION',
              'SBM_5.ACM1.ACM_1_FEEDING_SPEED_ACT_EXPLOREP_FORWARD_ACTUAL_SPEED',
              'SBM_5.ACM1.ACM_1_FEEDING_SPEED_SET_EXPLOREP_FORWARD_SET_POINT_SPEED',
              'SBM_5.ACM1.ACM_1_FRONT_L_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION',
              'SBM_5.ACM1.ACM_1_FRONT_L_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE',
              'SBM_5.ACM1.ACM_1_FRONT_R_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION',
              'SBM_5.ACM1.ACM_1_FRONT_R_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE',
              'SBM_5.ACM1.ACM_1_MOTOR_CURRENT_EXPLOREP_ROTATION_ACTUAL_AMPERE',
              'SBM_5.ACM1.ACM_1_MOTOR_SPEED_EXPLOREP_ROTATION_ACTUAL_SPEED',
              'SBM_5.ACM1.ACM_1_ROCKER_ARM_ENCODER_EXPLOREP_ROTATION_ACTUAL_ANGLE',
              'SBM_5.ACM1.ACM_1_TOP_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION',
              'SBM_5.ACM1.ACM_1_TOP_L_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE',
              'SBM_5.ACM1.ACM_1_TOP_R_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_POSITION',
              'SBM_6.ACM2.ACM_2_EOCR_CURRENT_EXPLOREP_ROTATION_ACTUAL_AMPERE',
              'SBM_6.ACM2.ACM_2_FEEDING_POSITION_EXPLOREP_FORWARD_ACTUAL_POSITION',
              'SBM_6.ACM2.ACM_2_FEEDING_SPEED_ACT_EXPLOREP_FORWARD_ACTUAL_SPEED',
              'SBM_6.ACM2.ACM_2_FEEDING_SPEED_SET_EXPLOREP_FORWARD_SET_POINT_SPEED',
              'SBM_6.ACM2.ACM_2_FRONT_L_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION',
              'SBM_6.ACM2.ACM_2_FRONT_L_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE',
              'SBM_6.ACM2.ACM_2_FRONT_R_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION',
              'SBM_6.ACM2.ACM_2_FRONT_R_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE',
              'SBM_6.ACM2.ACM_2_MOTOR_SPEED_EXPLOREP_ROTATION_ACTUAL_SPEED',
              'SBM_6.ACM2.ACM_2_ROCKER_ARM_ENCODER_EXPLOREP_ROTATION_ACTUAL_ANGLE',
              'SBM_6.ACM2.ACM_2_TOP_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION',
              'SBM_6.ACM2.ACM_2_TOP_L_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE',
              'SBM_6.ACM2.ACM_2_TOP_R_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_POSITION',
              'SBM_7.ACM3.ACM_3_FEEDING_SPEED_ACTUAL',
              'SBM_7.ACM3.ACM_3_FEEDING_SPEED_SET_POINT',
              'SBM_7.ACM3.ACM_3_MOTOR_EOCR_ROTATION_REFERENCE',
              'SBM_7.ACM3.ACM_3_MOTOR_SPEED_ACTUAL'
          )
      ) t1
    ) t2
  ) t3
  GROUP BY tag, seg_id, state
) s ON r.tag = s.tag AND r.srvtime BETWEEN s.seg_start AND s.seg_end
WHERE r.lag_sec >= 0  -- 음수 lag(시계 오차) 제외
GROUP BY r.tag, r.coltype, state
ORDER BY r.tag, r.coltype, state
;
