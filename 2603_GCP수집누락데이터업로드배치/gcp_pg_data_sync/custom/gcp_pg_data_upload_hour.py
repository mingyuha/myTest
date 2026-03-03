from mage_ai.settings.repo import get_repo_path
from mage_ai.io.config import ConfigFileLoader, ConfigKey
from mage_ai.io.bigquery import BigQuery
from mage_ai.io.postgres import Postgres
from google.cloud import bigquery
from google.oauth2 import service_account
from pytz import timezone
from os import path
import datetime
import pandas as pd

def get_delete_query(bq_table_id, st_dt, end_dt):

    sql_query = f"""
        delete
        from 
            {bq_table_id}
        where
            opc_srv_dtm >= datetime(timestamp '{st_dt}', 'Asia/Seoul') and opc_srv_dtm < datetime(timestamp '{end_dt}', 'Asia/Seoul') 
        ;
    """
    return sql_query

def get_bq_cnt_query(bq_table_id, st_dt, end_dt):

    sql_query = f"""
        select count(*) as cnt
        from 
            {bq_table_id}
        where
            opc_srv_dtm >= datetime(timestamp '{st_dt}', 'Asia/Seoul') and opc_srv_dtm < datetime(timestamp '{end_dt}', 'Asia/Seoul') 
        ;
    """

    return sql_query

def get_search_pg_query(schema, table, table_postfix, st_dt, end_dt):

    sql_query = f"""
        select 
            tag as disp_tag_nm,	
            keptag as std_tag_nm,
            srvtime as opc_srv_dtm,	
            srctime as opc_src_dtm,	
            nifitime as nifi_rcptn_dtm,	
            cast(status as varchar) as opc_status_cd,
            value as tag_value,	
            coltype as clct_type_cd,
            valtype as tag_value_type_cd
        from 
            {schema}.{table}{table_postfix}
        where 
            srvtime >= '{st_dt}' and srvtime < '{end_dt}'
        ;
    """
    return sql_query

def get_search_pg_without_keptag_query(schema, table, table_postfix, st_dt, end_dt):

    sql_query = f"""
        select 
            tag as disp_tag_nm,	
            '' as std_tag_nm,
            srvtime as opc_srv_dtm,	
            srctime as opc_src_dtm,	
            nifitime as nifi_rcptn_dtm,	
            cast(status as varchar) as opc_status_cd,
            value as tag_value,	
            coltype as clct_type_cd,
            valtype as tag_value_type_cd
        from 
            {schema}.{table}{table_postfix}
        where 
            srvtime >= '{st_dt}' and srvtime < '{end_dt}'
        ;
    """
    return sql_query

