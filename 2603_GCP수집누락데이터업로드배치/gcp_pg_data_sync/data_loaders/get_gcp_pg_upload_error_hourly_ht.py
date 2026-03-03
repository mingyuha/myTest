from mage_ai.settings.repo import get_repo_path
from mage_ai.io.config import ConfigFileLoader, ConfigKey
from mage_ai.io.postgres import Postgres
from os import path
from pytz import timezone
from os import path
import datetime
import pandas as pd

if 'data_loader' not in globals():
    from mage_ai.data_preparation.decorators import data_loader

def get_gcp_pg_table_chk_ht(chk_dt):
    sql_query = f"""
        select 
            ht.table_uid, 
            ht.chk_dte, 
            ht.diff_cnt , 
            ht.bq_cnt ,
            ht.pgsql_cnt , 
            ctm.bq_project_nm ,
            ctm.bq_dataset_nm , 
            ctm.bq_table_nm , 
            ctm.pgsql_db_nm ,
            ctm.pgsql_schema_nm ,
            ctm.pgsql_table_nm , 
            ctm.bq_prtn_column_nm , 
            ctm.pgsql_dtm_column_nm ,
            pdimm.access_ip as ip,
            pdimm.access_port as port
        from 
            comm_df.gcp_pg_upload_error_hourly_ht ht, comm_df.clct_table_mt ctm, comm_df.db_mt pdimm 
        where
            ht.diff_cnt < 0 and
            ht.table_uid = ctm.table_uid and
            ctm.pgsql_db_nm = pdimm.db_nm and
            chk_dte >= '{chk_dt}'
            and work_yn = 'N'
            and (bq_dataset_nm like '%_tag' or bq_table_nm like '%l2_mid_trk_mt')
        order by 
            ht.table_uid, ht.chk_dte
        ;
    """

    return sql_query

@data_loader
def load_data_from_postgres(*args, **kwargs):
    
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

    KST = timezone('Asia/Seoul')
    today = datetime.datetime.now(tz=KST)
    yesterday = today - datetime.timedelta(days=1)
    # chk_dt_str = yesterday.strftime('%Y-%m-%d 00:00:00')
    chk_dt_str = '2026-01-21 00:00:00'

    # 업로드 대상 선정 
    df_chk_history = pd.DataFrame()
    pg_query = get_gcp_pg_table_chk_ht(chk_dt_str)
    with Postgres(**conf) as loader:
        df_chk_history = loader.load(pg_query)

    df_chk_plc = df_chk_history.loc[df_chk_history.bq_dataset_nm.str.contains('_tag')]
    df_chk_idtrk = df_chk_history.loc[df_chk_history.bq_table_nm.str.contains('l2_mid_trk_mt')]
    
    return [df_chk_plc, df_chk_idtrk]