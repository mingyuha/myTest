import re
from datetime import datetime
from collections import defaultdict

def parse_korean_datetime(date_str):
    """한국어 날짜/시간 문자열을 파싱"""
    try:
        match = re.search(r'(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})', date_str)
        if match:
            year, month, day, hour, minute = match.groups()
            return datetime(int(year), int(month), int(day), int(hour), int(minute))
        return None
    except:
        return None

def extract_messages(lines, start_idx):
    """메시지 내용 추출"""
    messages = []
    i = start_idx

    while i < len(lines):
        line = lines[i].strip()

        # 다음 섹션이면 중단
        if line.startswith('**관련 메시지 수:**') or line.startswith('---'):
            break
        if line.startswith('###') or line.startswith('##') or line.startswith('# '):
            break

        # 메시지 파싱
        if re.match(r'^[\*\-] ?\*\*\d{2}:\d{2}', line) or re.match(r'^\*\*\d{2}:\d{2}', line):
            match = re.search(r'(\d{2}:\d{2}) \[([^\]]+)\]:\*\*(.+)?', line)
            if match:
                time = match.group(1)
                author = match.group(2)
                content = match.group(3) if match.group(3) else ''

                # 내용이 코드 블록에 있는 경우
                if i + 1 < len(lines) and lines[i + 1].strip().startswith('```'):
                    i += 1
                    content_lines = []
                    i += 1
                    while i < len(lines) and not lines[i].strip().startswith('```'):
                        content_lines.append(lines[i].rstrip())
                        i += 1
                    content = '\n'.join(content_lines).strip()
                elif not content and i + 1 < len(lines):
                    next_line = lines[i + 1].strip()
                    if next_line and not next_line.startswith('**') and not next_line.startswith('-') and not next_line.startswith('###'):
                        content = next_line

                messages.append({
                    'time': time,
                    'author': author,
                    'content': content
                })

        i += 1

    return messages, i

def analyze_conversation(conv_data):
    """대화 내용을 분석하여 문제와 조치결과 추출"""
    messages = conv_data['messages']

    if not messages:
        return {
            'problem': conv_data['title'][:100],
            'action': '정보 없음',
            'result': '정보 없음'
        }

    # 첫 메시지를 문제로
    problem = messages[0]['content'][:150]

    # 마지막 메시지를 결과로
    result = '진행 중'
    action = '확인 중'

    # 키워드 기반 조치/결과 찾기
    for msg in messages:
        content_lower = msg['content'].lower()

        # 조치 관련
        if any(keyword in content_lower for keyword in ['확인', '조치', '수정', '재시작', '복구', '설정', '변경']):
            action = msg['content'][:100]

        # 결과 관련
        if any(keyword in content_lower for keyword in ['해결', '정상', '완료', '복구됨', '이상없', '잘 되고']):
            result = msg['content'][:100]
        elif any(keyword in content_lower for keyword in ['작업종료', '비조업', '전원', '꺼']):
            result = msg['content'][:100]

    return {
        'problem': problem,
        'action': action,
        'result': result
    }

def parse_conversation_block(lines, start_idx):
    """대화 블록 파싱"""
    conv = {
        'title': '',
        'type': '',
        'systems': '',
        'datetime': '',
        'reporter': '',
        'messages': []
    }

    i = start_idx

    # 기본 정보 파싱
    while i < len(lines):
        line = lines[i].strip()

        if line.startswith('### [') and i > start_idx:
            break
        if line.startswith('# ') and i > start_idx:
            break

        if line.startswith('### ['):
            conv['title'] = re.sub(r'^### \[\d+\] ', '', line)
        elif line.startswith('**유형:**'):
            conv['type'] = line.replace('**유형:**', '').strip()
        elif line.startswith('**관련 설비/시스템:**'):
            conv['systems'] = line.replace('**관련 설비/시스템:**', '').strip()
        elif line.startswith('**발생 일시:**'):
            conv['datetime'] = line.replace('**발생 일시:**', '').strip()
        elif line.startswith('**최초 보고자:**'):
            conv['reporter'] = line.replace('**최초 보고자:**', '').strip()
        elif line.startswith('#### 대화 내용'):
            # 메시지 파싱 시작
            messages, next_i = extract_messages(lines, i + 1)
            conv['messages'] = messages
            i = next_i
            continue

        i += 1

    return conv, i

