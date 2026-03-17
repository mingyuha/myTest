# 베스틸 소압 태그 수집 이상 감지 분석

## 1. 개요

BigQuery 테이블에서 특정 태그의 수집 데이터를 조회하여, 태그 값이 비정상적으로 고정(freeze)되는 구간을 탐지하고 분석한다.

---

## 2. 데이터 소스

- **테이블**: `dataforge-seahbst.sbm_tag.acm_tag_mt`
- **분석 대상 태그** (총 36개):
  - `SBM_2.AFT.ACM_1_WHEEL_DIAMETER_TCP_ROTATION_ACTUAL_LENGTH`
  - `SBM_2.AFT.ACM_2_WHEEL_DIAMETER_TCP_ROTATION_ACTUAL_LENGTH`
  - `SBM_2.AFT.ACM_3_ENCODER_WHEEL_DIAMETER_TCP_ROTATION_ACTUAL_LENGTH`
  - `SBM_2.AFT.ACM_3_FRONT_ACT_PRESSURE_TCP_FORWARD_ACTUAL_PRESSURE`
  - `SBM_2.AFT.ACM_3_TOP_ACT_PRESSURE_TCP_UP_ACTUAL_PRESSURE`
  - `SBM_2.AFT.ACM_3_WHEEL_WHEEL_MEASURING_SENSOR_TCP_ROTATION_ACTUAL`
  - `SBM_5.ACM1.ACM_1_FEEDING_POSITION_EXPLOREP_FORWARD_ACTUAL_POSITION`
  - `SBM_5.ACM1.ACM_1_FEEDING_SPEED_ACT_EXPLOREP_FORWARD_ACTUAL_SPEED`
  - `SBM_5.ACM1.ACM_1_FEEDING_SPEED_SET_EXPLOREP_FORWARD_SET_POINT_SPEED`
  - `SBM_5.ACM1.ACM_1_FRONT_L_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION`
  - `SBM_5.ACM1.ACM_1_FRONT_L_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE`
  - `SBM_5.ACM1.ACM_1_FRONT_R_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION`
  - `SBM_5.ACM1.ACM_1_FRONT_R_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE`
  - `SBM_5.ACM1.ACM_1_MOTOR_CURRENT_EXPLOREP_ROTATION_ACTUAL_AMPERE`
  - `SBM_5.ACM1.ACM_1_MOTOR_SPEED_EXPLOREP_ROTATION_ACTUAL_SPEED`
  - `SBM_5.ACM1.ACM_1_ROCKER_ARM_ENCODER_EXPLOREP_ROTATION_ACTUAL_ANGLE`
  - `SBM_5.ACM1.ACM_1_TOP_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION`
  - `SBM_5.ACM1.ACM_1_TOP_L_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE`
  - `SBM_5.ACM1.ACM_1_TOP_R_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_POSITION`
  - `SBM_6.ACM2.ACM_2_EOCR_CURRENT_EXPLOREP_ROTATION_ACTUAL_AMPERE`
  - `SBM_6.ACM2.ACM_2_FEEDING_POSITION_EXPLOREP_FORWARD_ACTUAL_POSITION`
  - `SBM_6.ACM2.ACM_2_FEEDING_SPEED_ACT_EXPLOREP_FORWARD_ACTUAL_SPEED`
  - `SBM_6.ACM2.ACM_2_FEEDING_SPEED_SET_EXPLOREP_FORWARD_SET_POINT_SPEED`
  - `SBM_6.ACM2.ACM_2_FRONT_L_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION`
  - `SBM_6.ACM2.ACM_2_FRONT_L_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE`
  - `SBM_6.ACM2.ACM_2_FRONT_R_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION`
  - `SBM_6.ACM2.ACM_2_FRONT_R_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE`
  - `SBM_6.ACM2.ACM_2_MOTOR_SPEED_EXPLOREP_ROTATION_ACTUAL_SPEED`
  - `SBM_6.ACM2.ACM_2_ROCKER_ARM_ENCODER_EXPLOREP_ROTATION_ACTUAL_ANGLE`
  - `SBM_6.ACM2.ACM_2_TOP_CLAMP_POSITION_EXPLOREP_UPDOWN_ACTUAL_POSITION`
  - `SBM_6.ACM2.ACM_2_TOP_L_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_PRESSURE`
  - `SBM_6.ACM2.ACM_2_TOP_R_CLAMP_PRESSURE_EXPLOREP_UPDOWN_ACTUAL_POSITION`
  - `SBM_7.ACM3.ACM_3_FEEDING_SPEED_ACTUAL`
  - `SBM_7.ACM3.ACM_3_FEEDING_SPEED_SET_POINT`
  - `SBM_7.ACM3.ACM_3_MOTOR_EOCR_ROTATION_REFERENCE`
  - `SBM_7.ACM3.ACM_3_MOTOR_SPEED_ACTUAL`