@custom
def transform_custom(*args, **kwargs) -> None:

    _DATETIME_FIELDS = ['opc_srv_dtm', 'opc_src_dtm', 'nifi_rcptn_dtm']
    _EXIST_KEPTAG = ['cc3_tag','fg1_tag','fg2_tag','fp_tag','lbr_tag','pk_tag','lf_tag','sp_tag']
    _NOTEXIST_KEPTAG= ['cs2_tag','sm2_tag','srl_tag']
    # _STR_TABLES = ['eaf1_everguard_plcstr','eaf2_everguard_plcstr','eaf1_plcstr','eaf2_plcstr','all_everguard_plcstr','al_all_everguard_plcstr','bl_all_everguard_plcstr','cl_all_everguard_plcstr','dl_all_everguard_plcstr']

    corp_cd = kwargs['corp_cd']
    
    pg_config_path = path.join(get_repo_path(), 'io_config.yaml')
    pg_config_profile = f'{corp_cd}_stats'
    pg_config = ConfigFileLoader(pg_config_path, pg_config_profile)
    conf = {
        'dbname': pg_config[ConfigKey.POSTGRES_DBNAME], 
        'user': pg_config[ConfigKey.POSTGRES_USER],
        'password': pg_config[ConfigKey.POSTGRES_PASSWORD],
        'host': pg_config[ConfigKey.POSTGRES_HOST],
        'port': pg_config[ConfigKey.POSTGRES_PORT],
        'verbose': False
    }

    bq_config_path = path.join(get_repo_path(), 'io_config.yaml')
    bq_config_profile = f'{corp_cd}_bigquery'

    key_path = f'/home/src/DataForge/bigquery-all-dataset-{corp_cd}.json'
    credentials = service_account.Credentials.from_service_account_file(
        key_path,
        scopes=['https://www.googleapis.com/auth/cloud-platform']
    )
    client = bigquery.Client(credentials=credentials)

    # 업로드 대상 선정 
    df_chk_history = args[0][0]

    # print(df_chk_history)
    
    df_result = pd.DataFrame(columns=['table_uid','chk_dte','bq_cnt','after_work_bq_cnt','pgsql_cnt','diff_cnt','work_yn'])

    for idx, row in df_chk_history.iterrows():

        # 테스트 
        # if idx == 1:
        #     break
        
        
        chk_dte = row['chk_dte']
        bq_project_nm = row['bq_project_nm']
        bq_dataset_nm = row['bq_dataset_nm']
        bq_table_nm = row['bq_table_nm']
        bq_dataset_nm_list = bq_dataset_nm.split('_') 
        bq_dataset_prefix = bq_dataset_nm_list[0]
        bq_cnt = row['bq_cnt']
        pgsql_cnt = row['pgsql_cnt']
        diff_cnt = row['diff_cnt']
        
        bq_table_id = f'{bq_project_nm}.{bq_dataset_nm}.{bq_table_nm}'
        src_bucket_nm = f'dataforge-seah{corp_cd}-{bq_dataset_prefix}-collect-plc'

        pgsql_db_nm = row['pgsql_db_nm']
        pgsql_schema_nm = row['pgsql_schema_nm']
        pgsql_table_nm = row['pgsql_table_nm']
        db_ip = row['ip']
        db_port = row['port']
        pgsql_table_postfix = ''        
        # pgsql_table_postfix = '_' + pgsql_table_postfix
        

        conf['dbname'] = pgsql_db_nm
        conf['host'] = db_ip
        conf['port'] = db_port

        #1. pgsql -> bigquery 데이터 업로드 

        start_dt = chk_dte
        end_dt = start_dt + datetime.timedelta(hours=1)
        print(start_dt, end_dt, pgsql_db_nm, pgsql_schema_nm, pgsql_table_nm, row['table_uid'])

        if True:
            
            # 파티션이 분리된 테이블의 경우 예외처리 해야 함 
            r_arr = {
                'cc3plc_o_s_plc':'o_s_plc_202501_5',
                'cc3plc_p_r_plc':'p_r_plc_202501_5',
                'cc3plc_sr2_roll_plc':'sr2_roll_plc_202501_5',
                'cc3plc_trt_plc':'trt_plc_202501_5',
                'cs2plc_bt_std4_plc':'bt_std4_plc_202501_5',
                'cs2plc_bt_std6_plc':'bt_std6_plc_202501_5',
                'fg2plc_manipulator_100t_plc':'manipulator_100t_plc_202501_5',
                'fg2plc_no_1_2_3_furnace_plc':'no_1_2_3_furnace_plc_202501_24',
                'fg2plc_no_4_5_furnace_plc':'no_4_5_furnace_plc_202501_5',
                'fg2plc_press_9000t_plc':'press_9000t_plc_202501_5',
                'lbrplc_batch_no1_plc':'batch_no1_plc_202501_5',
                'lbrplc_batch_no2_plc':'batch_no2_plc_202501_5',
                'lbrplc_batch_no3_plc':'batch_no3_plc_202501_5',
                'lbrplc_batch_no4_plc':'batch_no4_plc_202501_5',
                'lbrplc_batch_no5_plc':'batch_no5_plc_202501_5',
                'lbrplc_batch_no7_plc':'batch_no7_plc_202501_5',
                'lbrplc_sbm_plc':'sbm_plc_202501_5',
                'sm2plc_eaf_plc':'eaf_plc_202501_5',
                'sm2plc_etc_plc':'etc_plc_202501_5',
                'sm3plc_vod_plc':'vod_plc_202501_5',
                'spplc_hotheating_vheater_plc':'hotheating_vheater_plc_202501_5',
                'srlplc_furnace_plc':'furnace_plc_202501_24',
                'srlplc_roughmill_plc':'roughmill_plc_202501_5',
                'srlplc_rsb_plc':'rsb_plc_202501_5'
            }

            schema_tb = pgsql_schema_nm + '_' + pgsql_table_nm
            # pgsql_table_nm_query = r_arr.get(schema_tb,pgsql_table_nm)            
            pgsql_table_nm_query = pgsql_table_nm
            
            if bq_dataset_nm in _EXIST_KEPTAG:
                pg_query = get_search_pg_query(pgsql_schema_nm, pgsql_table_nm_query, pgsql_table_postfix, start_dt, end_dt)                
            else:
                pg_query = get_search_pg_without_keptag_query(pgsql_schema_nm, pgsql_table_nm_query, pgsql_table_postfix, start_dt, end_dt)
            
            pg_result = pd.DataFrame()
            with Postgres(**conf) as loader:
                pg_result = loader.load(pg_query)  

            print(pg_query)
            
            if not pg_result.empty:
                
                #시간 컬럼 변경 
                for f in _DATETIME_FIELDS:
                    if f in pg_result.columns:
                        pg_result[f] = pd.to_datetime(pg_result[f], unit='ms', utc=True).dt.tz_convert('Asia/Seoul').dt.tz_localize(None)
                pg_result['opc_srv_ts'] = pg_result['opc_srv_dtm'].dt.tz_localize('Asia/Seoul')
                #값 컬럼 변경 
                # if pgsql_table_nm not in _STR_TABLES:
                pg_result['tag_value'] = pg_result['tag_value'].round(decimals=9)
                # print(pg_result)

                ########################################################
                #1. 해당 시간대 데이터 삭제 
                bq_query = get_delete_query(bq_table_id,start_dt,end_dt)
                query_job = client.query(bq_query)                
                ########################################################
                #2. 데이터 입력 
                BigQuery.with_config(ConfigFileLoader(bq_config_path, bq_config_profile)).export(
                    pg_result,
                    bq_table_id,
                    if_exists='append',  # Specify resolution policy if table name already exists
                    overwrite_types=None, # Specify the column types to overwrite in a dictionary
                    verbose=False
                )            
                ########################################################
                #3. 결과 count 조회 
                bq_query = get_bq_cnt_query(bq_table_id,start_dt,end_dt)
                query_job = client.query(bq_query)                
                out_results = query_job.result().to_dataframe()    
                after_work_bq_cnt = out_results.loc[0,'cnt'].astype(int)

                ########################################################
                #4. 결과 입력 
                diff_cnt = after_work_bq_cnt - pgsql_cnt
                print(bq_dataset_nm, bq_table_nm, f'after_work_bq_cnt:{after_work_bq_cnt}, pgsql_cnt:{pgsql_cnt}, diff_cnt:{diff_cnt}')
                df_result.loc[0] = [row['table_uid'], chk_dte, bq_cnt,after_work_bq_cnt,pgsql_cnt,diff_cnt,'Y']
                with Postgres.with_config(ConfigFileLoader(pg_config_path, pg_config_profile)) as loader:
                    loader.export(
                        df_result,
                        'comm_df',
                        'gcp_pg_upload_error_hourly_ht',
                        index=False,  # Specifies whether to include index in exported table
                        if_exists='append',  # Specify resolution policy if table name already exists
                        unique_conflict_method='UPDATE',
                        unique_constraints=['table_uid','chk_dte'],
                        verbose=False
                    )
                

    print('end gcp_pg_data_upload_hour_data')