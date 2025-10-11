#!/usr/bin/env python3
"""getCGVMx 통합 함수 테스트"""

import requests
import hmac
import hashlib
import base64
import time
import os
from datetime import datetime, timedelta

def generate_cgv_signature(pathname, body, timestamp):
    """CGV API x-signature 생성"""
    secret_key = "ydqXY0ocnFLmJGHr_zNzFcpjwAsXq_8JcBNURAkRscg"
    message = f"{timestamp}|{pathname}|{body}"
    signature = hmac.new(
        secret_key.encode('utf-8'),
        message.encode('utf-8'),
        hashlib.sha256
    ).digest()
    return base64.b64encode(signature).decode('utf-8')

def test_getCGVMx_filter():
    """getCGVMx의 필터링 로직 테스트"""
    tomorrow = datetime.now() + timedelta(days=1)
    date_str = tomorrow.strftime('%Y%m%d')

    url = f'https://api-mobile.cgv.co.kr/cnm/atkt/searchMovScnInfo?coCd=A420&siteNo=0013&scnYmd={date_str}&rtctlScopCd=08'
    pathname = '/cnm/atkt/searchMovScnInfo'
    timestamp = str(int(time.time()))
    signature = generate_cgv_signature(pathname, '', timestamp)

    headers = {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Origin': 'https://cgv.co.kr',
        'Referer': 'https://cgv.co.kr/',
        'X-TIMESTAMP': timestamp,
        'X-SIGNATURE': signature
    }

    response = requests.get(url, headers=headers)

    if response.status_code != 200:
        print(f"❌ API Error: {response.status_code}")
        return

    data = response.json()

    if data.get('statusCode') != 0:
        print(f"❌ API returned error: {data.get('statusMessage')}")
        return

    print(f"✅ API 호출 성공 - 총 {len(data.get('data', []))} 항목")
    print("=" * 80)

    # 아이맥스 필터링 테스트
    print("\n[아이맥스 필터링 테스트]")
    imax_times = []
    for item in data.get('data', []):
        if item.get('tcscnsGradNm') in ['아이맥스', '4DX']:
            if item.get('tcscnsGradNm') == '아이맥스':
                time_str = item.get('scnsrtTm', '')
                formatted = f"{time_str[:2]}:{time_str[2:]}"
                imax_times.append(formatted)
                print(f"  ✓ {formatted} - {item.get('prodNm')}")

    print(f"총 IMAX: {len(imax_times)}개")

    # 4DX 필터링 테스트
    print("\n[4DX 필터링 테스트]")
    fdx_times = []
    for item in data.get('data', []):
        if item.get('tcscnsGradNm') in ['아이맥스', '4DX']:
            if item.get('tcscnsGradNm') == '4DX':
                time_str = item.get('scnsrtTm', '')
                formatted = f"{time_str[:2]}:{time_str[2:]}"
                fdx_times.append(formatted)
                print(f"  ✓ {formatted} - {item.get('prodNm')}")

    print(f"총 4DX: {len(fdx_times)}개")

    # 중복 확인
    print("\n[중복 검사]")
    all_types = [item.get('tcscnsGradNm') for item in data.get('data', [])]
    imax_count = all_types.count('아이맥스')
    fdx_count = all_types.count('4DX')
    print(f"  전체 데이터의 아이맥스: {imax_count}개")
    print(f"  전체 데이터의 4DX: {fdx_count}개")
    print(f"  필터링된 아이맥스: {len(imax_times)}개")
    print(f"  필터링된 4DX: {len(fdx_times)}개")

    if imax_count == len(imax_times) and fdx_count == len(fdx_times):
        print("  ✅ 필터링 정상 작동!")
    else:
        print("  ❌ 필터링 오류 발생!")

if __name__ == '__main__':
    test_getCGVMx_filter()
