import requests
import json
import re

def login_and_get_golf_data():
    """아난티 로그인 및 골프 예약 데이터 가져오기"""

    session = requests.Session()

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    }
    session.headers.update(headers)

    # 1. 로그인 페이지 방문 (쿠키 얻기)
    print("=" * 60)
    print("1. 로그인 페이지 방문")
    print("=" * 60)

    login_page_url = "https://me.ananti.kr/user/signin"
    response = session.get(login_page_url)
    print(f"로그인 페이지 상태: {response.status_code}")

    # 2. 로그인 시도 (/user/signin_proc 사용)
    print("\n" + "=" * 60)
    print("2. 로그인 시도 (/user/signin_proc)")
    print("=" * 60)

    login_url = "https://me.ananti.kr/user/signin_proc"

    login_data = {
        'userId': '2211027500',
        'userPw': 'hateyou1@3',
        'saveId': 'false'  # 아이디 저장 옵션
    }

    session.headers.update({
        'Referer': 'https://me.ananti.kr/user/signin',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': 'https://me.ananti.kr'
    })

    response = session.post(login_url, data=login_data, allow_redirects=True)
    print(f"로그인 응답 상태: {response.status_code}")
    print(f"최종 URL: {response.url}")
    print(f"쿠키: {dict(session.cookies)}")

    # 3. 예약 페이지 접근
    print("\n" + "=" * 60)
    print("3. 예약 페이지 접근")
    print("=" * 60)

    reservation_url = "https://ananti.kr/ko/reservation/joongang/golf"
    response = session.get(reservation_url)
    print(f"예약 페이지 상태: {response.status_code}")
    print(f"최종 URL: {response.url}")

    if 'signin' in response.url:
        print("\n✗ 로그인 실패")
        return
    else:
        print("\n✓ 로그인 성공!")

    # 4. 페이지 소스에서 API 엔드포인트 찾기
    print("\n" + "=" * 60)
    print("4. API 엔드포인트 분석")
    print("=" * 60)

    content = response.text

    # JavaScript 파일 찾기
    js_files = re.findall(r'<script[^>]*src=["\']([^"\']+\.js[^"\']*)["\']', content)
    print(f"\nJavaScript 파일 개수: {len(js_files)}")

    # API 관련 패턴 찾기
    patterns = [
        r'["\']([^"\']*api[^"\']*golf[^"\']*)["\']',
        r'["\']([^"\']*reservation[^"\']*api[^"\']*)["\']',
        r'axios\.(get|post)\(["\']([^"\']+)["\']',
        r'fetch\(["\']([^"\']+)["\']',
        r'\$\.ajax\(\{[^}]*url:\s*["\']([^"\']+)["\']',
    ]

    for pattern in patterns:
        matches = re.findall(pattern, content)
        if matches:
            print(f"\n패턴: {pattern}")
            for match in list(set(matches))[:5]:
                print(f"  - {match}")

    # 5. 실제 날짜로 API 호출 시도
    print("\n" + "=" * 60)
    print("5. 골프 예약 API 호출 시도")
    print("=" * 60)

    test_date = "2025-10-21"

    # 다양한 API 엔드포인트 시도
    api_attempts = [
        {
            'url': 'https://ananti.kr/api/reservation/joongang/golf/times',
            'method': 'GET',
            'params': {'date': test_date, 'memNo': '2211027500'}
        },
        {
            'url': 'https://ananti.kr/api/golf/joongang/times',
            'method': 'GET',
            'params': {'date': test_date}
        },
        {
            'url': 'https://ananti.kr/ko/api/reservation/golf/times',
            'method': 'POST',
            'json': {'date': test_date, 'memNo': '2211027500', 'resortCode': 'joongang'}
        },
        {
            'url': 'https://ananti.kr/api/reservation/golf',
            'method': 'GET',
            'params': {'date': test_date, 'resort': 'joongang', 'memNo': '2211027500'}
        },
    ]

    session.headers.update({
        'Accept': 'application/json, text/plain, */*',
        'X-Requested-With': 'XMLHttpRequest'
    })

    for attempt in api_attempts:
        print(f"\n시도: {attempt['method']} {attempt['url']}")

        try:
            if attempt['method'] == 'GET':
                response = session.get(attempt['url'], params=attempt.get('params', {}))
            else:
                response = session.post(attempt['url'], json=attempt.get('json', {}))

            print(f"상태: {response.status_code}")

            if response.status_code == 200:
                print(f"응답 길이: {len(response.text)}")

                # JSON인지 확인
                try:
                    data = response.json()
                    print("✓ JSON 응답:")
                    print(json.dumps(data, indent=2, ensure_ascii=False)[:500])
                except:
                    print("HTML 응답 (첫 300자):")
                    print(response.text[:300])
        except Exception as e:
            print(f"에러: {e}")

    # 6. 페이지 내 인라인 스크립트에서 실제 API 찾기
    print("\n" + "=" * 60)
    print("6. 인라인 스크립트 분석")
    print("=" * 60)

    # script 태그 내용 추출
    scripts = re.findall(r'<script[^>]*>(.*?)</script>', content, re.DOTALL)
    print(f"인라인 스크립트 개수: {len(scripts)}")

    # API 호출 코드 찾기
    for i, script in enumerate(scripts[:10], 1):
        if 'api' in script.lower() or 'ajax' in script.lower() or 'fetch' in script.lower():
            print(f"\n--- 스크립트 {i} (일부) ---")
            # 공백 제거하고 앞 500자만
            print(script[:500].strip())

if __name__ == "__main__":
    login_and_get_golf_data()
