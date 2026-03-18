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

if 'custom' not in globals():
    from mage_ai.data_preparation.decorators import custom

# -------------------------------------------------------------------------
# 선행 블록 데이터 없을 때 DB 직접 조회 기준일 설정
# None 이면 전일 0시(KST) 자동 계산, 수동 지정 시 아래 값을 변경
# 예: CHK_DT_OVERRIDE = '2026-03-01 00:00:00'
# -------------------------------------------------------------------------
CHK_DT_OVERRIDE = None


def get_gcp_pg_table_chk_ht(chk_dt):
    """gcp_pg_upload_error_hourly_ht 에서 미처리(work_yn='N') 누락 건 조회"""
    sql_query = f"""
        select
            ht.table_uid,
            ht.chk_dte,
            ht.diff_cnt,
            ht.bq_cnt,
            ht.pgsql_cnt,
            ctm.bq_project_nm,
            ctm.bq_dataset_nm,
            ctm.bq_table_nm,
            ctm.pgsql_db_nm,
            ctm.pgsql_schema_nm,
            ctm.pgsql_table_nm,
            ctm.bq_prtn_column_nm,
            ctm.pgsql_dtm_column_nm,
            pdimm.access_ip as ip,
            pdimm.access_port as port
        from
            comm_df.gcp_pg_upload_error_hourly_ht ht,
            comm_df.clct_table_mt ctm,
            comm_df.db_mt pdimm
        where
            ht.diff_cnt < 0
            and ht.table_uid = ctm.table_uid
            and ctm.pgsql_db_nm = pdimm.db_nm
            and chk_dte >= '{chk_dt}'
            and work_yn = 'N'
            and (bq_dataset_nm like '%_tag' or bq_table_nm like '%l2_mid_trk_mt')
        order by
            ht.table_uid, ht.chk_dte
        ;
    """
    return sql_query


def get_delete_query(bq_table_id, st_dt, end_dt, date_col):
    sql_query = f"""
        delete from {bq_table_id}
        where
            {date_col} >= datetime(timestamp '{st_dt}', 'Asia/Seoul')
            and {date_col} < datetime(timestamp '{end_dt}', 'Asia/Seoul')
        ;
    """
    return sql_query


def get_bq_cnt_query(bq_table_id, st_dt, end_dt, date_col):
    sql_query = f"""
        select count(*) as cnt
        from {bq_table_id}
        where
            {date_col} >= datetime(timestamp '{st_dt}', 'Asia/Seoul')
            and {date_col} < datetime(timestamp '{end_dt}', 'Asia/Seoul')
        ;
    """
    return sql_query


def get_pg_tag_query(schema, table, st_dt, end_dt, has_keptag):
    if has_keptag:
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
            from {schema}.{table}
            where srvtime >= '{st_dt}' and srvtime < '{end_dt}'
            ;
        """
    else:
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
            from {schema}.{table}
            where srvtime >= '{st_dt}' and srvtime < '{end_dt}'
            ;
        """
    return sql_query


def get_pg_tms_query(schema, table, st_dt, end_dt):
    sql_query = f"""
        select tag, tmstime, value
        from {schema}.{table}
        where tmstime >= '{st_dt}' and tmstime < '{end_dt}'
        ;
    """
    return sql_query


