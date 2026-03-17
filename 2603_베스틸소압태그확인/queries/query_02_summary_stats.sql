-- ====================================================================
-- [쿼리 02] 요약 통계
-- 분석 항목: 비정상 구간 빈도, MTTR(평균 복구 시간), MTBF(평균 정상 유지 시간),
--            지속 시간 분포 (min / avg / max / p25 / p50 / p75)
-- ====================================================================

WITH params AS (
  SELECT
    DATE '2026-03-17' AS start_date,  -- ← 시작 날짜
    DATE '2026-03-17' AS end_date     -- ← 종료 날짜 (단일 날짜면 start_date와 동일하게)
),

raw_get1m AS (
  SELECT disp_tag_nm, opc_srv_dtm, opc_src_dtm, tag_value
  FROM `dataforge-seahbst.sbm_tag.acm_tag_mt`
  WHERE clct_type_cd = 'get1m'
    AND opc_srv_dtm >= DATETIME((SELECT start_date FROM params))
    AND opc_srv_dtm <  DATETIME_ADD(DATETIME((SELECT end_date FROM params)), INTERVAL 1 DAY)
    AND disp_tag_nm IN (
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
),

with_prev AS (
  SELECT *,
    LAG(opc_src_dtm) OVER (PARTITION BY disp_tag_nm ORDER BY opc_srv_dtm) AS prev_src_dtm
  FROM raw_get1m
),

flagged AS (
  SELECT *,
    CASE
      WHEN prev_src_dtm IS NULL          THEN 'normal'
      WHEN opc_src_dtm = prev_src_dtm    THEN 'abnormal'
      ELSE                                    'normal'
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
),

seg_summary AS (
  SELECT
    disp_tag_nm, seg_id, state,
    MIN(opc_srv_dtm)                                                AS seg_start,
    MAX(opc_srv_dtm)                                                AS seg_end,
    ROUND((DATETIME_DIFF(MAX(opc_srv_dtm), MIN(opc_srv_dtm), MINUTE) + 1) / 60.0, 2)  AS duration_hour
  FROM segmented
  GROUP BY disp_tag_nm, seg_id, state
),

-- 비정상 구간에 다음 비정상 구간 시작 시각 추가 (MTBF 계산: end → next start 간격)
abnormal_segs AS (
  SELECT *,
    LEAD(seg_start) OVER (PARTITION BY disp_tag_nm ORDER BY seg_start) AS next_abnormal_start
  FROM seg_summary
  WHERE state = 'abnormal'
)

SELECT
  disp_tag_nm,
  COUNT(*)                                                               AS abnormal_count,   -- 비정상 전환 횟수
  ROUND(SUM(duration_hour) / 24.0 * 100, 1)                                        AS abnormal_pct,      -- 하루 중 비정상 비율(%)
  -- MTTR: 각 비정상 구간 지속 시간 통계 (시간)
  ROUND(AVG(duration_hour),  2)                                                     AS mttr_avg_hour,
  MIN(duration_hour)                                                                AS mttr_min_hour,
  MAX(duration_hour)                                                                AS mttr_max_hour,
  ROUND(APPROX_QUANTILES(duration_hour, 4)[OFFSET(1)], 2)                          AS mttr_p25_hour,
  ROUND(APPROX_QUANTILES(duration_hour, 4)[OFFSET(2)], 2)                          AS mttr_p50_hour,
  ROUND(APPROX_QUANTILES(duration_hour, 4)[OFFSET(3)], 2)                          AS mttr_p75_hour,
  -- MTBF: 연속 비정상 구간 사이의 평균 정상 간격 (시간)
  ROUND(AVG(DATETIME_DIFF(next_abnormal_start, seg_end, MINUTE)) / 60.0, 2)       AS mtbf_avg_hour
FROM abnormal_segs
GROUP BY disp_tag_nm
ORDER BY disp_tag_nm
;
