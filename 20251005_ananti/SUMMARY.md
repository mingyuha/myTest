# 아난티 골프 예약 시스템 업데이트 요약

## 작업 완료 사항

### ✓ 문제 파악
- **기존 API**: `https://joongang.ananti.kr/kr/reservation/reservation-proc.asp` → **작동 중단**
- **원인**: 사이트가 새로운 시스템으로 완전히 변경됨

### ✓ 새 API 발견
- **새 URL**: `https://ananti.kr/reservation/joongang/ajax/golf-course`
- **Method**: POST (JSON)
- **특징**:
  - 로그인 필수
  - 코스별로 개별 호출 (마운틴, 레이크, 스카이)
  - 응답 형식 완전히 변경

### ✓ 코드 수정 완료
파일: `searchbot10.py`

1. **새 함수 추가**: `login_ananti_session()` (39-80번째 줄)
   - 아난티 로그인 및 세션 생성

2. **함수 재작성**: `getEmersonMemDay()` (100-188번째 줄)
   - 새 API에 맞게 완전히 재작성
   - 3개 코스 모두 조회
   - 응답 구조 변경 대응

3. **job() 함수 수정**: (801-823번째 줄)
   - 로그인 세션 생성 로직 추가
   - 함수 호출 방식 변경

### ✓ 테스트 파일 생성
1. `test_direct_api.py` - 쿠키로 직접 API 테스트 (검증 완료 ✓)
2. `test_new_api.py` - 로그인 포함 전체 테스트
3. `check_ananti_new.py` - 종합 분석 스크립트
4. `demo_working.py` - 간단한 데모

### ✓ 문서 작성
1. `USAGE_GUIDE.md` - 상세 사용 가이드
2. `README_API_GUIDE.md` - API 발견 방법
3. `SUMMARY.md` - 이 파일

## 검증된 작동

2025-10-21 날짜로 테스트 성공:
```
✓ 총 7개 예약 가능 시간 발견

06:35 - 마운틴 (₩78880)
06:42 - 레이크 (₩78880)
07:10 - 레이크 (₩78880)
07:10 - 스카이 (₩78880)
07:17 - 레이크 (₩78880)
07:24 - 마운틴 (₩78880)
07:24 - 스카이 (₩78880)
```

## 남은 문제

### ⚠️ 로그인 이슈
- **문제**: `userId: 2211027500`로 로그인 시 "입력하신 정보와 일치하는 회원정보가 없습니다"
- **원인**:
  - ID 형식이 다를 수 있음
  - 실제 로그인에 다른 정보 필요 (이메일? 전화번호?)

### 해결 방법 (2가지)

#### 방법 1: 정확한 로그인 정보 확인 (권장)
1. 실제 웹사이트에서 로그인
2. F12 > Network > signin_proc 요청 확인
3. 실제 사용하는 파라미터 확인
4. `login_ananti_session()` 함수 수정

#### 방법 2: 쿠키 직접 설정 (임시)
브라우저에서 로그인 후 쿠키를 복사하여 사용:

```python
def login_ananti_session(user_id, password):
    """쿠키 직접 설정 방식"""
    session = requests.Session()

    # 브라우저 F12 > Application > Cookies에서 복사
    cookies = {
        'ME_SID': '브라우저에서_복사한_값',
        'njiegnoal': '브라우저에서_복사한_값',
        'JSESSIONID': '브라우저에서_복사한_값',
    }
    session.cookies.update(cookies)

    headers = {'User-Agent': 'Mozilla/5.0 ...'}
    session.headers.update(headers)

    return session
```

**단점**: 쿠키는 시간이 지나면 만료됨 (주기적 업데이트 필요)

## 실제 사용 방법

### 1. config.ini 설정
```ini
[DEFAULT]
ananti_user_id = 2211027500
ananti_password = hateyou1@3  # 또는 실제 비밀번호
```

### 2. searchbot10.py 실행
```bash
python3 searchbot10.py
```

