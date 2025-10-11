import requests
import json

def test_login():
    """로그인 응답 상세 분석"""

    session = requests.Session()

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    }
    session.headers.update(headers)

    # 로그인 페이지 방문
    response = session.get("https://me.ananti.kr/user/signin")

    # 로그인 시도
    login_url = "https://me.ananti.kr/user/signin_proc"

    login_data = {
        'userId': '2211027500',
        'userPw': 'hateyou1@3',
    }

    session.headers.update({
        'Referer': 'https://me.ananti.kr/user/signin',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': 'https://me.ananti.kr',
        'Accept': 'application/json, text/javascript, */*; q=0.01'
    })

    response = session.post(login_url, data=login_data, allow_redirects=False)

    print("=" * 60)
    print("로그인 응답 분석")
    print("=" * 60)
    print(f"상태 코드: {response.status_code}")
    print(f"헤더:")
    for key, value in response.headers.items():
        print(f"  {key}: {value}")

    print(f"\n쿠키: {dict(session.cookies)}")

    print(f"\n응답 내용:")
    print(response.text[:1000])

    # JSON 파싱 시도
    try:
        data = response.json()
        print(f"\nJSON 데이터:")
        print(json.dumps(data, indent=2, ensure_ascii=False))
    except:
        print("\nJSON이 아닙니다.")

if __name__ == "__main__":
    test_login()
