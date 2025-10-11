#!/usr/bin/env python3
"""
searchbot10.py의 새 API 테스트
실제 getEmersonMemDay 함수 동작 확인
"""

import requests
import logging
import datetime
from pytz import timezone
import sys
import os

# searchbot10.py에서 필요한 함수만 import
sys.path.insert(0, '/home/lips/20251005_ananti')
from searchbot10 import login_ananti_session, getEmersonMemDay

def test_searchbot():
    """searchbot10.py의 새 함수 테스트"""

    print("=" * 60)
    print("searchbot10.py - 새 API 테스트")
    print("=" * 60)

    # 설정
    USER_ID = '2211027500'
    PASSWORD = 'hateyou1@3'
    TEST_DATE = '20251021'  # YYYYMMDD
    TEST_FILE = '/tmp/test_emerson_memday.txt'
    TARGET_TIMES = {'06:', '07:', '08:'}

    # 전역 변수 설정 (searchbot10.py에서 사용)
    import searchbot10
    searchbot10.arrange_time = TARGET_TIMES

    # 로거 설정
    logger = logging.getLogger('test')
    logger.setLevel(logging.INFO)
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)

    # 현재 시간
    KTC = timezone('Asia/Seoul')
    now1 = datetime.datetime.now(KTC)

    # 1. 로그인 테스트
    print("\n[1] 로그인 테스트")
    session = login_ananti_session(USER_ID, PASSWORD)

    if not session:
        print("✗ 로그인 실패")
        print("\n해결 방법:")
        print("1. 실제 웹사이트에서 로그인하여 ID 형식 확인")
        print("2. ID가 '2211027500'이 맞는지 확인")
        print("3. 비밀번호가 정확한지 확인")
        return
    else:
        print("✓ 로그인 성공")

    # 2. getEmersonMemDay 함수 테스트
    print(f"\n[2] getEmersonMemDay 함수 테스트")
    print(f"날짜: {TEST_DATE}")
    print(f"찾을 시간대: {TARGET_TIMES}")

    # 기존 파일 삭제 (테스트 초기화)
    if os.path.exists(TEST_FILE):
        os.remove(TEST_FILE)

    try:
        getEmersonMemDay(
            fileName=TEST_FILE,
            mdate=TEST_DATE,
            logger=logger,
            now1=now1,
            session=session,
            mem_no=USER_ID
        )

        print("\n✓ 함수 실행 완료")

        # 결과 파일 확인
        if os.path.exists(TEST_FILE):
            print(f"\n[3] 결과 파일 내용 ({TEST_FILE}):")
            with open(TEST_FILE, 'r', encoding='utf8') as f:
                content = f.read()
                if content:
                    print(content)
                else:
                    print("(비어있음 - 예약 가능한 시간 없음)")
        else:
            print("\n결과 파일이 생성되지 않음")

    except Exception as e:
        print(f"\n✗ 에러 발생: {e}")
        import traceback
        traceback.print_exc()

    print("\n" + "=" * 60)
    print("테스트 완료")
    print("=" * 60)


if __name__ == "__main__":
    test_searchbot()