def group_similar_conversations(conversations):
    """유사한 주제의 대화를 그룹화"""
    # 설비/시스템과 키워드 기반으로 그룹화
    groups = defaultdict(list)

    for conv in conversations:
        # 그룹 키 생성: 설비 + 핵심 키워드
        key_parts = []

        # 설비명 추출
        systems = conv['systems'].split(',')
        if systems:
            key_parts.append(systems[0].strip())

        # 제목에서 핵심 키워드 추출
        title = conv['title'].lower()
        keywords = []
        if 'plc' in title:
            keywords.append('PLC')
        if '통신' in title or 'kepserver' in title:
            keywords.append('통신')
        if '트래킹' in title or '지시' in title:
            keywords.append('트래킹')
        if '데이터' in title:
            keywords.append('데이터')

        if keywords:
            key_parts.extend(keywords)

        group_key = ' - '.join(key_parts) if key_parts else '기타'
        groups[group_key].append(conv)

    return groups

def read_markdown_file(filepath):
    """마크다운 파일 읽기"""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    conversations = []
    i = 0
    current_category = ''
    current_subcategory = ''

    while i < len(lines):
        line = lines[i].strip()

        if line.startswith('# ') and not line.startswith('# 2025'):
            current_category = line.replace('# ', '').strip()
        elif line.startswith('## ') and not line.startswith('## 목차') and not line.startswith('## 전체'):
            current_subcategory = line.replace('## ', '').strip()
        elif line.startswith('### ['):
            conv, next_i = parse_conversation_block(lines, i)
            conv['category'] = current_category
            conv['subcategory'] = current_subcategory
            if conv['title']:
                conversations.append(conv)
            i = next_i
            continue

        i += 1

    return conversations

def write_summary_format(conversations, output_file):
    """요약 형식으로 출력 - 모든 메시지 내용 포함"""
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("# 2025년 장애/이슈 요약 리포트\n")
        f.write(f"생성일시: {datetime.now().strftime('%Y. %m. %d. %H:%M:%S')}\n")
        f.write("---\n\n")

        # 카테고리별로 그룹화
        categories = defaultdict(list)
        for conv in conversations:
            categories[conv['category']].append(conv)

        # 각 카테고리별 출력
        for category, convs in categories.items():
            if not category:
                continue

            f.write(f"# {category}\n\n")

            # 유사 대화 그룹화
            grouped = group_similar_conversations(convs)

            for group_name, group_convs in sorted(grouped.items()):
                if len(group_convs) == 1:
                    # 단일 이슈
                    conv = group_convs[0]

                    f.write(f"## {conv['subcategory']} - {conv['title'][:80]}\n\n")
                    f.write(f"**발생:** {conv['datetime']} | **보고자:** {conv['reporter']}\n\n")

                    # 모든 메시지를 타임라인으로 표시
                    if conv['messages']:
                        f.write("#### 대화 내용 (전체)\n\n")
                        f.write("| 시간 | 담당자 | 내용 |\n")
                        f.write("|------|--------|------|\n")

                        for msg in conv['messages']:
                            time = msg['time']
                            author = msg['author']
                            content = msg['content'].replace('\n', ' ').replace('|', '\\|')
                            f.write(f"| {time} | {author} | {content} |\n")

                        f.write("\n")

                    f.write("---\n\n")

                else:
                    # 반복 이슈 - 각 건별로 상세하게
                    f.write(f"## {group_name} (반복 {len(group_convs)}건)\n\n")

                    # 날짜 범위
                    dates = [parse_korean_datetime(c['datetime']) for c in group_convs if parse_korean_datetime(c['datetime'])]
                    if dates:
                        date_range = f"{min(dates).strftime('%Y-%m-%d')} ~ {max(dates).strftime('%Y-%m-%d')}"
                        f.write(f"**발생 기간:** {date_range}\n\n")

                    # 각 건별로 상세 내용 표시
                    for idx, conv in enumerate(group_convs, 1):
                        f.write(f"### [{idx}] {conv['datetime']}\n\n")
                        f.write(f"**보고자:** {conv['reporter']}\n\n")

                        if conv['messages']:
                            f.write("| 시간 | 담당자 | 내용 |\n")
                            f.write("|------|--------|------|\n")

                            for msg in conv['messages']:
                                time = msg['time']
                                author = msg['author']
                                content = msg['content'].replace('\n', ' ').replace('|', '\\|')
                                f.write(f"| {time} | {author} | {content} |\n")

                            f.write("\n")

                    f.write("---\n\n")

# 메인 실행
if __name__ == "__main__":
    input_file = "/home/lips/20251001_messages/2025_conversations_by_topic.md"
    output_file = "/home/lips/20251001_messages/2025_summary_report.md"

    print("파일 읽는 중...")
    conversations = read_markdown_file(input_file)
    print(f"총 {len(conversations)}개 대화 파싱 완료")

    print("요약 리포트 생성 중...")
    write_summary_format(conversations, output_file)
    print(f"완료! 결과 파일: {output_file}")
