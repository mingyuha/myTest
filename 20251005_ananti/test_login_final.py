#!/usr/bin/env python3
"""정확한 파라미터로 로그인 테스트"""

import requests
import json

def test_login():
    """cmUserId, cmUserPw로 로그인 테스트"""

    session = requests.Session()

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
    }
    session.headers.update(headers)

    print("=" * 70)
    print("아난티 로그인 테스트 (정확한 파라미터)")
    print("=" * 70)

    # 1. 로그인 페이지 방문
    print("\n[1] 로그인 페이지 방문...")
    session.get("https://me.ananti.kr/user/signin")
    print("✓ 완료")

    # 2. 로그인 시도
    print("\n[2] 로그인 시도...")
    login_url = "https://me.ananti.kr/user/signin_proc"

    # 정확한 파라미터명 사용
    login_data = {
        'cmUserId': '2211027500',
        'cmUserPw': 'hateyou1@3',
        'saveId': ''
    }

    session.headers.update({
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Origin': 'https://me.ananti.kr',
        'Referer': 'https://me.ananti.kr/user/signin',
        'X-Requested-With': 'XMLHttpRequest'
    })

    print(f"URL: {login_url}")
    print(f"파라미터: {login_data}")

    response = session.post(login_url, data=login_data)

    print(f"\n응답 상태: {response.status_code}")

    try:
        data = response.json()
        print(f"응답 JSON:")
        print(json.dumps(data, indent=2, ensure_ascii=False))

        if data.get('code') == '200':
            print("\n" + "=" * 70)
            print("✓✓✓ 로그인 성공! ✓✓✓")
            print("=" * 70)

            # 쿠키 확인
            print(f"\n세션 쿠키:")
            for key, value in session.cookies.items():
                print(f"  {key}: {value[:50]}..." if len(value) > 50 else f"  {key}: {value}")

            # 3. 골프 예약 페이지 접근 테스트
            print("\n[3] 골프 예약 페이지 접근 테스트...")
            golf_url = "https://ananti.kr/ko/reservation/joongang/golf"
            resp = session.get(golf_url)

            if 'signin' in resp.url:
                print("✗ 로그인 페이지로 리다이렉트됨")
            else:
                print(f"✓ 예약 페이지 접근 성공 ({resp.status_code})")

            # 4. API 호출 테스트
            print("\n[4] 골프 예약 API 테스트...")
            api_url = "https://ananti.kr/reservation/joongang/ajax/golf-course"

            api_headers = {
                'Accept': 'application/json, text/javascript, */*; q=0.01',
                'Content-Type': 'application/json',
                'Origin': 'https://ananti.kr',
                'Referer': 'https://ananti.kr/ko/reservation/joongang/golf?memNo=2211027500&arr=&dep=',
                'X-Requested-With': 'XMLHttpRequest',
            }

            payload = {
                "memNo": "2211027500",
                "date": "20251020",
                "course": 1,
                "golfType": "GG",
                "bsns": "22"
            }

            api_resp = session.post(api_url, headers=api_headers, json=payload)
            print(f"API 응답 상태: {api_resp.status_code}")

            if api_resp.status_code == 200:
                api_data = api_resp.json()
                if api_data.get('code') == 200:
                    items = api_data.get('data', [])
                    print(f"✓ API 호출 성공! {len(items)}개 시간 조회됨")

                    if items:
                        print("\n예약 가능 시간:")
                        for item in items[:3]:
                            print(f"  {item.get('rtime')} - ₩{item.get('rate')}")
                else:
                    print(f"✗ API 에러: {api_data.get('message')}")
            else:
                print(f"✗ HTTP 에러")

        else:
            print("\n" + "=" * 70)
            print("✗ 로그인 실패")
            print("=" * 70)
            print(f"메시지: {data.get('message')}")

    except Exception as e:
        print(f"\n✗ 에러: {e}")
        print(f"응답 내용: {response.text[:200]}")

    print("\n" + "=" * 70)

if __name__ == "__main__":
    test_login()
