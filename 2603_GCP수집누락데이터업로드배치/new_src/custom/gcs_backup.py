from mage_ai.settings.repo import get_repo_path
from mage_ai.io.config import ConfigFileLoader, ConfigKey
from google.cloud import bigquery
from google.oauth2 import service_account
from os import path
import pandas as pd

if 'custom' not in globals():
    from mage_ai.data_preparation.decorators import custom


@custom
def transform_custom(*args, **kwargs):
    """
    블록3(upload_hour_data) 완료 목록 기반으로 BQ → GCS 백업
    - 날짜+테이블 단위로 중복 제거된 목록 수신
    - 각 테이블+날짜에 대해 export_2_gcs 프로시져 CALL
    - 날짜 전체(00:00 ~ 23:00) 1회 호출 (프로시져 내부에서 시간별 루프 처리)
    """
    corp_cd = kwargs['corp_cd']

    key_path = f'/home/src/DataForge/bigquery-all-dataset-{corp_cd}.json'
    credentials = service_account.Credentials.from_service_account_file(
        key_path,
        scopes=['https://www.googleapis.com/auth/cloud-platform']
    )
    client = bigquery.Client(credentials=credentials)

    df_done = args[0]

    if df_done.empty:
        print("GCS 백업 대상 없음 - 종료")
        return

    total = len(df_done)

    for idx, row in df_done.iterrows():

        chk_dte         = row['chk_dte']          # 'YYYY-MM-DD'
        bq_project_nm   = row['bq_project_nm']
        bq_dataset_nm   = row['bq_dataset_nm']
        bq_table_nm     = row['bq_table_nm']
        bq_prtn_col     = row['bq_prtn_col']
        pgsql_db_nm     = row['pgsql_db_nm']

        # GCS 버킷/폴더 파라미터 구성
        bq_dataset_prefix = bq_dataset_nm.split('_')[0]
        src_bucket_nm = f'dataforge-seah{corp_cd}-{bq_dataset_prefix}-collect-plc'
        target_folder1_nm = bq_dataset_nm

        s_dt_str = f'{chk_dte} 00:00:00'
        e_dt_str = f'{chk_dte} 23:00:00'

        print(f"\n[{idx+1}/{total}] GCS 백업: {bq_dataset_nm}.{bq_table_nm} / {chk_dte}")
        print(f"  버킷: {src_bucket_nm} / 폴더: {target_folder1_nm}")

        # export_2_gcs 프로시져 CALL
        call_query = f"""
            DECLARE result_str STRING;
            CALL `{bq_project_nm}`.comm_gcp.export_2_gcs(
                '{s_dt_str}',
                '{e_dt_str}',
                '{bq_project_nm}',
                '{src_bucket_nm}',
                '{target_folder1_nm}',
                '{bq_dataset_nm}',
                '{bq_table_nm}',
                '{bq_prtn_col}',
                result_str
            );
            SELECT result_str;
        """

        try:
            query_job = client.query(call_query)
            results = query_job.result().to_dataframe()
            result_str = results.loc[0, 'result_str'] if not results.empty else 'unknown'
            print(f"  결과: {result_str}")
        except Exception as e:
            print(f"  GCS 백업 실패: {e}")

    print(f"\nGCS 백업 완료 - 총 {total}건 처리")
