#!/usr/bin/env python3
"""응답결과1.txt 파싱하여 결과 출력"""

import json

# 응답결과1.txt 로드
with open('/home/lips/20251005_ananti/응답결과1.txt', 'r', encoding='utf-8') as f:
    data = json.load(f)

print("=" * 80)
print("2025-10-20 골프 예약 결과 (응답결과1.txt 기반)")
print("=" * 80)

print("\n[데이터 정보]")
print(f"응답 코드: {data['code']}")
print(f"날짜: 2025-10-20")
print(f"코스: 마운틴 (chCourse=1)")

TARGET_TIMES = ['06:', '07:', '08:']

items = data.get('data', [])
print(f"\n[전체 티타임: {len(items)}개]")

for idx, item in enumerate(items, 1):
    rtime = item['rtime']
    rate = item['rate']
    total = item['totalCnt']
    guest = item['guestCnt']
    print(f"{idx}. {rtime} - ₩{rate} (정원: {total}명, 예약: {guest}명)")

# 원하는 시간대 필터링
print(f"\n[원하는 시간대 ({', '.join(TARGET_TIMES)})]")
filtered = []

for item in items:
    rtime = item['rtime']
    if rtime[:3] in TARGET_TIMES:
        filtered.append(item)
        print(f"✓ {rtime} - ₩{item['rate']} (정원: {item['totalCnt']}명)")

if filtered:
    print(f"\n총 {len(filtered)}개 시간대 발견")

    print("\n[텔레그램 메시지 형식]")
    print("-" * 80)
    for item in filtered:
        msg = f"{item['rtime']}: 마운틴 2025-10-20 opened"
        print(msg)
else:
    print("\n원하는 시간대에 예약 가능한 시간 없음")

print("\n" + "=" * 80)
print("\n참고:")
print("- 이것은 마운틴 코스(course=1)만의 결과입니다")
print("- 레이크(course=2), 스카이(course=3)도 별도로 조회해야 합니다")
print("- 실제 searchbot10.py는 3개 코스 모두 자동으로 조회합니다")
print("=" * 80)
