SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

select * from ALL_TAB_COLUMNS where table_name='SPRD03015';
-- 오라클 컬럼 이름 과 속성 얻기 ( postgresql )
SELECT
  lower(c.COLUMN_NAME), 
  cc.COMMENTS, 
  case 
    when c.DATA_TYPE = 'VARCHAR2' then 'varchar'
    when c.DATA_TYPE = 'NUMBER' then 'numeric'
    when c.DATA_TYPE = 'DATE' then 'timestamptz'
    else c.DATA_TYPE
  end as dt, 
  case 
    when c.DATA_TYPE = 'VARCHAR2' then to_char(c.DATA_LENGTH)
    when c.DATA_TYPE = 'NUMBER' then to_char(c.DATA_LENGTH) || ' , ' || case when to_char(c.DATA_SCALE) is null then '0' else to_char(c.DATA_SCALE) end
    when c.DATA_TYPE = 'DATE' then ''
    else c.DATA_TYPE
  end as data_len,
  c.DATA_LENGTH, c.DATA_SCALE, c.DATA_PRECISION

-- 오라클 컬럼 이름 과 속성 얻기 ( bigquery )
-- SELECT
--   lower(c.COLUMN_NAME), 
--   cc.COMMENTS, 
--   case 
--     when c.DATA_TYPE = 'VARCHAR2' then 'string'
--     when c.DATA_TYPE = 'NUMBER' then 'numeric'
--     when c.DATA_TYPE = 'DATE' then 'datetime'
--     else c.DATA_TYPE
--   end as dt, 
--   case 
--     when c.DATA_TYPE = 'VARCHAR2' then '("' || to_char(c.DATA_LENGTH) || '")'
--     when c.DATA_TYPE = 'NUMBER' then '(' || to_char(c.DATA_LENGTH) || ' , ' || case when to_char(c.DATA_SCALE) is null then '0' else to_char(c.DATA_SCALE) end || ')'
--     when c.DATA_TYPE = 'DATE' then ''
--     else c.DATA_TYPE
--   end as data_len  

FROM
  ALL_TAB_COLUMNS c
  left join 
  ALL_COL_COMMENTS cc on c.TABLE_NAME = cc.TABLE_NAME and c.COLUMN_NAME = cc.COLUMN_NAME
WHERE
  c.TABLE_NAME='SPRD03015'
  AND c.COLUMN_NAME in (
    'LOT_NO', 'PROCESS_CODE', 'PROCESS_RANK', 'EQUIP_CODE', 'MATERIAL_LENGTH', 'SQUARENESS'
    )
;

SELECT
  C.AFTER_PROCESS_CODE as "after_process_code",
  B.PROCESS_RANK as "process_rank",
  B.LOT_NO as "lot_no",
  B.PROCESS_CODE as "process_code",
  B.EQUIP_CODE as "equip_code",
  B.CUT_SCRAP as "cut_scrap",
  B.INPUT_ED as "input_ed",
  B.INPUT_WGT as "input_wgt",
  B.PRODUCTION_ED as "production_ed",
  B.PRODUCTION_QTY as "production_qty",
  B.PRODUCTION_WGT as "production_wgt",  
  TO_CHAR(B.WORK_START_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "work_start_date",
  TO_CHAR(B.WORK_END_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "work_end_date",
  TO_CHAR(B.IN_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "in_date",
  TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "create_dtm"
FROM
  CMES.SPRC02002 A JOIN 
  (
    SELECT
      *
    FROM
      CMES.SPRC03009
    WHERE
      WORK_START_DATE >= TO_DATE('2025-06-10', 'YYYY-MM-DD') - INTERVAL '5' DAY and WORK_START_DATE < TO_DATE('2025-06-11', 'YYYY-MM-DD') + INTERVAL '1' DAY
      AND PROCESS_CODE = 'AB03'
  ) B ON B.LOT_NO = A.LOT_NO
  LEFT JOIN CMES.SPRC02003 C ON C.LOT_NO = B.LOT_NO AND C.PROCESS_RANK = B.PROCESS_RANK
WHERE 
  B.IN_DATE >= TO_DATE('2025-06-11', 'YYYY-MM-DD') and B.IN_DATE < TO_DATE('2025-06-11', 'YYYY-MM-DD') + INTERVAL '1' DAY
order by B.IN_DATE
;  

;  

;
-- explain plan for 
SELECT
  a.LOT_NO as "lot_no",
  a.PROCESS_CODE as "process_code",
  a.PROCESS_RANK as "process_rank",
  a.EQUIP_CODE as "equip_code",
  a.MATERIAL_LENGTH as "material_length",
  a.SQUARENESS as "squareness",
  TO_CHAR(a.IN_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "in_date",
  TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD HH24:MI:SS') AS "create_dtm"
FROM
  (
  SELECT
    *
  FROM 
    CMES.SPRD03015
  WHERE
    WORK_DATE >= TO_DATE('2025-06-10', 'YYYY-MM-DD') - INTERVAL '5' DAY and WORK_DATE < TO_DATE('2025-06-10', 'YYYY-MM-DD') + INTERVAL '1' DAY
  ) a
WHERE
  a.IN_DATE >= TO_DATE('2025-06-10', 'YYYY-MM-DD') and a.IN_DATE < TO_DATE('2025-06-10', 'YYYY-MM-DD') + INTERVAL '1' DAY
;  
-- group by heat_no

