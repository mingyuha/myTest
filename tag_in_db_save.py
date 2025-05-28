import os
import mysql.connector
from datetime import datetime


def strip_prefix(tag):
    """'ns=2;s=' 접두어를 제거하는 함수"""
    return tag.replace("ns=2;s=", "")


def fetch_tags_from_db():
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

        # COLLECT_YN = 'Y'인 태그 조회 쿼리
        query = "SELECT std_tag_nm FROM data_tags WHERE COLLECT_YN = 'Y'"
        cursor.execute(query)
        results = cursor.fetchall()

        return [result[0] for result in results]
    except mysql.connector.Error as err:
        print(f"Error: {err}")
        return []
    finally:
        cursor.close()
        connection.close()


def process_files(folder_path):
    collected_tags = fetch_tags_from_db()  # COLLECT_YN = 'Y'인 태그 목록 가져오기

    # 파일 처리
    for filename in os.listdir(folder_path):
        if filename.endswith(".txt"):  # 파일 형식 확인
            print(f"'{filename}'")
            original_file_path = os.path.join(folder_path, filename)

            with open(original_file_path, "r") as file:
                lines = file.readlines()  # 줄 단위로 읽기
                tags_to_save = []
                tags_to_output = []

                for line in lines:
                    tag = line.strip()
                    if tag.startswith("ns=2;s="):
                        tag_stripped = strip_prefix(tag)
                        if tag_stripped in collected_tags:
                            tags_to_save.append(tag_stripped)
                        else:
                            tags_to_output.append(tag_stripped)

            # 변경사항 확인
            if len(tags_to_output) == 0:
                print("변경사항이 없다")
                continue

            # 백업 파일 생성
            backup_filename = f"{os.path.splitext(filename)[0]}.txt.bak"  # 백업 파일명
            backup_file_path = os.path.join(folder_path, backup_filename)
            with open(backup_file_path, "w") as backup_file:
                backup_file.writelines(lines)  # 원본 파일 내용을 백업 파일에 저장

            # 태그 저장
            new_file_path = original_file_path  # 원본 파일명으로 저장
            if len(tags_to_save) > 0:
                with open(new_file_path, "w") as new_file:
                    for i, tag in enumerate(tags_to_save):
                        if i == len(tags_to_save) - 1:  # 마지막 태그
                            new_file.write(
                                f"ns=2;s={tag}"
                            )  # 마지막 태그에는 줄바꿈 없음
                        else:
                            new_file.write(f"ns=2;s={tag}\n")  # 줄바꿈 문자: LF (\n)
            else:
                # tags_to_save가 0일 경우 빈 파일 생성
                with open(new_file_path, "w") as new_file:
                    pass  # 빈 파일 생성
            # COLLECT_YN = 'N'인 태그의 개수 출력 및 태그 출력
            if tags_to_output:
                print(
                    f"COLLECT_YN = 'N' 태그 개수: {len(tags_to_output)}"
                )  # N 태그 개수 출력
                for tag in tags_to_output:
                    print(tag)
            print(
                f"COLLECT_YN = 'Y' 태그 개수: {len(tags_to_save)}\n"
            )  # Y 태그 개수 출력


# 주어진 폴더 경로에 맞게 경로 변경
folder_path = r"D:\GitHub\SDP_Promotion_Review\NiFi_Tags\Bst\소형압연\라인"
process_files(folder_path)
