from mage_ai.settings.repo import get_repo_path
from mage_ai.io.config import ConfigFileLoader
from mage_ai.io.postgres import Postgres
from pandas import DataFrame
from os import path
from json import dumps
from httplib2 import Http
from datetime import datetime
from pytz import timezone
import pandas as pd

if 'data_exporter' not in globals():
    from mage_ai.data_preparation.decorators import data_exporter

def send_webhook(url, message):
    
    message_headers = {'Content-Type': 'application/json; charset=UTF-8'}
    http_obj = Http()
    response = http_obj.request(
        uri=url,
        method='POST',
        headers=message_headers,
        body=dumps(message),
    )

@data_exporter
def export_data_to_postgres(df: DataFrame, **kwargs) -> None:

    if not df.empty:
        
        corp_cd = kwargs['corp_cd']

        config_path = path.join(get_repo_path(), 'io_config.yaml')
        config_profile = f'{corp_cd}_stats'

        schema_name = 'comm_df'  # Specify the name of the schema to export data to
        table_name = 'gcp_pg_table_chk_ht'  # Specify the name of the table to export data to

        with Postgres.with_config(ConfigFileLoader(config_path, config_profile)) as loader:
            loader.export(
                df[['table_uid','chk_dte','bq_cnt','pgsql_cnt','diff_cnt']],
                schema_name,
                table_name,
                index=False,  # Specifies whether to include index in exported table
                if_exists='append',  # Specify resolution policy if table name already exists
                unique_conflict_method='UPDATE',
                unique_constraints=['table_uid','chk_dte']
            )
        # test = df[df.diff_cnt.isnull()]
        # df = df.fillna(0)
        # pd.set_option('display.max_rows',None)
        
        app_message = {
            'text': f'''
사업장         : {corp_cd}
알람 발생 일시  : {datetime.now(timezone('Asia/Seoul'))}                
            '''
        }
        chk_nodata = True
        for idx, row in df.iterrows():
            bq_dataset_nm = row['bq_dataset_nm']
            bq_table_nm = row['bq_table_nm']
            table_uid = row['table_uid']
            chk_dte = row['chk_dte']
            diff_cnt = row['diff_cnt']
            if (diff_cnt< -10) | (diff_cnt>10000):
                table_uid=row['table_uid']
                message = f'''
===========================
Bigquery Dataset:{bq_dataset_nm}
Bigquery Table:{bq_table_nm}
Table Uid:{table_uid}
체크한날짜:{chk_dte}
개수차이(BQ-PgSQL):{diff_cnt}
            '''
                app_message['text']=app_message['text']+message
                chk_nodata = False
        if chk_nodata:
            message = f'''
설정범위를 벗어난 데이터가 없습니다.
===========================
            '''
            app_message['text']=app_message['text']+message
        # print(app_message)        
        send_webhook(kwargs['web_h_url'], app_message)