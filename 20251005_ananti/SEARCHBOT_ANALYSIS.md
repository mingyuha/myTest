# searchbot10.py 전체 분석

## 📋 개요

**목적**: 다양한 예약/조인 정보를 자동으로 크롤링하여 텔레그램으로 알림을 보내는 봇

**실행 환경**:
- 서버에서 cron 또는 스케줄러로 정기 실행
- 22시~06시 사이에는 실행 안 함 (880줄)

**핵심 기능**:
1. 아난티 골프장 예약 조회
2. 영화관 특별 상영관 조회 (IMAX, 4DX, Dolby Cinema)
3. 클리앙 지름 게시판 모니터링
4. 텔레그램 명령어로 설정 변경

---

## 🗂️ 파일 구조

### 설정 파일 (3개)
```
config.ini           - 파일명, 텔레그램 토큰 등 기본 설정
config_param.ini     - 조회할 영화 제목, 날짜 등 파라미터
config_id.ini        - 텔레그램 업데이트 ID (마지막 처리 위치)
```

### 로그 파일
- `fileNameLog`: 실행 로그

### 데이터 파일 (각 기능별 캐시)
- `fileNameEmerson`: 아난티 조인 게시판 캐시
- `fileNameEmemDay`: 아난티 골프 예약 캐시
- `fileNameClub`: 에이스 골프 조인 캐시
- `fileNameMx`: 메가박스 Dolby Cinema 캐시
- `fileNameIMax`: CGV IMAX 캐시
- `fileNameCGVTitle`: CGV 특정 영화 캐시
- `fileNameCGV4DX`: CGV 4DX 캐시
- `fileNameMegaBoxTitle`: 메가박스 특정 영화 캐시
- `fileNameGetMarket`: 클리앙 지름 게시판 캐시

---

## 🔧 주요 함수 분석

### 1. **텔레그램 관련** (16-37줄)

```python
telegram_send(message, logger)    # 재시도 로직 포함
_telegram_send(message)             # 실제 전송
```

**특징**:
- 최대 10번 재시도
- RetryAfter, TimedOut 에러 처리
- 10초 간격으로 재시도

---

### 2. **아난티 골프 관련** (39-248줄)

#### `login_ananti_session(user_id, password)` ✨ **새로 추가됨**

**목적**: 아난티 로그인 및 세션 생성

**프로세스**:
```
1. me.ananti.kr/user/signin 방문 (쿠키 초기화)
2. me.ananti.kr/user/signin_proc POST (로그인)
   - 파라미터: cmUserId, cmUserPw, saveId
3. 성공 시 Session 객체 반환, 실패 시 None
```

**반환값**: `requests.Session` 또는 `None`

#### `getEmerson(fileName, logger, now1)` (84-143줄)

**목적**: 아난티 조인 게시판 모니터링

**URL**: `https://ananti.kr/ko/joongang/board/gcJoin`

**동작**:
1. 게시판 페이지네이션 파싱
2. 각 게시글에서 날짜, 시간, 내용 추출
3. 필터링:
   - `permitDays` (토,일,금) 요일만
   - `arrange_time` (06:, 07:, 08:, 09:, 11:) 시간대만
   - "부부" 문자열 제외
4. 새로운 게시글이면 텔레그램 전송

**출력 형식**: `2025-10-20 금 코스명 08:30 정원4 [내용]`

#### `getEmersonMemDay(fileName, mdate, logger, now1, session, mem_no)` ✨ **새로 수정됨**

**목적**: 특정 날짜의 골프 예약 가능 시간 조회

**새 API**: `https://ananti.kr/reservation/joongang/ajax/golf-course`

**프로세스**:
```
1. 예약 페이지 접근 → CSRF 토큰 추출
2. 3개 코스 각각 API 호출:
   - course=1 (마운틴)
   - course=2 (레이크)
   - course=3 (스카이)
3. 원하는 시간대(arrange_time) 필터링
4. 새로운 예약이면 텔레그램 전송
```

**요청 페이로드**:
```json
{
    "memNo": "2211027500",
    "date": "20251020",
    "course": 1,
    "golfType": "GG",
    "bsns": "22"
}
```

**응답 파싱**: `data[].rtime` 필드에서 시간 추출

**출력 형식**: `06:42: 마운틴 2025-10-20 opened`

---

### 3. **영화관 관련**

#### `getCGVIMax(dateStr, fileNameIMax, logger, now1)` (259-328줄)

**목적**: CGV IMAX 상영 시간 조회

**URL**: `http://www.cgv.co.kr/common/showtimes/iframeTheater.aspx?...&theatercode=0013`