### 3. 로그 확인
- 로그인 성공: "Ananti login success"
- 로그인 실패: "Ananti login failed - skipping golf reservation check"

## API 상세 정보

### 요청
```http
POST https://ananti.kr/reservation/joongang/ajax/golf-course
Content-Type: application/json

{
    "memNo": "2211027500",
    "date": "20251021",
    "course": 1,        // 1=마운틴, 2=레이크, 3=스카이
    "golfType": "GG",
    "bsns": "22"
}
```

### 응답
```json
{
    "code": 200,
    "message": null,
    "data": [
        {
            "seq": null,
            "chCourse": "1",
            "chDate": "20251020",
            "rateCd": "2",
            "guestCnt": "0",
            "totalCnt": "4",
            "rsvnType": "ORIGIN",
            "rsvnGubun": "GG",
            "rate": "78880",
            "originRate": "",
            "rateDesc": "",
            "chPart": "1",
            "rtime": "06:42"
        }
    ]
}
```

### 응답 필드 매핑
| 기존 | 새 API | 설명 |
|------|--------|------|
| `R_TIME` | `rtime` | 티타임 |
| `STATUS_DESC` | (없음) | 예약 가능 여부는 응답에 포함됨 의미 |
| `COURSE_NAME` | `chCourse` | 코스 번호 (1,2,3) |

## 주요 변경 사항

### 코드 레벨
```python
# 기존 (작동 안 함)
URL_Em_Memday = 'https://joongang.ananti.kr/kr/reservation/reservation-proc.asp'
data_Em_Memday = {
    'frm_flag': 'getTimeList',
    'frm_RsvnDate': '2025-10-21',
    'frm_memNo': '11027500',
}
res = requests.post(URL_Em_Memday, data=data_Em_Memday)

# 새 방식 (작동함)
url = "https://ananti.kr/reservation/joongang/ajax/golf-course"
payload = {
    "memNo": "2211027500",
    "date": "20251021",
    "course": 1,
    "golfType": "GG",
    "bsns": "22"
}
res = session.post(url, headers=headers, json=payload)
```

### 파싱 변경
```python
# 기존
for sen in array_list:
    r_time = sen['R_TIME'][:3]
    if '예약가능' in sen['STATUS_DESC'] and r_time in arrange_time:
        message = sen['R_TIME'] + ': ' + sen['COURSE_NAME'] + mdate

# 새 방식
for sen in array_list:
    r_time = sen.get('rtime', '')[:3]
    if r_time in arrange_time:
        message = f"{sen.get('rtime')}: {course_name} {formatted_date}"
```

## 다음 단계

1. **로그인 정보 확정**
   - 브라우저에서 실제 로그인 프로세스 확인
   - 정확한 ID 형식 파악

2. **테스트**
   - 다양한 날짜로 테스트
   - 에러 처리 확인

3. **배포**
   - config.ini 업데이트
   - 스케줄러로 정기 실행

## 파일 목록

### 수정된 파일
- ✓ `searchbot10.py` - 메인 스크립트 (새 API 적용)

### 새로 생성된 파일
- `test_direct_api.py` - API 직접 테스트 (작동 확인됨 ✓)
- `test_new_api.py` - 로그인 포함 테스트
- `check_ananti_new.py` - 종합 분석
- `demo_working.py` - 간단한 데모
- `USAGE_GUIDE.md` - 사용 가이드
- `README_API_GUIDE.md` - API 발견 가이드
- `SUMMARY.md` - 이 파일

### 참고 파일 (제공받음)
- `header.txt` - 실제 API 요청 헤더
- `요청페이로드.txt` - API 요청 페이로드
- `응답결과1.txt` - API 응답 예시

## 문의사항

로그인 관련:
- 실제 웹사이트에서 로그인 시 사용하는 ID는?
- 이메일인가요? 전화번호인가요? 회원번호인가요?
- 추가 파라미터가 필요한가요?

확인되면 `login_ananti_session()` 함수를 즉시 수정하여 완전히 자동화할 수 있습니다.
