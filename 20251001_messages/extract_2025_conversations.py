import json
from collections import defaultdict
from datetime import datetime

# JSON 파일 읽기
print("Loading messages.json...")
with open(r'D:\git\myTest\messages.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

messages = data['messages']
print(f"Total messages loaded: {len(messages)}")

# 2025년 메시지 필터링
print("Filtering 2025 messages...")
messages_2025 = []
for msg in messages:
    created_date = msg.get('created_date', '')
    if created_date.startswith('2025년'):
        messages_2025.append(msg)

print(f"2025 messages found: {len(messages_2025)}")

# topic_id별로 그룹화
print("Grouping by topic_id...")
topics = defaultdict(list)
for msg in messages_2025:
    topic_id = msg.get('topic_id', 'no_topic')
    topics[topic_id].append(msg)

print(f"Total topics: {len(topics)}")

# 각 토픽 내에서 시간순 정렬을 위한 함수
def parse_korean_date(date_str):
    """한국어 날짜 문자열을 파싱하여 정렬 가능한 형태로 변환"""
    try:
        # "2025년 1월 3일 금요일 오전 12시 30분 36초 UTC" 형식
        parts = date_str.split()
        year = int(parts[0].replace('년', ''))
        month = int(parts[1].replace('월', ''))
        day = int(parts[2].replace('일', ''))

        time_period = parts[4]  # 오전 or 오후
        time_parts = parts[5].split('시')
        hour = int(time_parts[0])

        minute_parts = time_parts[1].split('분')
        minute = int(minute_parts[0])

        second_parts = minute_parts[1].split('초')
        second = int(second_parts[0])

        # 오후 처리
        if time_period == '오후' and hour != 12:
            hour += 12
        elif time_period == '오전' and hour == 12:
            hour = 0

        return datetime(year, month, day, hour, minute, second)
    except:
        return datetime(1900, 1, 1)

# 각 토픽별로 시간순 정렬
print("Sorting messages by time within each topic...")
for topic_id in topics:
    topics[topic_id].sort(key=lambda x: parse_korean_date(x.get('created_date', '')))

# 토픽을 첫 메시지 시간 기준으로 정렬
sorted_topics = sorted(topics.items(), key=lambda x: parse_korean_date(x[1][0].get('created_date', '')))

# 결과 파일 작성
output_file = r'D:\git\myTest\2025_conversations_organized.md'
print(f"Writing organized conversations to {output_file}...")

with open(output_file, 'w', encoding='utf-8') as f:
    f.write("# 2025년 대화 내용 정리\n\n")
    f.write(f"## 개요\n")
    f.write(f"- **총 메시지 수**: {len(messages_2025)}개\n")
    f.write(f"- **총 대화 주제(Topic) 수**: {len(topics)}개\n")
    f.write(f"- **정리 날짜**: 2025년 9월 30일\n\n")
    f.write("---\n\n")

    # 각 토픽별로 작성
    for idx, (topic_id, msgs) in enumerate(sorted_topics, 1):
        f.write(f"## Topic {idx}: {topic_id}\n\n")

        # 첫 메시지 정보
        first_msg = msgs[0]
        creator = first_msg.get('creator', {})
        creator_name = creator.get('name', 'Unknown')
        creator_email = creator.get('email', 'Unknown')
        first_date = first_msg.get('created_date', 'Unknown')

        f.write(f"**주제 시작자**: {creator_name} ({creator_email})\n")
        f.write(f"**시작 시간**: {first_date}\n")
        f.write(f"**메시지 수**: {len(msgs)}개\n\n")

        # 모든 메시지 작성
        f.write("### 대화 내용\n\n")

        for msg_idx, msg in enumerate(msgs, 1):
            msg_creator = msg.get('creator', {})
            msg_name = msg_creator.get('name', 'Unknown')
            msg_email = msg_creator.get('email', 'Unknown')
            msg_date = msg.get('created_date', 'Unknown')
            msg_text = msg.get('text', '')

            f.write(f"#### 메시지 {msg_idx}\n")
            f.write(f"**작성자**: {msg_name} ({msg_email})\n")
            f.write(f"**시간**: {msg_date}\n\n")

            if msg_text:
                f.write(f"**내용**:\n```\n{msg_text}\n```\n\n")
            else:
                f.write("**내용**: (텍스트 없음)\n\n")

            # 첨부 파일 정보
            attached_files = msg.get('attached_files', [])
            if attached_files:
                f.write("**첨부 파일**:\n")
                for file in attached_files:
                    original_name = file.get('original_name', 'Unknown')
                    export_name = file.get('export_name', 'Unknown')
                    f.write(f"- {original_name} (내보내기: {export_name})\n")
                f.write("\n")

            # 반응(reactions) 정보
            reactions = msg.get('reactions', [])
            if reactions:
                f.write("**반응**:\n")
                for reaction in reactions:
                    emoji = reaction.get('emoji', {}).get('unicode', '')
                    reactor_emails = reaction.get('reactor_emails', [])
                    f.write(f"- {emoji} by {', '.join(reactor_emails)}\n")
                f.write("\n")

            # 주석(annotations) 정보
            annotations = msg.get('annotations', [])
            if annotations and len(annotations) > 0:
                f.write(f"**주석**: {len(annotations)}개의 서식 정보 포함\n\n")

            f.write("---\n\n")

        f.write("\n\n")

print("Done!")

# 주요 대화 주제 분석
print("\n=== 주요 대화 주제 분석 ===")
topic_summaries = []
for topic_id, msgs in sorted_topics[:20]:  # 상위 20개 토픽
    first_text = msgs[0].get('text', '')
    # 첫 100자만 추출
    summary = first_text[:100].replace('\n', ' ') if first_text else '(텍스트 없음)'
    topic_summaries.append((topic_id, len(msgs), summary))

print("\n주요 대화 주제 (메시지 수가 많은 순):")
sorted_by_count = sorted([(tid, msgs) for tid, msgs in topics.items()],
                         key=lambda x: len(x[1]), reverse=True)[:20]

for topic_id, msgs in sorted_by_count:
    first_text = msgs[0].get('text', '')[:80].replace('\n', ' ')
    print(f"- {topic_id}: {len(msgs)}개 메시지 - {first_text}...")

print(f"\n총 결과:")
print(f"- 2025년 메시지 총 개수: {len(messages_2025)}")
print(f"- 대화 주제(Topic) 개수: {len(topics)}")
print(f"- 출력 파일: {output_file}")