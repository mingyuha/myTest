#!/usr/bin/env python3
"""새 API 테스트"""

import requests
import json
import re

def login_ananti(user_id, password):
    """아난티 로그인 및 세션 반환"""
    session = requests.Session()

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
    }
    session.headers.update(headers)

    # 1. 로그인 페이지 방문
    print("[1] 로그인 페이지 방문...")
    session.get("https://me.ananti.kr/user/signin")

    # 2. 로그인
    print("[2] 로그인 시도...")
    login_url = "https://me.ananti.kr/user/signin_proc"
    login_data = {
        'userId': user_id,
        'userPw': password,
    }

    session.headers.update({
        'Referer': 'https://me.ananti.kr/user/signin',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': 'https://me.ananti.kr',
        'Accept': 'application/json'
    })

    response = session.post(login_url, data=login_data)

    try:
        data = response.json()
        if data.get('code') == '200':
            print(f"✓ 로그인 성공")
            return session
        else:
            print(f"✗ 로그인 실패: {data.get('message')}")
            return None
    except:
        print(f"✗ 로그인 응답 파싱 실패")
        return None


def get_csrf_token(session):
    """예약 페이지에서 CSRF 토큰 추출"""
    print("[3] 예약 페이지에서 CSRF 토큰 추출...")

    url = "https://ananti.kr/ko/reservation/joongang/golf"
    response = session.get(url)

    if response.status_code != 200:
        print(f"✗ 예약 페이지 접근 실패: {response.status_code}")
        return None

    # HTML에서 CSRF 토큰 찾기
    # <meta name="_csrf" content="...">
    match = re.search(r'<meta\s+name=["\']_csrf["\']\s+content=["\']([^"\']+)["\']', response.text)
    if match:
        token = match.group(1)
        print(f"✓ CSRF 토큰 발견: {token[:20]}...")
        return token

    # JavaScript 변수에서 찾기
    match = re.search(r'_csrf["\']?\s*[:=]\s*["\']([^"\']+)["\']', response.text)
    if match:
        token = match.group(1)
        print(f"✓ CSRF 토큰 발견 (JS): {token[:20]}...")
        return token

    print("⚠ CSRF 토큰을 찾을 수 없음 (없이 시도)")
    return None


def get_golf_times(session, csrf_token, mem_no, date, course=1):
    """
    골프 예약 가능 시간 조회
    Args:
        session: 로그인된 세션
        csrf_token: CSRF 토큰
        mem_no: 회원번호
        date: 날짜 (YYYYMMDD 형식)
        course: 코스 (1=마운틴, 2=레이크, 3=스카이)
    """
    print(f"[4] 골프 예약 시간 조회 (날짜: {date}, 코스: {course})...")

    url = "https://ananti.kr/reservation/joongang/ajax/golf-course"

    headers = {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Content-Type': 'application/json',
        'Origin': 'https://ananti.kr',
        'Referer': f'https://ananti.kr/ko/reservation/joongang/golf?memNo={mem_no}&arr=&dep=',
        'X-Requested-With': 'XMLHttpRequest',
    }

    if csrf_token:
        headers['X-CSRF-Token'] = csrf_token

    payload = {
        "memNo": mem_no,
        "date": date,
        "course": course,
        "golfType": "GG",
        "bsns": "22"
    }

    print(f"  요청 URL: {url}")
    print(f"  페이로드: {json.dumps(payload, ensure_ascii=False)}")

    response = session.post(url, headers=headers, json=payload)

    print(f"  응답 상태: {response.status_code}")

    if response.status_code == 200:
        try:
            data = response.json()
            print(f"✓ 응답 성공")
            return data
        except:
            print(f"✗ JSON 파싱 실패")
            print(f"  응답: {response.text[:200]}")
            return None
    else:
        print(f"✗ 요청 실패")
        print(f"  응답: {response.text[:200]}")
        return None


def parse_times(data, target_times=['06:', '07:', '08:']):
    """응답 데이터에서 원하는 시간대 추출"""
    if not data or data.get('code') != 200:
        return []

    results = []
    items = data.get('data', [])

    course_names = {
        "1": "마운틴",
        "2": "레이크",
        "3": "스카이"
    }

    for item in items:
        rtime = item.get('rtime', '')
        if rtime[:3] in target_times:
            results.append({
                'time': rtime,
                'course': course_names.get(item.get('chCourse'), item.get('chCourse')),
                'rate': item.get('rate'),
                'totalCnt': item.get('totalCnt'),
                'guestCnt': item.get('guestCnt')
            })

    return results


def main():
    USER_ID = '2211027500'
    PASSWORD = 'hateyou1@3'
    TEST_DATE = '20251021'  # YYYYMMDD 형식
    TARGET_TIMES = ['06:', '07:', '08:']

    print("=" * 60)
    print("아난티 골프 예약 시스템 - 새 API 테스트")
    print("=" * 60)

    # 1. 로그인
    session = login_ananti(USER_ID, PASSWORD)
    if not session:
        print("\n로그인 실패로 종료")
        return

    # 2. CSRF 토큰 가져오기
    csrf_token = get_csrf_token(session)

    # 3. 각 코스별로 예약 시간 조회
    all_results = []

    for course in [1, 2, 3]:  # 1=마운틴, 2=레이크, 3=스카이
        print(f"\n{'=' * 60}")
        data = get_golf_times(session, csrf_token, USER_ID, TEST_DATE, course)

        if data:
            results = parse_times(data, TARGET_TIMES)
            all_results.extend(results)

            if results:
                print(f"✓ {len(results)}개 시간대 발견")
                for r in results:
                    print(f"  {r['time']} - {r['course']} (₩{r['rate']})")

    # 4. 최종 결과
    print("\n" + "=" * 60)
    print("최종 결과")
    print("=" * 60)

    if all_results:
        print(f"✓ 총 {len(all_results)}개 예약 가능 시간 발견\n")
        for r in sorted(all_results, key=lambda x: x['time']):
            print(f"{r['time']} - {r['course']} (₩{r['rate']})")
    else:
        print(f"원하는 시간대({TARGET_TIMES})에 예약 가능한 시간 없음")


if __name__ == "__main__":
    main()
