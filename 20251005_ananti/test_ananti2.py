import requests
import json
import re

def analyze_login_page():
    """로그인 페이지 분석하여 실제 로그인 API 찾기"""

    session = requests.Session()

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    }
    session.headers.update(headers)

    # 로그인 페이지 가져오기
    login_page_url = "https://me.ananti.kr/user/signin"
    response = session.get(login_page_url)

    print("=" * 60)
    print("로그인 페이지 분석")
    print("=" * 60)

    content = response.text

    # form action 찾기
    form_actions = re.findall(r'<form[^>]*action=["\']([^"\']+)["\']', content)
    print("\n발견된 Form Actions:")
    for action in form_actions:
        print(f"  - {action}")

    # API 엔드포인트 찾기
    api_endpoints = re.findall(r'["\']([^"\']*(?:api|auth|login|signin)[^"\']*)["\']', content)
    print("\n발견된 API 관련 엔드포인트 (중복 제거):")
    unique_endpoints = list(set([e for e in api_endpoints if len(e) > 5 and len(e) < 100]))
    for endpoint in unique_endpoints[:20]:
        print(f"  - {endpoint}")

    # input 필드 찾기
    input_fields = re.findall(r'<input[^>]*name=["\']([^"\']+)["\']', content)
    print("\n발견된 Input 필드명:")
    for field in set(input_fields):
        print(f"  - {field}")

    # CSRF 토큰 찾기
    csrf_matches = re.findall(r'_csrf["\']?\s*(?:content|value)=["\']([^"\']+)["\']', content)
    if csrf_matches:
        print(f"\nCSRF 토큰: {csrf_matches[0]}")

    # meta 태그의 csrf
    csrf_meta = re.findall(r'<meta name=["\']_csrf["\'] content=["\']([^"\']+)["\']', content)
    if csrf_meta:
        print(f"CSRF 토큰 (meta): {csrf_meta[0]}")
        csrf_token = csrf_meta[0]
    else:
        csrf_token = None

    # 실제 로그인 시도
    print("\n" + "=" * 60)
    print("로그인 시도")
    print("=" * 60)

    # 가능한 로그인 데이터 조합들
    login_attempts = [
        {
            'url': 'https://me.ananti.kr/user/signin',
            'data': {
                'userId': '2211027500',
                'userPw': 'hateyou1@3',
            }
        },
        {
            'url': 'https://me.ananti.kr/api/user/signin',
            'data': {
                'userId': '2211027500',
                'userPw': 'hateyou1@3',
            }
        },
        {
            'url': 'https://me.ananti.kr/user/signin',
            'data': {
                'id': '2211027500',
                'pw': 'hateyou1@3',
            }
        },
    ]

    # CSRF 토큰이 있으면 추가
    if csrf_token:
        for attempt in login_attempts:
            attempt['data']['_csrf'] = csrf_token

    for i, attempt in enumerate(login_attempts, 1):
        print(f"\n시도 {i}: {attempt['url']}")
        print(f"데이터: {attempt['data']}")

        try:
            # Referer 추가
            session.headers.update({
                'Referer': 'https://me.ananti.kr/user/signin',
                'Content-Type': 'application/x-www-form-urlencoded'
            })

            response = session.post(attempt['url'], data=attempt['data'], allow_redirects=False)
            print(f"상태 코드: {response.status_code}")
            print(f"응답 길이: {len(response.text)}")

            # 리다이렉트 확인
            if 'Location' in response.headers:
                print(f"리다이렉트: {response.headers['Location']}")

            # 성공 여부 확인 (쿠키 변화, 리다이렉트 등)
            print(f"쿠키: {dict(session.cookies)}")

            # 응답 내용 일부 출력
            if len(response.text) < 500:
                print(f"응답 내용: {response.text}")
            else:
                print(f"응답 일부: {response.text[:300]}")

            # 리다이렉트 따라가기
            if response.status_code in [301, 302, 303, 307, 308]:
                redirect_url = response.headers.get('Location')
                if redirect_url:
                    print(f"\n리다이렉트 따라가기: {redirect_url}")
                    if not redirect_url.startswith('http'):
                        redirect_url = 'https://me.ananti.kr' + redirect_url
                    response2 = session.get(redirect_url)
                    print(f"리다이렉트 후 상태: {response2.status_code}")

        except Exception as e:
            print(f"에러: {e}")

    # 로그인 후 예약 페이지 접근 시도
    print("\n" + "=" * 60)
    print("예약 페이지 접근")
    print("=" * 60)

    reservation_url = "https://ananti.kr/ko/reservation/joongang/golf"
    response = session.get(reservation_url)
    print(f"상태 코드: {response.status_code}")
    print(f"최종 URL: {response.url}")

    # 로그인 성공 여부 확인
    if 'signin' not in response.url:
        print("\n✓ 로그인 성공!")

        # 페이지 내용에서 API 엔드포인트 찾기
        content = response.text

        # JavaScript 코드에서 API 호출 찾기
        api_calls = re.findall(r'(?:fetch|ajax|post|get)\s*\(["\']([^"\']+)["\']', content)
        print("\nJavaScript API 호출:")
        for api in set(api_calls[:10]):
            print(f"  - {api}")

        # URL 패턴 찾기
        urls = re.findall(r'["\']https?://[^"\']+["\']', content)
        print("\n발견된 URL:")
        for url in set(urls[:10]):
            print(f"  - {url}")

    else:
        print("\n✗ 로그인 실패 - 여전히 로그인 페이지로 리다이렉트됨")

if __name__ == "__main__":
    analyze_login_page()
