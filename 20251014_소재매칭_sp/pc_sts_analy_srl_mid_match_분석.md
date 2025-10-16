# pc_sts_analy_srl_mid_match SQL 쿼리 구조 분석

## 1. 메타데이터 및 주석 (1~5행)
- 날짜 파라미터 선언 (주석 처리됨)
- dateFrom, dateTo 사용 예정

## 2. 타겟 테이블 및 컬럼 정의 (6~1291행)
**INSERT INTO srl_tag.mid_stats_rt**

### 기본 정보 컬럼 (16개)
- heat_no: 용탕번호
- m_lot_no: 모재 로트번호
- lot_no_seq_no: 로트순서번호
- lot_tot_proc_seq_no: 로트 총 공정순서번호
- lot_no: 로트번호 (PK)
- str_no: 스트랜드번호
- seq_no: 순서번호
- zone_id: 구역 ID
- zone_nm: 구역명
- entry_dtm: 입고시간
- exit_dtm: 출고시간
- company_steel_grade_name: 강종명
- rolling_out_dia: 압연 출측 직경
- new_shape: 신규 형상
- main_equip_type: 주설비 타입
- stats_sec_dtm: 초단위 통계 시간 (배열)

### Zone별 태그 데이터 (시계열 배열)

| Zone | Zone명 | 태그 개수 | 설명 |
|------|--------|-----------|------|
| srlzone0301 | Zone3-1 | 323개 | 가열로 Zone3-1 |
| srlzone0302 | Zone3-2 | 1개 | 가열로 Zone3-2 |
| srlzone0401 | Zone4-ST1_4 | 40개 | STAND 1~4 |
| srlzone0402 | Zone4-ST5_8 | 34개 | STAND 5~8 |
| srlzone0601 | Zone6-1 | 8개 | Zone6-1 |
| srlzone0602 | Zone6-2 | 6개 | Zone6-2 |
| srlzone0603 | Zone6-3 | 6개 | Zone6-3 |
| srlzone0604 | Zone6-4 | 6개 | Zone6-4 |
| srlzone0605 | Zone6-5 | 6개 | Zone6-5 |
| srlzone0606 | Zone6-6 | 6개 | Zone6-6 |
| srlzone0607 | Zone6-7 | 25개 | Zone6-7 |
| srlzone18 | STAND9_SHEAR10 | 48개 | STAND 9 |
| srlzone07 | KOCKS500 | 51개 | KOCKS500 |
| srlzone0801 | 3LOOP | 53개 | 3LOOP |
| srlzone0803 | RSB | 209개 | RSB (Reducing Sizing Block) |
| srlzone0804 | Zone8-4 | 6개 | Zone8-4 |
| srlzone09 | COMBINED_SHEAR | 3개 | 결합 전단기 |
| srlzone10 | PREFINISHING | 38개 | 조정마 |
| srlzone11 | NTM | 36개 | NTM (No Twist Mill) |
| srlzone1202 | RSM | 6개 | RSM |
| srlzone13 | RTD_LH | 21개 | RTD_LH |
| srlzone14 | Zone14 | 96개 | Zone14 |
| srlzone15 | Zone15 | 152개 | Zone15 |
| srlzone20 | Zone20 | 42개 | Zone20 |
| srlzone21 | Zone21 | 46개 | Zone21 |

**총 태그 컬럼 수: 1,268개**
**총 컬럼 수: 기본 16개 + 태그 1,268개 = 1,284개**

## 3. 데이터 소스 준비 - WITH 절 (1293~1419행)

### T1: 기본 추적 데이터
- 소스: `srl_l2.srl_zone_mid_trk_mt`
- 필터링 조건:
  - is_anomaly = 'N' (정상 데이터만)
  - entry_dtm IS NOT NULL
  - entry_dtm < exit_dtm (시간 유효성)
  - lot_no NOT LIKE '%TEST%' (테스트 데이터 제외)
  - lot_no NOT IN ('B360311201', 'B450169800') (특정 불량 데이터 제외)
  - 날짜 범위: dateFrom ~ dateTo
- 집계: 각 lot의 zone별 entry_dtm, exit_dtm 추출

### T2: 초단위 타임스탬프 배열
- GENERATE_TIMESTAMP_ARRAY 사용
- dateFrom 00:00:00 ~ dateTo 23:59:59
- 간격: 1초

### T3: Zone 정보
- 소스: `srl_l2.srl_zone_info_mt`
- zone_nm → zone_cd 매핑

### T4: 태그 리스트
- 소스: `srl_l2.srl_tag_list_mt`
- zone_id, zone_nm 매핑

### T5: 로트-스트랜드 매핑
- 소스1: `pk_mes.insp_daily_report_mt` (PK 검사 일보)
- 소스2: `srl_mes.wire_heating_daily_report_mt` (선재 가열 일보)
- heat_no, m_lot_no, serial_no → str_no, ser_no 매핑

### T6: 작업지시 정보
- 소스: `srl_l2.srl_workorder_mt`
- lot_no별 최신 데이터 선택 (ROW_NUMBER)
- 강종명, 압연 출측 직경, 형상, 설비 타입 등 제공

