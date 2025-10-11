#!/usr/bin/env python3
"""
아난티 골프 예약 시스템 분석 및 테스트
2025년 사이트 구조 변경 대응
"""

import requests
import json
import sys
from datetime import datetime

def login_ananti(session, user_id, password):
    """
    아난티 로그인
    Args:
        session: requests.Session 객체
        user_id: 사용자 ID (회원번호)
        password: 비밀번호
    Returns:
        (success: bool, message: str)
    """
    print(f"\n[로그인 시도] ID: {user_id}")

    # 1. 로그인 페이지 방문 (세션 초기화)
    session.get("https://me.ananti.kr/user/signin")

    # 2. 로그인 요청
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

    response = session.post(login_url, data=login_data, allow_redirects=False)

    try:
        data = response.json()
        if data.get('code') == '200':
            print(f"✓ 로그인 성공")
            return True, "성공"
        else:
            print(f"✗ 로그인 실패: {data.get('message')}")
            return False, data.get('message', '알 수 없는 오류')
    except:
        print(f"✗ 로그인 응답 파싱 실패")
        return False, "응답 파싱 실패"


def get_golf_times_new_api(session, date_str, mem_no):
    """
    새로운 API로 골프 예약 시간 조회 (추측)
    Args:
        session: 로그인된 세션
        date_str: 날짜 (YYYY-MM-DD 형식)
        mem_no: 회원번호
    Returns:
        예약 가능 시간 리스트 또는 None
    """
    print(f"\n[새 API 테스트] 날짜: {date_str}")

    session.headers.update({
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': 'https://ananti.kr/ko/reservation/joongang/golf'
    })

    # 시도할 API 엔드포인트들
    api_endpoints = [
        {
            'url': 'https://ananti.kr/api/reservation/joongang/golf/schedule',
            'method': 'GET',
            'params': {'date': date_str, 'memNo': mem_no}
        },
        {
            'url': 'https://ananti.kr/api/golf/joongang/schedule',
            'method': 'GET',
            'params': {'date': date_str}
        },
        {
            'url': 'https://ananti.kr/api/reservation/schedule',
            'method': 'POST',
            'json': {'date': date_str, 'resort': 'joongang', 'type': 'golf', 'memNo': mem_no}
        },
        {
            'url': 'https://ananti.kr/ko/api/reservation/golf',
            'method': 'GET',
            'params': {'date': date_str, 'resort': 'joongang'}
        },
    ]

    for endpoint in api_endpoints:
        url = endpoint['url']
        method = endpoint['method']

        print(f"\n  시도: {method} {url}")

        try:
            if method == 'GET':
                response = session.get(url, params=endpoint.get('params', {}))
            else:
                response = session.post(url, json=endpoint.get('json', {}))

            print(f"  상태: {response.status_code}")

            if response.status_code == 200:
                content_type = response.headers.get('Content-Type', '')

                if 'json' in content_type:
                    try:
                        data = response.json()
                        print(f"  ✓ JSON 응답 받음")
                        print(f"  응답 구조: {json.dumps(data, indent=2, ensure_ascii=False)[:500]}")
                        return data
                    except:
                        print(f"  ✗ JSON 파싱 실패")
                else:
                    print(f"  ✗ HTML 응답 (API 아님)")
            elif response.status_code == 401:
                print(f"  ✗ 인증 필요 (로그인 상태 확인)")
            elif response.status_code == 404:
                print(f"  ✗ API 없음")

        except Exception as e:
            print(f"  에러: {e}")

    return None


def get_golf_times_old_api(session, date_str, mem_no):
    """
    기존 API로 골프 예약 시간 조회
    Args:
        session: 세션
        date_str: 날짜 (YYYY-MM-DD 형식)
        mem_no: 회원번호
    Returns:
        예약 가능 시간 리스트 또는 None
    """
    print(f"\n[기존 API 테스트] 날짜: {date_str}")

    old_api_url = "https://joongang.ananti.kr/kr/reservation/reservation-proc.asp"

    data = {
        'frm_flag': 'getTimeList',
        'frm_RsvnDate': date_str,
        'frm_memNo': mem_no,
        'frm_timezone': ''
    }

    try:
        response = session.post(old_api_url, data=data)
        print(f"  상태: {response.status_code}")

        if response.status_code == 200:
            content_type = response.headers.get('Content-Type', '')

            if 'json' in content_type:
                try:
                    json_data = response.json()
                    print(f"  ✓ JSON 응답:")
                    print(f"  {json.dumps(json_data, indent=2, ensure_ascii=False)[:500]}")
                    return json_data
                except:
                    print(f"  ✗ JSON 파싱 실패")
            else:
                print(f"  ✗ HTML 응답 (API 변경됨)")
                print(f"  응답 일부: {response.text[:200]}")

    except Exception as e:
        print(f"  에러: {e}")

    return None


