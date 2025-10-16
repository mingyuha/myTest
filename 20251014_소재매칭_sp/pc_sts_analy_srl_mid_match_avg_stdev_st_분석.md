# pc_sts_analy_srl_mid_match_avg_stdev_st SQL 쿼리 구조 분석

## 1. 메타데이터 및 파라미터 설정 (1~16행)
- 작업 목적: 소형압연 아이디 매칭 데이터 평균/표준편차 작업
- 작성/수정 정보: 2025-10-14 (하민규)

### 파라미터
- `p_datetime`: 날짜 파라미터 (기본값: 현재일시 - 2일)
- `p_torque_std`: 토크 기준값 (기본값: 5)
- `p_date`: 사용자 입력 날짜 (있을 경우 p_datetime 덮어쓰기)

## 2. 타겟 테이블 및 컬럼 정의 (17~35행)
**INSERT INTO comm_analy.sts_analy_srl_mid_match_avg_stdev_st**

### 기본 정보 컬럼 (7개)
- rm_work_dte: 조압연 통과일
- rm_entry_dtm: 조압연 입고시간
- lot_no: 로트번호
- serial_no: 일련번호
- heat_no: 용탕번호
- strnd_no: 스트랜드번호
- strnd_seq: 스트랜드순서

### Zone별 평균(avg_) 및 표준편차(std_dev_) 컬럼
각 Zone의 센서 태그에 대해 평균과 표준편차를 저장

| Zone | 설비명 | 평균 컬럼 수 | 표준편차 컬럼 수 | 설명 |
|------|--------|-------------|----------------|------|
| srlzone0401 | Zone4-ST1_4 | 31개 | 31개 | STAND 1~4 |
| srlzone0402 | Zone4-ST5_8 | 29개 | 29개 | STAND 5~8 |
| srlzone18 | STAND9_SHEAR10 | 26개 | 26개 | STAND 9 |
| srlzone07 | KOCKS500 | 22개 | 22개 | KOCKS500 |
| srlzone0801 | 3LOOP | 42개 | 42개 | 3LOOP |
| srlzone09 | COMBINED_SHEAR | 1개 | 1개 | 결합 전단기 |
| srlzone1202 | RSM | 6개 | 6개 | RSM |
| srlzone13 | RTD_LH | 1개 | 1개 | RTD_LH |
| srlzone0803 | RSB | 83개 | 83개 | RSB |
| srlzone10 | PREFINISHING | 26개 | 26개 | 조정마 |
| srlzone11 | NTM | 21개 | 21개 | NTM |

**총 컬럼 수: 기본 7개 + 평균 288개 + 표준편차 288개 = 583개**

## 3. 데이터 소스 준비 - WITH 절 (36~130행)

### w: 작업지시 데이터
- 소스: `srl_l2.srl_workorder_mt`
- 필터링 조건:
  - 시간 범위: p_datetime - 2개월 ~ p_datetime + 1일
  - 특정 강종: 316LDS1, STS410S5, STS304SX, STS303S1, 316LDSZ

### cp3: CP3 작업결과 데이터
- 소스: `srl_mes.cp3_work_result_mt`
- str_no, ser_no 매핑용

### worked_billet_list: 작업된 빌렛 목록
- 소스: `srl_l2.srl_zone_mid_trk_mt`
- 조건: Zone4-ST1_4 통과, is_anomaly = 'N'

### trk: 추적 데이터
- 11개 Zone 데이터 통합:
  - Zone4-ST1_4
  - Zone4-ST5_8
  - Zone18-STAND9_SHEAR10
  - Zone7-KOCKS500
  - Zone8-3LOOP
  - Zone8-RSB
  - Zone9-COMBINED_SHEAR
  - Zone10-PREFINISHING
  - Zone11-NTM
  - Zone12-RSM
  - Zone13-RTD_LH
- QUALIFY로 이상치 제거: is_anomaly = 'Y'가 하나라도 있으면 제외

### sec: 초단위 타임스탬프 배열
- GENERATE_TIMESTAMP_ARRAY 사용
- p_datetime - 6시간 ~ p_datetime + 30시간
- 간격: 1초

### z0401 ~ z13: Zone별 초단위 태그 데이터
각 Zone의 초단위 센서 데이터 테이블에서 해당 시간 범위 데이터 추출

## 4. 평균 및 표준편차 계산 (131~711행)

### 계산 방식
```sql
-- 평균값
ROUND(AVG(컬럼명), 4) AS avg_컬럼명

-- 표준편차
CAST(ROUND(STDDEV(컬럼명), 4) AS NUMERIC) AS std_dev_컬럼명
```

