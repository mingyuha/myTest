-- ====================================================================
-- [쿼리 03] 시간대별 / 요일별 발생 패턴 (PostgreSQL)
-- 분석 항목: 시간대별 발생 패턴, 요일별 발생 패턴, 일별 추이, 재발 주기
--
-- [단일 날짜] 같은 날 → 시간대별 패턴 확인
-- [다중 날짜] 범위 지정 → 요일별/일별 추이 분석
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
  seg_start::date                    AS seg_date,             -- 발생 날짜 (일별 추이 확인)
  TO_CHAR(seg_start, 'Day')          AS day_of_week,          -- 요일 (영문)
  EXTRACT(HOUR FROM seg_start)::int  AS hour_of_day,          -- 시간대 (0~23)
  COUNT(*)                           AS abnormal_start_count, -- 해당 시간대 비정상 시작 횟수
  ROUND(SUM(duration_hour)::numeric, 2)   AS total_abnormal_hour,  -- 해당 시간대 누적 비정상 시간
  ROUND(AVG(duration_hour)::numeric, 2)   AS avg_duration_hour     -- 평균 지속 시간
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
  WHERE state = 'abnormal'
  GROUP BY tag, seg_id
) abnormal_segs
GROUP BY tag, seg_date, day_of_week, hour_of_day
ORDER BY tag, seg_date, hour_of_day
;
