#!/usr/bin/env python3
"""완전한 플로우: 로그인 → 예약페이지 방문 → API 호출"""

import requests
import json

session = requests.Session()
session.headers.update({
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
})

print("=" * 70)
print("완전한 플로우 테스트")
print("=" * 70)

# 1. me.ananti.kr 로그인
print("\n[1] me.ananti.kr 로그인...")
session.get('https://me.ananti.kr/user/signin')

login_data = {
    'cmUserId': '2211027500',
    'cmUserPw': 'hateyou1@3',
    'saveId': ''
}

session.headers.update({
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    'X-Requested-With': 'XMLHttpRequest',
    'Origin': 'https://me.ananti.kr',
    'Referer': 'https://me.ananti.kr/user/signin'
})

resp = session.post('https://me.ananti.kr/user/signin_proc', data=login_data)
login_result = resp.json()
print(f"로그인 결과: {login_result}")

if login_result.get('code') != '200':
    print("✗ 로그인 실패")
    exit(1)

print("✓ 로그인 성공")

# 2. ananti.kr 메인 페이지 방문
print("\n[2] ananti.kr 메인 페이지 방문...")
resp = session.get('https://ananti.kr/ko')
print(f"상태: {resp.status_code}")

# 3. 예약 페이지 방문 (중요!)
print("\n[3] 골프 예약 페이지 방문...")
golf_url = 'https://ananti.kr/ko/reservation/joongang/golf?memNo=2211027500&arr=&dep='
resp = session.get(golf_url)
print(f"상태: {resp.status_code}")
print(f"URL: {resp.url}")

if 'signin' in resp.url:
    print("✗ 로그인 페이지로 리다이렉트됨")
else:
    print("✓ 예약 페이지 접근 성공")

# 4. 쿠키 확인
print("\n[4] 현재 쿠키 상태:")
for cookie in session.cookies:
    print(f"  {cookie.name} (domain={cookie.domain}): {cookie.value[:40]}...")

# 5. API 호출
print("\n[5] 골프 예약 API 호출...")
api_url = "https://ananti.kr/reservation/joongang/ajax/golf-course"

session.headers.update({
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Content-Type': 'application/json',
    'Origin': 'https://ananti.kr',
    'Referer': golf_url,
    'X-Requested-With': 'XMLHttpRequest'
})

payload = {
    "memNo": "2211027500",
    "date": "20251020",
    "course": 1,
    "golfType": "GG",
    "bsns": "22"
}

print(f"URL: {api_url}")
print(f"Payload: {json.dumps(payload, ensure_ascii=False)}")

api_resp = session.post(api_url, json=payload)

print(f"\nAPI 응답 상태: {api_resp.status_code}")

if api_resp.status_code == 200:
    try:
        api_data = api_resp.json()
        print(f"응답 코드: {api_data.get('code')}")

        if api_data.get('code') == 200:
            items = api_data.get('data', [])
            print(f"\n✓✓✓ 성공! ✓✓✓")
            print(f"총 {len(items)}개 티타임 조회됨 (마운틴 코스)")

            if items:
                print("\n예약 가능 시간:")
                for idx, item in enumerate(items, 1):
                    print(f"{idx}. {item.get('rtime')} - ₩{item.get('rate')} (정원: {item.get('totalCnt')})")

                # 6:,7:,8: 시간대 필터링
                target_times = ['06:', '07:', '08:']
                filtered = [item for item in items if item.get('rtime', '')[:3] in target_times]

                if filtered:
                    print(f"\n원하는 시간대 ({', '.join(target_times)}): {len(filtered)}개")
                    print("\n텔레그램 메시지:")
                    for item in filtered:
                        print(f"  {item.get('rtime')}: 마운틴 2025-10-20 opened")
        else:
            print(f"✗ API 에러: {api_data.get('message')}")
            print(f"전체 응답: {json.dumps(api_data, indent=2, ensure_ascii=False)}")

    except Exception as e:
        print(f"✗ JSON 파싱 에러: {e}")
        print(f"응답: {api_resp.text[:300]}")

elif api_resp.status_code == 403:
    print("✗ 403 Forbidden")
    print(f"응답: {api_resp.text[:300]}")

else:
    print(f"✗ HTTP {api_resp.status_code}")
    print(f"응답: {api_resp.text[:300]}")

print("\n" + "=" * 70)
