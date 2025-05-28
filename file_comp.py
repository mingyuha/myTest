import paramiko
import os
import stat  # 원격 파일이 디렉토리인지 확인하기 위해 필요
import posixpath  # 원격 경로 조합을 위해 posixpath 사용 (리눅스 스타일 경로)
import mysql.connector  # MySQL 데이터베이스 연결을 위해 필요

# --- 설정 정보 ---
LOCAL_FOLDER_PATH = r"D:\GitHub\SDP_Promotion_Review\NiFi_Tags\Bst\소형압연\라인"  # 로컬 폴더 경로 (예: './data/local')
REMOTE_FOLDER_PATH = (
    "/opt/sdp-edge/tag_files"  # 리눅스 서버 폴더 경로 (예: '/home/user/data/remote')
)

# SSH 연결 정보
SSH_HOST = "172.31.208.84"  # 서버 IP 또는 호스트 이름
SSH_PORT = 22  # SSH 포트 (기본값 22)
SSH_USER = "root"  # 서버 사용자 이름
# SSH 인증 방법 선택 (비밀번호 또는 키 파일)
SSH_PASSWORD = "wnsxhtm1212"  # 비밀번호 인증 시 사용
# SSH_KEY_FILE = '/path/to/your/private_key.pem' # 키 파일 인증 시 사용 (예: ~/.ssh/id_rsa)
DB_HOST = "172.17.40.191"  # MySQL 서버 IP 또는 호스트 이름
DB_PORT = 4406  # MySQL 포트 (기본값 3306)
DB_USER = "dataforge"  # MySQL 사용자 이름
DB_PASSWORD = "dataforge1212"  # MySQL 비밀번호
DB_NAME = "df_wg"  # 데이터베이스 이름

# --- 설정 정보 끝 ---


def read_file_lines(file_path):
    """주어진 파일 경로에서 파일을 읽어 라인 리스트를 반환합니다."""
    tags = []
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            # 각 라인의 앞뒤 공백 및 줄바꿈 문자 제거 후 저장, 비어있지 않은 라인만 포함
            tags = [line.strip() for line in f if line.strip()]
        return tags
    except FileNotFoundError:
        # 파일이 없을 경우 빈 리스트와 함께 메시지 출력 (다른 파일 비교는 계속 진행)
        print(
            f"경고: 로컬 파일 '{file_path}'를 찾을 수 없습니다. 해당 파일은 비교 대상에서 제외됩니다."
        )
        return []
    except Exception as e:
        # 그 외 읽기 오류 발생 시 None 반환 (해당 파일 처리 중단)
        print(f"로컬 파일 '{file_path}' 읽기 중 오류 발생: {e}")
        return None


def get_remote_file_list_sftp(sftp_client, remote_folder_path):
    """SFTP를 사용하여 원격 폴더의 파일 목록을 가져옵니다."""
    try:
        items = sftp_client.listdir(remote_folder_path)
        files = []
        for item in items:
            # remote_item_path = os.path.join(remote_folder_path, item)
            remote_item_path = (
                remote_folder_path.rstrip("/") + "/" + item
            )  # 원격 폴더 경로 끝에 슬래시가 없더라도 추가
            try:
                # item이 파일인지 확인 (디렉토리, 심볼릭 링크 등 제외)
                # stat.S_ISREG(mode)는 mode가 일반 파일인지 확인하는 함수
                if stat.S_ISREG(sftp_client.stat(remote_item_path).st_mode):
                    files.append(item)
            except FileNotFoundError:
                # listdir에는 나왔지만 stat으로 확인하려니 없는 경우 (경쟁 조건 등)
                print(
                    f"경고: 원격 항목 '{remote_item_path}'의 상태를 확인할 수 없습니다. 목록에서 제외합니다."
                )
                continue
            except Exception as e:
                print(
                    f"경고: 원격 항목 '{remote_item_path}' 상태 확인 중 오류 발생: {e}. 목록에서 제외합니다."
                )
                continue
        return files  # 파일 이름 리스트 반환
    except FileNotFoundError:
        print(f"오류: 원격 폴더 '{remote_folder_path}'를 서버에서 찾을 수 없습니다.")
        return None
    except paramiko.SSHException as e:
        print(f"원격 파일 목록 가져오기 중 SSH 오류 발생: {e}")
        return None
    except Exception as e:
        print(f"원격 파일 목록 가져오기 중 예상치 못한 오류 발생: {e}")
        return None


