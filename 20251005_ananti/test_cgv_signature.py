#!/usr/bin/env python3
"""CGV API 서명 테스트"""

import requests
import hmac
import hashlib
import base64
import time
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

def test_cgv_api():
    """CGV API 테스트"""
    # 내일 날짜
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

    print(f"Testing CGV API for date: {date_str}")
    print(f"URL: {url}")
    print(f"Timestamp: {timestamp}")
    print(f"Signature: {signature}")
    print("-" * 80)

    response = requests.get(url, headers=headers)

    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.text[:500]}")
    print("-" * 80)

    if response.status_code == 200:
        data = response.json()
        print(f"Status Code in JSON: {data.get('statusCode')}")
        print(f"Status Message: {data.get('statusMessage')}")

        if data.get('statusCode') == 0:
            print(f"\n✅ SUCCESS! Found {len(data.get('data', []))} items")

            # IMAX 상영 시간
            imax_times = []
            for item in data.get('data', []):
                if item.get('tcscnsGradNm') == '아이맥스':
                    time_str = item.get('scnsrtTm', '')
                    formatted = f"{time_str[:2]}:{time_str[2:]}"
                    imax_times.append(formatted)
                    print(f"  IMAX - {item.get('prodNm')} at {formatted}")

            # 4DX 상영 시간
            fdx_times = []
            for item in data.get('data', []):
                if item.get('tcscnsGradNm') == '4DX':
                    time_str = item.get('scnsrtTm', '')
                    formatted = f"{time_str[:2]}:{time_str[2:]}"
                    fdx_times.append(formatted)
                    print(f"  4DX - {item.get('prodNm')} at {formatted}")

            return True
        else:
            print(f"\n❌ API returned error: {data.get('statusMessage')}")
            return False
    else:
        print(f"\n❌ HTTP Error: {response.status_code}")
        return False

if __name__ == '__main__':
    test_cgv_api()
