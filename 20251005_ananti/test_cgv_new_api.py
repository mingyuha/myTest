#!/usr/bin/env python3
"""CGV 새 API 테스트"""

import requests
import json

def test_cgv_new_api():
    """CGV 새 API로 IMAX와 4DX 조회 테스트"""

    # 테스트 날짜
    test_date = '20251006'

    print("=" * 70)
    print(f"CGV 새 API 테스트 - {test_date}")
    print("=" * 70)

    # API 호출
    url = f'https://api-mobile.cgv.co.kr/cnm/atkt/searchMovScnInfo?coCd=A420&siteNo=0013&scnYmd={test_date}&rtctlScopCd=08'

    import time

    timestamp = str(int(time.time()))

    headers = {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Origin': 'https://cgv.co.kr',
        'Referer': 'https://cgv.co.kr/',
        'x-timestamp': timestamp,
        'x-signature': 'DwXT3z02fhCvstj6dls5PTRC3M4z4VL2As2l1WXkO1Y='  # Test with example signature
    }

    print(f"\n[API 호출]")
    print(f"URL: {url}")

    response = requests.get(url, headers=headers)

    print(f"상태: {response.status_code}")

    if response.status_code != 200:
        print("✗ API 호출 실패")
        return

    data = response.json()
    print(f"응답 코드: {data.get('statusCode')}")
    print(f"메시지: {data.get('statusMessage')}")

    if data.get('statusCode') != 0:
        print("✗ 데이터 없음")
        return

    # 전체 상영 정보
    all_items = data.get('data', [])
    print(f"\n총 {len(all_items)}개 상영 정보")

    # IMAX 추출
    print("\n" + "=" * 70)
    print("[IMAX 상영 시간]")
    print("=" * 70)

    imax_times = []
    for item in all_items:
        if item.get('tcscnsGradNm') == '아이맥스':
            scnsrt_time = item.get('scnsrtTm', '')
            formatted_time = scnsrt_time[:2] + ':' + scnsrt_time[2:]
            movie_name = item.get('prodNm', '')
            imax_times.append(formatted_time)
            print(f"{formatted_time} - {movie_name}")

    if imax_times:
        print(f"\n✓ IMAX {len(imax_times)}개 상영")
        print(f"텔레그램 메시지: IMAX opened in {test_date} {' '.join(imax_times)}")
    else:
        print("\nIMAX 상영 없음")

    # 4DX 추출
    print("\n" + "=" * 70)
    print("[4DX 상영 시간]")
    print("=" * 70)

    dx4_times = []
    for item in all_items:
        if item.get('tcscnsGradNm') == '4DX':
            scnsrt_time = item.get('scnsrtTm', '')
            formatted_time = scnsrt_time[:2] + ':' + scnsrt_time[2:]
            movie_name = item.get('prodNm', '')
            dx4_times.append(formatted_time)
            print(f"{formatted_time} - {movie_name}")

    if dx4_times:
        print(f"\n✓ 4DX {len(dx4_times)}개 상영")
        print(f"텔레그램 메시지: 4DX opened in {test_date} {' '.join(dx4_times)}")
    else:
        print("\n4DX 상영 없음")

    # 기타 특별관
    print("\n" + "=" * 70)
    print("[기타 특별관]")
    print("=" * 70)

    other_types = set()
    for item in all_items:
        grad_nm = item.get('tcscnsGradNm', '')
        if grad_nm and grad_nm not in ['일반', '아이맥스', '4DX']:
            other_types.add(grad_nm)

    if other_types:
        print("발견된 기타 상영관 타입:")
        for t in sorted(other_types):
            count = sum(1 for item in all_items if item.get('tcscnsGradNm') == t)
            print(f"  - {t}: {count}개")
    else:
        print("기타 특별관 없음")

    print("\n" + "=" * 70)
    print("✓ 테스트 완료")
    print("=" * 70)


if __name__ == "__main__":
    test_cgv_new_api()
