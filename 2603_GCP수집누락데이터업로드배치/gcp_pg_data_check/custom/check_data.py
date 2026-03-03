from mage_ai.settings.repo import get_repo_path
from mage_ai.io.config import ConfigFileLoader, ConfigKey
from mage_ai.io.bigquery import BigQuery
from mage_ai.io.postgres import Postgres
from pytz import timezone
from os import path
import datetime
import pandas as pd
import time

if 'custom' not in globals():
    from mage_ai.data_preparation.decorators import custom

def get_search_bq_query(project, dataset, table, column, st_dt):

    sql_query = f"""
        SELECT 
            ifnull(format_date('%F',a.chk_dte), '{st_dt}') as chk_dte, count(a.chk_dte) as bq_cnt
        FROM
        (
        WITH oq AS (
            SELECT
            date_trunc(cast({column} as datetime), day) as chk_dte
            FROM
            `{project}`.{dataset}.{table}
            WHERE
            date_trunc(cast({column} as datetime), day) = date_trunc(parse_date('%Y-%m-%d','{st_dt}'),day)
        )
        SELECT * FROM oq
        UNION ALL
        SELECT null as chk_dte FROM `{project}`.comm_gcp.default_cnt WHERE (SELECT count(*) FROM oq)=0
        ) a
        GROUP BY a.chk_dte
        ORDER BY a.chk_dte
    """

    return sql_query

def get_search_pg_query(schema, table, column, st_dt):

    sql_query = f"""
        select 
            to_char(a.chk_dte, 'YYYY-MM-DD') as chk_dte, count(a.chk_dte) as pgsql_cnt 
        from ( 
            select 
                date_trunc('day' , {column}) as chk_dte
            from 
                {schema}.{table}
            where 
                date_trunc('day' , {column}) = to_timestamp('{st_dt}', 'YYYY-MM-DD')::timestamp at time zone 'Asia/Seoul'
        ) a  
        group by a.chk_dte
        order by a.chk_dte
        ;
    """

    return sql_query

def get_search_pg_plc_query(st_dt):

    sql_query = f"""
        select 
            db_name as pgsql_db_nm, schema_name as pgsql_schema_nm, table_name as pgsql_table_nm,'{st_dt}' as chk_dte, sum(collect_count) as pgsql_cnt
        from 
            tags.stats
        where 
            date_trunc('day' , tag_srvtime) = to_timestamp('{st_dt}', 'YYYY-MM-DD')::timestamp at time zone 'Asia/Seoul'
        group by pgsql_db_nm , pgsql_schema_nm, pgsql_table_nm , chk_dte
        order by pgsql_db_nm , pgsql_schema_nm , pgsql_table_nm 
        ;
    """

    return sql_query

@custom
def transform_custom(*args, **kwargs):
    """
    args: The output from any upstream parent blocks (if applicable)

    Returns:
        Anything (e.g. data frame, dictionary, array, int, str, etc.)
    """
    # Specify your custom logic here
    corp_cd = kwargs['corp_cd']
    #Bigquery, Postgresql config 설정 
    bq_config_path = path.join(get_repo_path(), 'io_config.yaml')
    bq_config_profile = f'{corp_cd}_bigquery'

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

    # start_dt, end_dt 설정
    KST = timezone("Asia/Seoul")

    today = datetime.datetime.now(tz=KST)
    # today_str = today.strftime("%Y-%m-%d")
    # today_str = '2024-10-15'
    #월요일인 경우 금,토,일 확인 필요
    # if today.weekday() == 0:
    #     startday = today - datetime.timedelta(days=3)
    # else:
    #     startday = today - datetime.timedelta(days=1)
    startday = today - datetime.timedelta(days=1)
    start_dt = startday.strftime("%Y-%m-%d")
    # endday = today - datetime.timedelta(days=1)
    # end_dt = endday.strftime("%Y-%m-%d")

    # plc 데이터는 기 수집되고 있던 테이블에서 갯수를 별도로 가져온다 
    df_plc = pd.DataFrame()
    pg_query = get_search_pg_plc_query(start_dt)
    
    with Postgres(**conf) as loader:
        df_plc = loader.load(pg_query)        

    df_pre = args[0]
    df_result = pd.DataFrame()

    # 일 데이터 수 차이 < -10 것 중 시간별 을 별도로 정리하는데 전체 개수가 10까지만 정리 
    # 전일 어떤 장애로 인해 데이터 전체 시간별 비교가 될 수 있으므로 최소한의 작업 개수 등록 
    total_check_limit = 0
    
    for idx, row in df_pre.iterrows():

        table_uid = row['table_uid']
        bq_project_nm = row['bq_project_nm']
        bq_dataset_nm = row['bq_dataset_nm']
        bq_table_nm = row['bq_table_nm']
        bq_prtn_column_nm = row['bq_prtn_column_nm']
        pgsql_db_nm = row['pgsql_db_nm']
        pgsql_schema_nm = row['pgsql_schema_nm']
        pgsql_table_nm = row['pgsql_table_nm']
        pgsql_dtm_column_nm = row['pgsql_dtm_column_nm']

        # 테스트 
        # if idx>4:
        #     break
        # if bq_table_nm != 'hotextrusion_650tpress_tag_mt':
        #     continue
            

        print(idx, pgsql_schema_nm, pgsql_table_nm)
        bq_query = get_search_bq_query(bq_project_nm, bq_dataset_nm, bq_table_nm, bq_prtn_column_nm, start_dt)
        bq_result = BigQuery.with_config(ConfigFileLoader(bq_config_path, bq_config_profile)).load(bq_query, verbose=False)
        pg_result = pd.DataFrame()
        
        if pgsql_table_nm.endswith('plc'):
            pg_result = df_plc.loc[(df_plc.pgsql_db_nm==pgsql_db_nm) & (df_plc.pgsql_schema_nm==pgsql_schema_nm) &(df_plc.pgsql_table_nm==pgsql_table_nm)]
            pg_result = pg_result[['chk_dte','pgsql_cnt']]
            df_join = pd.merge(bq_result, pg_result, how='left', on=['chk_dte'])            
        else:
            pg_query = get_search_pg_query(pgsql_schema_nm, pgsql_table_nm, pgsql_dtm_column_nm, start_dt)
            conf['dbname'] = pgsql_db_nm
            conf['host'] = row['ip']
            conf['port'] = row['port']
            with Postgres(**conf) as loader:
                pg_result = loader.load(pg_query)        
            df_join = pd.merge(bq_result, pg_result, how='left', on=['chk_dte'])
        
        df_join.fillna(0, inplace=True)

        df_join['table_uid'] = table_uid
        df_join['bq_dataset_nm'] = bq_dataset_nm
        df_join['bq_table_nm'] = bq_table_nm
        df_join['pgsql_db_nm'] = pgsql_db_nm
        df_join['pgsql_schema_nm'] = pgsql_schema_nm
        df_join['pgsql_table_nm'] = pgsql_table_nm        
        df_join['host'] = row['ip']
        df_join['port'] = row['port']
        df_join['diff_cnt'] = df_join['bq_cnt'] - df_join['pgsql_cnt']
        df_result = df_result.append(df_join, ignore_index=True)
        time.sleep(0.5)

    df_result = df_result.astype({'bq_cnt':'int','pgsql_cnt':'int','diff_cnt':'int'})

    return df_result