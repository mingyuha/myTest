# searchbot10.py 새 API 적용 가이드

## 변경 사항

### 1. 수정된 함수
- `getEmersonMemDay()`: 새 API에 맞게 완전히 재작성
- `login_ananti_session()`: 새로 추가된 로그인 함수
- `job()`: 로그인 세션 생성 로직 추가

### 2. 새 API 정보
```
URL: https://ananti.kr/reservation/joongang/ajax/golf-course
Method: POST
Content-Type: application/json

요청:
{
    "memNo": "2211027500",
    "date": "20251021",
    "course": 1,  // 1=마운틴, 2=레이크, 3=스카이
    "golfType": "GG",
    "bsns": "22"
}

응답:
{
    "code": 200,
    "message": null,
    "data": [
        {
            "rtime": "06:42",
            "chCourse": "1",
            "rate": "78880",
            ...
        }
    ]
}
```

## 설정 방법

### 옵션 1: 로그인 정보 설정 (추천하지 않음 - 현재 로그인 실패)

config.ini 파일에 추가:
```ini
[DEFAULT]
ananti_user_id = 2211027500
ananti_password = your_password_here
```

**문제**: 현재 로그인 API가 "입력하신 정보와 일치하는 회원정보가 없습니다" 반환
- ID 형식이 다를 수 있음
- 로그인 방식이 변경되었을 수 있음

### 옵션 2: 쿠키 직접 설정 (임시 방편)

브라우저에서 로그인 후 쿠키를 복사하여 사용하는 방법입니다.

#### 단계:
1. 브라우저에서 https://me.ananti.kr/user/signin 로그인
2. F12 > Application > Cookies > me.ananti.kr
3. 다음 쿠키 복사:
   - `njiegnoal` (JWT 토큰)
   - `JSESSIONID`
   - `ME_SID`

4. searchbot10.py의 `login_ananti_session()` 함수 수정:

```python
def login_ananti_session(user_id, password):
    """아난티 세션 생성 - 쿠키 직접 설정"""
    session = requests.Session()

    # 브라우저에서 복사한 쿠키 설정
    cookies = {
        'ME_SID': '여기에_ME_SID_값',
        'njiegnoal': '여기에_njiegnoal_값',
        'JSESSIONID': '여기에_JSESSIONID_값',
        'org.springframework.web.servlet.i18n.CookieLocaleResolver.LOCALE': 'ko',
    }
    session.cookies.update(cookies)

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }
    session.headers.update(headers)

    return session
```

**주의**: 쿠키는 시간이 지나면 만료됩니다. 정기적으로 업데이트 필요.

### 옵션 3: 로그인 방식 재조사 (권장)

실제 웹사이트의 로그인 방식을 재확인:

1. 브라우저에서 로그인 페이지 접속
2. F12 > Network 탭 열기
3. 로그인 시도
4. Network 탭에서 `signin_proc` 또는 로그인 API 찾기
5. Request Payload 확인

**확인 사항**:
- 실제 로그인에 사용하는 ID는? (이메일? 전화번호? 회원번호?)
- 파라미터 이름은? (`userId`? `loginId`? `memberId`?)
- 추가 파라미터가 필요한가? (CSRF 토큰 등)

## 테스트 방법

### 1. 직접 API 테스트 (쿠키 사용)

```bash
# header.txt의 쿠키로 테스트
python3 test_direct_api.py
```

### 2. 새 함수 단독 테스트

```bash
python3 test_searchbot_new.py
```

### 3. 전체 searchbot10.py 실행

```bash
# config.ini와 config_param.ini 설정 후
python3 searchbot10.py
```

## 출력 예시

성공 시:
```
06:35 - 마운틴 2025-10-21 opened
06:42 - 레이크 2025-10-21 opened
07:10 - 레이크 2025-10-21 opened
07:10 - 스카이 2025-10-21 opened
07:17 - 레이크 2025-10-21 opened
07:24 - 마운틴 2025-10-21 opened
07:24 - 스카이 2025-10-21 opened
```

## 코드 변경 요약

### 주요 변경점:
1. **URL 변경**:
   - ✗ `https://joongang.ananti.kr/kr/reservation/reservation-proc.asp`
   - ✓ `https://ananti.kr/reservation/joongang/ajax/golf-course`

2. **데이터 형식 변경**:
   - ✗ Form data (`frm_flag`, `frm_RsvnDate` 등)
   - ✓ JSON (`{"memNo": "...", "date": "...", "course": 1}`)

3. **응답 구조 변경**:
   - ✗ `json_dic['rtnData']`, `sen['R_TIME']`, `sen['STATUS_DESC']`, `sen['COURSE_NAME']`
   - ✓ `json_dic['data']`, `sen['rtime']`, (상태는 응답에 포함됨), 코스는 번호(1,2,3)

4. **코스 조회 방식**:
   - 이전: 한 번 호출로 모든 코스 정보
   - 현재: 각 코스별로 3번 호출 (마운틴, 레이크, 스카이)

5. **로그인 필요**:
   - 이전: 로그인 없이 가능했을 수 있음
   - 현재: 반드시 로그인된 세션 필요

## 문제 해결

### Q: 로그인이 계속 실패합니다
**A**:
1. 실제 웹사이트에서 로그인 가능한지 확인
2. 브라우저 개발자 도구로 실제 로그인 프로세스 확인
3. 임시로 쿠키 직접 설정 방식 사용

### Q: "입력하신 정보와 일치하는 회원정보가 없습니다"
**A**:
1. ID가 '2211027500'이 맞는지 확인
2. 실제 로그인 시 사용하는 ID 형식 확인 (앞에 0이 있나? 다른 형식?)
3. 전화번호나 이메일로 로그인하는지 확인

### Q: API 호출은 성공하지만 데이터가 없습니다
**A**:
1. 해당 날짜에 실제로 예약 가능한 시간이 없을 수 있음
2. `arrange_time` 설정 확인 (현재: `{'06:', '07:', '08:', '09:', '11:'}`)
3. 다른 날짜로 테스트

### Q: 세션이 자동으로 끊깁니다
**A**:
1. 쿠키 만료 시간 확인
2. 로그인을 주기적으로 다시 수행
3. `login_ananti_session()` 함수를 호출 시마다 실행하도록 수정

## 향후 개선 사항

1. **로그인 방식 확정**: 실제 작동하는 로그인 API 찾기
2. **세션 유지**: 로그인을 매번 하지 않고 세션 재사용
3. **에러 처리**: 네트워크 오류, API 변경 등 대응
4. **CSRF 토큰**: 필요 시 자동 추출 및 설정
5. **리트라이**: 실패 시 재시도 로직

## 참고 파일

- `test_new_api.py`: 새 API 테스트 (로그인 포함)
- `test_direct_api.py`: 쿠키로 직접 API 호출
- `test_searchbot_new.py`: searchbot10.py 함수 테스트
- `README_API_GUIDE.md`: API 발견 가이드
- `check_ananti_new.py`: 종합 분석 스크립트
