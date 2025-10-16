# pc_sts_analy_sm2_mid_match SQL 쿼리 구조 분석

## 1. 메타데이터 및 주석 (1~9행)
- 작업 목적: 2제강 아이디 매칭 데이터 작업
- 작성/수정 정보: 2025-10-15 (하민규)
- 파라미터: YYYY-MM-DD 형식의 문자열 (dateFrom, dateTo)

## 2. 타겟 테이블 및 컬럼 정의 (11~400행)
**INSERT INTO sm2_tag.mid_stats_rt**

### 기본 정보 컬럼 (10개)
- heat_no: 용탕번호
- step_seq_no: 공정순서번호
- step_cd: 공정코드
- rework_seq_no: 재작업순서번호
- zone_id: 구역 ID
- zone_nm: 구역명
- subzone_nm: 하위구역명
- entry_dtm: 입고시간
- exit_dtm: 출고시간
- cssteelkindname: 강종명

### 시간 정보
- stats_sec_dtm: 초단위 통계 시간 (배열)

### Zone별 태그 데이터
| Zone | 설비명 | 태그 개수 | 설명 |
|------|--------|-----------|------|
| sm2zone01 | EAF | 148개 | 전기로 (Electric Arc Furnace) |
| sm2zone02 | LF | 84개 | 정련로 (Ladle Furnace) |
| sm2zone03 | VD | 87개 | 진공탈가스 (Vacuum Degassing) |
| sm2zone04 | AOD | 28개 | 진공탈탄 (Argon Oxygen Decarburization) |
| sm2zone05 | LTS | 30개 | 래들이송대차 (Ladle Transfer System) |

**총 태그 컬럼 수: 377개**

## 3. 데이터 소스 준비 - WITH 절 (401~476행)

### T1: 기본 추적 데이터
- 소스: `sm2_l2.sm2_zone_mid_trk_mt`
- 조인: zone_info_mt (zone_id 매핑), step_info_mt (step_seq_no 매핑)
- 필터링 조건:
  - abnorm_yn = 'n' (정상 데이터만)
  - entry_dtm, exit_dtm NOT NULL
  - entry_dtm < exit_dtm (시간 유효성)
  - 날짜 범위: dateFrom ~ dateTo
- 집계: heat_no, step, zone 정보별 MIN(entry_dtm), MAX(exit_dtm)

### T2: 작업지시 데이터
- 소스: `sm2_l2.sm2_workorder_mt`
- 특정 강종 필터링:
  - 316LDS1
  - STS410S5
  - STS304SX
  - STS303S1
  - 316LDSZ
- ROW_NUMBER로 최신 데이터만 선택

### T3: 초단위 타임스탬프 배열
- GENERATE_TIMESTAMP_ARRAY 사용
- dateFrom 00:00:00 ~ dateTo 23:59:59
- 간격: 1초

### Z1 ~ Z5: Zone별 초단위 태그 데이터
| CTE | Zone명 | 소스 테이블 |
|-----|--------|-------------|
| Z1 | EAF | sm2_tag.tag_sec_zone01_st |
| Z2 | LF | sm2_tag.tag_sec_zone02_st |
| Z3 | VD | sm2_tag.tag_sec_zone03_st |
| Z4 | AOD | sm2_tag.tag_sec_zone04_st |
| Z5 | LTS | sm2_tag.tag_sec_zone05_st |

### T9: 전체 데이터 조인
- T1 (추적) LEFT JOIN T2 (작업지시) ON heat_no
- T1 LEFT JOIN T3 (시간) ON stats_sec_dtm BETWEEN entry_dtm AND exit_dtm
- T1 LEFT JOIN Z1~Z5 ON zone_nm AND stats_sec_dtm
- 필터: 모든 Zone의 stats_sec_dtm이 NULL인 경우 제외

## 4. 최종 집계 및 출력 (477~880행)

### 집계 방식
- **ARRAY_AGG** 함수 사용
- IGNORE NULLS 옵션
- ORDER BY stats_sec_dtm (시간순 정렬)

### GROUP BY 키
- heat_no (용탕번호)
- step_seq_no (공정순서)
- step_cd (공정코드)
- rework_seq_no (재작업순서)
- zone_id (구역 ID)
- zone_nm (구역명)
- subzone_nm (하위구역명)
- entry_dtm (입고시간)
- exit_dtm (출고시간)
- cssteelkindname (강종명)

### 결과 데이터 구조
각 heat_no의 Zone별 체류 시간 동안의 모든 태그값을 초단위 배열로 저장
- 예: heat_no 'H123'이 EAF에서 100초 체류 → sm2zone01_1~148 각각 100개 요소를 가진 배열

## 핵심 목적

**제강공정의 각 Zone(EAF/LF/VD/AOD/LTS)에서 발생하는 센서 태그 데이터를 heat_no별로 초단위 시계열 배열로 집계하여 mid_stats_rt 테이블에 저장**

이를 통해:
- 용탕별 전 공정 이력 추적
- 특정 강종의 공정 프로파일 분석
- 시계열 센서 데이터 기반 품질 분석
- 소재 매칭 및 최적화에 활용
