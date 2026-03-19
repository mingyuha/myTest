-- ====================================================================
-- [쿼리 02] 요약 통계 (PostgreSQL)
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
  COUNT(*)                                                                                AS abnormal_count,   -- 비정상 전환 횟수
  ROUND((SUM(duration_hour) / 24.0 * 100)::numeric, 1)                                    AS abnormal_pct,     -- 하루 중 비정상 비율(%)
  -- MTTR: 각 비정상 구간 지속 시간 통계 (시간)
  ROUND(AVG(duration_hour)::numeric, 2)                                                   AS mttr_avg_hour,
  MIN(duration_hour)                                                                      AS mttr_min_hour,
  MAX(duration_hour)                                                                      AS mttr_max_hour,
  ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY duration_hour)::numeric, 2)          AS mttr_p25_hour,
  ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY duration_hour)::numeric, 2)          AS mttr_p50_hour,
  ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY duration_hour)::numeric, 2)          AS mttr_p75_hour,
  -- MTBF: 연속 비정상 구간 사이의 평균 정상 간격 (시간)
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
  ) seg_summary
) abnormal_segs
GROUP BY tag
ORDER BY tag
;
