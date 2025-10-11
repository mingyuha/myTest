# CGV API 업데이트 진행 상황

## 날짜: 2025-10-05

## 문제 상황
CGV 웹사이트가 개편되면서 기존 HTML 스크래핑 방식이 작동하지 않음.
새로운 JSON API로 전환 필요.

## 새 API 정보

### API 엔드포인트
```
https://api-mobile.cgv.co.kr/cnm/atkt/searchMovScnInfo?coCd=A420&siteNo=0013&scnYmd={날짜}&rtctlScopCd=08
```

### 파라미터
- `coCd`: A420 (고정)
- `siteNo`: 0013 (CGV 용산 아이파크몰)
- `scnYmd`: 날짜 (YYYYMMDD 형식, 예: 20251006)
- `rtctlScopCd`: 08 (고정)

### 응답 데이터 구조
```json
{
  "statusCode": 0,
  "statusMessage": "success",
  "data": [
    {
      "tcscnsGradNm": "아이맥스",  // 또는 "4DX"
      "scnsrtTm": "0720",  // 상영 시작 시간 (HHMM)
      "prodNm": "영화제목"
    }
  ]
}
```

### 필요한 헤더 (현재 문제 지점)
```
Accept: application/json
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36
Origin: https://cgv.co.kr
Referer: https://cgv.co.kr/
x-timestamp: 1759662858  (Unix timestamp)
x-signature: DwXT3z02fhCvstj6dls5PTRC3M4z4VL2As2l1WXkO1Y=  (HMAC 서명 - 생성 방법 불명)
```

## 완료된 작업

1. **searchbot10.py 함수 수정 완료**
   - `getCGVIMax()` (lines 250-315): 새 API 사용하도록 변경
   - `getCGV4DX()` (lines 317-382): 새 API 사용하도록 변경
   - 시간 형식 변환: "0720" → "07:20"
   - 응답에서 `tcscnsGradNm` 필드로 상영관 타입 구분
     - IMAX: `tcscnsGradNm == "아이맥스"`
     - 4DX: `tcscnsGradNm == "4DX"`

2. **테스트 파일 생성**
   - `/home/lips/20251005_ananti/test_cgv_new_api.py`: CGV API 테스트용

## 현재 문제점

### 401 Unauthorized 에러
API 호출 시 401 에러 발생. `x-signature` 헤더가 필요하지만 생성 방법을 모름.

### 시도한 해결 방법들 (모두 실패)

1. **서명 없이 호출**: 401 에러
2. **예제 서명 사용**: 시간 민감형이라 실패
3. **일반적인 HMAC-SHA256 키 시도**:
   - 'cgv', 'CGV', 'cgv-mobile-api', 'api-mobile', 'searchMovScnInfo' 등 - 모두 실패
4. **URL 파라미터 포함한 서명 생성**: 실패
5. **JavaScript 파일 분석**: Next.js로 빌드된 minified 코드라 분석 어려움

## 다음 단계 (내일 진행할 작업)

### 방법 1: 브라우저 개발자 도구로 JavaScript 디버깅
```javascript
// Chrome DevTools Console에서 실행
// API 호출하는 fetch/XMLHttpRequest를 가로채서 서명 생성 로직 찾기

// 모든 fetch 호출 가로채기
const originalFetch = window.fetch;
window.fetch = function(...args) {
    console.log('Fetch called:', args);
    return originalFetch.apply(this, args);
};

// 또는 Network 탭에서 Initiator 추적하여 호출 스택 확인
```

### 방법 2: 브라우저 확장 프로그램 사용
- ModHeader 또는 Requestly로 실제 요청 캡처
- 여러 요청의 timestamp와 signature 수집하여 패턴 분석

### 방법 3: 프록시 도구 사용
```bash
# mitmproxy 설치 및 사용
pip install mitmproxy
mitmproxy

# 브라우저 프록시 설정 후 CGV 접속하여 실제 요청 캡처
# https://api-mobile.cgv.co.kr 호출 시점의 정확한 헤더 확인
```

