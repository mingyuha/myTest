-- ====================================================================
-- [쿼리 01] 비정상 구간 목록
-- 분석 항목: 비정상 시작 시점 목록, 비정상 전환 횟수, 비정상 구간 지속 시간
--
-- [날짜 변경] params CTE의 start_dt / end_dt를 수정하세요.
--   하루 전체: DATETIME '2026-03-17 00:00:00' ~ DATETIME '2026-03-17 23:59:00'
--   시간 범위: DATETIME '2026-03-17 09:00:00' ~ DATETIME '2026-03-17 18:00:00'
--   범위 조회: start_dt ~ end_dt (여러 날, 구간이 날짜 경계를 넘어도 자동 처리)
-- [태그 추가] raw_get1m CTE의 IN 절에 태그를 추가하세요.
-- [시간 필터] min_duration_hour / max_duration_hour로 구간 길이 필터링
--   필터 없음: min = 0, max = 999
--   예) 10시간 초과만: min_duration_hour = 10, max_duration_hour = 999
--   예) 1~5시간 구간만: min_duration_hour = 1, max_duration_hour = 5
-- ====================================================================

WITH params AS (
  SELECT
    DATETIME '2026-03-17 00:00:00' AS start_dt,          -- ← 시작 일시 (분 단위 지정 가능)
    DATETIME '2026-03-17 23:59:00' AS end_dt,            -- ← 종료 일시 (분 단위 지정 가능)
    0                              AS min_duration_hour,  -- ← 최소 지속 시간 (이상, 필터 없으면 0)
    999                            AS max_duration_hour   -- ← 최대 지속 시간 (이하, 필터 없으면 999)
),

-- get1m 데이터 기준으로 freeze 감지 (1분 주기로 opc_src_dtm 변화 여부 확인)
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

-- 이전 row의 opc_src_dtm 가져오기
with_prev AS (
  SELECT *,
    LAG(opc_src_dtm) OVER (PARTITION BY disp_tag_nm ORDER BY opc_srv_dtm) AS prev_src_dtm
  FROM raw_get1m
),

-- 정상/비정상 플래그: opc_src_dtm이 이전 row와 동일하면 비정상(freeze)
flagged AS (
  SELECT *,
    CASE
      WHEN prev_src_dtm IS NULL          THEN 'normal'    -- 첫 번째 row
      WHEN opc_src_dtm = prev_src_dtm    THEN 'abnormal'  -- freeze
      ELSE                                    'normal'
    END AS state
  FROM with_prev
),

-- 상태 변경 여부 플래그 (LAG는 중첩 불가하므로 별도 CTE로 분리)
with_state_change AS (
  SELECT *,
    CASE
      WHEN state <> LAG(state, 1, 'normal') OVER (PARTITION BY disp_tag_nm ORDER BY opc_srv_dtm)
      THEN 1 ELSE 0
    END AS is_new_seg
  FROM flagged
),

-- 상태 변경 시마다 seg_id 증가 (islands & gaps 기법)
segmented AS (
  SELECT *,
    SUM(is_new_seg) OVER (PARTITION BY disp_tag_nm ORDER BY opc_srv_dtm ROWS UNBOUNDED PRECEDING) AS seg_id
  FROM with_state_change
)

-- 비정상 구간만 집계 출력
SELECT
  disp_tag_nm,
  MIN(opc_srv_dtm)                                                  AS seg_start,       -- 비정상 시작 시점
  MAX(opc_srv_dtm)                                                  AS seg_end,         -- 비정상 종료 시점
  ROUND((DATETIME_DIFF(MAX(opc_srv_dtm), MIN(opc_srv_dtm), MINUTE) + 1) / 60.0, 2)  AS duration_hour,  -- 지속 시간(시간)
  COUNT(*)                                                          AS row_count,       -- 구간 내 row 수
  ANY_VALUE(opc_src_dtm)                                            AS frozen_src_dtm,  -- 고착된 소스 시각
  ANY_VALUE(tag_value)                                              AS frozen_tag_value -- 고착된 태그 값
FROM segmented
WHERE state = 'abnormal'
GROUP BY disp_tag_nm, seg_id
HAVING
  ROUND((DATETIME_DIFF(MAX(opc_srv_dtm), MIN(opc_srv_dtm), MINUTE) + 1) / 60.0, 2)
    BETWEEN (SELECT min_duration_hour FROM params)
        AND (SELECT max_duration_hour FROM params)
ORDER BY disp_tag_nm, seg_start
;