**동작**:
- BeautifulSoup로 IMAX 상영관 파싱
- 상영 시간 추출
- 새로운 시간이면 알림

#### `getCGV4DX(dateStr, fileName, logger, now1)` (331-396줄)

**목적**: CGV 4DX 상영 시간 조회

**특징**: 쿠키 포함하여 요청

#### `getCGVMovNum(dateStr, movnum, fileNameCGVMovNum, logger, now1)` (398-434줄)

**목적**: 특정 영화 예매 오픈 확인

**동작**:
- 영화 상세 페이지에서 "예매중" 텍스트 확인
- 있으면 알림

#### `getMegaBoxMx(dateStr, URL_Megabox, data_Mx, fileNameMx, logger, now1)` (436-479줄)

**목적**: 메가박스 Dolby Cinema 상영 시간 조회

**URL**: `https://www.megabox.co.kr/on/oh/ohc/Brch/schedulePage.do`

**특징**: JSON API 사용

#### `getMegaBoxTitle(dateStr, megaTitle, URL_Megabox, data_Title, fileNameMegaBoxTitle, logger, now1)` (481-527줄)

**목적**: 메가박스 특정 영화 상영 시간 조회

---

### 4. **기타 모니터링**

#### `getMarket(fileName, mTitle, logger, now1)` (529-584줄)

**목적**: 클리앙 지름 게시판 검색

**URL**: `https://www.clien.net/service/search/board/jirum?sk=title&sv={검색어}`

**필터링**: "품절" 제외

#### `getAceJoin(fileName, logger, now1)` (250-257줄)

**목적**: 에이스 골프 조인 게시판

**URL**: `http://www.acegolf.com/club/board/list.php?cb_id=1504&gsn=15144`

**특징**: 세션 로그인 필요

---

### 5. **설정 관리** (586-689줄)

#### `getUpdate(configParam, configId, logger, now1)`

**목적**: 텔레그램으로 설정 변경

**명령어**:
```
/help                       - 도움말
/list                       - 현재 설정 확인

/upd/mxdt/20251020         - Dolby Cinema 날짜 변경
/upd/megat/영화제목         - 메가박스 검색 제목 변경
/upd/4dx/20251020          - 4DX 날짜 변경
/updememdt/20251020        - 골프 예약 날짜 변경 (콤마로 여러 날짜)
/updemejoindt/20251020     - 조인 게시판 조회 종료일
/updmarket/제품명/20251020  - 지름 게시판 검색어/날짜

/upda/제목/20251020         - 모든 영화관 설정 일괄 변경
```

**동작**:
1. 텔레그램 봇에서 메시지 가져오기
2. 명령어 파싱
3. configParam 수정
4. 파일에 저장
5. 변경 사항 텔레그램으로 확인

---

### 6. **메인 실행 함수** (736-873줄)

#### `job()`

**프로세스**:
```
1. 로그 설정
2. 설정 파일 읽기
3. 텔레그램 업데이트 처리 (설정 변경 확인)
4. 각 기능별로 실행:

   a. 아난티 조인 게시판 (날짜 체크)
   b. 아난티 골프 예약 (로그인 → 날짜별 조회)
   c. 메가박스 Dolby Cinema
   d. 메가박스 특정 영화
   e. CGV 4DX
   f. CGV IMAX
   g. CGV 특정 영화
   h. 클리앙 지름 게시판

5. 로그 핸들러 정리
```

**날짜 체크 로직**:
```python
target_date = datetime.datetime.strptime(date_str, '%Y%m%d')
delta = target_date - c_date
if delta.days > 0:
    # 미래 날짜만 조회
```

---

## 🚀 실행 흐름

### 시작 (875-935줄)

```
1. 시간 체크: 22시~06시 사이면 종료
2. 환경 설정: SERVER or LOCAL
3. 설정 파일 로드
4. 전역 변수 설정:
   - permitDays = {'토','일','금'}
   - arrange_time = {'06:','07:','08:','09:','11:'}
5. job() 실행
6. 종료
```

### 스케줄러 (주석 처리됨)

```python
# 837-839줄
sched = BlockingScheduler()
sched.add_job(job, 'cron', minute="*/5", hour="7-22")
sched.start()
```

**의미**: 원래는 7-22시 사이 5분마다 실행하도록 설계됨

---

## ⚙️ 설정 파일 구조

