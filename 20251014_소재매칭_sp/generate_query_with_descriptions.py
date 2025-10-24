"""
BigQuery 테이블의 컬럼명을 description으로 변환하여 SELECT 쿼리 생성
"""
from google.cloud import bigquery
from typing import Dict, List, Set

def get_table_schema(client: bigquery.Client, project_id: str, dataset_id: str, table_id: str) -> Dict[str, str]:
    """
    BigQuery 테이블의 스키마를 가져와서 {컬럼명: description} 딕셔너리 반환
    """
    table_ref = f"{project_id}.{dataset_id}.{table_id}"
    table = client.get_table(table_ref)

    schema_dict = {}
    for field in table.schema:
        # description이 없으면 컬럼명을 그대로 사용
        description = field.description if field.description else field.name
        schema_dict[field.name] = description

    return schema_dict

def parse_except_columns(except_clause: str) -> Set[str]:
    """
    EXCEPT(col1, col2) 형태에서 제외할 컬럼 리스트 추출
    """
    if not except_clause:
        return set()

    # except(col1, col2) -> col1, col2
    columns = except_clause.strip('()').replace('except', '').replace('EXCEPT', '').strip()
    return {col.strip() for col in columns.split(',')}

def generate_select_clause(
    table_schemas: Dict[str, Dict[str, str]],
    select_config: List[dict]
) -> str:
    """
    SELECT 절 생성

    Args:
        table_schemas: {테이블명: {컬럼명: description}} 딕셔너리
        select_config: [{"alias": "cim", "table": "sm2_chem_insp_mt", "except": ["create_dtm"]}, ...]

    Returns:
        생성된 SELECT 절
    """
    select_parts = []

    for config in select_config:
        alias = config['alias']
        table = config['table']
        except_cols = set(config.get('except', []))

        schema = table_schemas.get(table, {})

        for col_name, description in schema.items():
            if col_name not in except_cols:
                # 설명에서 BigQuery에서 문제가 될 수 있는 특수문자 제거/치환
                safe_description = description.replace("`", "")
                safe_description = safe_description.replace("(", "")
                safe_description = safe_description.replace(")", "")
                safe_description = safe_description.replace(",", "")
                safe_description = safe_description.replace("=", "")
                safe_description = safe_description.replace("/", "_")
                safe_description = safe_description.replace("'", "")
                safe_description = safe_description.replace('"', "")
                select_parts.append(f"  {alias}.{col_name} AS `{safe_description}`")

    return ",\n".join(select_parts)

