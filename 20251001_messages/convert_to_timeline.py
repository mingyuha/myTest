import re
from datetime import datetime

def parse_korean_datetime(date_str):
    """한국어 날짜/시간 문자열을 파싱"""
    try:
        # "2025-01-07 01:06" 형식
        match = re.search(r'(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})', date_str)
        if match:
            year, month, day, hour, minute = match.groups()
            return datetime(int(year), int(month), int(day), int(hour), int(minute))
        return None
    except:
        return None

def extract_time(date_str):
    """날짜 문자열에서 시간만 추출 (HH:MM)"""
    match = re.search(r'(\d{2}):(\d{2})', date_str)
    if match:
        return match.group(0)
    return ""

def parse_conversation_block(lines, start_idx):
    """대화 블록 하나를 파싱"""
    conv = {
        'title': '',
        'type': '',
        'systems': '',
        'datetime': '',
        'reporter': '',
        'messages': []
    }

    i = start_idx
    while i < len(lines):
        line = lines[i].strip()

        # 다음 대화 블록 시작 또는 주요 섹션 시작이면 중단
        if line.startswith('### [') and i > start_idx:
            break
        if line.startswith('# ') and i > start_idx:
            break

        # 제목
        if line.startswith('### ['):
            conv['title'] = re.sub(r'^### \[\d+\] ', '', line)

        # 유형
        elif line.startswith('**유형:**'):
            conv['type'] = line.replace('**유형:**', '').strip()

        # 관련 설비/시스템
        elif line.startswith('**관련 설비/시스템:**'):
            conv['systems'] = line.replace('**관련 설비/시스템:**', '').strip()

        # 발생 일시
        elif line.startswith('**발생 일시:**'):
            conv['datetime'] = line.replace('**발생 일시:**', '').strip()

        # 최초 보고자
        elif line.startswith('**최초 보고자:**'):
            conv['reporter'] = line.replace('**최초 보고자:**', '').strip()

        # 메시지 파싱 (타임스탬프가 있는 라인)
        elif re.match(r'^[\*\-] ?\*\*\d{2}:\d{2}', line) or re.match(r'^\*\*\d{2}:\d{2}', line):
            # "**01:06 [유병재(랜디)]:**" 또는 "- **08:40 [정현태 (닉스)]:**" 형식
            match = re.search(r'(\d{2}:\d{2}) \[([^\]]+)\]:\*\*(.+)?', line)
            if match:
                time = match.group(1)
                author = match.group(2)
                content = match.group(3) if match.group(3) else ''

                # 다음 줄이 내용인 경우
                if i + 1 < len(lines) and lines[i + 1].strip().startswith('```'):
                    i += 1
                    content_lines = []
                    i += 1
                    while i < len(lines) and not lines[i].strip().startswith('```'):
                        content_lines.append(lines[i].rstrip())
                        i += 1
                    content = '\n'.join(content_lines).strip()
                elif not content and i + 1 < len(lines):
                    # 내용이 없으면 다음 줄 확인
                    next_line = lines[i + 1].strip()
                    if next_line and not next_line.startswith('**') and not next_line.startswith('-') and not next_line.startswith('###'):
                        content = next_line

                conv['messages'].append({
                    'time': time,
                    'author': author,
                    'content': content
                })

        i += 1

    return conv, i

def read_markdown_file(filepath):
    """마크다운 파일을 읽어서 대화 블록들을 파싱"""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    conversations = []
    i = 0
    current_category = ''
    current_subcategory = ''

    while i < len(lines):
        line = lines[i].strip()

        # 대카테고리 (# PLC/통신 장애)
        if line.startswith('# ') and not line.startswith('# 2025'):
            current_category = line.replace('# ', '').strip()

        # 소카테고리 (## 1단조)
        elif line.startswith('## ') and not line.startswith('## 목차') and not line.startswith('## 전체'):
            current_subcategory = line.replace('## ', '').strip()

        # 대화 블록 시작
        elif line.startswith('### ['):
            conv, next_i = parse_conversation_block(lines, i)
            conv['category'] = current_category
            conv['subcategory'] = current_subcategory
            if conv['messages'] or conv['title']:
                conversations.append(conv)
            i = next_i
            continue

        i += 1

    return conversations

def write_timeline_format(conversations, output_file):
    """타임라인 형식으로 출력"""
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("# 2025년 대화 내용 (타임라인 형식)\n")
        f.write(f"생성일시: {datetime.now().strftime('%Y. %m. %d. %H:%M:%S')}\n")
        f.write("---\n\n")

        f.write("## 전체 통계\n\n")
        f.write(f"- **총 대화 건수**: {len(conversations)}건\n")
        total_messages = sum(len(conv['messages']) for conv in conversations)
        f.write(f"- **총 메시지 수**: {total_messages}개\n\n")
        f.write("---\n\n")

        # 카테고리별로 그룹화
        categories = {}
        for conv in conversations:
            cat = conv['category']
            if cat not in categories:
                categories[cat] = []
            categories[cat].append(conv)

        # 각 카테고리별로 출력
        for category, convs in categories.items():
            if not category:
                continue

            f.write(f"# {category}\n\n")

            # 서브카테고리별로 그룹화
            subcategories = {}
            for conv in convs:
                subcat = conv['subcategory']
                if subcat not in subcategories:
                    subcategories[subcat] = []
                subcategories[subcat].append(conv)

            for subcategory, subconvs in subcategories.items():
                if subcategory:
                    f.write(f"## {subcategory}\n\n")

                for idx, conv in enumerate(subconvs, 1):
                    f.write(f"### [{idx}] {conv['title']}\n\n")

                    # 기본 정보
                    if conv['type']:
                        f.write(f"**유형:** {conv['type']}\n")
                    if conv['systems']:
                        f.write(f"**관련 설비:** {conv['systems']}\n")
                    if conv['datetime']:
                        f.write(f"**발생 일시:** {conv['datetime']}\n")
                    if conv['reporter']:
                        f.write(f"**최초 보고자:** {conv['reporter']}\n")

                    f.write("\n")

                    # 타임라인 테이블
                    if conv['messages']:
                        f.write("#### 대화 타임라인\n\n")
                        f.write("| 시간 | 담당자 | 내용 |\n")
                        f.write("|------|--------|------|\n")

                        for msg in conv['messages']:
                            time = msg['time']
                            author = msg['author']
                            content = msg['content'].replace('\n', ' ').replace('|', '\\|')
                            # 내용이 너무 길면 자르기
                            if len(content) > 100:
                                content = content[:97] + "..."
                            f.write(f"| {time} | {author} | {content} |\n")

                        f.write("\n")

                    f.write("---\n\n")

# 메인 실행
if __name__ == "__main__":
    input_file = "/home/lips/20251001_messages/2025_conversations_by_topic.md"
    output_file = "/home/lips/20251001_messages/2025_conversations_timeline.md"

    print("파일 읽는 중...")
    conversations = read_markdown_file(input_file)
    print(f"총 {len(conversations)}개 대화 파싱 완료")

    print("타임라인 형식으로 변환 중...")
    write_timeline_format(conversations, output_file)
    print(f"완료! 결과 파일: {output_file}")
