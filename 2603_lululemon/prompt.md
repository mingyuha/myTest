# 룰루레몬 재고 알림 추가 작업

## 작업 내용
`refer/searchbot10.py` 에 룰루레몬 특정 제품 재고 확인 및 텔레그램 알림 로직 추가

## 대상 제품
- 제품명 : 패스트 앤 프리 하프 타이츠 8
- 색상 : black (color code: 0001)
- 사이즈 : M
- URL : https://www.lululemon.co.kr/ko-kr/p/%ED%8C%A8%EC%8A%A4%ED%8A%B8-%EC%95%A4-%ED%94%84%EB%A6%AC-%ED%95%98%ED%94%84-%ED%83%80%EC%9D%B4%EC%B8%A0-8%22/prod11380319.html?dwvar_prod11380319_color=0001

## 변경 파일
- `refer/searchbot10.py.bak` : 작업 전 백업
- `refer/searchbot10.py` : 아래 내용 추가됨

### 추가된 함수
```
getLululemon(fileName, productUrl, productName, targetSize, logger, now1)
```
- 룰루레몬 SFCC API(`/on/demandware.store/Sites-lululemon-kr-Site/ko_KR/Product-Variation`) 호출
- M 사이즈 재고 확인 (selectable=True, soldOut=False)
- 재고 있으면 텔레그램으로 전송: `패스트 앤 프리 하프 타이츠 8 M 재고있음`
- 이미 알림 보낸 상태는 파일에 저장해 중복 전송 방지

### job() 함수 변경
- `config[session]['fileNameLululemon']` 읽어서 상태 파일 경로 사용
- 매 실행마다 `getLululemon()` 호출

## config.ini 에 추가 필요
```ini
[SERVER]
fileNameLululemon = /root/searchInfo/lululemon.txt
```

## 단독 테스트
```bash
python test_lululemon.py
```
- `test_lululemon.py` : 텔레그램/config 없이 재고 여부만 출력
- 사이즈 목록과 각 재고 상태를 콘솔에 출력
