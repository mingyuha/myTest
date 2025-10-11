#!/usr/bin/env python3
import requests
import re

session = requests.Session()
session.headers.update({
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
})

# 로그인
session.get('https://me.ananti.kr/user/signin')
login_data = {'cmUserId': '2211027500', 'cmUserPw': 'hateyou1@3', 'saveId': ''}
session.headers.update({'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8', 'X-Requested-With': 'XMLHttpRequest'})
session.post('https://me.ananti.kr/user/signin_proc', data=login_data)

# 예약 페이지
resp = session.get('https://ananti.kr/ko/reservation/joongang/golf?memNo=2211027500&arr=&dep=')
html = resp.text

# CSRF 토큰 찾기
patterns = [
    (r'<meta\s+name=["\']_csrf["\']\s+content=["\']([^"\']+)["\']', 'meta name first'),
    (r'<meta\s+content=["\']([^"\']+)["\']\s+name=["\']_csrf["\']', 'meta content first'),
    (r'csrfToken["\']?\s*[:=]\s*["\']([^"\']+)["\']', 'csrfToken variable'),
    (r'_csrf["\']?\s*[:=]\s*["\']([^"\']+)["\']', '_csrf variable'),
]

print('CSRF 토큰 검색:')
csrf_token = None
for pattern, desc in patterns:
    match = re.search(pattern, html, re.IGNORECASE)
    if match:
        csrf_token = match.group(1)
        print(f'✓ 발견! ({desc})')
        print(f'  토큰: {csrf_token}')
        break

if not csrf_token:
    print('✗ 패턴 매칭 실패')
    print('\nHTML에서 csrf 관련 코드 검색:')
    count = 0
    for line in html.split('\n'):
        if 'csrf' in line.lower():
            print(f'  {line.strip()[:200]}')
            count += 1
            if count >= 10:
                break

    if count == 0:
        print('  csrf 관련 코드 없음')