def read_remote_file_content_sftp(sftp_client, remote_file_path):
    """SFTP를 사용하여 원격 서버의 특정 파일 내용을 읽어 라인 리스트를 반환합니다."""
    tags = []
    try:
        # 원격 파일 열기 및 읽기
        with sftp_client.open(remote_file_path, "r") as f:
            # 각 라인의 앞뒤 공백 및 줄바꿈 문자 제거 후 저장, 비어있지 않은 라인만 포함
            tags = [line.strip() for line in f if line.strip()]
        return tags
    except FileNotFoundError:
        # 파일이 없을 경우 빈 리스트와 함께 메시지 출력 (다른 파일 비교는 계속 진행)
        print(
            f"경고: 원격 파일 '{remote_file_path}'를 서버에서 찾을 수 없습니다. 해당 파일은 비교 대상에서 제외됩니다."
        )
        return []
    except paramiko.SSHException as e:
        print(f"원격 파일 '{remote_file_path}' 읽기 중 SSH 오류 발생: {e}")
        return None
    except Exception as e:
        # 그 외 읽기 오류 발생 시 None 반환 (해당 파일 처리 중단)
        print(f"원격 파일 '{remote_file_path}' 읽기 중 예상치 못한 오류 발생: {e}")
        return None


def find_difference(list1, list2):
    """두 리스트의 차이점을 집합 연산을 사용하여 찾습니다."""
    set1 = set(list1)
    set2 = set(list2)

    # list1에는 있고 list2에는 없는 요소
    only_in_list1 = sorted(list(set1 - set2))  # 결과를 정렬하여 출력하면 보기 좋습니다.

    # list2에는 있고 list1에는 없는 요소
    only_in_list2 = sorted(list(set2 - set1))  # 결과를 정렬하여 출력하면 보기 좋습니다.

    return only_in_list1, only_in_list2


def check_tag_in_db(db_connection, tag_name):
    """MySQL DB에서 특정 태그 이름의 COLLECT_YN 값을 조회합니다. 태그 정보 중 'ns=2;s=' 접두사를 제외하고 조회합니다."""

    # 'ns=2;s=' 접두사 제거
    prefix = "ns=2;s="
    if tag_name.startswith(prefix):
        tag_to_check = tag_name[len(prefix) :]
    else:
        tag_to_check = tag_name  # 접두사가 없으면 그대로 사용

    cursor = None
    try:
        cursor = db_connection.cursor()
        # std_tag_nm 컬럼에서 접두사 제거된 태그 이름으로 조회
        query = f"SELECT COLLECT_YN FROM {DB_NAME}.data_tags WHERE std_tag_nm = %s"
        cursor.execute(query, (tag_to_check,))
        result = cursor.fetchone()  # 첫 번째 결과만 가져옴

        if result:
            return result[0]  # COLLECT_YN 값 반환
        else:
            return None  # DB에 해당 태그 없음
    except mysql.connector.Error as err:
        print(f"DB 조회 중 오류 발생: {err}")
        return None  # 오류 발생 시 None 반환
    finally:
        if cursor:
            cursor.close()


