#!/usr/bin/env python3
"""로그인 + CSRF 토큰 추출 + API 호출"""

import requests
import json
import re

def test_full_flow():
    """전체 플로우 테스트"""

    session = requests.Session()

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
    }
    session.headers.update(headers)

    print("=" * 70)
    print("전체 플로우 테스트 (로그인 → CSRF → API)")
    print("=" * 70)

    # 1. 로그인
    print("\n[1] 로그인...")
    session.get("https://me.ananti.kr/user/signin")

    login_url = "https://me.ananti.kr/user/signin_proc"
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

    response = session.post(login_url, data=login_data)
    data = response.json()

    if data.get('code') != '200':
        print("✗ 로그인 실패")
        return

    print("✓ 로그인 성공")

    # 2. 예약 페이지 접근 및 CSRF 토큰 추출
    print("\n[2] 예약 페이지에서 CSRF 토큰 추출...")
    golf_url = "https://ananti.kr/ko/reservation/joongang/golf"
    resp = session.get(golf_url)

    print(f"예약 페이지 상태: {resp.status_code}")

    # CSRF 토큰 찾기
    csrf_token = None

    # meta 태그
    match = re.search(r'<meta\s+name=["\']_csrf["\']\s+content=["\']([^"\']+)["\']', resp.text)
    if match:
        csrf_token = match.group(1)
        print(f"✓ CSRF 토큰 발견 (meta): {csrf_token[:30]}...")

    # JavaScript 변수
    if not csrf_token:
        match = re.search(r'csrfToken\s*[:=]\s*["\']([^"\']+)["\']', resp.text)
        if match:
            csrf_token = match.group(1)
            print(f"✓ CSRF 토큰 발견 (JS): {csrf_token[:30]}...")

    if not csrf_token:
        print("⚠ CSRF 토큰 없음 (없이 시도)")

    # 3. API 호출 (CSRF 토큰 포함)
    print("\n[3] 골프 예약 API 호출...")
    api_url = "https://ananti.kr/reservation/joongang/ajax/golf-course"

    api_headers = {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Content-Type': 'application/json',
        'Origin': 'https://ananti.kr',
        'Referer': 'https://ananti.kr/ko/reservation/joongang/golf?memNo=2211027500&arr=&dep=',
        'X-Requested-With': 'XMLHttpRequest',
    }

    if csrf_token:
        api_headers['X-CSRF-Token'] = csrf_token

    payload = {
        "memNo": "2211027500",
        "date": "20251020",
        "course": 1,
        "golfType": "GG",
        "bsns": "22"
    }

    print(f"URL: {api_url}")
    print(f"CSRF 토큰: {csrf_token[:30] if csrf_token else '없음'}...")
    print(f"Payload: {payload}")

    api_resp = session.post(api_url, headers=api_headers, json=payload)
    print(f"\nAPI 응답 상태: {api_resp.status_code}")

    if api_resp.status_code == 200:
        try:
            api_data = api_resp.json()
            print(f"응답 코드: {api_data.get('code')}")

            if api_data.get('code') == 200:
                items = api_data.get('data', [])
                print(f"\n✓✓✓ API 호출 성공! ✓✓✓")
                print(f"총 {len(items)}개 티타임 조회됨")

                if items:
                    print("\n예약 가능 시간 (마운틴 코스):")
                    for idx, item in enumerate(items, 1):
                        rtime = item.get('rtime')
                        rate = item.get('rate')
                        total = item.get('totalCnt')
                        print(f"{idx}. {rtime} - ₩{rate} (정원: {total})")

                    # 원하는 시간대 필터링
                    target_times = ['06:', '07:', '08:']
                    filtered = [item for item in items if item.get('rtime', '')[:3] in target_times]

                    if filtered:
                        print(f"\n원하는 시간대({', '.join(target_times)}): {len(filtered)}개")
                        for item in filtered:
                            msg = f"{item.get('rtime')}: 마운틴 2025-10-20 opened"
                            print(f"  {msg}")
            else:
                print(f"✗ API 에러: {api_data.get('message')}")
        except Exception as e:
            print(f"✗ JSON 파싱 에러: {e}")
            print(f"응답: {api_resp.text[:200]}")

    elif api_resp.status_code == 403:
        print("✗ 403 Forbidden")
        print("응답:", api_resp.text[:200])

        # 쿠키 확인
        print("\n현재 쿠키:")
        for key in ['ME_SID', 'njiegnoal', 'JSESSIONID']:
            value = session.cookies.get(key, '없음')
            if value != '없음':
                print(f"  {key}: {value[:50]}...")
            else:
                print(f"  {key}: 없음")

    else:
        print(f"✗ HTTP {api_resp.status_code}")

    print("\n" + "=" * 70)

if __name__ == "__main__":
    test_full_flow()