def main():
    # ========== 설정 부분 (수정 필요) ==========
    PROJECT_ID = "dataforge-seahcss"  # 여기에 프로젝트 ID 입력
    DATASET_ID = "comm_analy"

    # 4개 테이블 정보
    TABLES = {
        "sm2_chem_insp_mt": "cim",
        "sts_analy_sm2_mid_match_avg_std_dev_st": "sm2_idm",
        "sts_analy_srl_mid_match_avg_std_dev_st": "srl_idm",
        "sts_analy_bad_mt": "brm"
    }

    # SELECT 구성 (기존 쿼리 구조 반영)
    # CTE 1: cim_sm2_idm = cim.* except(create_dtm) + sm2_idm.* except(heat_no)
    # CTE 2: srl_idm_brm = srl_idm.* + brm.* except(heat_no, lot_no)
    # Final: cim_sm2_idm.* + srl_idm_brm.* except(heat_no)

    # ==========================================

    # BigQuery 클라이언트 생성
    client = bigquery.Client(project=PROJECT_ID)

    print("테이블 스키마 정보를 가져오는 중...")

    # 각 테이블의 스키마 가져오기
    table_schemas = {}
    for table_name in TABLES.keys():
        print(f"  - {table_name}")
        schema = get_table_schema(client, PROJECT_ID, DATASET_ID, table_name)
        table_schemas[table_name] = schema

    print(f"\n총 {len(table_schemas)}개 테이블의 스키마를 가져왔습니다.\n")

    # 각 테이블별 컬럼 수 출력
    for table_name, schema in table_schemas.items():
        print(f"{table_name}: {len(schema)}개 컬럼")

    print("\n" + "="*80)
    print("생성된 SELECT 쿼리:")
    print("="*80 + "\n")

    # Final SELECT 절 생성
    # cim_sm2_idm의 모든 컬럼 (이미 create_dtm, heat_no 제외된 상태)
    cim_cols = [col for col in table_schemas["sm2_chem_insp_mt"].keys() if col != "create_dtm"]
    sm2_idm_cols = [col for col in table_schemas["sts_analy_sm2_mid_match_avg_std_dev_st"].keys() if col != "heat_no"]

    # srl_idm_brm의 모든 컬럼 (이미 heat_no, lot_no 제외된 상태)
    srl_idm_cols = list(table_schemas["sts_analy_srl_mid_match_avg_std_dev_st"].keys())

    # brm에서 이미 srl_idm에 있는 컬럼 제외 (heat_no, lot_no 외에도 중복 컬럼 제거)
    srl_idm_col_set = set(srl_idm_cols)
    brm_cols = [col for col in table_schemas["sts_analy_bad_mt"].keys()
                if col not in ["heat_no", "lot_no"] and col not in srl_idm_col_set]

    # 최종 SELECT에서 heat_no 중복 제거
    final_cols = []

    # 컬럼명 -> 설명 매핑 딕셔너리 생성
    column_mapping = {}

    # cim_sm2_idm 컬럼들 (cim + sm2_idm)
    for col in cim_cols:
        desc = table_schemas["sm2_chem_insp_mt"][col]
        column_mapping[col] = desc
        final_cols.append(f"  cim_sm2_idm.{col}")

    for col in sm2_idm_cols:
        desc = table_schemas["sts_analy_sm2_mid_match_avg_std_dev_st"][col]
        column_mapping[col] = desc
        final_cols.append(f"  cim_sm2_idm.{col}")

    # srl_idm_brm 컬럼들 (srl_idm + brm), heat_no 제외
    for col in srl_idm_cols:
        if col != "heat_no":  # heat_no는 이미 cim_sm2_idm에 있으므로 제외
            desc = table_schemas["sts_analy_srl_mid_match_avg_std_dev_st"][col]
            column_mapping[col] = desc
            final_cols.append(f"  srl_idm_brm.{col}")

    for col in brm_cols:
        desc = table_schemas["sts_analy_bad_mt"][col]
        column_mapping[col] = desc
        final_cols.append(f"  srl_idm_brm.{col}")

    # 최종 쿼리 출력
    query = f"""with cim_sm2_idm as (
  select
    cim.* except(create_dtm), sm2_idm.* except(heat_no)
  from
    `{PROJECT_ID}.{DATASET_ID}.sm2_chem_insp_mt` cim
    inner join `{PROJECT_ID}.{DATASET_ID}.sts_analy_sm2_mid_match_avg_std_dev_st` sm2_idm on cim.heat_no = sm2_idm.heat_no
  where
    cim.last_chmcl_yn = 'Y'
  order by sm2_idm.heat_no, sm2_idm.min_entry_dtm
  ),
  srl_idm_brm as (
    select
      srl_idm.*, brm.* except(heat_no, lot_no, strnd_no, strnd_seq, irn_code)
    from
      `{PROJECT_ID}.{DATASET_ID}.sts_analy_srl_mid_match_avg_std_dev_st` srl_idm
      left outer join `{PROJECT_ID}.{DATASET_ID}.sts_analy_bad_mt` brm on (
        srl_idm.heat_no = brm.heat_no 
        and srl_idm.strnd_no = brm.strnd_no 
        and srl_idm.strnd_seq = brm.strnd_seq
        and srl_idm.lot_no = brm.lot_no
      )
    order by
      srl_idm.lot_no, srl_idm.rm_entry_dtm
  )
select
{','.join([chr(10) + col for col in final_cols])}
from
  cim_sm2_idm inner join srl_idm_brm on cim_sm2_idm.heat_no = srl_idm_brm.heat_no
where
  1=1
  -- cim_sm2_idm.heat_no='S55019'
order by
  cim_sm2_idm.heat_no, cim_sm2_idm.min_entry_dtm, srl_idm_brm.lot_no, srl_idm_brm.rm_entry_dtm"""

    print(query)

    # 파일로 저장
    output_file = "generated_query.sql"
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(query)

    print(f"\n\n쿼리가 '{output_file}' 파일로 저장되었습니다.")
    print(f"총 {len(final_cols)}개의 컬럼")

    # 컬럼 매핑 JSON 파일 저장
    import json
    mapping_file = "column_mapping.json"
    with open(mapping_file, "w", encoding="utf-8") as f:
        json.dump(column_mapping, f, ensure_ascii=False, indent=2)

    print(f"컬럼 매핑이 '{mapping_file}' 파일로 저장되었습니다.")

    print("\n" + "="*80)
    print("다음 단계:")
    print("="*80)
    print("1. BigQuery 콘솔에서 generated_query.sql 내용을 복사하여 실행")
    print("2. 쿼리 결과를 CSV로 다운로드 (예: result.csv)")
    print("3. 다음 명령으로 CSV 헤더를 한글 설명으로 변경:")
    print("   python3 rename_csv_headers.py result.csv")
    print("4. result_renamed.csv 파일 생성됨 (헤더가 한글 설명으로 변경)")

if __name__ == "__main__":
    main()