# --- 메인 실행 ---
if __name__ == "__main__":
    transport = None
    sftp = None
    db_connection = None

    # 로컬 폴더 존재 확인
    if not os.path.isdir(LOCAL_FOLDER_PATH):
        print(
            f"오류: 로컬 폴더 '{LOCAL_FOLDER_PATH}'를 찾을 수 없습니다. 스크립트를 종료합니다."
        )
        exit(1)

    try:
        print(f"SSH 서버 '{SSH_HOST}'에 연결 중 (포트: {SSH_PORT})...")
        transport = paramiko.Transport((SSH_HOST, SSH_PORT))

        # SSH 인증
        # 비밀번호 인증 사용 시 SSH_PASSWORD 변수에 값을 할당하고 아래 주석 해제
        # 키 파일 인증 사용 시 SSH_KEY_FILE 변수에 값을 할당하고 아래 주석 해제
        if "SSH_PASSWORD" in locals() and SSH_PASSWORD:
            print(f"사용자 '{SSH_USER}'로 비밀번호 인증 시도...")
            transport.connect(username=SSH_USER, password=SSH_PASSWORD)
        elif (
            "SSH_KEY_FILE" in locals() and SSH_KEY_FILE and os.path.exists(SSH_KEY_FILE)
        ):
            print(f"사용자 '{SSH_USER}'로 키 파일 '{SSH_KEY_FILE}' 인증 시도...")
            try:
                key = paramiko.RSAKey.from_private_key_file(
                    SSH_KEY_FILE
                )  # 또는 사용 키 종류에 맞게 변경 (Ed25519Key 등)
                transport.connect(username=SSH_USER, pkey=key)
            except paramiko.PasswordRequiredException:
                print(
                    f"오류: 키 파일 '{SSH_KEY_FILE}'에 암호가 설정되어 있습니다. 코드에서 암호를 처리하거나 암호 없는 키 파일을 사용하세요."
                )
                exit(1)
            except paramiko.SSHException as e:
                print(f"키 파일 인증 중 SSH 오류 발생: {e}")
                exit(1)
            except Exception as e:
                print(f"키 파일 로딩 또는 인증 중 오류 발생: {e}")
                exit(1)
        else:
            print(
                "오류: SSH 인증 정보(비밀번호 또는 유효한 키 파일 경로)가 제공되지 않았습니다."
            )
            exit(1)

        print("SSH 연결 성공.")
        print("SFTP 클라이언트 생성 중...")
        sftp = paramiko.SFTPClient.from_transport(transport)
        print("SFTP 클라이언트 생성 성공.")

        # MySQL DB 연결
        print(f"MySQL DB '{DB_NAME}'에 연결 중...")
        db_connection = mysql.connector.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,  # 연결 시 DB 이름 지정
        )
        print("MySQL DB 연결 성공.")

        # 로컬 및 원격 파일 목록 가져오기
        print(f"\n로컬 폴더 '{LOCAL_FOLDER_PATH}'의 파일 목록 가져오는 중...")
        try:
            local_items = os.listdir(LOCAL_FOLDER_PATH)
            # 실제 파일만 걸러냄
            local_files = {
                item
                for item in local_items
                if os.path.isfile(os.path.join(LOCAL_FOLDER_PATH, item))
            }
            print(f"로컬에서 찾은 파일 ({len(local_files)}개): {list(local_files)}")
        except Exception as e:
            print(f"로컬 파일 목록 가져오기 중 오류 발생: {e}")
            local_files = set()  # 오류 발생 시 빈 집합으로 초기화

        print(f"\n원격 폴더 '{REMOTE_FOLDER_PATH}'의 파일 목록 가져오는 중...")
        remote_files_list = get_remote_file_list_sftp(sftp, REMOTE_FOLDER_PATH)

        if remote_files_list is not None:
            remote_files = set(remote_files_list)
            print(f"원격에서 찾은 파일 ({len(remote_files)}개): {list(remote_files)}")

            # 공통 파일 찾기
            common_files = sorted(list(local_files.intersection(remote_files)))
            print(
                f"\n로컬과 원격에 모두 존재하는 파일 ({len(common_files)}개): {common_files}"
            )

            if not common_files:
                print("\n비교할 공통 파일이 없습니다.")
            else:
                print("\n--- 파일별 태그 정보 비교 시작 ---")
                for filename in common_files:
                    local_file_path = os.path.join(LOCAL_FOLDER_PATH, filename)
                    # remote_file_path = os.path.join(REMOTE_FOLDER_PATH, filename)
                    remote_file_path = (
                        REMOTE_FOLDER_PATH.rstrip("/") + "/" + filename
                    )  # 원격 폴더 경로 끝에 슬래시가 없더라도 추가
                    print(f"\n파일 '{filename}' 비교 중...")

                    # 로컬 파일 읽기
                    local_tags = read_file_lines(local_file_path)
                    if local_tags is None:  # 읽기 오류 발생 시 해당 파일 건너뛰기
                        print(
                            f"로컬 파일 '{filename}' 읽기에 실패하여 비교를 건너뜁니다."
                        )
                        continue
                    # print(f"  로컬 태그 ({len(local_tags)}개): {local_tags[:5]}...") # 디버깅용 출력

                    # 원격 파일 읽기
                    remote_tags = read_remote_file_content_sftp(sftp, remote_file_path)
                    if remote_tags is None:  # 읽기 오류 발생 시 해당 파일 건너뛰기
                        print(
                            f"원격 파일 '{filename}' 읽기에 실패하여 비교를 건너뜁니다."
                        )
                        continue
                    # print(f"  원격 태그 ({len(remote_tags)}개): {remote_tags[:5]}...") # 디버깅용 출력

                    # 태그 비교
                    only_in_local, only_in_remote = find_difference(
                        local_tags, remote_tags
                    )

                    if only_in_local:
                        print(f"  --- '{filename}' - 로컬에만 있는 태그 ---")
                        for tag in only_in_local:
                            collect_yn = check_tag_in_db(db_connection, tag)
                            if collect_yn is not None:
                                print(f"    - {tag}: COLLECT_YN = {collect_yn}")
                            else:
                                print(f"    - {tag}: DB에 없음")
                    # else:
                    #     # print("  로컬 파일에만 있는 태그가 없습니다.")

                    if only_in_remote:
                        print(f"  --- '{filename}' - 원격 서버에만 있는 태그 ---")
                        for tag in only_in_remote:
                            collect_yn = check_tag_in_db(db_connection, tag)
                            if collect_yn is not None:
                                print(f"    - {tag}: COLLECT_YN = {collect_yn}")
                            else:
                                print(f"    - {tag}: DB에 없음")
                    # else:
                    #     # print("  원격 서버 파일에만 있는 태그가 없습니다.")

                print("\n--- 파일별 태그 정보 비교 완료 ---")

                # 한쪽에만 존재하는 파일 목록 (필요하다면 추가)
                only_local_files = local_files - remote_files
                only_remote_files = remote_files - local_files

                print("\n--- 한쪽에만 존재하는 파일 목록 ---")
                print(
                    f"로컬에만 있는 파일 ({len(only_local_files)}개): {sorted(list(only_local_files))}"
                )
                print(
                    f"원격 서버에만 있는 파일 ({len(only_remote_files)}개): {sorted(list(only_remote_files))}"
                )

        else:
            print(
                "\n원격 폴더의 파일 목록을 가져오는데 실패했습니다. 비교를 수행할 수 없습니다."
            )

    except paramiko.AuthenticationException:
        print(
            "\n오류: SSH 인증에 실패했습니다. 사용자 이름, 비밀번호 또는 키 파일을 확인하세요."
        )
    except paramiko.SSHException as e:
        print(f"\nSSH 연결 또는 작업 중 오류 발생: {e}")
    except Exception as e:
        print(f"\n스크립트 실행 중 예상치 못한 오류 발생: {e}")

    finally:
        # 연결 종료
        if sftp:
            sftp.close()
            print("\nSFTP 클라이언트 종료.")
        if transport:
            transport.close()
            print("SSH 연결 종료.")
        if db_connection and db_connection.is_connected():
            db_connection.close()
            print("MySQL DB 연결 종료.")