### Z0301 ~ Z2100: Zone별 초단위 태그 데이터
25개 Zone의 초단위 센서 데이터 테이블에서 해당 날짜 범위 데이터 추출

```sql
Z0301 AS ( SELECT 'SRLZONE0301' zone_cd, * FROM srl_tag.tag_sec_zone0301_st ...
Z0302 AS ( SELECT 'SRLZONE0302' zone_cd, * FROM srl_tag.tag_sec_zone0302_st ...
...
Z2100 AS ( SELECT 'SRLZONE21' zone_cd, * FROM srl_tag.tag_sec_zone21_st ...
```

### T9: 전체 데이터 조인
- T1 (추적) LEFT JOIN T4 (태그리스트) ON zone_nm
- T1 LEFT JOIN T5 (로트-스트랜드) ON heat_no, m_lot_no, serial_no
- T1 LEFT JOIN T6 (작업지시) ON lot_no
- T1 INNER JOIN T2 (시간) ON stats_sec_dtm BETWEEN entry_dtm AND exit_dtm
- T2 LEFT JOIN Z0301~Z2100 ON stats_sec_dtm AND zone_cd

**주요 특징:**
- INNER JOIN으로 시간 범위 내 데이터만 선택
- LEFT JOIN으로 25개 Zone 데이터 병합
- EXCEPT 구문으로 zone_cd, stats_sec_dtm 중복 제거

## 4. 최종 집계 및 출력 (1493~2780행)

### 집계 방식
**ARRAY_AGG** 함수 사용
```sql
ARRAY_AGG(컬럼명 IGNORE NULLS ORDER BY stats_sec_dtm)
```

### GROUP BY 키 (15개)
- heat_no (용탕번호)
- m_lot_no (모재 로트번호)
- lot_no_seq_no (로트순서번호)
- lot_tot_proc_seq_no (로트 총 공정순서번호)
- pk_lot_no (PK 로트번호)
- str_no (스트랜드번호)
- seq_no (순서번호)
- zone_id (구역 ID)
- zone_nm (구역명)
- entry_dtm (입고시간)
- exit_dtm (출고시간)
- company_steel_grade_name (강종명)
- rolling_out_dia (압연 출측 직경)
- new_shape (형상)
- main_equip_type (주설비 타입)

### ORDER BY
```sql
ORDER BY heat_no, m_lot_no, lot_no_seq_no, zone_id
```

### 결과 데이터 구조
각 lot_no의 Zone별 체류 시간 동안의 모든 태그값을 초단위 배열로 저장
- 예: lot_no 'L123'이 Zone3-1에서 100초 체류 → srlzone0301_1~323 각각 100개 요소를 가진 배열

## 핵심 목적

**소형압연(SRL) 공정의 전체 25개 Zone에서 발생하는 센서 태그 데이터를 lot_no별로 초단위 시계열 배열로 집계하여 mid_stats_rt 테이블에 저장**

이를 통해:
- 로트별 전 공정 이력 추적 (가열로 → STAND → 후처리)
- 초단위 센서 데이터 기반 상세 품질 분석
- 시계열 프로파일 분석 및 이상 탐지
- 공정 최적화 및 소재 매칭에 활용

## 주요 특징

### 1. 광범위한 Zone 커버리지
- 25개 Zone 통합 (2제강 대비 5배)
- 가열로부터 최종 제품까지 전 공정 포함

### 2. 대용량 태그 데이터
- 1,268개 태그 컬럼
- Zone별 특성에 따라 1~323개 태그

### 3. 복잡한 ID 매핑
- heat_no → m_lot_no → pk_lot_no
- serial_no → str_no, ser_no
- 여러 시스템(L2, MES, PK) 통합

### 4. 데이터 품질 관리
- 이상치 필터링 (is_anomaly = 'N')
- 테스트 데이터 제외
- 시간 유효성 검증
- 최신 작업지시 정보 사용 (ROW_NUMBER)

## 비교: 3개 쿼리 종합 분석

| 구분 | pc_sts_analy_sm2_mid_match | pc_sts_analy_srl_mid_match | pc_sts_analy_srl_mid_match_avg_stdev_st |
|------|----------------------------|----------------------------|------------------------------------------|
| 공정 | 2제강 (SM2) | 소형압연 (SRL) | 소형압연 (SRL) |
| Zone 수 | 5개 | 25개 | 11개 |
| 태그 수 | 377개 | 1,268개 | 288개 |
| 출력 형태 | **시계열 배열** | **시계열 배열** | **평균/표준편차** |
| 데이터 크기 | 매우 큼 | 초대형 | 작음 |
| 이상치 처리 | 없음 | 기본 필터링만 | **3단계 정교한 필터링** |
| 사용 목적 | 제강 공정 분석 | 압연 공정 전체 분석 | 소재 매칭 최적화 |
| 집계 함수 | ARRAY_AGG | ARRAY_AGG | AVG, STDDEV |
| ID 복잡도 | 낮음 (heat_no 중심) | 높음 (다중 시스템 통합) | 높음 (다중 시스템 통합) |
