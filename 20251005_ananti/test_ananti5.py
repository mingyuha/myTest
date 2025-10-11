import requests
import json
import re

def test_login_and_reservation():
    """다양한 로그인 정보로 시도"""

    session = requests.Session()

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    }
    session.headers.update(headers)

    # 로그인 페이지 방문
    session.get("https://me.ananti.kr/user/signin")

    # 여러 로그인 정보 시도
    login_attempts = [
        {'userId': '2211027500', 'userPw': 'hateyou1@3'},  # 원본
        {'userId': '11027500', 'userPw': 'hateyou1@3'},    # 22 제거
        {'userId': '022-11027500', 'userPw': 'hateyou1@3'}, # 전화번호 형식?
    ]

    print("=" * 60)
    print("로그인 시도")
    print("=" * 60)

    login_url = "https://me.ananti.kr/user/signin_proc"

    session.headers.update({
        'Referer': 'https://me.ananti.kr/user/signin',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': 'https://me.ananti.kr',
        'Accept': 'application/json'
    })

    success = False
    for i, login_data in enumerate(login_attempts, 1):
        print(f"\n시도 {i}: {login_data}")
        response = session.post(login_url, data=login_data, allow_redirects=False)

        try:
            data = response.json()
            print(f"응답: {json.dumps(data, ensure_ascii=False)}")

            if data.get('code') == '200' or 'success' in data.get('message', '').lower():
                print("✓ 로그인 성공!")
                success = True
                break
        except:
            print(f"응답 (비JSON): {response.text[:200]}")

    if not success:
        print("\n모든 로그인 시도 실패")
        print("\n주의: 실제 웹사이트에서 정확한 로그인 정보 확인 필요")
        return

    # 로그인 성공 후 예약 페이지 접근
    print("\n" + "=" * 60)
    print("예약 페이지 접근")
    print("=" * 60)

    reservation_url = "https://ananti.kr/ko/reservation/joongang/golf"
    response = session.get(reservation_url)
    print(f"상태: {response.status_code}")
    print(f"URL: {response.url}")

    if 'signin' not in response.url:
        print("✓ 예약 페이지 접근 성공")

        # API 찾기
        content = response.text

        # fetch, axios, ajax 호출 찾기
        api_patterns = [
            r'fetch\(["\']([^"\']+)["\']',
            r'axios\.(get|post)\(["\']([^"\']+)["\']',
            r'url:\s*["\']([^"\']+api[^"\']*)["\']',
        ]

        print("\nAPI 엔드포인트 탐색:")
        for pattern in api_patterns:
            matches = re.findall(pattern, content)
            if matches:
                print(f"\n패턴: {pattern}")
                for match in list(set(matches))[:5]:
                    print(f"  - {match}")

        # 실제 API 호출 테스트
        test_date = "2025-10-21"

        print(f"\n" + "=" * 60)
        print(f"테스트 날짜: {test_date}")
        print("=" * 60)

        # API 시도
        api_tests = [
            ('GET', 'https://ananti.kr/api/reservation/joongang/golf/times', {'date': test_date}),
            ('GET', 'https://ananti.kr/api/golf/times', {'date': test_date, 'resort': 'joongang'}),
            ('POST', 'https://ananti.kr/api/reservation/times', {'date': test_date, 'resortCode': 'joongang'}),
        ]

        session.headers.update({
            'Accept': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
        })

        for method, url, params in api_tests:
            print(f"\n{method} {url}")
            try:
                if method == 'GET':
                    resp = session.get(url, params=params)
                else:
                    resp = session.post(url, json=params)

                print(f"상태: {resp.status_code}")
                if resp.status_code == 200:
                    try:
                        data = resp.json()
                        print(f"JSON 응답: {json.dumps(data, indent=2, ensure_ascii=False)[:500]}")
                    except:
                        print(f"HTML 응답: {resp.text[:200]}")
            except Exception as e:
                print(f"에러: {e}")

if __name__ == "__main__":
    test_login_and_reservation()
