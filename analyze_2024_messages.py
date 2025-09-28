#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import re
from collections import defaultdict, Counter
from datetime import datetime
import calendar

def extract_month_from_date(date_str):
    """한국어 날짜에서 월 추출"""
    months = {
        '1월': 1, '2월': 2, '3월': 3, '4월': 4, '5월': 5, '6월': 6,
        '7월': 7, '8월': 8, '9월': 9, '10월': 10, '11월': 11, '12월': 12
    }
    for month_kr, month_num in months.items():
        if month_kr in date_str:
            return month_num
    return 0

def is_substantial_message(text):
    """실질적인 메시지인지 판단"""
    if not text or len(text.strip()) < 10:
        return False

    # 단순한 인사말이나 확인 메시지 제외
    simple_patterns = [
        r'^(네|예|감사합니다|알겠습니다|확인했습니다)\.?$',
        r'^(👍|👌|✅|🙏)$',
        r'^(ㅇㅋ|ㄱㅅ|ㄳ)$'
    ]

    for pattern in simple_patterns:
        if re.match(pattern, text.strip(), re.IGNORECASE):
            return False

    return True

def categorize_message(text, title=""):
    """메시지를 카테고리별로 분류"""
    categories = []

    tech_keywords = {
        'database': ['데이터베이스', 'DB', 'SQL', 'Oracle', 'MySQL', 'PostgreSQL', '쿼리', 'Index', '인덱스'],
        'monitoring': ['모니터링', '감시', '알림', '경보', 'Grafana', 'Zabbix', '임계치', '메트릭'],
        'network': ['네트워크', '통신', 'TCP', 'UDP', 'HTTP', 'API', '연결', '접속'],
        'server': ['서버', '시스템', 'CPU', '메모리', '디스크', '로드', '성능'],
        'backup': ['백업', '복원', '복구', 'Recovery', 'Backup'],
        'security': ['보안', '인증', '권한', '암호화', 'SSL', 'TLS'],
        'deployment': ['배포', '릴리즈', '업데이트', '설치', '버전'],
        'troubleshooting': ['장애', '오류', '에러', '문제', '해결', '조치', '복구'],
        'automation': ['자동화', '스크립트', '배치', 'Script', 'Automation'],
        'infrastructure': ['인프라', '클라우드', 'AWS', 'Docker', 'Kubernetes']
    }

    text_lower = text.lower()
    title_lower = title.lower()
    combined_text = f"{text_lower} {title_lower}"

    for category, keywords in tech_keywords.items():
        for keyword in keywords:
            if keyword.lower() in combined_text:
                categories.append(category)
                break

    return categories if categories else ['general']

def extract_people_mentioned(text):
    """메시지에서 언급된 사람들 추출"""
    # @멘션 패턴
    mentions = re.findall(r'@([가-힣a-zA-Z0-9_]+)', text)

    # 일반적인 한국 이름 패턴 (성+이름)
    names = re.findall(r'([가-힣]{2,4})\s*(?:님|씨|팀장|과장|부장|차장|대리|주임)', text)

    return list(set(mentions + names))

def main():
    print("2024년 메시지 종합 분석 시작...")

    # JSON 파일 읽기
    with open('/home/lips/messages.json', 'r', encoding='utf-8') as f:
        data = json.load(f)

    # 2024년 메시지 추출
    messages_2024 = []
    total_messages = len(data.get('messages', []))

    for message in data.get('messages', []):
        created_date = message.get('created_date', '')
        if '2024년' in created_date:
            # topic_id를 conversation_id로 사용
            message['conversation_id'] = message.get('topic_id', '')
            message['conversation_title'] = message.get('topic_id', '')
            messages_2024.append(message)

    print(f"전체 메시지 수: {total_messages}")
    print(f"2024년 메시지 수: {len(messages_2024)}")

    # 실질적인 메시지 필터링
    substantial_messages = []
    for msg in messages_2024:
        text = msg.get('text', '')
        if is_substantial_message(text):
            substantial_messages.append(msg)

    print(f"실질적인 2024년 메시지 수: {len(substantial_messages)}")

    # 월별 분석
    monthly_stats = defaultdict(lambda: {
        'count': 0,
        'messages': [],
        'categories': Counter(),
        'people': Counter(),
        'conversations': set()
    })

    # 전체 통계
    all_categories = Counter()
    all_people = Counter()
    all_conversations = set()

    for msg in substantial_messages:
        # 월 추출
        month = extract_month_from_date(msg.get('created_date', ''))
        if month == 0:
            continue

        text = msg.get('text', '')
        title = msg.get('conversation_title', '')

        # 월별 통계 업데이트
        monthly_stats[month]['count'] += 1
        monthly_stats[month]['messages'].append(msg)
        monthly_stats[month]['conversations'].add(title)

        # 카테고리 분석
        categories = categorize_message(text, title)
        for cat in categories:
            monthly_stats[month]['categories'][cat] += 1
            all_categories[cat] += 1

        # 사람 언급 분석
        people = extract_people_mentioned(text)
        for person in people:
            monthly_stats[month]['people'][person] += 1
            all_people[person] += 1

        all_conversations.add(title)

    # 결과 출력
    print("\n=== 2024년 메시지 분석 결과 ===")
    print(f"총 2024년 메시지: {len(messages_2024)}")
    print(f"실질적 메시지: {len(substantial_messages)}")
    print(f"비실질적 메시지: {len(messages_2024) - len(substantial_messages)}")
    print(f"관련 대화 수: {len(all_conversations)}")

    print("\n=== 월별 분포 ===")
    for month in sorted(monthly_stats.keys()):
        month_name = calendar.month_name[month]
        stats = monthly_stats[month]
        print(f"{month}월 ({month_name}): {stats['count']}개 메시지, {len(stats['conversations'])}개 대화")

    print("\n=== 주요 기술 테마 ===")
    for category, count in all_categories.most_common(10):
        print(f"{category}: {count}회")

    print("\n=== 주요 인물 ===")
    for person, count in all_people.most_common(10):
        print(f"{person}: {count}회 언급")

    # 상세 분석을 위한 데이터 저장
    analysis_data = {
        'total_messages': len(messages_2024),
        'substantial_messages': len(substantial_messages),
        'monthly_stats': dict(monthly_stats),
        'all_categories': dict(all_categories),
        'all_people': dict(all_people),
        'all_conversations': list(all_conversations)
    }

    # 분석 데이터를 JSON으로 저장
    with open('/home/lips/2024_analysis_data.json', 'w', encoding='utf-8') as f:
        # set을 list로 변환하여 JSON 직렬화 가능하게 만들기
        serializable_data = {}
        for key, value in analysis_data.items():
            if key == 'monthly_stats':
                serializable_data[key] = {}
                for month, stats in value.items():
                    serializable_data[key][month] = {
                        'count': stats['count'],
                        'messages': stats['messages'],
                        'categories': dict(stats['categories']),
                        'people': dict(stats['people']),
                        'conversations': list(stats['conversations'])
                    }
            else:
                serializable_data[key] = value

        json.dump(serializable_data, f, ensure_ascii=False, indent=2)

    print(f"\n분석 데이터가 /home/lips/2024_analysis_data.json에 저장되었습니다.")

    return analysis_data

if __name__ == "__main__":
    analysis_data = main()