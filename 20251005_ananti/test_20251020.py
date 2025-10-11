#!/usr/bin/env python3
"""2025-10-20 날짜 조회"""

import requests
import json

def test_date_20251020():
    session = requests.Session()

    # 헤더 설정 (제공받은 header.txt 기반)
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Content-Type': 'application/json',
        'Origin': 'https://ananti.kr',
        'Referer': 'https://ananti.kr/ko/reservation/joongang/golf?memNo=2211027500&arr=&dep=',
        'X-Requested-With': 'XMLHttpRequest',
    }
    session.headers.update(headers)

    print("=" * 80)
    print("아난티 골프 예약 조회 - 2025-10-20 (월요일)")
    print("=" * 80)

    MEM_NO = '2211027500'
    TEST_DATE = '20251020'
    TARGET_TIMES = ['06:', '07:', '08:']

    url = "https://ananti.kr/reservation/joongang/ajax/golf-course"

    courses = {
        1: "마운틴",
        2: "레이크",
        3: "스카이"
    }

    all_results = []

    # 각 코스별로 조회
    for course_num, course_name in courses.items():
        print(f"\n[{course_name} 코스]")

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
                    print(f"총 {len(items)}개 티타임")

                    # 모든 시간 출력
                    if items:
                        print("\n전체 시간:")
                        for item in items:
                            rtime = item.get('rtime', '')
                            rate = item.get('rate', '')
                            total = item.get('totalCnt', '')
                            print(f"  {rtime} - ₩{rate} (정원: {total})")

                        # 원하는 시간대만 필터링
                        print(f"\n원하는 시간대({', '.join(TARGET_TIMES)}):")
                        found = False
                        for item in items:
                            rtime = item.get('rtime', '')
                            if rtime[:3] in TARGET_TIMES:
                                found = True
                                result = {
                                    'time': rtime,
                                    'course': course_name,
                                    'rate': item.get('rate'),
                                    'total': item.get('totalCnt'),
                                }
                                all_results.append(result)
                                print(f"  ✓ {rtime} - ₩{result['rate']} (정원: {result['total']})")

                        if not found:
                            print(f"  (없음)")
                    else:
                        print("  예약 가능한 시간 없음")

                elif data.get('code') == 401:
                    print(f"  ✗ 로그인 필요 (쿠키 만료)")
                else:
                    print(f"  ✗ API 에러 (code: {data.get('code')}): {data.get('message')}")

            elif response.status_code == 403:
                print(f"  ✗ 403 Forbidden - 로그인 필요 또는 권한 없음")
                print(f"     브라우저에서 로그인 후 쿠키를 복사하세요")
            else:
                print(f"  ✗ HTTP {response.status_code}")

        except requests.exceptions.Timeout:
            print(f"  ✗ 타임아웃")
        except Exception as e:
            print(f"  ✗ 에러: {e}")

    # 최종 결과
    print("\n" + "=" * 80)
    print("최종 결과 - 2025-10-20 (월요일)")
    print("=" * 80)

    if all_results:
        print(f"\n✓ 원하는 시간대({', '.join(TARGET_TIMES)})에 총 {len(all_results)}개 발견\n")

        # 시간순 정렬
        all_results.sort(key=lambda x: x['time'])

        for idx, r in enumerate(all_results, 1):
            print(f"{idx}. {r['time']} - {r['course']} (₩{r['rate']}, 정원: {r['total']})")

        print("\n텔레그램 메시지 형식:")
        print("-" * 80)
        for r in all_results:
            msg = f"{r['time']}: {r['course']} 2025-10-20 opened"
            print(msg)

    else:
        print(f"\n원하는 시간대({', '.join(TARGET_TIMES)})에 예약 가능한 시간 없음")
        print("\n참고: 403 에러가 발생했다면 로그인이 필요합니다.")
        print("브라우저에서 https://ananti.kr 로그인 후 쿠키를 복사하세요.")

    print("\n" + "=" * 80)


if __name__ == "__main__":
    test_date_20251020()