@custom
def transform_custom(*args, **kwargs):
    """
    블록2(compare_insert_hour) 결과 기반으로 누락 시간대 BQ 재업로드
    1. BQ 해당 시간대 DELETE
    2. PG 해당 시간대 데이터 조회
    3. BQ INSERT
    4. BQ 건수 재확인 → after_work_bq_cnt
    5. gcp_pg_upload_error_hourly_ht work_yn='Y' 업데이트
    """
    _EXIST_KEPTAG = ['cc3_tag', 'fg1_tag', 'fg2_tag', 'fp_tag', 'lbr_tag', 'pk_tag', 'lf_tag', 'sp_tag']
    _DATETIME_FIELDS = ['opc_srv_dtm', 'opc_src_dtm', 'nifi_rcptn_dtm']

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

    df_missing = args[0]
    if isinstance(df_missing, list):
        df_missing = df_missing[0] if df_missing else pd.DataFrame()

    _RESULT_COLUMNS = [
        'table_uid', 'chk_dte', 'bq_project_nm', 'bq_dataset_nm', 'bq_table_nm',
        'bq_prtn_col', 'pgsql_db_nm', 'pgsql_schema_nm', 'pgsql_table_nm'
    ]

    if df_missing.empty:
        print("선행 블록 데이터 없음 - DB에서 직접 조회")
        KST = timezone('Asia/Seoul')
        if CHK_DT_OVERRIDE is not None:
            chk_dt_str = CHK_DT_OVERRIDE
        else:
            yesterday = datetime.datetime.now(tz=KST) - datetime.timedelta(days=1)
            chk_dt_str = yesterday.strftime('%Y-%m-%d 00:00:00')
        print(f"  기준일: {chk_dt_str}")

        pg_query = get_gcp_pg_table_chk_ht(chk_dt_str)
        with Postgres.with_config(ConfigFileLoader(pg_config_path, pg_config_profile)) as loader:
            df_missing = loader.load(pg_query)

        if df_missing.empty:
            print("DB 조회 결과도 없음 - 종료")
            return pd.DataFrame(columns=_RESULT_COLUMNS)

        print(f"  DB 조회: {len(df_missing)}건")

    df_done = pd.DataFrame(columns=_RESULT_COLUMNS)
    total = len(df_missing)

    for idx, row in df_missing.iterrows():

        table_uid       = row['table_uid']
        chk_dte         = row['chk_dte']  # 'YYYY-MM-DD HH:00:00'
        bq_dataset_nm   = row['bq_dataset_nm']
        bq_table_nm     = row['bq_table_nm']
        pgsql_db_nm     = row['pgsql_db_nm']
        pgsql_schema_nm = row['pgsql_schema_nm']
        pgsql_table_nm  = row['pgsql_table_nm']
        bq_project_nm   = row['bq_project_nm']
        bq_prtn_col     = row['bq_prtn_column_nm']
        bq_cnt          = row['bq_cnt']
        pgsql_cnt       = row['pgsql_cnt']

        bq_table_id = f'{bq_project_nm}.{bq_dataset_nm}.{bq_table_nm}'

        # 해당 시간대 범위 계산
        st_dt = chk_dte
        end_dt = (datetime.datetime.strptime(chk_dte, '%Y-%m-%d %H:00:00') + datetime.timedelta(hours=1)).strftime('%Y-%m-%d %H:00:00')

        conf['dbname'] = pgsql_db_nm
        conf['host']   = row['ip']
        conf['port']   = row['port']

        print(f"\n[{idx+1}/{total}] {pgsql_schema_nm}.{pgsql_table_nm} / {st_dt} ~ {end_dt}")

        # tms 여부 판단
        is_tms = 'tms_' in bq_table_nm
        date_col = 'tmstime' if is_tms else 'opc_srv_dtm'
        has_keptag = bq_dataset_nm in _EXIST_KEPTAG

        # PG 데이터 조회
        if is_tms:
            pg_query = get_pg_tms_query(pgsql_schema_nm, pgsql_table_nm, st_dt, end_dt)
        else:
            pg_query = get_pg_tag_query(pgsql_schema_nm, pgsql_table_nm, st_dt, end_dt, has_keptag)

        pg_result = pd.DataFrame()
        with Postgres(**conf) as loader:
            pg_result = loader.load(pg_query)

        if pg_result.empty:
            print(f"  PG 데이터 없음 - 스킵")
            continue

        print(f"  PG 조회: {len(pg_result)}건")

        # datetime 컬럼 변환
        for f in _DATETIME_FIELDS:
            if f in pg_result.columns:
                pg_result[f] = pd.to_datetime(pg_result[f], unit='ms', utc=True).dt.tz_convert('Asia/Seoul').dt.tz_localize(None)
        if not is_tms:
            pg_result['opc_srv_ts'] = pg_result['opc_srv_dtm'].dt.tz_localize('Asia/Seoul')
            if not pgsql_table_nm.endswith('str'):
                pg_result['tag_value'] = pg_result['tag_value'].round(decimals=9)

        # 1. BQ 해당 시간대 DELETE
        bq_delete = get_delete_query(bq_table_id, st_dt, end_dt, date_col)
        try:
            client.query(bq_delete).result()  # 동기 처리 - DELETE 완료 보장
            print(f"  BQ DELETE 완료")
        except Exception as e:
            print(f"  BQ DELETE 실패 - 스킵: {e}")
            continue

        # 2. BQ INSERT
        try:
            BigQuery.with_config(ConfigFileLoader(bq_config_path, bq_config_profile)).export(
                pg_result,
                bq_table_id,
                if_exists='append',
                overwrite_types=None,
                verbose=False
            )
            print(f"  BQ INSERT 완료: {len(pg_result)}건")
        except Exception as e:
            print(f"  BQ INSERT 실패: {e}")
            print(f"  [경고] {bq_table_id} {st_dt} ~ {end_dt} DELETE 후 INSERT 실패 - 수동 복구 필요")
            continue

        # 3. BQ 건수 재확인
        bq_cnt_query = get_bq_cnt_query(bq_table_id, st_dt, end_dt, date_col)
        out = client.query(bq_cnt_query).result().to_dataframe()
        after_work_bq_cnt = int(out.loc[0, 'cnt'])
        diff_cnt = after_work_bq_cnt - pgsql_cnt
        print(f"  결과: after_bq={after_work_bq_cnt}, pg={pgsql_cnt}, diff={diff_cnt}")

        # 4. hourly_ht work_yn='Y' 업데이트
        df_upd = pd.DataFrame([{
            'table_uid': table_uid,
            'chk_dte': chk_dte,
            'bq_cnt': bq_cnt,
            'after_work_bq_cnt': after_work_bq_cnt,
            'pgsql_cnt': pgsql_cnt,
            'diff_cnt': diff_cnt,
            'work_yn': 'Y'
        }])
        with Postgres.with_config(ConfigFileLoader(pg_config_path, pg_config_profile)) as loader:
            loader.export(
                df_upd,
                'comm_df',
                'gcp_pg_upload_error_hourly_ht',
                index=False,
                if_exists='append',
                unique_conflict_method='UPDATE',
                unique_constraints=['table_uid', 'chk_dte'],
                verbose=False
            )

        # 완료 목록 누적 (블록4 GCS 백업용 - 날짜+테이블 정보)
        df_done = pd.concat([df_done, pd.DataFrame([{
            'table_uid':       table_uid,
            'chk_dte':         chk_dte[:10],  # 날짜만 (YYYY-MM-DD)
            'bq_project_nm':   bq_project_nm,
            'bq_dataset_nm':   bq_dataset_nm,
            'bq_table_nm':     bq_table_nm,
            'bq_prtn_col':     bq_prtn_col,
            'pgsql_db_nm':     pgsql_db_nm,
            'pgsql_schema_nm': pgsql_schema_nm,
            'pgsql_table_nm':  pgsql_table_nm,
        }])], ignore_index=True)

    # 날짜+테이블 단위 중복 제거 (블록4에서 날짜별 1회 GCS 백업)
    if not df_done.empty:
        df_done = df_done.drop_duplicates(subset=['table_uid', 'chk_dte'])

    print(f"\n업로드 완료 - GCS 백업 대상: {len(df_done)}건 (table+날짜 기준)")
    return df_done
