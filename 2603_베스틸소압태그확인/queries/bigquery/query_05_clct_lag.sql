-- ====================================================================
-- [쿼리 05] 수집 유형 및 지연 분석
-- 분석 항목:
--   (A) 비정상 구간 내 sub 데이터 소실 여부 (구간별 clct_type_cd 분포)
--   (B) get1m vs sub 중 비정상 진입/복귀를 어느 쪽이 먼저 감지하는지
--   (C) 수집 지연(lag = opc_srv_dtm - opc_src_dtm) 정상/비정상 상태별 비교
--
-- ※ 이 쿼리는 get1m + sub 전체 데이터를 사용합니다.
-- ====================================================================

WITH params AS (
  SELECT
    DATETIME_TRUNC(DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 1 DAY), DAY) AS start_dt,  -- ← 어제 0시
    DATETIME_ADD(DATETIME_TRUNC(CURRENT_DATETIME(), DAY), INTERVAL 8 HOUR) AS end_dt    -- ← 오늘 8시
),

-- [Part A/B/C 공통] get1m 기준 비정상 구간 탐지
raw_get1m AS (
  SELECT disp_tag_nm, opc_srv_dtm, opc_src_dtm, tag_value
  FROM `dataforge-seahbst.sbm_tag.acm_tag_mt`
  WHERE clct_type_cd = 'get1m'
    AND opc_srv_dtm >= (SELECT start_dt FROM params)
    AND opc_srv_dtm <= (SELECT end_dt FROM params)
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

seg_bounds AS (
  SELECT disp_tag_nm, seg_id, state,
    MIN(opc_srv_dtm) AS seg_start,
    MAX(opc_srv_dtm) AS seg_end
  FROM segmented
  GROUP BY disp_tag_nm, seg_id, state
),

-- [Part A/B] 전체 데이터 (get1m + sub) 로드
raw_all AS (
  SELECT disp_tag_nm, opc_srv_dtm, opc_src_dtm, tag_value, clct_type_cd,
    DATETIME_DIFF(opc_srv_dtm, opc_src_dtm, SECOND) AS lag_sec  -- 수집 지연(초)
  FROM `dataforge-seahbst.sbm_tag.acm_tag_mt`
  WHERE opc_srv_dtm >= (SELECT start_dt FROM params)
    AND opc_srv_dtm <= (SELECT end_dt FROM params)
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

-- 각 row에 비정상 구간 상태 매핑 (시간 범위로 join)
all_with_state AS (
  SELECT
    r.*,
    COALESCE(s.state, 'normal') AS state,  -- 구간에 속하지 않으면 normal
    s.seg_id
  FROM raw_all r
  LEFT JOIN seg_bounds s
    ON  r.disp_tag_nm = s.disp_tag_nm
    AND r.opc_srv_dtm BETWEEN s.seg_start AND s.seg_end
)

-- ============================================================
-- [Part A] 비정상 구간 내 sub 데이터 소실 여부
--   → abnormal 구간에서 sub 행이 있는지 없는지 확인
-- ============================================================
-- 주석 해제하여 실행:
/*
SELECT
  disp_tag_nm,
  state,
  clct_type_cd,
  COUNT(*) AS row_count
FROM all_with_state
GROUP BY disp_tag_nm, state, clct_type_cd
ORDER BY disp_tag_nm, state, clct_type_cd
;
*/

-- ============================================================
-- [Part B/C] 수집 지연(lag) 정상 vs 비정상 상태별 통계
--   → 비정상 진입 전후로 lag이 급증하는지 확인
-- ============================================================
SELECT
  disp_tag_nm,
  clct_type_cd,
  state,
  COUNT(*)                                          AS row_count,
  ROUND(AVG(lag_sec),  1)                           AS lag_avg_sec,
  MIN(lag_sec)                                      AS lag_min_sec,
  MAX(lag_sec)                                      AS lag_max_sec,
  ROUND(APPROX_QUANTILES(lag_sec, 4)[OFFSET(1)], 1) AS lag_p25_sec,
  ROUND(APPROX_QUANTILES(lag_sec, 4)[OFFSET(2)], 1) AS lag_p50_sec,
  ROUND(APPROX_QUANTILES(lag_sec, 4)[OFFSET(3)], 1) AS lag_p75_sec
FROM all_with_state
WHERE lag_sec >= 0  -- 음수 lag(시계 오차) 제외
GROUP BY disp_tag_nm, clct_type_cd, state
ORDER BY disp_tag_nm, clct_type_cd, state
;