---

## 3. 기준 쿼리

```sql
SELECT
  disp_tag_nm, opc_srv_dtm, opc_src_dtm, tag_value, clct_type_cd
FROM
  `dataforge-seahbst.sbm_tag.acm_tag_mt`
WHERE
  opc_srv_dtm BETWEEN DATETIME("2026-03-17") AND DATETIME_ADD("2026-03-17", INTERVAL 1 DAY)
  AND disp_tag_nm IN (
    'SBM_5.ACM1.ACM_1_MOTOR_CURRENT_EXPLOREP_ROTATION_ACTUAL_AMPERE'
  )
ORDER BY disp_tag_nm, opc_src_dtm, opc_srv_dtm
```

> 날짜는 분석 대상 기간에 맞게 변경하여 사용한다.

---

## 4. 컬럼 설명

| 컬럼 | 설명 |
|---|---|
| `disp_tag_nm` | 태그명 |
| `opc_srv_dtm` | 서버가 데이터를 수집한 시각 (수집 시각) |
| `opc_src_dtm` | OPC 소스(장비)에서 값이 변경된 시각 (소스 시각) |
| `tag_value` | 태그 값 |
| `clct_type_cd` | 수집 유형 (`get1m`: 1분 주기 강제 수집, `sub`: 값 변경 시 subscription 수신) |

---

## 5. 정상 / 비정상 기준

### 정상 상태
`opc_srv_dtm`, `opc_src_dtm`, `tag_value` 가 모두 row마다 다른 값을 가진다.

**정상 예제**
```json
[{
  "opc_srv_dtm": "2026-03-17T09:25:00.021000",
  "opc_src_dtm": "2026-03-17T09:24:59.457000",
  "tag_value": "8.0",
  "clct_type_cd": "get1m"
}, {
  "opc_srv_dtm": "2026-03-17T09:25:00.021000",
  "opc_src_dtm": "2026-03-17T09:24:59.457000",
  "tag_value": "8.0",
  "clct_type_cd": "sub"
}, {
  "opc_srv_dtm": "2026-03-17T09:25:01.726000",
  "opc_src_dtm": "2026-03-17T09:25:00.457000",
  "tag_value": "16.0",
  "clct_type_cd": "sub"
}, {
  "opc_srv_dtm": "2026-03-17T09:25:02.723000",
  "opc_src_dtm": "2026-03-17T09:25:01.457000",
  "tag_value": "73.0",
  "clct_type_cd": "sub"
}, {
  "opc_srv_dtm": "2026-03-17T09:25:03.719000",
  "opc_src_dtm": "2026-03-17T09:25:02.457000",
  "tag_value": "98.0",
  "clct_type_cd": "sub"
}]
```

### 비정상 상태
`opc_srv_dtm`은 1분마다 정상 증가하지만, `opc_src_dtm`과 `tag_value`가 변하지 않고 고정된다.

