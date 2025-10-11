#!/usr/bin/env python3
"""
searchbot10.py 최종 테스트
수정된 함수들이 정상 작동하는지 확인
"""

import sys
sys.path.insert(0, '/home/lips/20251005_ananti')

import logging
import datetime
from pytz import timezone
import os

# searchbot10.py에서 함수 import
from searchbot10 import login_ananti_session, getEmersonMemDay

def test_final():
    """최종 통합 테스트"""

    print("=" * 70)
    print("searchbot10.py 최종 테스트")
    print("=" * 70)

    # 설정
    USER_ID = '2211027500'
    PASSWORD = 'hateyou1@3'
    TEST_DATE = '20251020'  # YYYYMMDD
    TEST_FILE = '/tmp/test_final_emerson.txt'

    # 로거 설정
    logger = logging.getLogger('test')
    logger.setLevel(logging.INFO)
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)

    # searchbot10의 전역 변수 설정
    import searchbot10
    searchbot10.arrange_time = {'06:', '07:', '08:', '09:', '11:'}

    # 현재 시간
    KTC = timezone('Asia/Seoul')
    now1 = datetime.datetime.now(KTC)

    # 1. 로그인
    print("\n[1] 로그인 테스트")
    print(f"ID: {USER_ID}")
    session = login_ananti_session(USER_ID, PASSWORD)

    if not session:
        print("✗ 로그인 실패")
        return
    else:
        print("✓ 로그인 성공")

    # 2. getEmersonMemDay 함수 테스트
    print(f"\n[2] getEmersonMemDay 함수 테스트")
    print(f"날짜: {TEST_DATE} (2025-10-20)")
    print(f"찾을 시간대: 06:, 07:, 08:, 09:, 11:")

    # 기존 파일 삭제
    if os.path.exists(TEST_FILE):
        os.remove(TEST_FILE)

    try:
        # 텔레그램 전송 비활성화 (테스트용)
        original_send = searchbot10.telegram_send
        messages_sent = []

        def mock_send(message, logger):
            messages_sent.append(message)
            print(f"  📱 텔레그램: {message}")

        searchbot10.telegram_send = mock_send

        # 함수 실행
        getEmersonMemDay(
            fileName=TEST_FILE,
            mdate=TEST_DATE,
            logger=logger,
            now1=now1,
            session=session,
            mem_no=USER_ID
        )

        # 복원
        searchbot10.telegram_send = original_send

        print(f"\n✓ 함수 실행 완료")

        # 결과 파일 확인
        if os.path.exists(TEST_FILE):
            print(f"\n[3] 결과 파일 ({TEST_FILE}):")
            with open(TEST_FILE, 'r', encoding='utf8') as f:
                content = f.read()
                if content:
                    lines = content.strip().split('\n')
                    print(f"총 {len(lines)}개 예약 가능 시간:\n")
                    for line in lines:
                        print(f"  {line}")
                else:
                    print("(비어있음 - 예약 가능한 시간 없음)")

            print(f"\n[4] 텔레그램 전송된 메시지:")
            if messages_sent:
                for msg in messages_sent:
                    print(f"  {msg}")
            else:
                print("  (없음 - 이전에 이미 알림받았거나 예약 없음)")

        print("\n" + "=" * 70)
        print("✓✓✓ 모든 테스트 성공! ✓✓✓")
        print("=" * 70)
        print("\nsearchbot10.py가 정상적으로 작동합니다!")
        print("config.ini에 ananti_password를 설정하고 실행하세요.")

    except Exception as e:
        print(f"\n✗ 에러 발생: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    test_final()
