# 작업 제목
GCP 수집 누락 데이터 업로드 배치

---

## 개요
- Edge 서버에서 수집한 태그 데이터를 PostgreSQL에 저장하고 동시에 GCS에 파일을 올리고 해당 파일에서 Bigquery로 데이터를 저장한다
- 매일 Bigquery에 데이터가 정상적으로 업로드 되었는지 Edge의 PostgreSQL DB의 매칭된 테이블에서 데이터 개수를 비교하여 알림을 받고 있다
- 만약 데이터 개수가 서로 상이하다면 Bigquery에 업로드된 데이터의 개수가 적다면 별도로 수동으로 PostgreSQL 데이터를 가져와서 Bigquery로 전송하고 있다

## 목적
- 수동으로 업로드하는 로직을 자동으로 해야 한다
- 현재는 비교 후 일비교 테이블에 비교결과가 저장되고 있다
- 일 데이터가 크기때문에 보다 정밀하게 시간단위로 비교해서 시간단위 비교 테이블에 저장해야 한다
- 수동으로 처리할때는 비교해야할 대상이 생기면 시간대별로 비교해서 시간대에서 차이나는 시간과 차이를 저장한 후 별도의 배치로 데이터를 업로드 하고 있다
- 수동으로 처리할때 GCS에 별도로 업로드한 데이터를 백업해야 한다

## 현재 상황 (Context)
- **언어**: 파이썬
- **플랫폼/환경**: Mage.AI에서 여러 블록들이 순차적으로 실행되고 있다
- **DB**: PostgreSQL, Bigquery
- **기타 기술 스택**: GCS 업로드 필요

---

## 프로젝트 구조
```
프로젝트/
├── gcp_pg_data_check      : 데이터 갯수 비교하는 Mage.AI 파이프라인 소스 (기존)
├── gcp_pg_data_sync       : 수동 배치 Mage.AI 파이프라인 소스 (기존, 참조용)
├── compare_insert_hour_ht : 시간대별 BQ/PG 비교 후 gcp_pg_upload_error_hourly_ht 에 저장하는 소스 (참조용)
├── export_2_gcs           : Bigquery → GCS 로 데이터 저장하는 Bigquery 프로시져
├── trigger 샘플 : 다른 파이프라인 스케줄을 호출하는 트리거 샘플
├── new_src                : 생성해야 할 자동화 업로드 배치 소스 (신규 개발 대상)
└──
```

### 기존 파이프라인 블록 구조 (참조)

**gcp_pg_data_check** (일별 비교 - 자동 실행)
```
get_check_table_info.sql → check_data.py → insert_gcp_pg_table_chk_ht.py
```

**gcp_pg_data_sync** (수동 재업로드 - 참조용)
```
흐름1 (일별): get_chk_data.py → gcp_pg_data_sync_plc.py / gcp_pg_data_sync_idtrk.py
흐름2 (시간별): get_gcp_pg_upload_error_hourly_ht.py → gcp_pg_data_upload_hour.py
```

### 주요 DB 테이블
| 테이블 | 용도 |
|--------|------|
| `comm_df.clct_table_mt` | 비교 대상 테이블 메타 정보 (`bq_pgsql_compare_yn='Y'`) |
| `comm_df.db_mt` | DB 접속 정보 (ip, port) |
| `comm_df.gcp_pg_table_chk_ht` | 일별 BQ/PG 비교 결과 저장 |
| `comm_df.gcp_pg_upload_error_hourly_ht` | 시간별 누락 데이터 정보 저장 |

### gcp_pg_upload_error_hourly_ht 컬럼
```
table_uid, chk_dte (YYYY-MM-DD HH:00:00),
bq_cnt, after_work_bq_cnt, pgsql_cnt, diff_cnt, work_yn
```

### 데이터 종류 구분
- **PLC 태그 데이터**: `bq_dataset_nm`이 `_tag` 또는 `_tms` 포함
- **ID Tracking 데이터**: `bq_table_nm`이 `l2_mid_trk_mt` 포함
- **plc 테이블**: `pgsql_table_nm`이 `plc`로 끝나면 `tags.stats_hour` 에서 통계 사용

---

## 현재 수동 처리 흐름
```
[1] gcp_pg_data_check 실행 (매일 자동)
      → BQ/PG 일별 건수 비교 → gcp_pg_table_chk_ht 저장
      → diff_cnt < -10 또는 > 10000 이면 webhook 알림

[2] (수동) 알림 확인 후 해당 날짜를 시간별로 BQ/PG 건수 비교
      → 차이나는 시간대 정보를 gcp_pg_upload_error_hourly_ht 에 입력

[3] (수동) gcp_pg_upload_error_hourly_ht 읽어서 업로드 실행
      → 해당 시간대 BQ 데이터 DELETE 후 PG 데이터 INSERT

[4] (누락) GCS 백업 없음
      → BQ 데이터를 GCS 파일로 저장하는 로직이 빠져 있음
```