### 방법 4: Selenium으로 브라우저 자동화
```python
from selenium import webdriver
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities

# 네트워크 로그 활성화
caps = DesiredCapabilities.CHROME
caps['gw:loggingPrefs'] = {'performance': 'ALL'}
driver = webdriver.Chrome(desired_capabilities=caps)

driver.get('https://cgv.co.kr/theaters/?regionCode=110')
# 네트워크 로그에서 API 호출 헤더 추출

logs = driver.get_log('performance')
# x-signature 생성 코드 찾기
```

### 방법 5: JavaScript 코드 역난독화
```bash
# Chrome DevTools Sources 탭에서
# Pretty print로 코드 정리 후
# 'signature', 'hmac', 'sha256' 검색
# Breakpoint 설정하여 실행 흐름 추적
```

### 방법 6: 대안 API 찾기
- CGV 모바일 앱의 API 분석 (앱 트래픽 스니핑)
- 구 버전 API가 아직 작동하는지 확인
- 다른 영화 정보 제공 서비스 검토

## 참고 파일

- `/home/lips/20251005_ananti/searchbot10.py` - 메인 봇 스크립트 (수정됨, 테스트 필요)
- `/home/lips/20251005_ananti/cgv요청헤더.txt` - 브라우저에서 캡처한 요청 헤더 (418KB)
- `/home/lips/20251005_ananti/test_cgv_new_api.py` - CGV API 테스트 스크립트

## 코드 위치

### searchbot10.py에서 수정된 함수들

**getCGVIMax() - lines 250-315**
```python
def getCGVIMax(dateStr, fileNameIMax,logger, now1):
    """CGV IMAX 상영 시간 조회 (2025 새 API)"""
    # ...
    url = f'https://api-mobile.cgv.co.kr/cnm/atkt/searchMovScnInfo?coCd=A420&siteNo=0013&scnYmd={dateStr}&rtctlScopCd=08'
    # x-signature 헤더 추가 필요!!!
```

**getCGV4DX() - lines 317-382**
```python
def getCGV4DX(dateStr, fileName,logger, now1):
    """CGV 4DX 상영 시간 조회 (2025 새 API)"""
    # ...
    url = f'https://api-mobile.cgv.co.kr/cnm/atkt/searchMovScnInfo?coCd=A420&siteNo=0013&scnYmd={dateStr}&rtctlScopCd=08'
    # x-signature 헤더 추가 필요!!!
```

## 해결해야 할 핵심 문제

**x-signature 생성 알고리즘 찾기**

가능성:
1. HMAC-SHA256 (secret key 필요)
2. JWT 토큰 기반
3. 특정 알고리즘 + timestamp + URL params
4. 사용자별 API 키 필요 (로그인 필요?)

## 추가 정보

브라우저 요청 헤더 전체:
```
:authority: api-mobile.cgv.co.kr
:method: GET
:path: /cnm/atkt/searchMovScnInfo?coCd=A420&siteNo=0013&scnYmd=20251006&rtctlScopCd=08
:scheme: https
accept: application/json
accept-encoding: gzip, deflate, br, zstd
accept-language: ko-KR
cookie: _cfuvid=...; _ga=...; __cf_bm=...; _ga_HV92ZRC3WF=...
origin: https://cgv.co.kr
priority: u=1, i
referer: https://cgv.co.kr/
sec-ch-ua: "Chromium";v="140", "Not=A?Brand";v="24", "Google Chrome";v="140"
sec-ch-ua-mobile: ?0
sec-ch-ua-platform: "Windows"
sec-fetch-dest: empty
sec-fetch-mode: cors
sec-fetch-site: same-site
user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36
x-signature: DwXT3z02fhCvstj6dls5PTRC3M4z4VL2As2l1WXkO1Y=
x-timestamp: 1759662858
```

## 내일 첫 시도할 방법

**Chrome DevTools에서 직접 디버깅:**

1. https://cgv.co.kr 접속
2. F12 → Network 탭 열기
3. 상영시간표 페이지 이동
4. `searchMovScnInfo` API 호출 찾기
5. Initiator 탭에서 호출한 JavaScript 코드 확인
6. 해당 JS 파일 Sources에서 열기
7. Pretty print 후 signature 생성 코드 검색
8. Breakpoint 설정하여 실행 시 변수 확인

이게 가장 빠르고 확실한 방법일 것으로 예상됨.
