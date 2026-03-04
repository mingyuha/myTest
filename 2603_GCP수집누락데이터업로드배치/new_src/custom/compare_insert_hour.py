from mage_ai.settings.repo import get_repo_path
from mage_ai.io.config import ConfigFileLoader, ConfigKey
from mage_ai.io.bigquery import BigQuery
from mage_ai.io.postgres import Postgres
from pytz import timezone
from os import path
import datetime
import pandas as pd

if 'custom' not in globals():
    from mage_ai.data_preparation.decorators import custom


def get_bq_hour_query(project, dataset, table, column, chk_dte):
    """해당 날짜 전체 시간별 BQ 건수 1회 조회 (비용 절감)"""
    sql_query = f"""
        SELECT
            format_datetime('%Y-%m-%d %H:00:00', datetime_trunc(cast({column} as datetime), hour)) as chk_dte,
            count(*) as bq_cnt
        FROM
            `{project}`.{dataset}.{table}
        WHERE
            date_trunc(cast({column} as datetime), day) = date_trunc(datetime('{chk_dte}'), day)
        GROUP BY chk_dte
        ORDER BY chk_dte
    """
    return sql_query


def get_pg_hour_query(schema, table, column, chk_dte):
    """해당 날짜 전체 시간별 PG 건수 조회"""
    sql_query = f"""
        select
            to_char(date_trunc('hour', {column}), 'YYYY-MM-DD HH24:00:00') as chk_dte,
            count(*) as pgsql_cnt
        from
            {schema}.{table}
        where
            date_trunc('day', {column}) = to_timestamp('{chk_dte}', 'YYYY-MM-DD')::timestamp at time zone 'Asia/Seoul'
        group by chk_dte
        order by chk_dte
        ;
    """
    return sql_query


def get_pg_plc_hour_query(db_nm, schema_nm, table_nm, chk_dte):
    """plc 테이블: tags.stats_hour 에서 시간별 건수 조회"""
    sql_query = f"""
        select
            to_char(date_trunc('hour', start_range), 'YYYY-MM-DD HH24:00:00') as chk_dte,
            sum(collect_count) as pgsql_cnt
        from
            tags.stats_hour
        where
            db_name = '{db_nm}'
            and schema_name = '{schema_nm}'
            and table_name = '{table_nm}'
            and date_trunc('day', start_range) = to_timestamp('{chk_dte}', 'YYYY-MM-DD')::timestamp at time zone 'Asia/Seoul'
        group by chk_dte
        order by chk_dte
        ;
    """
    return sql_query


@custom
def transform_custom(*args, **kwargs):
    """
    블록1(get_daily_targets) 결과 대상으로 날짜별 시간별 BQ/PG 건수 비교 후
    diff_cnt < 0 인 시간대를 gcp_pg_upload_error_hourly_ht 에 UPSERT
    """
    corp_cd = kwargs['corp_cd']

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

    df_targets = args[0]

    if df_targets.empty:
        print("처리 대상 없음 - 종료")
        return pd.DataFrame()

    df_result = pd.DataFrame()
    total = len(df_targets)

    for idx, row in df_targets.iterrows():

        table_uid       = row['table_uid']
        chk_dte         = row['chk_dte']
        bq_project_nm   = row['bq_project_nm']
        bq_dataset_nm   = row['bq_dataset_nm']
        bq_table_nm     = row['bq_table_nm']
        bq_prtn_col     = row['bq_prtn_column_nm']
        pgsql_db_nm     = row['pgsql_db_nm']
        pgsql_schema_nm = row['pgsql_schema_nm']
        pgsql_table_nm  = row['pgsql_table_nm']
        pgsql_dtm_col   = row['pgsql_dtm_column_nm']

        print(f"\n[{idx+1}/{total}] {pgsql_schema_nm}.{pgsql_table_nm} / {chk_dte}")

        # BQ 시간별 건수 1회 조회
        bq_query = get_bq_hour_query(bq_project_nm, bq_dataset_nm, bq_table_nm, bq_prtn_col, chk_dte)
        df_bq = BigQuery.with_config(
            ConfigFileLoader(bq_config_path, bq_config_profile)
        ).load(bq_query, verbose=False)
        print(f"  BQ 조회: {len(df_bq)}개 시간대")

        # PG 시간별 건수 조회
        df_pg = pd.DataFrame()
        if pgsql_table_nm.endswith('plc'):
            pg_query = get_pg_plc_hour_query(pgsql_db_nm, pgsql_schema_nm, pgsql_table_nm, chk_dte)
            with Postgres(**conf) as loader:
                df_pg = loader.load(pg_query)
        else:
            conf['dbname'] = pgsql_db_nm
            conf['host']   = row['ip']
            conf['port']   = row['port']
            pg_query = get_pg_hour_query(pgsql_schema_nm, pgsql_table_nm, pgsql_dtm_col, chk_dte)
            with Postgres(**conf) as loader:
                df_pg = loader.load(pg_query)
        print(f"  PG 조회: {len(df_pg)}개 시간대")

        # 전체 24시간 생성 후 BQ/PG 결과 병합
        hour_list = pd.date_range(
            start=f'{chk_dte} 00:00:00',
            end=f'{chk_dte} 23:00:00',
            freq='h'
        ).strftime('%Y-%m-%d %H:00:00').tolist()

        df_hours = pd.DataFrame({'chk_dte': hour_list})
        df_join = df_hours.merge(df_bq, on='chk_dte', how='left')
        df_join = df_join.merge(df_pg, on='chk_dte', how='left')
        df_join.fillna(0, inplace=True)
        df_join['bq_cnt']    = df_join['bq_cnt'].astype(int)
        df_join['pgsql_cnt'] = df_join['pgsql_cnt'].astype(int)
        df_join['diff_cnt']  = df_join['bq_cnt'] - df_join['pgsql_cnt']

        # diff_cnt < 0 인 시간대만 추출
        df_missing = df_join[df_join['diff_cnt'] < 0].copy()
        df_missing['table_uid']       = table_uid
        df_missing['bq_dataset_nm']   = bq_dataset_nm
        df_missing['bq_table_nm']     = bq_table_nm
        df_missing['pgsql_db_nm']     = pgsql_db_nm
        df_missing['pgsql_schema_nm'] = pgsql_schema_nm
        df_missing['pgsql_table_nm']  = pgsql_table_nm
        df_missing['after_work_bq_cnt'] = 0
        df_missing['work_yn']         = 'N'

        print(f"  누락 시간대: {len(df_missing)}개")

        if not df_missing.empty:
            df_insert = df_missing[['table_uid', 'chk_dte', 'bq_cnt', 'after_work_bq_cnt', 'pgsql_cnt', 'diff_cnt', 'work_yn']]

            with Postgres.with_config(ConfigFileLoader(pg_config_path, pg_config_profile)) as loader:
                loader.export(
                    df_insert,
                    'comm_df',
                    'gcp_pg_upload_error_hourly_ht',
                    index=False,
                    if_exists='append',
                    unique_conflict_method='UPSERT',
                    unique_constraints=['table_uid', 'chk_dte'],
                    verbose=False
                )
            df_result = pd.concat([df_result, df_missing], ignore_index=True)

    print(f"\n시간별 비교 완료 - 총 누락 시간대: {len(df_result)}개")
    return df_result
