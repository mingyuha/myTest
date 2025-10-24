# BigQuery 컬럼명 → Description 자동 변환 및 CSV 내보내기

BigQuery 테이블의 컬럼명을 스키마에 정의된 description으로 자동 변환하여 SELECT 쿼리를 생성하고, 결과를 CSV 파일로 저장합니다.

## 사용 방법

### 1. 의존성 설치

```bash
pip install -r requirements.txt
```

### 2. BigQuery 인증 설정

Google Cloud 인증이 필요합니다. 다음 중 하나의 방법으로 설정하세요:

**방법 1: 서비스 계정 키 사용**
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
```

**방법 2: gcloud CLI 인증**
```bash
gcloud auth application-default login
```

### 3. 스크립트 수정

`generate_query_with_descriptions.py` 파일을 열어서 다음 부분을 수정하세요:

```python
PROJECT_ID = "your-project-id"  # 여기에 실제 프로젝트 ID 입력
OUTPUT_CSV = "result.csv"  # 원하는 CSV 파일명
```

### 4. 실행

```bash
python generate_query_with_descriptions.py
```

### 5. 결과

스크립트 실행 시 다음과 같은 작업이 수행됩니다:

1. **SQL 쿼리 생성**: `generated_query.sql` 파일로 저장
2. **BigQuery 쿼리 실행**: 자동으로 쿼리를 실행
3. **CSV 파일 저장**: `result_YYYYMMDD_HHMMSS.csv` 형식으로 저장 (타임스탬프 포함)

출력 예시:
```
테이블 스키마 정보를 가져오는 중...
  - sm2_chem_insp_mt
  - sts_analy_sm2_mid_match_avg_std_dev_st
  - sts_analy_srl_mid_match_avg_std_dev_st
  - sts_analy_bad_mt

총 4개 테이블의 스키마를 가져왔습니다.

쿼리가 'generated_query.sql' 파일로 저장되었습니다.
총 150개의 컬럼이 description으로 변환되었습니다.

BigQuery 쿼리 실행 중...
쿼리가 실행되었습니다. 결과를 가져오는 중...
총 1,234개의 행을 가져왔습니다.

결과가 'result_20250124_153045.csv' 파일로 저장되었습니다.
파일 크기: 1234행 x 150열
```

## 작동 원리

1. **스키마 가져오기**: BigQuery API를 통해 4개 테이블의 스키마 정보를 가져옵니다
2. **Description 추출**: 각 컬럼의 `description` 필드를 읽어옵니다
3. **쿼리 생성**: 기존 쿼리 구조를 유지하면서 `SELECT *` 부분을 `SELECT col AS 'description'` 형태로 변환합니다
4. **쿼리 실행**: 생성된 쿼리를 BigQuery에서 실행합니다
5. **CSV 저장**: 결과를 Pandas DataFrame으로 변환하여 CSV 파일로 저장합니다 (UTF-8 BOM 포함, Excel 호환)

## 주의사항

- BigQuery 스키마에 description이 정의되어 있어야 합니다
- description이 없는 컬럼은 컬럼명을 그대로 사용합니다
- 다음 권한이 필요합니다:
  - `bigquery.tables.get`: 스키마 조회
  - `bigquery.jobs.create`: 쿼리 실행
- CSV 파일은 `utf-8-sig` 인코딩으로 저장되어 Excel에서 한글이 정상 표시됩니다
- 데이터가 많을 경우 쿼리 실행 시간이 오래 걸릴 수 있습니다
