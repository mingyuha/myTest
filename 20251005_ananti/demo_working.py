#!/usr/bin/env python3
"""
2025-10-21 날짜의 골프 예약 가능 시간 출력 (실제 작동 데모)
로그인 문제를 우회하여 쿠키로 직접 접근
"""

import requests
import json
from datetime import datetime

def get_golf_times_demo():
    """쿠키를 사용한 실제 작동 데모"""

    print("=" * 70)
    print("아난티 골프 예약 조회 - 실제 작동 데모")
    print("=" * 70)

    # 세션 생성
    session = requests.Session()

    # 참고: 실제 사용 시에는 브라우저에서 로그인 후 쿠키를 복사해야 합니다
    # 아래는 제공된 header.txt의 쿠키 (시간이 지나면 만료됨)
    print("\n[주의] 이 데모는 제공된 쿠키를 사용합니다.")
    print("쿠키가 만료되면 작동하지 않습니다.")
    print("실제 사용 시에는 브라우저에서 로그인 후 쿠키를 복사하세요.\n")

    # 설정
    MEM_NO = '2211027500'
    TEST_DATE = '20251021'
    TARGET_TIMES = ['06:', '07:', '08:']

    # 헤더 설정
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Content-Type': 'application/json',
        'Origin': 'https://ananti.kr',
        'Referer': f'https://ananti.kr/ko/reservation/joongang/golf?memNo={MEM_NO}&arr=&dep=',
        'X-Requested-With': 'XMLHttpRequest',
    }
    session.headers.update(headers)

    # API URL
    url = "https://ananti.kr/reservation/joongang/ajax/golf-course"

    # 코스 정보
    courses = {
        1: "마운틴 (Mountain)",
        2: "레이크 (Lake)",
        3: "스카이 (Sky)"
    }

    print(f"조회 날짜: {TEST_DATE} (2025년 10월 21일)")
    print(f"찾을 시간대: {', '.join(TARGET_TIMES)}")
    print("\n" + "=" * 70)

    all_available = []

    # 각 코스별로 조회
    for course_num, course_name in courses.items():
        print(f"\n[{course_name} 코스 조회 중...]")

        payload = {
            "memNo": MEM_NO,
            "date": TEST_DATE,
            "course": course_num,
            "golfType": "GG",
            "bsns": "22"
        }

        try:
            response = session.post(url, json=payload, timeout=10)

            if response.status_code == 200:
                data = response.json()

                if data.get('code') == 200:
                    items = data.get('data', [])
                    print(f"  총 {len(items)}개 시간 발견")

                    # 원하는 시간대 필터링
                    course_available = []
                    for item in items:
                        rtime = item.get('rtime', '')
                        if rtime[:3] in TARGET_TIMES:
                            course_available.append({
                                'time': rtime,
                                'course': course_name,
                                'rate': item.get('rate'),
                                'total': item.get('totalCnt'),
                                'guest': item.get('guestCnt')
                            })

                    if course_available:
                        print(f"  ✓ 원하는 시간대: {len(course_available)}개")
                        for slot in course_available:
                            print(f"    - {slot['time']} (₩{slot['rate']}, 정원: {slot['total']})")
                            all_available.append(slot)
                    else:
                        print(f"  - 원하는 시간대({TARGET_TIMES})에 예약 가능한 시간 없음")
                else:
                    print(f"  ✗ API 에러: {data.get('message')}")
                    if data.get('code') == 401 or 'login' in str(data.get('message', '')).lower():
                        print("  → 로그인이 필요합니다. 쿠키를 업데이트하세요.")
            else:
                print(f"  ✗ HTTP 에러: {response.status_code}")

        except requests.exceptions.Timeout:
            print(f"  ✗ 타임아웃 발생")
        except Exception as e:
            print(f"  ✗ 에러: {e}")

    # 최종 결과
    print("\n" + "=" * 70)
    print("최종 결과")
    print("=" * 70)

    if all_available:
        print(f"\n✓ 총 {len(all_available)}개 예약 가능 시간 발견:\n")

        # 시간순 정렬
        all_available.sort(key=lambda x: x['time'])

        for idx, slot in enumerate(all_available, 1):
            print(f"{idx}. {slot['time']} - {slot['course']}")
            print(f"   요금: ₩{slot['rate']}, 정원: {slot['total']}명")

        print("\n텔레그램 메시지 형식:")
        print("-" * 70)
        for slot in all_available:
            # searchbot10.py와 동일한 형식
            date_formatted = f"{TEST_DATE[:4]}-{TEST_DATE[4:6]}-{TEST_DATE[6:]}"
            msg = f"{slot['time']}: {slot['course'].split()[0]} {date_formatted} opened"
            print(msg)

    else:
        print(f"\n원하는 시간대({', '.join(TARGET_TIMES)})에 예약 가능한 시간이 없습니다.")

    print("\n" + "=" * 70)
    print("\n[참고] 실제 searchbot10.py 사용 방법:")
    print("1. config.ini에 ananti_password 설정")
    print("2. 또는 login_ananti_session() 함수에서 쿠키 직접 설정")
    print("3. USAGE_GUIDE.md 참조")
    print("=" * 70)


if __name__ == "__main__":
    get_golf_times_demo()
