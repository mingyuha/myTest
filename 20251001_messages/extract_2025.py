import json
import sys

# JSON 파일 읽기
with open('messages.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# 2025년 메시지만 필터링
messages_2025 = []
for msg in data['messages']:
    if '2025년' in msg['created_date']:
        messages_2025.append(msg)

print(f'Total 2025 messages: {len(messages_2025)}')

# 2025년 데이터를 별도 파일로 저장
with open('messages_2025.json', 'w', encoding='utf-8') as f:
    json.dump({'messages': messages_2025}, f, ensure_ascii=False, indent=2)

print('2025 data saved to messages_2025.json')