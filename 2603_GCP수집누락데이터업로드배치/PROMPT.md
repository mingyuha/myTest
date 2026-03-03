# 작업 제목
GCP 수집 누락 데이터 업로드 배치 
## 개요
<!-- 이 작업의 목표를 한두 줄로 설명 -->
- Edge 서버에서 수집한 태그 데이터를 PostgreSQL에 저장하고 동시에 GCS에 파일을 올리고 해당 파일에서 Bigquery로 데이터를 저장한다
- 매일 Bigquery에 데이터가 정상적으로 업로드 되었는지 Edge 의 PostgreSQL DB의 매칭된 테이블에서 데이터 개수를 비교하여 알림을 받고 있다
- 만약 데이터 개수가 서로 상이하다면 Bigquery에 업로드 된 데이터의 개수가 적다면 별도로 수동으로 PostgreSQL 데이터를 가져와서 Bigquery로 전송하고 있다
## 목적
- 수동으로 업로드하는 로직을 자동으로 해야 한다
- 현재는 비교 후 일비교 테이블에 비교결과가 저장되고 있다
- 현재 기준은 Bigquery 데이터 - PostgreSQL 테이블의 데이터 가 10보다 크다면 재업로드를 대상이다
- 하지만 일 데이터가 크기때문에 보다 정밀하고 시간단위로 비교해서 시간대로 별도로 비교해서 시간단위 비교 테이블에 저장해야 한다
- 수동으로 처리할때는 비교해야할 대상이 생기면 시간대별롤 비교해서 시간대에서 차이나는 시간과 차이를 저장한 후 별도의 배치로 데이터를 업로드 하고 있다
- 수동으로 처리할때 GCS에 별도로 업로드한 데이터를 백업해야 한다
## 현재 상황 (Context)
- **언어**: 파이썬 
- **플랫폼/환경**:Mage.AI에서 여러 블록들이 순차적으로 실행되고 있다.
- **DB**: PostgreSQL, Bigquery
- **기타 기술 스택**: 추가로 GCS 업로드 필요

## 프로젝트 구조
<!-- 관련 파일/폴더 구조를 간략히 -->
```
프로젝트/
├── gcp_pg_data_check : 데이터 갯수 비교하는 Mage.AI 파이프라인 소스
├── gcp_pg_data_sync : 수동 배치 Mage.AI 파이프라인 소스
├── new_src : 생성해야할 업로드 배치 소스
└── 
```

## 기존 소스 코드

> 소스 파일은 아래 폴더에 있으므로 클로드에게 "해당 폴더 조사해줘" 요청으로 읽을 수 있음
> - `gcp_pg_data_check/` : 일별 데이터 비교 파이프라인
> - `gcp_pg_data_sync/` : 수동 누락 데이터 업로드 파이프라인

## 분석 결과 (클로드가 소스 조사 후 파악한 내용)

### gcp_pg_data_check 파이프라인 블록 순서
```
get_check_table_info (SQL) → check_data (Python) → insert_gcp_pg_table_chk_ht (Python)
```
- `comm_df.clct_table_mt` 에서 비교 대상 테이블 목록 조회 (`bq_pgsql_compare_yn = 'Y'`)
- BQ/PG 각각 일별 건수 조회 후 `diff_cnt = BQ건수 - PG건수` 계산
- `comm_df.gcp_pg_table_chk_ht` 에 저장 (unique: `table_uid + chk_dte`)
- `diff_cnt < -10` 또는 `diff_cnt > 10000` 이면 Google Chat Webhook 알림
- 매일 오후 2시 실행, `corp_cd` 변수로 사업장 구분

### gcp_pg_data_sync 파이프라인 블록 구조
```
흐름 1 (일별 누락 업로드 - 수동 트리거)
get_chk_data ──┬──→ gcp_pg_data_sync_plc   (PLC 태그 데이터 - 시간별 루프로 업로드)
               └──→ gcp_pg_data_sync_idtrk  (ID Tracking 데이터 - 일 단위로 업로드)

흐름 2 (시간별 누락 업로드 - 수동 트리거)
get_gcp_pg_upload_error_hourly_ht → gcp_pg_data_upload_hour
```

### 주요 DB 테이블
| 테이블 | 용도 |
|--------|------|
| `comm_df.clct_table_mt` | 비교 대상 테이블 메타 정보 |
| `comm_df.db_mt` | DB 접속 정보 (ip, port) |
| `comm_df.gcp_pg_table_chk_ht` | 일별 비교 결과 저장 |
| `comm_df.gcp_pg_upload_error_hourly_ht` | 시간별 누락 데이터 정보 (이미 존재) |

### gcp_pg_upload_error_hourly_ht 테이블 컬럼 (소스에서 유추)
```
table_uid, chk_dte (날짜+시간 형식: '2026-01-21 00:00:00'),
bq_cnt, after_work_bq_cnt, pgsql_cnt, diff_cnt, work_yn
```

### 데이터 종류 구분
- **PLC 태그 데이터**: `bq_dataset_nm`이 `_tag` 또는 `_tms` 포함
- **ID Tracking 데이터**: `bq_table_nm`이 `l2_mid_trk_mt` 포함
- **plc 테이블**: `pgsql_table_nm`이 `plc`로 끝나면 `tags.stats`에서 통계 사용

### 새로 만들어야 할 흐름 (new_src)
```
[현재 - 수동]
gcp_pg_data_check → 일별 비교결과 저장 → (수동으로) gcp_pg_data_sync 실행

[목표 - 자동]
gcp_pg_data_check → 일별 비교결과 저장
                  → diff_cnt < -10 인 경우
                    → 시간별 BQ/PG 건수 비교
                    → gcp_pg_upload_error_hourly_ht 저장
                    → 자동으로 시간별 업로드 실행
                    → GCS 백업 (※ 로직 추가 필요 - 아직 미확인)
```

## 제약 조건
- 파이썬 프로그램이지만 Mage.AI에서 여러 블록으로 실행되야 한다
- BigQuery 조회 비용 최소화 필요

## 미결 사항 (추가 논의 필요)
- [ ] GCS 백업 로직: 수동 작업 시 어떤 방식으로 백업했는지 확인 필요
- [ ] 전체 테이블 누락 케이스 처리: `diff_cnt > 10000` 등 대량 누락 시 업로드 skip 또는 별도 알림 기준 미정
- [ ] 시간별 비교 기준: 10건 차이 동일 적용 여부 확인 필요

## 요청 사항
- 개수 비교 후 시간별로 비교하여 누락된 시간대 정보를 테이블로 저장 후 한꺼번에 업로드 작업
- 전체 테이블 누락 시 비용 폭증 방지 로직 필요 (Bigquery 조회 비용)
- GCS에 업로드한 데이터 백업 필요