---

## 자동화 로직 설계 (new_src 파이프라인)

### 처리 기준 (확정)
- **`diff_cnt < -100`** (BQ 건수가 PG 건수보다 100건 이상 적을 때)만 자동 처리 실행
- 일 단위 전체 재업로드 대신 시간 단위 세분화 처리로 범위 최소화

### GCS 백업 방식 (확정)
- **프로시져**: `export_2_gcs` (Bigquery Stored Procedure - BQ에 배포 완료)
- **호출 방식**: Python에서 `client.query("CALL project.dataset.export_2_gcs(...)")` 실행
- **백업 타이밍**: 날짜 단위 일괄 백업 (해당 날짜 전체 시간 업로드 완료 후 1회 호출)
- **프로시져 입력 파라미터**:
  ```
  s_dt_str          : 시작 시간 ('YYYY-MM-DD 00:00:00')
  e_dt_str          : 종료 시간 ('YYYY-MM-DD 23:00:00')
  project_nm        : BQ 프로젝트명
  src_bucket_nm     : 소스 버킷명 (예: dataforge-seah{corp_cd}-{prefix}-collect-plc)
  target_folder1_nm : 폴더명 (bq_dataset_nm 활용)
  dataset_nm        : BQ 데이터셋명
  table_nm          : BQ 테이블명
  partition_column_nm : 파티션 컬럼명 (bq_prtn_column_nm)
  result_str        : OUT - 성공/실패 메시지
  ```
- **GCS 저장 경로**:
  ```
  gs://{project_nm}-zbackup/{src_bucket_nm}/{folder}/yr={년}/dt={날짜}/{folder}_{yyyymmddHH}_*_.bigquery.json.gz
  ```

### 확정된 자동화 흐름
```
[블록 1] get_daily_targets
  - gcp_pg_table_chk_ht 에서 diff_cnt < -100 AND work_yn='N' 조회
  - 출력: 처리 대상 (table_uid, chk_dte, BQ/PG 메타정보) 목록

[블록 2] compare_insert_hour
  - 블록1 대상 각 (table_uid, chk_dte) 에 대해:
    → BQ: 해당 날짜 전체 시간별 건수 1회 쿼리 (비용 절감)
    → PG: 시간별 건수 조회
    → 시간별 diff_cnt = BQ건수 - PG건수 계산
    → diff_cnt < 0 인 시간대만 gcp_pg_upload_error_hourly_ht UPSERT (work_yn='N')
  - 출력: 저장된 시간별 누락 레코드

[블록 3] upload_hour_data
  - 블록2 결과(work_yn='N') 각 시간 레코드 처리:
    1. BQ 해당 시간대 DELETE
    2. PG 해당 시간대 데이터 조회
    3. BQ INSERT
    4. BQ 건수 재확인 → after_work_bq_cnt
    5. gcp_pg_upload_error_hourly_ht work_yn='Y', after_work_bq_cnt 업데이트
  - 출력: 업로드 완료된 (table_uid, 날짜) 목록

[블록 4] gcs_backup
  - 블록3 완료 목록에서 날짜 단위로 중복 제거
  - 각 테이블+날짜에 대해 CALL export_2_gcs(
      s_dt_str='YYYY-MM-DD 00:00:00',
      e_dt_str='YYYY-MM-DD 23:00:00',
      project_nm, src_bucket_nm, target_folder1_nm,
      dataset_nm, table_nm, partition_column_nm, result_str
    )
  - result_str 확인 후 성공/실패 로깅
```

---

## 제약 조건
- 파이썬 프로그램이지만 Mage.AI에서 여러 블록으로 실행되어야 한다
- BigQuery 조회 비용 최소화 필요

## 확정 사항
- [x] `export_2_gcs` 프로시져 BQ에 배포되어 있음 → CALL 호출 방식 사용
- [x] GCS 백업 방식: CALL 호출 (`client.query("CALL ...")`)
- [x] `new_src` 파이프라인명: **`gcp_pg_data_check_sync`** (확정)
  - `gcp_pg_data_sync` 는 스케줄러가 아니므로 이름 충돌 없음
- [x] `new_src` 실행 방식: 조건부 트리거 (Option A)
  - `insert_gcp_pg_table_chk_ht.py` 마지막에 트리거 코드 추가
  - `diff_cnt < -100` 인 건이 하나라도 있을 때만 트리거 발생
  - 없으면 트리거 발생 안 함 → 불필요한 파이프라인 실행 방지

### 트리거 코드 (insert_gcp_pg_table_chk_ht.py 마지막에 추가)
```python
if (df['diff_cnt'] < -100).any():
    trigger_pipeline(
        'gcp_pg_data_check_sync',
        variables={},
        check_status=False,
        error_on_failure=False,
        poll_interval=60,
        poll_timeout=None,
        schedule_name='gcp_pg_data_check_sync',
        verbose=True,
    )
```

## 미결 사항
- 없음 (모든 설계 확정)
