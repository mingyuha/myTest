-- Docs: https://docs.mage.ai/guides/sql-blocks
select 
mt.table_uid, mt.bq_project_nm, mt.bq_dataset_nm , mt.bq_table_nm ,mt.bq_prtn_column_nm ,mt.pgsql_db_nm, mt.pgsql_schema_nm, mt.pgsql_table_nm, mt.pgsql_dtm_column_nm, pd.access_ip as ip , pd.access_port as port 
from comm_df.clct_table_mt mt left join comm_df.db_mt pd on mt.pgsql_db_nm  = pd.db_nm 
where 1=1
and bq_pgsql_compare_yn = 'Y'
and pd.db_kind = 'postgresql'
order by bq_dataset_nm ,bq_table_nm 
;