### 집계 대상
하위 쿼리(712~1069행)에서 이상치가 제거된 데이터를 대상으로 집계

## 5. 이상치 제거 로직 (712~1069행)

### 5.1. 토크 기반 필터링
**STAND별 토크 센서를 기준으로 실제 작업 구간만 선택**

```sql
CASE WHEN sec.stats_sec_dtm
  BETWEEN
    MIN(CASE WHEN ABS(토크센서) >= p_torque_std THEN sec.stats_sec_dtm END)
      OVER (PARTITION BY lot_no, lot_no_seq_no)
  AND
    MAX(CASE WHEN ABS(토크센서) >= p_torque_std THEN sec.stats_sec_dtm END)
      OVER (PARTITION BY lot_no, lot_no_seq_no)
  THEN 센서값
END
```

**적용 Zone:**
- srlzone0401 (STAND 1~4): 토크 센서별 필터링
- srlzone0402 (STAND 5~8): 토크 센서별 필터링
- srlzone18 (STAND 9): srlzone18_32 기준
- srlzone07 (KOCKS500): srlzone07_42 기준
- srlzone0801 (3LOOP): srlzone0801_5 기준
- srlzone0803 (RSB): srlzone0803_42 기준
- srlzone10 (PREFINISHING): srlzone10_26 기준

### 5.2. 통계적 이상치 제거
**평균 ± 1.5 × 표준편차 범위 내 값만 선택**

```sql
CASE WHEN 센서값
  BETWEEN
    AVG(센서값) OVER (PARTITION BY lot_no, lot_no_seq_no)
      - (1.5 * STDDEV(센서값) OVER (PARTITION BY lot_no, lot_no_seq_no))
  AND
    AVG(센서값) OVER (PARTITION BY lot_no, lot_no_seq_no)
      + (1.5 * STDDEV(센서값) OVER (PARTITION BY lot_no, lot_no_seq_no))
  THEN 센서값
END
```

**적용 대상:**
- 냉각수 유량 (COOLING FLOW)
- 루프 센서 (LOOP)
- 기타 비토크 센서들

### 5.3. 온도 필터링
**최소 온도 기준 적용**

```sql
-- Zone4-ST1_4 온도: 600도 이상
CASE WHEN srlzone0401_4 > 600 THEN srlzone0401_4 END

-- Zone4-ST5_8 온도: 400도 이상
CASE WHEN srlzone0402_1 > 400 THEN srlzone0402_1 END
```

## 6. 데이터 조인 및 집계 (1044~1071행)

### 조인 구조
```
trk (추적 데이터)
  INNER JOIN sec (초단위 타임스탬프)
    ON sec.stats_sec_dtm BETWEEN trk.entry_dtm AND trk.exit_dtm
  LEFT JOIN z0401~z13 (Zone별 태그 데이터)
    ON sec.stats_sec_dtm = zone.stats_sec_dtm AND trk.zone_cd = zone.zone_cd
```

### GROUP BY 키
- heat_no (용탕번호)
- str_no (스트랜드번호)
- ser_no (스트랜드순서)
- lot_no (로트번호)
- lot_no_seq_no (로트순서번호)

## 7. 예외 처리 (1073~1076행)
```sql
EXCEPTION
    WHEN ERROR THEN
    SELECT @@error.message;
```

## 핵심 목적

**소형압연 공정의 각 Zone에서 발생하는 센서 데이터를 lot_no별로 집계하되, 다음과 같은 이상치 제거 후 평균과 표준편차를 계산하여 저장:**

1. **토크 기반 필터링**: 토크가 기준값(기본 5) 이상인 실제 작업 구간만 선택
2. **통계적 이상치 제거**: 평균 ± 1.5×표준편차 범위 내 값만 사용
3. **물리적 조건 필터링**: 온도 등 물리적으로 유효한 범위의 데이터만 선택

## 주요 차이점 (vs pc_sts_analy_sm2_mid_match)

| 구분 | pc_sts_analy_sm2_mid_match | pc_sts_analy_srl_mid_match_avg_stdev_st |
|------|----------------------------|------------------------------------------|
| 공정 | 2제강 (SM2) | 소형압연 (SRL) |
| 출력 형태 | **시계열 배열** (초단위 전체 데이터) | **통계값** (평균, 표준편차) |
| 데이터 크기 | 매우 큼 (수백~수천 개 배열) | 작음 (각 태그당 2개 값) |
| 이상치 처리 | 없음 | **3단계 필터링** (토크/통계/물리) |
| 사용 목적 | 시계열 분석, 상세 프로파일 분석 | 소재 매칭, 통계 기반 품질 분석 |
| 집계 함수 | ARRAY_AGG | AVG, STDDEV |