def parse_available_times(data, target_times=['06:', '07:', '08:']):
    """
    응답 데이터에서 예약 가능한 시간 추출
    Args:
        data: API 응답 데이터
        target_times: 찾고자 하는 시간대 (예: ['06:', '07:', '08:'])
    Returns:
        예약 가능 시간 리스트
    """
    available = []

    if not data:
        return available

    # 기존 API 형식 (rtnData 배열)
    if 'rtnData' in data and isinstance(data['rtnData'], list):
        for item in data['rtnData']:
            r_time = item.get('R_TIME', '')[:3]
            status = item.get('STATUS_DESC', '')
            course = item.get('COURSE_NAME', '')

            if '예약가능' in status and r_time in target_times:
                available.append({
                    'time': item.get('R_TIME'),
                    'course': course,
                    'status': status
                })

    # 새 API 형식 (추측) - 다양한 형식 대응
    elif isinstance(data, list):
        for item in data:
            # 시간 정보 찾기
            time_key = None
            for key in ['time', 'r_time', 'rTime', 'startTime', 'teeTime']:
                if key in item:
                    time_key = key
                    break

            if time_key:
                r_time = str(item.get(time_key, ''))[:3]
                status = item.get('status', item.get('STATUS', item.get('available', '')))
                course = item.get('course', item.get('courseName', item.get('COURSE_NAME', '')))

                # 예약 가능 여부 확인
                is_available = False
                if isinstance(status, bool):
                    is_available = status
                elif isinstance(status, str):
                    is_available = '가능' in status or 'available' in status.lower()

                if is_available and r_time in target_times:
                    available.append({
                        'time': item.get(time_key),
                        'course': course,
                        'status': status
                    })

    return available


def main():
    """메인 함수"""

    # 설정
    USER_ID = '2211027500'
    PASSWORD = 'hateyou1@3'
    TEST_DATE = '2025-10-21'
    TARGET_TIMES = ['06:', '07:', '08:']

    print("=" * 60)
    print("아난티 골프 예약 시스템 분석")
    print("=" * 60)

    # 세션 생성
    session = requests.Session()
    session.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    })

    # 1. 로그인 시도
    success, msg = login_ananti(session, USER_ID, PASSWORD)

    if not success:
        print(f"\n경고: 로그인 실패 ({msg})")
        print("  - 로그인 정보를 확인하세요")
        print("  - 사이트에서 직접 로그인하여 정확한 ID 형식을 확인하세요")
        print("\n로그인 없이 API 테스트를 계속합니다...")

    # 2. 기존 API 테스트
    print("\n" + "=" * 60)
    print("1. 기존 API 테스트")
    print("=" * 60)

    old_data = get_golf_times_old_api(session, TEST_DATE, USER_ID)

    if old_data:
        available = parse_available_times(old_data, TARGET_TIMES)
        if available:
            print(f"\n✓ 기존 API 작동 - {len(available)}개 시간대 발견")
            for item in available:
                print(f"  {item['time']} - {item['course']} ({item['status']})")
        else:
            print(f"\n- 기존 API 작동하나 원하는 시간대({TARGET_TIMES}) 없음")
    else:
        print("\n✗ 기존 API 작동하지 않음 (사이트 변경됨)")

    # 3. 새 API 테스트
    print("\n" + "=" * 60)
    print("2. 새 API 탐색")
    print("=" * 60)

    new_data = get_golf_times_new_api(session, TEST_DATE, USER_ID)

    if new_data:
        print(f"\n✓ 새 API 발견!")
        available = parse_available_times(new_data, TARGET_TIMES)
        if available:
            print(f"\n✓ {len(available)}개 시간대 발견")
            for item in available:
                print(f"  {item['time']} - {item['course']} ({item['status']})")
    else:
        print("\n✗ 새 API를 자동으로 찾지 못했습니다")
        print("\n다음 단계:")
        print("  1. 브라우저에서 https://ananti.kr/ko/reservation/joongang/golf 접속")
        print("  2. 개발자 도구 (F12) > Network 탭 열기")
        print("  3. 날짜 선택하여 예약 시간 조회")
        print("  4. Network 탭에서 API 호출 찾기 (XHR/Fetch 필터)")
        print("  5. 발견된 API URL과 파라미터를 이 스크립트에 추가")

    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()
