#!/usr/bin/env python3
"""쿠키를 사용한 직접 API 테스트 (로그인 없이)"""

import requests
import json

def test_api_with_cookies():
    """header.txt의 쿠키로 직접 API 호출"""

    session = requests.Session()

    # header.txt의 쿠키 (일부만 중요한 것들)
    cookies = {
        'ME_SID': 'NDNmYTMyMDMtNTNkNS00MTVkLWE3MjktNDhhNjhlZDNiNGI4',
        'njiegnoal': 'eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiIyMjExMDI3NTAwIiwiYXRub2FrbmV0bmkiOiI3NWVlNmRhZTJjYzkzM2FjZTU2NWNhZTliOGQ4Y2VlYTNiMmNmNzA1Mzg4YmE3YjMwOTQ2M2Y3MDVmZjVlM2RkZTU4OWU5NTVlOWJiNjg1Yzg3NWRmMjQ2MmJmNTFlOWJlZmU0NWNmMDQxYmY3ZDcyMDEzZGNiZDY2NWM3ZmQ1MCIsImNtTm8iOiIzMDI2NjkyIiwiZXhwIjoxNzY3NDEzOTMxLCJpYXQiOjE3NTk2Mzc5MzF9.y6e0PEXYjbTl2AoDfv5al25G6RWcq1qbYHCuUijuYpAu-LJBZyGloI6PW3DestZ7ycIM3EMd5Bc47fLLpybUvw',
        'JSESSIONID': 'ZTJmNTgyYTMtMTQyYi00Yjc1LTkzMWQtNWVhNDU2ODY3NDU5',
        'org.springframework.web.servlet.i18n.CookieLocaleResolver.LOCALE': 'ko',
        '_ga': 'GA1.1.91133131.1745565703',
    }

    session.cookies.update(cookies)

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Content-Type': 'application/json',
        'Origin': 'https://ananti.kr',
        'Referer': 'https://ananti.kr/ko/reservation/joongang/golf?memNo=2211027500&arr=&dep=',
        'X-Requested-With': 'XMLHttpRequest',
        'X-CSRF-Token': '1be60b8c-f22a-4e48-8ffd-4f32b3435646',  # header.txt의 토큰
    }

    session.headers.update(headers)

    print("=" * 60)
    print("새 API 직접 테스트 (쿠키 사용)")
    print("=" * 60)

    # 테스트 날짜
    test_date = '20251021'
    mem_no = '2211027500'

    url = "https://ananti.kr/reservation/joongang/ajax/golf-course"

    course_names = {1: "마운틴", 2: "레이크", 3: "스카이"}
    target_times = ['06:', '07:', '08:']

    all_results = []

    # 각 코스별로 조회
    for course_num, course_name in course_names.items():
        print(f"\n[코스 {course_num}: {course_name}]")

        payload = {
            "memNo": mem_no,
            "date": test_date,
            "course": course_num,
            "golfType": "GG",
            "bsns": "22"
        }

        print(f"요청: {json.dumps(payload, ensure_ascii=False)}")

        try:
            response = session.post(url, json=payload)
            print(f"응답 상태: {response.status_code}")

            if response.status_code == 200:
                data = response.json()
                print(f"응답 코드: {data.get('code')}")

                if data.get('code') == 200:
                    items = data.get('data', [])
                    print(f"총 {len(items)}개 시간")

                    # 원하는 시간대 필터링
                    for item in items:
                        rtime = item.get('rtime', '')
                        if rtime[:3] in target_times:
                            result = {
                                'time': rtime,
                                'course': course_name,
                                'rate': item.get('rate'),
                                'totalCnt': item.get('totalCnt'),
                                'guestCnt': item.get('guestCnt'),
                            }
                            all_results.append(result)
                            print(f"  ✓ {rtime} - ₩{item.get('rate')} (정원: {item.get('totalCnt')})")
                else:
                    print(f"에러: {data.get('message')}")
            else:
                print(f"HTTP 에러: {response.text[:200]}")

        except Exception as e:
            print(f"예외 발생: {e}")

    # 최종 결과
    print("\n" + "=" * 60)
    print(f"최종 결과 - {test_date} 날짜")
    print("=" * 60)

    if all_results:
        print(f"✓ 총 {len(all_results)}개 예약 가능 시간 발견\n")
        for r in sorted(all_results, key=lambda x: x['time']):
            print(f"{r['time']} - {r['course']} (₩{r['rate']})")
    else:
        print(f"원하는 시간대({target_times})에 예약 가능한 시간 없음")


if __name__ == "__main__":
    test_api_with_cookies()
