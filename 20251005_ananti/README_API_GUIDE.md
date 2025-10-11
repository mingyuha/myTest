# 아난티 골프 예약 API 변경 가이드

## 문제 상황
- 기존 API `https://joongang.ananti.kr/kr/reservation/reservation-proc.asp` 작동 안 함
- 사이트가 새로운 구조로 변경됨
- 로그인 방식도 변경됨

## 확인된 사항

### 1. 기존 API (searchbot10.py의 getEmersonMemDay 함수)
```python
# ✗ 작동 안 함
URL: https://joongang.ananti.kr/kr/reservation/reservation-proc.asp
Method: POST
Data: {
    'frm_flag': 'getTimeList',
    'frm_RsvnDate': '2025-10-21',
    'frm_memNo': '11027500',
    'frm_timezone': ''
}
```

### 2. 새 사이트 구조
- 로그인 페이지: `https://me.ananti.kr/user/signin`
- 로그인 API: `https://me.ananti.kr/user/signin_proc`
- 예약 페이지: `https://ananti.kr/ko/reservation/joongang/golf`
- 새 API는 **로그인 필수** (401 Unauthorized)

### 3. 로그인 문제
- 제공된 ID: `2211027500` → 로그인 실패
- 실제 로그인 ID 형식 확인 필요

## 직접 확인 방법

### 단계 1: 로그인 정보 확인
1. 브라우저에서 `https://me.ananti.kr/user/signin` 접속
2. **실제 로그인 성공하는 ID** 확인
   - 회원번호 전체? (예: 2211027500)
   - 앞자리 제외? (예: 11027500)
   - 전화번호?
   - 이메일?

### 단계 2: API 엔드포인트 찾기
1. 브라우저에서 로그인 후 예약 페이지 접속:
   ```
   https://ananti.kr/ko/reservation/joongang/golf
   ```

2. **F12** 눌러 개발자 도구 열기

3. **Network** 탭 선택

4. **XHR** 또는 **Fetch** 필터 선택

5. 달력에서 **2025-10-21** 날짜 클릭

6. Network 탭에 나타난 API 호출 확인:
   - URL은?
   - Method는? (GET/POST)
   - 파라미터는?
   - 응답 형식은?

### 예시: 찾아야 할 정보
```
URL: https://ananti.kr/api/golf/schedule  (예시)
Method: GET
Params: {
    "date": "2025-10-21",
    "resort": "joongang"
}

Response: {
    "success": true,
    "data": [
        {
            "time": "06:00",
            "course": "마운틴",
            "available": true
        },
        ...
    ]
}
```

## 적용 방법

### 단계 3: API 정보를 가지고 코드 수정

`check_ananti_new.py` 파일의 다음 부분을 수정:

```python
# 1. 로그인 정보 수정 (37-38번째 줄 근처)
USER_ID = '실제_작동하는_ID'
PASSWORD = 'hateyou1@3'

# 2. API 엔드포인트 추가 (get_golf_times_new_api 함수 내)
api_endpoints = [
    {
        'url': '여기에_실제_API_URL',  # 브라우저에서 찾은 URL
        'method': 'GET',  # 또는 'POST'
        'params': {'date': date_str}  # 실제 파라미터
    },
]
```

### 단계 4: 응답 파싱 함수 수정

브라우저에서 확인한 응답 형식에 맞게 `parse_available_times` 함수 수정

## 테스트

```bash
python3 check_ananti_new.py
```

성공하면 다음과 같이 출력됩니다:
```
✓ 로그인 성공
✓ 새 API 발견!
✓ 3개 시간대 발견
  06:00 - 마운틴 (예약가능)
  07:00 - 레이크 (예약가능)
  08:30 - 스카이 (예약가능)
```

## 빠른 테스트 스크립트

브라우저 콘솔(F12 > Console)에서 직접 테스트:

```javascript
// 1. 로그인 상태에서 실행
fetch('https://ananti.kr/api/reservation/joongang/golf/schedule?date=2025-10-21', {
    credentials: 'include'
})
.then(r => r.json())
.then(data => console.log(data))
.catch(err => console.error(err));
```

다양한 URL 패턴 시도:
```javascript
const urls = [
    '/api/golf/schedule',
    '/api/reservation/golf/times',
    '/api/joongang/golf/available',
    '/ko/api/reservation/schedule'
];

urls.forEach(url => {
    fetch(url + '?date=2025-10-21', {credentials: 'include'})
        .then(r => r.json())
        .then(data => console.log(url, '→', data))
        .catch(err => console.log(url, '→ 실패'));
});
```

## 도움이 필요하면

발견한 정보를 알려주세요:
1. 실제 로그인 성공한 ID 형식
2. Network 탭에서 찾은 API URL
3. API 요청 파라미터
4. API 응답 예시

그럼 즉시 코드를 수정해드리겠습니다!
