import json
import re
from datetime import datetime
from collections import defaultdict

def parse_korean_date(date_str):
    """한글 날짜를 파싱"""
    try:
        # "2025년 1월 3일 금요일 오전 12시 30분 36초 UTC" 형식 파싱
        match = re.search(r'(\d{4})년 (\d{1,2})월 (\d{1,2})일.*?(오전|오후) (\d{1,2})시 (\d{1,2})분', date_str)
        if match:
            year, month, day, ampm, hour, minute = match.groups()
            hour = int(hour)
            if ampm == '오후' and hour != 12:
                hour += 12
            elif ampm == '오전' and hour == 12:
                hour = 0
            return f"{year}-{month.zfill(2)}-{day.zfill(2)} {str(hour).zfill(2)}:{minute.zfill(2)}"
    except:
        pass
    return date_str

def categorize_message(text):
    """메시지 내용을 기반으로 카테고리 분류"""
    text_lower = text.lower()

    # PLC/통신 장애
    if any(keyword in text_lower for keyword in ['plc', '통신', '연결', '끊', '수신', '미수신', 'kepserver', 'device', 'not responding']):
        if '1단조' in text or '1tan' in text_lower:
            return ('PLC/통신 장애', '1단조')
        elif '2단조' in text or '2tan' in text_lower:
            return ('PLC/통신 장애', '2단조')
        elif '소압' in text or 'srl' in text_lower or '소형압연' in text:
            return ('PLC/통신 장애', '소형압연')
        elif 'dst' in text_lower:
            return ('PLC/통신 장애', '소형압연 DST')
        elif '산세' in text:
            if '1산세' in text:
                return ('PLC/통신 장애', '1산세')
            elif '2산세' in text:
                return ('PLC/통신 장애', '2산세')
            else:
                return ('PLC/통신 장애', '산세')
        elif '소경' in text:
            return ('PLC/통신 장애', '소경')
        elif '2제강' in text or 'bgm' in text_lower:
            return ('PLC/통신 장애', '2제강/BGM')
        elif 'quenching' in text_lower or '퀜칭' in text:
            return ('PLC/통신 장애', 'QUENCHING')
        elif 'rfm' in text_lower:
            return ('PLC/통신 장애', 'RFM')
        else:
            return ('PLC/통신 장애', '기타')

    # 트래킹/데이터 수신 이슈
    if any(keyword in text_lower for keyword in ['트래킹', 'tracking', '지시', '실적', '수신']):
        if '소경' in text:
            return ('트래킹/데이터', '소경')
        elif '산세' in text:
            return ('트래킹/데이터', '산세')
        elif '2제강' in text or '연주' in text or '빌렛' in text:
            return ('트래킹/데이터', '2제강/연주')
        else:
            return ('트래킹/데이터', '기타')

    # 담당자 변경
    if any(keyword in text for keyword in ['담당자', '퇴사', '변경']):
        return ('조직/담당자 변경', '담당자 변경')

    # 일반 문의
    if any(keyword in text for keyword in ['문의', '확인', '부탁', '질문']):
        return ('일반 문의', '기타')

    # 기타
    return ('기타', '미분류')

def group_messages_by_topic(messages):
    """topic_id로 메시지 그룹화"""
    topic_groups = defaultdict(list)
    for msg in messages:
        topic_id = msg.get('topic_id', 'unknown')
        topic_groups[topic_id].append(msg)
    return topic_groups

def analyze_conversation(messages):
    """대화 분석"""
    if not messages:
        return None

    # 시간순 정렬
    messages.sort(key=lambda x: x.get('created_date', ''))

    first_msg = messages[0]
    first_text = first_msg.get('text', '')

    # 카테고리 분류
    category, subcategory = categorize_message(first_text)

    # 참여자 추출
    participants = set()
    for msg in messages:
        creator = msg.get('creator', {})
        name = creator.get('name', '')
        if name:
            participants.add(name)

    return {
        'category': category,
        'subcategory': subcategory,
        'first_message': first_msg,
        'messages': messages,
        'participants': sorted(participants),
        'message_count': len(messages)
    }

def determine_conversation_type(messages):
    """대화 유형 결정"""
    if not messages:
        return "기타"

    first_text = messages[0].get('text', '').lower()

    if any(k in first_text for k in ['확인 부탁', '문의', '질문']):
        return "질의응답"
    elif any(k in first_text for k in ['장애', '미수신', '끊', '문제']):
        return "장애보고"
    elif any(k in first_text for k in ['요청', '작업', '변경']):
        return "작업요청"
    elif any(k in first_text for k in ['퇴사', '담당자', '변경']):
        return "정보공유"
    else:
        return "일반"

def extract_equipment(text):
    """설비/시스템 추출"""
    equipment = []

    patterns = [
        r'(\d+단조)', r'(소형압연)', r'(소압)', r'(\d+산세)', r'(산세)',
        r'(소경)', r'(\d+제강)', r'(BGM)', r'(RFM)', r'(DST)',
        r'(QUENCHING)', r'(퀜칭)', r'(연주)', r'(빌렛)',
        r'(PLC)', r'(KEPSERVER)', r'(Kepserver)'
    ]

    for pattern in patterns:
        matches = re.findall(pattern, text, re.IGNORECASE)
        equipment.extend(matches)

    return list(set(equipment)) if equipment else ['명시되지 않음']

