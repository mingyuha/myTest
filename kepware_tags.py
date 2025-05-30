import os
import csv
import mysql.connector
from mysql.connector import Error
import re


# MySQL 데이터베이스 연결 설정
def create_db_connection():
    try:
        connection = mysql.connector.connect(
            host="",
            user="",
            password="",
            database="",
            port=4406,
        )
        if connection.is_connected():
            return connection
    except Error as e:
        print(f"MySQL 연결 에러: {e}")
    return None


# collect_yn='Y'인 모든 태그를 한 번에 가져오는 함수
def get_all_collected_tags(connection):
    try:
        cursor = connection.cursor()
        query = "SELECT std_tag_nm FROM data_tags WHERE COLLECT_YN = 'Y'"
        cursor.execute(query)
        results = cursor.fetchall()
        cursor.close()

        # 결과를 set으로 변환하여 빠른 검색 가능하게 함
        collected_tags = {row[0] for row in results}
        return collected_tags

    except Error as e:
        print(f"쿼리 실행 에러: {e}")
        return set()


# CSV 파일 처리 함수
def process_csv_files(folder_path, save_path=None, test_mode=False):
    # 저장 경로가 지정되지 않은 경우 입력 폴더와 동일하게 설정
    if save_path is None:
        save_path = folder_path

    # 저장 경로가 존재하는지 확인하고 없으면 생성
    if not os.path.exists(save_path):
        os.makedirs(save_path)
        print(f"저장 경로가 존재하지 않아 새로 생성했습니다: {save_path}")

    # 폴더 내 모든 CSV 파일 가져오기
    csv_files = [f for f in os.listdir(folder_path) if f.endswith(".csv")]

    if not csv_files:
        print("처리할 CSV 파일이 없습니다.")
        return

    # DB 연결 및 collect_yn='Y'인 태그 한 번에 가져오기
    connection = create_db_connection()
    if not connection:
        print("데이터베이스 연결 실패. 프로그램을 종료합니다.")
        return

    collected_tags_set = get_all_collected_tags(connection)
    connection.close()  # DB 작업 완료 후 연결 종료

    print(
        f"데이터베이스에서 collect_yn='Y'인 태그 {len(collected_tags_set)}개를 불러왔습니다."
    )

    # 테스트 모드일 경우 첫 번째 파일만 처리
    if test_mode:
        print("\n테스트 모드: 첫 번째 파일만 처리합니다.")
        csv_files = csv_files[:1]

    # 전체 합계를 위한 변수 초기화
    total_collected_tags = 0
    total_non_collected_tags = 0

    # 각 CSV 파일 처리
    for csv_file in csv_files:
        file_path = os.path.join(folder_path, csv_file)
        base_name = csv_file.replace(".csv", "")

        # 결과 저장용 리스트
        collected_rows = []
        non_collected_tags = []

        # CSV 파일 읽기
        with open(file_path, "r", newline="", encoding="utf-8") as file:
            csv_reader = csv.reader(file)
            headers = next(csv_reader)  # 첫 번째 라인은 헤더로 저장
            collected_rows.append(headers)  # 헤더는 항상 포함

            for row in csv_reader:
                if not row:  # 빈 행 건너뛰기
                    continue

                tag_column = row[0]
                full_tag_name = f"{base_name}.{tag_column}"

                # 미리 가져온 collected_tags_set과 비교
                if full_tag_name in collected_tags_set:
                    collected_rows.append(row)
                else:
                    non_collected_tags.append(full_tag_name)

        # 현재 파일의 결과를 전체 합계에 추가
        file_collected_tags = len(collected_rows) - 1  # 헤더 제외
        file_non_collected_tags = len(non_collected_tags)

        total_collected_tags += file_collected_tags
        total_non_collected_tags += file_non_collected_tags

        # 결과 출력
        print(f"\n파일이름: {csv_file}")
        print(
            f"collect_yn='Y' 인 태그 갯수: {len(collected_rows) - 1}, collect_yn='Y'가 아닌 태그 개수: {len(non_collected_tags)}"
        )

        # 모든 태그가 collect_yn='Y'인 경우 (non_collected_tags가 비어있는 경우)
        if not non_collected_tags:
            print("모든 태그가 수집 대상입니다. 파일 생성을 건너뜁니다.")
            print("-" * 50)
            continue  # 다음 파일로 넘어감

        print("collect_yn='Y'가 아닌 태그 목록:")
        for tag in non_collected_tags:
            print(tag)
        print("-" * 50)

        # 'new' 접미사를 붙여 새 파일 저장
        new_file_path = os.path.join(save_path, base_name + "_new.csv")
        tag_name_idx = 0
        address_idx = 1
        negate_value_idx = 15

        # 해당 인덱스를 리스트로 저장
        special_indices = [
            i for i in [tag_name_idx, address_idx, negate_value_idx] if i >= 0
        ]
        with open(new_file_path, "w", newline="", encoding="utf-8") as file:
            csv_writer = csv.writer(file)
            csv_writer.writerow(headers)
            for row in collected_rows[1:]:
                for idx in special_indices:
                    row[idx] = '"' + row[idx] + '"'
                csv_writer.writerow(row)  # collect_yn='Y'인 태그만 저장

    # 전체 합계 출력 (프로그램 마지막 부분)
    print("\n" + "=" * 60)
    print("처리 완료 - 전체 합계")
    print("=" * 60)
    print(f"총 collect_yn='Y' 태그 개수: {total_collected_tags}")
    print(f"총 collect_yn='Y'가 아닌 태그 개수: {total_non_collected_tags}")
    print(f"전체 태그 개수: {total_collected_tags + total_non_collected_tags}")
    print("=" * 60)

    if test_mode:
        print("\n테스트 완료: 첫 번째 파일만 처리했습니다.")
    else:
        print("\n모든 파일 처리가 완료되었습니다.")


# 메인 실행 부분
if __name__ == "__main__":
    folder_path = r"D:\work\bst_소압라인_kepservrer태그\20250530_민규\삭제전원본"
    save_path = r"D:\work\bst_소압라인_kepservrer태그\20250530_민규\신규적용"

    # 테스트 모드 활성화 (True: 첫 번째 파일만 처리, False: 모든 파일 처리)
    test_mode = False

    process_csv_files(folder_path, save_path, test_mode)
