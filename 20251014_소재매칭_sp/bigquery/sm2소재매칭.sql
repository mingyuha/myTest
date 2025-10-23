DECLARE p_datetime DATETIME DEFAULT DATETIME('2024-01-04');
with T1 AS (
        SELECT
            t1.heat_no,
            t3.step_seq_no,
            t1.step_cd,
            t1.rework_seq_no,
            DATETIME_TRUNC(MIN(t1.entry_dtm), SECOND) entry_dtm,
            DATETIME_TRUNC(MAX(t1.exit_dtm), SECOND) exit_dtm,
            t2.zone_id,
            t1.zone_nm,
            t1.subzone_nm
        FROM `sm2_l2.sm2_zone_mid_trk_mt` t1
        INNER JOIN (
          SELECT 
            heat_no
          FROM 
            `dataforge-seahcss.sm2_l2.sm2_zone_mid_trk_mt`
          WHERE 
            inout_dtm BETWEEN DATE_SUB(DATE(p_datetime), INTERVAL 1 DAY) AND DATE_ADD(DATE(p_datetime), INTERVAL 1 DAY)
            and zone_nm in ('EAF') and step_cd in ('REP')
          GROUP BY heat_no
        ) as  t1_only -- 시작 시점에 존재하는 heat 만 선택 
        on t1.heat_no = t1_only.heat_no
        LEFT JOIN `sm2_l2.sm2_zone_info_mt` t2 ON t1.subzone_nm=t2.zone_nm
        LEFT JOIN `sm2_l2.sm2_step_info_mt` t3 ON t1.subzone_nm=t3.zone_nm AND t1.step_cd=t3.step_cd
        WHERE (1=1)
        AND t1.abnorm_yn IN ('n', 'N')
        AND t1.entry_dtm IS NOT NULL
        AND t1.exit_dtm IS NOT NULL
        AND t1.entry_dtm < t1.exit_dtm
        AND DATE(t1.inout_dtm) BETWEEN DATE_SUB(DATE(p_datetime), INTERVAL 1 DAY) AND DATE_ADD(DATE(p_datetime), INTERVAL 2 DAY)
        AND DATE(t1.entry_dtm) >= DATE(p_datetime)
        AND DATE(t1.entry_dtm) < DATE_ADD(DATE(p_datetime), INTERVAL 2 DAY)
        GROUP BY t1.heat_no, t3.step_seq_no, t1.step_cd, t1.rework_seq_no, t2.zone_id, t1.zone_nm, t1.subzone_nm, t2.zone_cd
    ), T2 AS (
        SELECT *
        FROM (
            SELECT
                heat_no, cssteelkindname,
                ROW_NUMBER() OVER(PARTITION BY heat_no ORDER BY trktime DESC) AS row_num
            FROM dataforge-seahcss.sm2_l2.sm2_workorder_mt
            WHERE
                DATE(trktime) BETWEEN DATE_SUB(DATE(p_datetime), INTERVAL 1 YEAR) AND DATE_ADD(DATE(p_datetime), INTERVAL 1 YEAR) AND
                cssteelkindname in ('316LDS1', 'STS410S5','STS304SX','STS303S1','316LDSZ')
        )
        WHERE row_num = 1
    ), T3 AS (
        SELECT DATETIME(stats_sec_dtm) AS stats_sec_dtm
        FROM UNNEST(GENERATE_TIMESTAMP_ARRAY(
            TIMESTAMP(p_datetime),
            TIMESTAMP_ADD(TIMESTAMP(p_datetime), INTERVAL 2 DAY),
            INTERVAL 1 SECOND)) AS stats_sec_dtm
    ), Z1 AS (
        SELECT 'EAF' zone_nm, *
        FROM sm2_tag.tag_sec_zone01_st
        WHERE stats_sec_dtm >= p_datetime
        AND stats_sec_dtm < DATETIME_ADD(p_datetime, INTERVAL 2 DAY)
    ), Z2 AS (
        SELECT 'LF' zone_nm, *
        FROM sm2_tag.tag_sec_zone02_st
        WHERE stats_sec_dtm >= p_datetime
        AND stats_sec_dtm < DATETIME_ADD(p_datetime, INTERVAL 2 DAY)
    ), Z3 AS (
        SELECT 'VD' zone_nm, *
        FROM sm2_tag.tag_sec_zone03_st
        WHERE stats_sec_dtm >= p_datetime
        AND stats_sec_dtm < DATETIME_ADD(p_datetime, INTERVAL 2 DAY)
    ), Z4 AS (
        SELECT 'AOD' zone_nm, *
        FROM sm2_tag.tag_sec_zone04_st
        WHERE stats_sec_dtm >= p_datetime
        AND stats_sec_dtm < DATETIME_ADD(p_datetime, INTERVAL 2 DAY)
    ), Z5 AS (
        SELECT 'LTS' zone_nm, *
        FROM sm2_tag.tag_sec_zone05_st
        WHERE stats_sec_dtm >= p_datetime
        AND stats_sec_dtm < DATETIME_ADD(p_datetime, INTERVAL 2 DAY)
    ), T9 AS (
        SELECT
            T1.heat_no,
            CAST(T1.step_seq_no AS STRING) step_seq_no,
            T1.step_cd,
            CAST(T1.rework_seq_no AS STRING) rework_seq_no,
            CAST(T1.zone_id AS STRING) zone_id,
            T1.zone_nm,
            T1.subzone_nm,
            T1.entry_dtm,
            T1.exit_dtm,
            T2.cssteelkindname,
            T3.stats_sec_dtm,
            Z1.* EXCEPT(zone_nm, stats_sec_dtm),
            Z2.* EXCEPT(zone_nm, stats_sec_dtm),
            Z3.* EXCEPT(zone_nm, stats_sec_dtm),
            Z4.* EXCEPT(zone_nm, stats_sec_dtm),
            Z5.* EXCEPT(zone_nm, stats_sec_dtm)
        FROM T1
        INNER JOIN T2 t2 ON t1.heat_no=t2.heat_no
        LEFT JOIN T3 ON T3.stats_sec_dtm BETWEEN T1.entry_dtm AND T1.exit_dtm
        LEFT JOIN Z1 ON T1.zone_nm=Z1.zone_nm AND T3.stats_sec_dtm=Z1.stats_sec_dtm
        LEFT JOIN Z2 ON T1.zone_nm=Z2.zone_nm AND T3.stats_sec_dtm=Z2.stats_sec_dtm
        LEFT JOIN Z3 ON T1.zone_nm=Z3.zone_nm AND T3.stats_sec_dtm=Z3.stats_sec_dtm
        LEFT JOIN Z4 ON T1.zone_nm=Z4.zone_nm AND T3.stats_sec_dtm=Z4.stats_sec_dtm
        LEFT JOIN Z5 ON T1.zone_nm=Z5.zone_nm AND T3.stats_sec_dtm=Z5.stats_sec_dtm
        WHERE NOT (
            Z1.stats_sec_dtm IS NULL
            AND Z2.stats_sec_dtm IS NULL
            AND Z3.stats_sec_dtm IS NULL
            AND Z4.stats_sec_dtm IS NULL
            AND Z5.stats_sec_dtm IS NULL
        )
    )
select 
  heat_no,
  rework_seq_no,
  zone_id,
  zone_nm,
  subzone_nm,
  entry_dtm,
  exit_dtm,
  cssteelkindname,
  sm2zone01_1
from T9
-- GROUP BY
--   heat_no,
--   rework_seq_no,
--   zone_id,
--   zone_nm,
--   subzone_nm,
--   entry_dtm,
--   exit_dtm,
--   cssteelkindname
where
 1=1
 order by heat_no, entry_dtm;