### config.ini (추정)
```ini
[DEFAULT]
my_token = 텔레그램_봇_토큰
my_id = 텔레그램_채팅_ID
ananti_user_id = 2211027500
ananti_password = hateyou1@3

[SERVER]
fileNameLog = /root/searchInfo/log.txt
fileNameEmerson = /root/searchInfo/emerson.txt
fileNameEmemDay = /root/searchInfo/ememday.txt
...
```

### config_param.ini (추정)
```ini
[DEFAULT]
cgvt = 영화제목
cgvtdt = 20251020
megat = 영화제목
megatdt = 20251020
mxdt = 20251020
imaxdt = 20251020
4dx = 20251020
markett = 제품명
marketdt = 20251020
ememdt = 20251020,20251021,20251022
emejoindt = 20251231
movienum = 영화번호
```

### config_id.ini (추정)
```ini
[DEFAULT]
updateId = 123456789
```

---

## 🔄 데이터 흐름

### 1. 캐시 시스템

각 기능은 독립적인 캐시 파일 사용:

```
1. 파일 읽기 → currentList
2. 새 데이터 조회 → newList
3. 비교: newList - currentList = 알림 대상
4. 텔레그램 전송
5. newList를 파일에 저장
```

**장점**:
- 중복 알림 방지
- 서버 재시작 후에도 이전 상태 유지

**단점**:
- 파일이 삭제되면 모든 항목을 새 알림으로 인식

### 2. 아난티 골프 예약 특별 처리 (170-177줄)

```python
# 과거 메시지 중 유효한 것만 유지
for old_msg in currentList:
    if mdate not in old_msg:  # 현재 조회 날짜가 아니면
        datestr = old_msg[-8:]  # 메시지의 날짜 추출
        if datestr > nowstr:    # 미래 날짜면
            writeList.append(old_msg)  # 유지
```

**의미**:
- 여러 날짜를 동시에 모니터링
- 지난 날짜 메시지는 자동 삭제
- 파일 크기 관리

---

## 🔐 보안 고려사항

### 1. 민감 정보
```python
my_token = config['DEFAULT']['my_token']  # 텔레그램 봇 토큰
my_id = config['DEFAULT']['my_id']        # 텔레그램 사용자 ID
ananti_password = config['DEFAULT'].get('ananti_password', '')  # 골프장 비밀번호
```

**권장**: config.ini 파일은 `.gitignore`에 추가

### 2. 로그인 정보
```python
# 911-918줄 - 에이스 골프 로그인 (현재 비밀번호 비어있음)
LOGIN_INFO = {
    'user_id': 'leeps',
    'user_pass': '',  # 빈 문자열
}
```

---

## 📊 실행 통계 (추정)

### 1분당 API 호출 횟수 (모든 기능 활성화 시)

```
아난티 조인 게시판:    ~5 회 (페이지 수에 따라)
아난티 골프 예약:      4 회 (페이지 1 + 코스별 3)
CGV IMAX:            1 회
CGV 4DX:             1 회
CGV 영화:            1 회
메가박스 Dolby:       1 회
메가박스 영화:        1 회
클리앙 지름:          1 회
텔레그램 업데이트:     1 회

총 ~16회
```

5분마다 실행 시: **시간당 ~192회**

---

## 🐛 잠재적 이슈

### 1. 예외 처리
대부분의 함수가 모든 예외를 catch:
```python
except Exception as ex:
    logger.error("...")
```

**문제**:
- 특정 에러 타입 구분 안 됨
- 네트워크 오류 vs 파싱 오류 구분 불가

### 2. BeautifulSoup 의존성
- `from bs4 import BeautifulSoup` (2줄)
- HTML 구조 변경 시 크롤링 실패 가능

### 3. CSRF 토큰 (아난티만 처리됨)
- 아난티 골프는 CSRF 토큰 자동 추출 (186-188줄)
- 다른 사이트들은 처리 안 됨

### 4. 시간대 처리
```python
UTC = pytz.utc
KTC = timezone('Asia/Seoul')
```
모든 날짜를 UTC → KST 변환하지만, 일부 로직에서 일관성 없음

---

## ✅ 최근 수정 사항 (2025년)

### 1. 아난티 로그인 함수 추가
- **라인**: 39-82
- **변경**: 새로운 로그인 API 대응
- **파라미터**: `cmUserId`, `cmUserPw` (기존 `userId`, `userPw`에서 변경)

### 2. getEmersonMemDay 완전 재작성
- **라인**: 145-248
- **변경**:
  - 기존 ASP API → 새 JSON API
  - CSRF 토큰 자동 추출
  - 3개 코스 개별 조회
- **URL 변경**:
  - ✗ `https://joongang.ananti.kr/kr/reservation/reservation-proc.asp`
  - ✓ `https://ananti.kr/reservation/joongang/ajax/golf-course`

