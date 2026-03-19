-- ====================================================================
-- [쿼리 06] 다중 태그 분석
-- 분석 항목:
--   (A) 동시 비정상 발생 여부 - 여러 태그가 동일 시점에 함께 비정상이 되는지
--   (B) 태그별 비정상 빈도 비교 - 태그 간 비정상 발생 빈도 및 지속 시간 비교
--
-- [날짜 변경] start_dt / end_dt 부분을 수정하세요.
--   동적 설정 (기본값):
--     DATETIME_TRUNC(DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 1 DAY), DAY) -- 어제 0시
--     DATETIME_ADD(DATETIME_TRUNC(CURRENT_DATETIME(), DAY), INTERVAL 8 HOUR) -- 오늘 8시
--   수동 설정 예시:
--     DATETIME '2026-03-18 00:00:00'
--     DATETIME '2026-03-19 08:00:00'
-- ====================================================================

WITH params AS (
  SELECT
    DATETIME_TRUNC(DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 1 DAY), DAY) AS start_dt,  -- ← 어제 0시
    DATETIME_ADD(DATETIME_TRUNC(CURRENT_DATETIME(), DAY), INTERVAL 8 HOUR) AS end_dt    -- ← 오늘 8시
),

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
      WHEN prev_src_dtm IS NULL           THEN 'normal'
      WHEN opc_src_dtm = prev_src_dtm     THEN 'abnormal'
      ELSE                                     'normal'
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

-- 각 태그별 비정상 구간 요약
seg_summary AS (
  SELECT
    disp_tag_nm,
    seg_id,
    MIN(opc_srv_dtm)                                                  AS seg_start,
    MAX(opc_srv_dtm)                                                  AS seg_end,
    ROUND((DATETIME_DIFF(MAX(opc_srv_dtm), MIN(opc_srv_dtm), MINUTE) + 1) / 60.0, 2)  AS duration_hour
  FROM segmented
  WHERE state = 'abnormal'
  GROUP BY disp_tag_nm, seg_id
)

-- ============================================================
-- [Part A] 동시 비정상 발생 분석
--   → 동일 시점(분 단위)에 비정상인 태그 수 집계
-- ============================================================
-- 주석 해제하여 실행:
/*
SELECT
  DATETIME_TRUNC(opc_srv_dtm, MINUTE) AS time_minute,
  COUNT(DISTINCT disp_tag_nm) AS abnormal_tag_count,
  STRING_AGG(DISTINCT disp_tag_nm, ', ' ORDER BY disp_tag_nm) AS abnormal_tags
FROM segmented
WHERE state = 'abnormal'
GROUP BY time_minute
HAVING COUNT(DISTINCT disp_tag_nm) >= 2  -- 2개 이상 태그가 동시 비정상
ORDER BY abnormal_tag_count DESC, time_minute
LIMIT 100
;
*/

-- ============================================================
-- [Part B] 태그별 비정상 빈도 비교
--   → 태그 간 비정상 발생 빈도 및 지속 시간 비교
-- ============================================================
SELECT
  disp_tag_nm,
  COUNT(*)                                      AS abnormal_count,        -- 비정상 구간 수
  ROUND(SUM(duration_hour), 2)                  AS total_abnormal_hour,   -- 총 비정상 시간
  ROUND(AVG(duration_hour), 2)                  AS avg_duration_hour,     -- 평균 지속 시간
  MIN(duration_hour)                            AS min_duration_hour,     -- 최소 지속 시간
  MAX(duration_hour)                            AS max_duration_hour,     -- 최대 지속 시간
  MIN(seg_start)                                AS first_abnormal_start,  -- 첫 비정상 시작
  MAX(seg_end)                                  AS last_abnormal_end      -- 마지막 비정상 종료
FROM seg_summary
GROUP BY disp_tag_nm
ORDER BY total_abnormal_hour DESC, abnormal_count DESC
;
