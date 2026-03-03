---
### gcp_pg_data_sync
---
- 작업자: 하민규
- 관련 문서
    - [24.10.21 GCP 수집 데이터 점검 배치 개발](https://vntg.atlassian.net/wiki/x/PIF9Q)
    
- 기능설명:
    - "gcp_pg_data_check" 의 결과로 누락된 데이터가 확인됐다면 누락 데이터 결과 테이블을 확인 후 수동으로 작업
    - comm_df.gcp_pg_upload_error_hourly_ht 에 테이블에 시간 별로 누락된 데이터 정보가 있다면 "get_gcp_pg_upload_error_hourly_ht" 블럭을 실행하여 진행
- 트리거:
    - 수동
---