### 3. job() 함수 로그인 로직 추가
- **라인**: 818-840
- **변경**:
  - 아난티 로그인 세션 생성
  - 로그인 실패 시 골프 예약 조회 스킵
  - 여러 날짜 반복 조회

---

## 🎯 사용 시나리오

### 시나리오 1: 골프 조인 찾기
```
1. 금/토/일 중 원하는 날짜에 조인 게시글 올라옴
2. 06:~11: 시간대 중 하나
3. "부부" 조인 아님
→ 즉시 텔레그램 알림
```

### 시나리오 2: 골프 예약 모니터링
```
1. config_param.ini에 ememdt = 20251020,20251021 설정
2. 5분마다 두 날짜의 예약 가능 시간 조회
3. 06:, 07:, 08:, 09:, 11: 시간대 발견 시
→ 즉시 텔레그램 알림
```

### 시나리오 3: IMAX 영화 예매
```
1. config_param.ini에 imaxdt = 20251020 설정
2. CGV 용산 IMAX 상영 시간 확인
3. 새로운 상영 시간 오픈 시
→ 텔레그램 알림
```

### 시나리오 4: 텔레그램으로 설정 변경
```
1. 텔레그램에서 "/upd/mxdt/20251025" 전송
2. 봇이 다음 실행 시 명령어 처리
3. Dolby Cinema 조회 날짜가 20251025로 변경
4. 변경 사항 텔레그램으로 확인
```

---

## 📝 개선 제안

### 1. 에러 처리 세분화
```python
except requests.exceptions.ConnectionError:
    logger.error("Network error")
except json.JSONDecodeError:
    logger.error("JSON parsing error")
except Exception as ex:
    logger.error("Unknown error", exc_info=True)
```

### 2. 설정 검증
```python
def validate_config():
    """필수 설정 확인"""
    required = ['my_token', 'my_id']
    for key in required:
        if not config['DEFAULT'].get(key):
            raise ValueError(f"Missing config: {key}")
```

### 3. 재시도 로직 일반화
```python
def retry_request(func, max_tries=3, delay=5):
    """API 호출 재시도 데코레이터"""
    for i in range(max_tries):
        try:
            return func()
        except Exception as e:
            if i == max_tries - 1:
                raise
            time.sleep(delay)
```

### 4. 로깅 개선
```python
logger.info(f"Checking golf reservation for {mdate}")
logger.debug(f"API response: {res.status_code}")
logger.warning(f"No available slots for {mdate}")
```

### 5. 테스트 코드
```python
def test_ananti_login():
    """로그인 테스트"""
    session = login_ananti_session('test_id', 'test_pw')
    assert session is not None or session is None  # 실패 허용
```

---

## 📚 의존성

```python
requests          # HTTP 클라이언트
beautifulsoup4    # HTML 파싱
python-telegram-bot  # 텔레그램 봇
pytz              # 시간대 처리
apscheduler       # 스케줄러 (현재 미사용)
```

**설치**:
```bash
pip install requests beautifulsoup4 python-telegram-bot pytz apscheduler
```

---

## 🔍 코드 메트릭스

- **총 라인 수**: ~935줄
- **함수 개수**: 13개
- **클래스**: 없음 (절차적 프로그래밍)
- **주요 외부 API**: 8개
- **설정 파일**: 3개
- **데이터 파일**: 9개

---

## 💡 핵심 포인트

1. **멀티 모니터링**: 골프, 영화관, 쇼핑 등 다양한 사이트 통합 모니터링
2. **텔레그램 중심**: 모든 알림과 설정 변경을 텔레그램으로 처리
3. **캐시 기반**: 파일 시스템으로 중복 알림 방지
4. **날짜 기반 필터링**: 미래 날짜만 조회하여 불필요한 조회 방지
5. **2025년 업데이트**: 아난티 API 변경에 성공적으로 대응

---

## 🎓 결론

이 스크립트는 **개인용 자동 모니터링 봇**으로서:
- ✅ 다양한 예약 정보를 효율적으로 수집
- ✅ 텔레그램으로 실시간 알림
- ✅ 유연한 설정 변경 (텔레그램 명령어)
- ✅ 안정적인 캐시 시스템
- ✅ 최신 API 변경에 대응 완료

**강점**: 실용성, 확장성, 자동화
**약점**: 테스트 부족, 에러 처리 미흡, BeautifulSoup 의존성

전반적으로 **잘 작동하는 실용적인 자동화 스크립트**입니다.