**비정상 예제**
```json
[{
  "opc_srv_dtm": "2026-03-17T00:00:00.016000",
  "opc_src_dtm": "2026-03-16T15:46:34.465000",
  "tag_value": "0.0",
  "clct_type_cd": "get1m"
}, {
  "opc_srv_dtm": "2026-03-17T00:01:00.035000",
  "opc_src_dtm": "2026-03-16T15:46:34.465000",
  "tag_value": "0.0",
  "clct_type_cd": "get1m"
}, {
  "opc_srv_dtm": "2026-03-17T00:02:00.013000",
  "opc_src_dtm": "2026-03-16T15:46:34.465000",
  "tag_value": "0.0",
  "clct_type_cd": "get1m"
}, {
  "opc_srv_dtm": "2026-03-17T00:03:00.028000",
  "opc_src_dtm": "2026-03-16T15:46:34.465000",
  "tag_value": "0.0",
  "clct_type_cd": "get1m"
}, {
  "opc_srv_dtm": "2026-03-17T00:04:00.030000",
  "opc_src_dtm": "2026-03-16T15:46:34.465000",
  "tag_value": "0.0",
  "clct_type_cd": "get1m"
}]
```

---

## 6. 분석 목표

특정 날짜 범위에서 태그가 비정상(freeze) 구간에 진입했다가 정상으로 복귀하는 패턴을 분석한다.

### 6-1. 구간 탐지

| 분석 항목 | 설명 |
|---|---|
| 비정상 시작 시점 목록 | 각 비정상 구간이 시작된 `opc_srv_dtm` 목록 |
| 비정상 전환 횟수 | 정상 → 비정상으로 전환된 횟수 |
| 비정상 구간 지속 시간 | 각 비정상 구간의 길이 (시작 ~ 복귀까지) |
| 비정상 구간 빈도 | 하루 중 비정상 상태가 얼마나 자주 발생하는가 |

### 6-2. 구간 특성 분석

| 분석 항목 | 설명 |
|---|---|
| MTTR (Mean Time To Recovery) | 비정상 진입 후 정상으로 복귀하는 데 걸리는 평균 시간 |
| MTBF (Mean Time Between Failures) | 비정상 구간 사이의 평균 정상 유지 시간 |
| 지속 시간 분포 | 비정상 구간 길이의 min / max / avg / 분위수 (짧은 순간인지 장시간인지) |

### 6-3. 패턴 분석

| 분석 항목 | 설명 |
|---|---|
| 시간대별 발생 패턴 | 새벽 / 오전 / 오후 / 야간 등 특정 시간대에 집중되는지 |
| 요일별 발생 패턴 | 특정 요일에 반복적으로 발생하는지 |
| 일별 추이 | 날짜를 바꿔가며 조회 시 일별 비정상 횟수/시간 변화 추이 |
| 재발 주기 패턴 | 일정한 주기(예: 매일 자정 등)로 반복되는지 |

### 6-4. 값 분석

| 분석 항목 | 설명 |
|---|---|
| 비정상 고착 값 분포 | freeze 시 고정되는 `tag_value`가 어떤 값인지 (0.0이 대부분인지 등) |
| 비정상 직전 마지막 정상 값 | 비정상 진입 직전 row의 `tag_value` |
| 비정상 복구 직후 첫 번째 값 | 정상 복귀 직후 row의 `tag_value` |

### 6-5. 수집 유형별 분석

| 분석 항목 | 설명 |
|---|---|
| 비정상 구간의 sub 데이터 소실 여부 | 비정상 시 `sub` 타입 데이터가 완전히 사라지고 `get1m`만 남는지 |
| sub vs get1m 감지 선후 관계 | 비정상 진입/복귀를 어느 수집 유형이 먼저 감지하는지 |
| 수집 지연(lag) 분석 | `opc_srv_dtm` - `opc_src_dtm` 차이가 비정상 진입 직전에 급증하는지 |

### 6-6. 다중 태그 분석 (태그 추가 시 적용)

| 분석 항목 | 설명 |
|---|---|
| 동시 비정상 발생 여부 | 여러 태그가 동일 시점에 함께 비정상이 되는지 (공통 원인 가능성) |
| 태그별 비정상 빈도 비교 | 태그 간 비정상 발생 빈도 및 지속 시간 비교 |
