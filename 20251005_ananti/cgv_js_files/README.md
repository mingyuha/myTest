# CGV JavaScript Files

이 폴더는 CGV API의 secret key를 찾기 위한 JavaScript 파일들을 보관합니다.

## Secret Key가 변경되었을 때 대처 방법

### 1. JavaScript 파일 다시 다운로드
```bash
cd /home/lips/20251005_ananti/cgv_js_files
./download.sh
```

### 2. Secret Key 찾기
```bash
# HmacSHA256 함수 포함된 파일 검색
grep -l "HmacSHA256" *.js

# Secret key 추출
grep -oP 'HmacSHA256\([^)]+,"[^"]{43}"' *.js
```

### 3. 현재 Secret Key (2025-10-07 기준)
```
ydqXY0ocnFLmJGHr_zNzFcpjwAsXq_8JcBNURAkRscg
```

### 4. 서명 생성 알고리즘
```javascript
message = timestamp + "|" + pathname + "|" + body
signature = HMAC-SHA256(message, secret_key).base64()
```

### 5. 확인된 파일
- `1453-*.js` - API 인터셉터 및 서명 생성 로직 포함

## 401 에러 발생 시

1. `download.sh` 실행하여 최신 JS 파일 다운로드
2. 위의 grep 명령어로 새 secret key 찾기
3. `searchbot10.py`의 `generate_cgv_signature()` 함수에서 secret_key 업데이트
4. 테스트: `python3 test_cgv_signature.py`

## 변경 이력
- 2025-10-07: 초기 키 발견 `ydqXY0ocnFLmJGHr_zNzFcpjwAsXq_8JcBNURAkRscg`