def generate_markdown(conversations):
    """마크다운 생성"""
    output = []
    output.append("# 2025년 대화 내용 주제별 정리\n")
    output.append(f"생성일시: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    output.append("---\n\n")

    # 카테고리별로 그룹화
    by_category = defaultdict(list)
    for conv in conversations:
        by_category[conv['category']].append(conv)

    # 카테고리 순서 정의
    category_order = [
        'PLC/통신 장애',
        '트래킹/데이터',
        '조직/담당자 변경',
        '일반 문의',
        '기타'
    ]

    # 통계 정보
    output.append("## 전체 통계\n\n")
    total_conversations = len(conversations)
    total_messages = sum(c['message_count'] for c in conversations)
    output.append(f"- **총 대화 건수**: {total_conversations}건\n")
    output.append(f"- **총 메시지 수**: {total_messages}개\n\n")

    output.append("### 카테고리별 통계\n\n")
    for cat in category_order:
        if cat in by_category:
            count = len(by_category[cat])
            msg_count = sum(c['message_count'] for c in by_category[cat])
            output.append(f"- **{cat}**: {count}건 ({msg_count}개 메시지)\n")

            # 서브카테고리 통계
            subcats = defaultdict(int)
            for conv in by_category[cat]:
                subcats[conv['subcategory']] += 1

            for subcat, cnt in sorted(subcats.items(), key=lambda x: -x[1]):
                output.append(f"  - {subcat}: {cnt}건\n")

    output.append("\n---\n\n")

    # 카테고리별 상세 내용
    for category in category_order:
        if category not in by_category:
            continue

        output.append(f"# {category}\n\n")

        # 서브카테고리별로 그룹화
        by_subcat = defaultdict(list)
        for conv in by_category[category]:
            by_subcat[conv['subcategory']].append(conv)

        for subcategory, convs in sorted(by_subcat.items()):
            output.append(f"## {subcategory}\n\n")

            for idx, conv in enumerate(convs, 1):
                messages = conv['messages']
                first_msg = conv['first_message']

                # 제목 생성 (첫 메시지의 첫 줄)
                first_text = first_msg.get('text', '')
                title_lines = first_text.split('\n')
                title = title_lines[0][:100] if title_lines else "제목 없음"

                # 대화 유형
                conv_type = determine_conversation_type(messages)

                # 설비 추출
                equipment = extract_equipment(first_text)

                # 시간 파싱
                date_str = parse_korean_date(first_msg.get('created_date', ''))

                output.append(f"### [{idx}] {title}\n\n")
                output.append(f"**유형:** {conv_type}\n\n")
                output.append(f"**관련 설비/시스템:** {', '.join(equipment)}\n\n")
                output.append(f"**발생 일시:** {date_str}\n\n")
                output.append(f"**최초 보고자:** {first_msg.get('creator', {}).get('name', '알 수 없음')}\n\n")

                output.append("#### 대화 내용\n\n")

                for msg_idx, msg in enumerate(messages):
                    creator_name = msg.get('creator', {}).get('name', '알 수 없음')
                    text = msg.get('text', '')
                    time_str = parse_korean_date(msg.get('created_date', ''))

                    # 시간만 추출 (HH:MM)
                    time_only = time_str.split()[-1] if ' ' in time_str else time_str

                    if text:
                        # 긴 텍스트는 들여쓰기
                        if '\n' in text:
                            output.append(f"**{time_only} [{creator_name}]:**\n```\n{text}\n```\n\n")
                        else:
                            output.append(f"- **{time_only} [{creator_name}]:** {text}\n")

                    # 첨부파일 정보
                    attached_files = msg.get('attached_files', [])
                    if attached_files:
                        for file in attached_files:
                            output.append(f"  - 📎 첨부파일: {file.get('original_name', '알 수 없음')}\n")

                    output.append("\n")

                output.append(f"**관련 메시지 수:** {conv['message_count']}개\n\n")
                output.append(f"**참여자:** {', '.join(conv['participants'])}\n\n")
                output.append("---\n\n")

    return ''.join(output)

# 메인 실행
print("2025년 데이터 분석 시작...")

# JSON 파일 읽기
with open('messages.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

print(f"전체 메시지 수: {len(data['messages'])}")

# 2025년 메시지 필터링
messages_2025 = []
for msg in data['messages']:
    if '2025년' in msg.get('created_date', ''):
        messages_2025.append(msg)

print(f"2025년 메시지 수: {len(messages_2025)}")

# topic_id로 그룹화
topic_groups = group_messages_by_topic(messages_2025)
print(f"고유 topic 수: {len(topic_groups)}")

# 각 대화 분석
conversations = []
for topic_id, messages in topic_groups.items():
    conv = analyze_conversation(messages)
    if conv:
        conversations.append(conv)

print(f"분석된 대화 수: {len(conversations)}")

# 마크다운 생성
markdown_content = generate_markdown(conversations)

# 파일 저장
output_file = '2025_conversations_by_topic.md'
with open(output_file, 'w', encoding='utf-8') as f:
    f.write(markdown_content)

print(f"\n마크다운 파일 생성 완료: {output_file}")

# 통계 출력
print("\n=== 주제별 케이스 개수 ===")
by_category = defaultdict(list)
for conv in conversations:
    by_category[conv['category']].append(conv)

for category, convs in sorted(by_category.items()):
    print(f"{category}: {len(convs)}건")

    # 서브카테고리별
    by_subcat = defaultdict(int)
    for conv in convs:
        by_subcat[conv['subcategory']] += 1

    for subcat, count in sorted(by_subcat.items(), key=lambda x: -x[1]):
        print(f"  - {subcat}: {count}건")

print("\n작업 완료!")