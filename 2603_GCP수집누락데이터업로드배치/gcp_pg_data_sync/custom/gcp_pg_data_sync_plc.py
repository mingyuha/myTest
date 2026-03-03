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

def get_delete_query(bq_table_id, st_dt, end_dt, date_col):
    sql_query = f"""
        delete
        from 
            {bq_table_id}
        where
            {date_col} >= datetime('{st_dt}') and {date_col} < datetime('{end_dt}') 
        ;
    """
    return sql_query

def get_bq_cnt_query(bq_table_id, chk_dt, date_col):
    sql_query = f"""
        select count(*) as cnt
        from 
            {bq_table_id}
        where
            date_trunc({date_col}, day) = datetime_trunc(datetime('{chk_dt}'), day) 
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

def get_search_pg_tms_query(schema, table, table_postfix, st_dt, end_dt):

    sql_query = f"""
        select 
            tag,	
            tmstime,	            
            value
        from 
            {schema}.{table}{table_postfix}
        where 
            tmstime >= '{st_dt}' and tmstime < '{end_dt}'
        ;
    """
    return sql_query

@custom
def transform_custom(*args, **kwargs) -> None:

    _DATETIME_FIELDS = ['opc_srv_dtm', 'opc_src_dtm', 'nifi_rcptn_dtm', 'tmstime']
    _EXIST_KEPTAG = ['cc3_tag','fg1_tag','fg2_tag','fp_tag','lbr_tag','pk_tag','lf_tag','sp_tag']
    _NOTEXIST_KEPTAG= ['cs2_tag','sm2_tag','srl_tag']
    # _STR_TABLES = ['eaf1_everguard_plcstr','eaf2_everguard_plcstr','eaf1_plcstr','eaf2_plcstr','all_everguard_plcstr','al_all_everguard_plcstr','bl_all_everguard_plcstr','cl_all_everguard_plcstr','dl_all_everguard_plcstr']

    # _PERMIT_TIMES = ['02:','03:','04:'] #,'11:','12:','13:']
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
        # if idx == 9:
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
        start_dt_str = chk_dte
        end_dt = datetime.datetime.strptime(start_dt_str,'%Y-%m-%d') + datetime.timedelta(1)
        end_dt_str = end_dt.strftime('%Y-%m-%d')

        date_list = pd.date_range(start_dt_str, end_dt_str, freq='h', tz='Asia/Seoul').strftime("%Y-%m-%d %H:%M:%S").tolist()
        # table_postfix_list = pd.date_range(start_dt_str, end_dt_str, freq='h', tz='Asia/Seoul').strftime("%Y%m").tolist()
        
        last_idx = len(date_list) - 1

        date_col_str = 'opc_srv_dtm'
        
        for idx, t in enumerate(date_list):
            st_dt = t
            end_dt = t
            if last_idx != idx:                        
                end_dt = date_list[idx+1]
            else:
                break

            # 2025.06.14 임시로 2,3,4 시 데이터만 추가 
            # to_go = False 
            # for t in _PERMIT_TIMES:
            #     if t in st_dt:
            #         to_go = True
            # if not to_go:
            #     continue

            print(st_dt, end_dt, pgsql_table_nm)
            if True:
                if bq_dataset_nm in _EXIST_KEPTAG:
                    pg_query = get_search_pg_query(pgsql_schema_nm, pgsql_table_nm, pgsql_table_postfix, st_dt, end_dt)                
                else:
                    pg_query = get_search_pg_without_keptag_query(pgsql_schema_nm, pgsql_table_nm, pgsql_table_postfix, st_dt, end_dt)
                #tms 처리    
                if 'tms_' in bq_table_nm:
                    pg_query = get_search_pg_tms_query(pgsql_schema_nm, pgsql_table_nm, pgsql_table_postfix, st_dt, end_dt)
                    date_col_str = 'tmstime'
                
                          
                pg_result = pd.DataFrame()
                with Postgres(**conf) as loader:
                    pg_result = loader.load(pg_query)  

                if not pg_result.empty:
                    
                    #시간 컬럼 변경 
                    for f in _DATETIME_FIELDS:
                        if f in pg_result.columns:
                            pg_result[f] = pd.to_datetime(pg_result[f], unit='ms', utc=True).dt.tz_convert('Asia/Seoul').dt.tz_localize(None)
                    if 'tms_' not in bq_table_nm:
                        pg_result['opc_srv_ts'] = pg_result['opc_srv_dtm'].dt.tz_localize('Asia/Seoul')

                    #값 컬럼 변경 
                    if 'tms_' not in bq_table_nm and not pgsql_table_nm.endswith('str') :
                        pg_result['tag_value'] = pg_result['tag_value'].round(decimals=9)

                    ########################################################
                    #1. 해당 시간대 데이터 삭제 
                    bq_query = get_delete_query(bq_table_id,st_dt,end_dt,date_col_str)
                    query_job = client.query(bq_query)
                    # out_results = query_job.result().to_dataframe()    
                    # print(query_job)        
                    # print(f"{deleted_count}개의 행이 삭제되었습니다.")
                    ########################################################
                    #2. 데이터 입력 
                    BigQuery.with_config(ConfigFileLoader(bq_config_path, bq_config_profile)).export(
                        pg_result,
                        bq_table_id,
                        if_exists='append',  # Specify resolution policy if table name already exists
                        overwrite_types=None, # Specify the column types to overwrite in a dictionary
                        verbose = False
                    )
        ########################################################
        #3. 결과 count 조회 
        bq_query = get_bq_cnt_query(bq_table_id,chk_dte,date_col_str)
        query_job = client.query(bq_query)
        out_results = query_job.result().to_dataframe()    
        after_work_bq_cnt = out_results.loc[0,'cnt'].astype(int)
        ########################################################
        diff_cnt = after_work_bq_cnt - pgsql_cnt
        print(bq_dataset_nm, bq_table_nm, f'after_work_bq_cnt:{after_work_bq_cnt}, pgsql_cnt:{pgsql_cnt}, diff_cnt:{diff_cnt}')
        df_result.loc[0] = [row['table_uid'], chk_dte, bq_cnt,after_work_bq_cnt,pgsql_cnt,diff_cnt,'Y']
        with Postgres.with_config(ConfigFileLoader(pg_config_path, pg_config_profile)) as loader:
            loader.export(
                df_result,
                'comm_df',
                'gcp_pg_table_chk_ht',
                index=False,  # Specifies whether to include index in exported table
                if_exists='append',  # Specify resolution policy if table name already exists
                unique_conflict_method='UPDATE',
                unique_constraints=['table_uid','chk_dte'],
                verebose=False
            )

    print('end gcp_pg_data_sync_plc')