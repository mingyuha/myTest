import requests
import json
from datetime import datetime

def test_ananti_reservation():
    """아난티 골프 예약 시스템 분석"""

    session = requests.Session()

    # User-Agent 설정
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7'
    }
    session.headers.update(headers)

    print("=" * 60)
    print("1. 로그인 페이지 접속")
    print("=" * 60)

    # 로그인 페이지 먼저 방문 (쿠키 등을 받기 위해)
    login_page_url = "https://me.ananti.kr/user/signin"
    response = session.get(login_page_url)
    print(f"로그인 페이지 상태: {response.status_code}")

    # 로그인 시도
    print("\n" + "=" * 60)
    print("2. 로그인 시도")
    print("=" * 60)

    # 로그인 API 엔드포인트를 찾아야 함
    # 일반적으로 /api/login, /user/login, /auth/login 등의 형태
    login_urls = [
        "https://me.ananti.kr/user/signin",
        "https://me.ananti.kr/api/user/signin",
        "https://ananti.kr/api/auth/login",
        "https://me.ananti.kr/api/auth/signin"
    ]

    login_data = {
        'userId': '2211027500',
        'password': 'hateyou1@3',
        'userPw': 'hateyou1@3',
        'id': '2211027500',
        'pw': 'hateyou1@3',
        'loginId': '2211027500',
        'loginPw': 'hateyou1@3'
    }

    # POST로 로그인 시도
    for login_url in login_urls:
        try:
            print(f"\n시도 URL: {login_url}")
            response = session.post(login_url, data=login_data)
            print(f"응답 상태: {response.status_code}")
            print(f"응답 길이: {len(response.text)}")

            if response.status_code == 200:
                print("성공 가능성 있음")
                # 쿠키 확인
                print(f"쿠키: {session.cookies.get_dict()}")
                break
        except Exception as e:
            print(f"에러: {e}")
            continue

    # 예약 페이지 접속 시도
    print("\n" + "=" * 60)
    print("3. 예약 페이지 접속")
    print("=" * 60)

    reservation_url = "https://ananti.kr/ko/reservation/joongang/golf?memNo=2211027500&arr=&dep="
    response = session.get(reservation_url)
    print(f"예약 페이지 상태: {response.status_code}")
    print(f"최종 URL: {response.url}")

    if response.status_code == 200:
        print("\n페이지 내용 분석 중...")
        # API 엔드포인트 찾기
        content = response.text

        # 자주 사용되는 API 패턴 찾기
        import re
        api_patterns = [
            r'https?://[^"\s]+/api/[^"\s]+',
            r'/api/[^"\s]+',
            r'reservation-proc',
            r'getTimeList',
            r'golf[^"\s]*api'
        ]

        for pattern in api_patterns:
            matches = re.findall(pattern, content)
            if matches:
                print(f"\n발견된 패턴 ({pattern}):")
                for match in set(matches[:5]):  # 중복 제거하고 최대 5개만
                    print(f"  - {match}")

    # 구 API 엔드포인트 시도
    print("\n" + "=" * 60)
    print("4. 기존 API 엔드포인트 테스트")
    print("=" * 60)

    old_api_url = "https://joongang.ananti.kr/kr/reservation/reservation-proc.asp"
    test_date = "2025-10-21"

    data = {
        'frm_flag': 'getTimeList',
        'frm_RsvnDate': test_date,
        'frm_memNo': '2211027500',
        'frm_timezone': ''
    }

    try:
        response = session.post(old_api_url, data=data)
        print(f"구 API 상태: {response.status_code}")
        print(f"응답: {response.text[:500]}")
    except Exception as e:
        print(f"구 API 에러: {e}")

    # 새로운 API 시도
    print("\n" + "=" * 60)
    print("5. 새로운 API 엔드포인트 추측 및 테스트")
    print("=" * 60)

    new_api_urls = [
        "https://ananti.kr/api/reservation/joongang/golf/times",
        "https://ananti.kr/api/reservation/times",
        "https://ananti.kr/ko/reservation/joongang/golf/api/times",
        "https://api.ananti.kr/reservation/golf/times",
        "https://ananti.kr/api/golf/reservation/times"
    ]

    for api_url in new_api_urls:
        try:
            print(f"\n시도: {api_url}")
            # GET 시도
            response = session.get(f"{api_url}?date={test_date}&memNo=2211027500")
            print(f"GET 상태: {response.status_code}, 길이: {len(response.text)}")

            # POST 시도
            response = session.post(api_url, json={'date': test_date, 'memNo': '2211027500'})
            print(f"POST 상태: {response.status_code}, 길이: {len(response.text)}")

        except Exception as e:
            print(f"에러: {e}")

    print("\n" + "=" * 60)
    print("세션 쿠키 정보:")
    print("=" * 60)
    print(session.cookies.get_dict())

if __name__ == "__main__":
    test_ananti_reservation()
