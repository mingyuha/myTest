"""
CSV 파일의 헤더를 BigQuery 컬럼명에서 한글 설명으로 변경
"""
import sys
import json
import csv

def rename_csv_headers(input_csv, mapping_file="column_mapping.json", output_csv=None):
    """
    CSV 파일의 헤더를 매핑 파일을 기반으로 변경

    Args:
        input_csv: 입력 CSV 파일 경로
        mapping_file: 컬럼 매핑 JSON 파일
        output_csv: 출력 CSV 파일 (None이면 자동 생성)
    """
    # 출력 파일명 생성
    if output_csv is None:
        if input_csv.endswith('.csv'):
            output_csv = input_csv.replace('.csv', '_renamed.csv')
        else:
            output_csv = input_csv + '_renamed.csv'

    # 매핑 파일 로드
    print(f"매핑 파일 로딩: {mapping_file}")
    with open(mapping_file, 'r', encoding='utf-8') as f:
        column_mapping = json.load(f)

    print(f"입력 파일: {input_csv}")
    print(f"출력 파일: {output_csv}")

    # CSV 읽기 및 헤더 변경
    with open(input_csv, 'r', encoding='utf-8') as infile:
        # CSV 파일 읽기 (쉼표가 데이터에 포함될 수 있으므로 proper quoting 사용)
        reader = csv.reader(infile)

        # 헤더 읽기
        original_headers = next(reader)
        print(f"\n원본 컬럼 수: {len(original_headers)}")

        # 헤더를 한글 설명으로 변경
        renamed_headers = []
        unmapped_count = 0

        for col in original_headers:
            if col in column_mapping:
                # 매핑된 설명을 사용
                description = column_mapping[col]
                # CSV에서 문제될 수 있는 쉼표를 다른 문자로 치환
                # (CSV writer가 자동으로 따옴표 처리하지만, 안전을 위해)
                safe_description = description.replace(',', '、')  # 일본식 쉼표로 변경
                renamed_headers.append(safe_description)
            else:
                # 매핑이 없으면 원본 컬럼명 사용
                renamed_headers.append(col)
                unmapped_count += 1
                print(f"  매핑 없음: {col}")

        print(f"변경된 컬럼 수: {len(renamed_headers)}")
        if unmapped_count > 0:
            print(f"매핑되지 않은 컬럼: {unmapped_count}개")

        # 새 CSV 파일 작성
        with open(output_csv, 'w', encoding='utf-8-sig', newline='') as outfile:
            writer = csv.writer(outfile, quoting=csv.QUOTE_MINIMAL)

            # 변경된 헤더 작성
            writer.writerow(renamed_headers)

            # 나머지 데이터 복사
            row_count = 0
            for row in reader:
                writer.writerow(row)
                row_count += 1

            print(f"데이터 행 수: {row_count:,}행")

    print(f"\n완료! 파일이 저장되었습니다: {output_csv}")
    print(f"Excel에서 열면 한글이 정상적으로 표시됩니다 (UTF-8 BOM)")

def main():
    if len(sys.argv) < 2:
        print("사용법: python3 rename_csv_headers.py <input.csv> [output.csv]")
        print("예제: python3 rename_csv_headers.py result.csv")
        sys.exit(1)

    input_csv = sys.argv[1]
    output_csv = sys.argv[2] if len(sys.argv) > 2 else None

    rename_csv_headers(input_csv, output_csv=output_csv)

if __name__ == "__main__":
    main()
