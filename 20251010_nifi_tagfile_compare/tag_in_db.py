import os
import mysql.connector
from collections import defaultdict


def strip_prefix(tag):
    """'ns=2;s=' 접두어를 제거하는 함수"""
    return tag.replace("ns=2;s=", "")


def fetch_tags_from_db(tags):
    """데이터베이스에서 태그 정보를 조회하는 함수"""
    try:
        # MySQL DB 연결 설정
        connection = mysql.connector.connect(
            host="172.17.40.191",
            user="dataforge",
            password="dataforge1212",
            database="df_wg",
            port=4406,
        )

        cursor = connection.cursor()

        # 템플릿 쿼리 생성
        query = "SELECT std_tag_nm FROM data_tags WHERE std_tag_nm IN (%s) AND COLLECT_YN = 'N'"
        formatted_query = query % ",".join(
            ["%s"] * len(tags)
        )  # IN 절을 위한 쿼리 포맷팅

        # 쿼리 실행
        cursor.execute(formatted_query, tags)
        results = cursor.fetchall()

        return [result[0] for result in results]
    except mysql.connector.Error as err:
        print(f"Error: {err}")
        return []
    finally:
        cursor.close()
        connection.close()


def process_files(folder_path):
    all_tags = defaultdict(list)

    for filename in os.listdir(folder_path):
        if filename.endswith(".txt"):  # 파일 형식 확인
            with open(os.path.join(folder_path, filename), "r") as file:
                for line in file:
                    tag = line.strip()
                    if tag.startswith("ns=2;s="):
                        tag = strip_prefix(tag)
                        # 태그를 파일 이름에 추가
                        all_tags[filename].append(tag)

    # 파일 이름을 기준으로 정렬
    sorted_filenames = sorted(all_tags.keys())

    # DB에서 태그 정보 조회를 위한 유니크 태그 목록
    unique_tags = list(set(tag for tags in all_tags.values() for tag in tags))
    filtered_tags = fetch_tags_from_db(unique_tags)

    # 결과 출력
    print("COLLECT_YN = 'N'인 태그 및 해당 파일 이름:")

    for filename in sorted_filenames:
        # 해당 파일에 포함된 태그를 필터링
        tags_to_display = [tag for tag in all_tags[filename] if tag in filtered_tags]
        if tags_to_display:  # 태그가 존재할 경우 출력
            print(f"'{filename}'")
            for tag in tags_to_display:
                print(tag)
            print()  # 파일 이름과 태그 간의 공백 한 줄 추가


# 주어진 폴더 경로에 맞게 경로 변경
folder_path = r"D:\GitHub\SDP_Promotion_Review\NiFi_Tags\Bst\대형압연"
process_files(folder_path)
