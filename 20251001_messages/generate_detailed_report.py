#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import re
from collections import defaultdict, Counter
from datetime import datetime
import calendar

def extract_key_topics_from_messages(messages):
    """메시지들에서 주요 기술적 주제 추출"""
    topics = []

    for msg in messages:
        text = msg.get('text', '')
        if len(text) < 20:  # 너무 짧은 메시지는 제외
            continue

        # 기술적 키워드나 이슈 패턴 찾기
        tech_patterns = [
            r'(BGM|배치|실적|수신|전송|데이터|시스템|서버|네트워크|DB|데이터베이스)',
            r'(오류|에러|장애|문제|이슈|해결|조치|복구)',
            r'(압연|제강|연주|가열로|냉간|열간|소재|트래킹)',
            r'(API|HTTP|TCP|UDP|통신|연결|접속)',
            r'(모니터링|감시|알림|경보|임계치)',
            r'(백업|복원|복구|저장)',
            r'(보안|권한|인증|암호화)',
            r'(자동화|스크립트|배치작업)',
            r'(성능|로드|CPU|메모리|디스크)',
            r'(버전|업데이트|배포|설치)'
        ]

        for pattern in tech_patterns:
            matches = re.findall(pattern, text, re.IGNORECASE)
            if matches:
                # 문맥과 함께 주제 추출
                sentences = re.split(r'[.!?]', text)
                for sentence in sentences:
                    if any(match in sentence for match in matches):
                        topics.append({
                            'text': sentence.strip()[:200],  # 최대 200자
                            'keywords': matches,
                            'date': msg.get('created_date', ''),
                            'creator': msg.get('creator', {}).get('name', 'Unknown')
                        })
                        break

    return topics

def analyze_recurring_issues(messages):
    """반복되는 기술적 이슈 분석"""
    issue_patterns = {
        'BGM 실적 수신 문제': r'BGM.*실적.*수신',
        '데이터 전송 이슈': r'데이터.*전송|전송.*데이터',
        '시스템 연결 문제': r'연결.*안됨|접속.*불가|통신.*장애',
        '압연 관련 이슈': r'압연.*문제|압연.*오류|압연.*장애',
        '백업/복구 관련': r'백업.*문제|복구.*필요|저장.*이슈',
        '성능 문제': r'성능.*저하|속도.*느림|로드.*높음',
        '권한/보안 이슈': r'권한.*문제|인증.*실패|보안.*이슈'
    }

    recurring_issues = defaultdict(list)

    for msg in messages:
        text = msg.get('text', '')
        for issue_type, pattern in issue_patterns.items():
            if re.search(pattern, text, re.IGNORECASE):
                recurring_issues[issue_type].append({
                    'date': msg.get('created_date', ''),
                    'creator': msg.get('creator', {}).get('name', 'Unknown'),
                    'text': text[:300]  # 처음 300자만
                })

    return dict(recurring_issues)

def extract_projects_and_initiatives(messages):
    """주요 프로젝트와 이니셔티브 추출"""
    projects = []

    project_keywords = [
        '프로젝트', '개발', '구축', '도입', '개선', '업그레이드',
        '시스템', '플랫폼', '솔루션', '구현', '적용'
    ]

    for msg in messages:
        text = msg.get('text', '')
        if len(text) < 30:
            continue

        # 프로젝트 관련 키워드가 포함된 메시지 찾기
        if any(keyword in text for keyword in project_keywords):
            # 문장 단위로 분리하여 프로젝트 관련 내용 추출
            sentences = re.split(r'[.!?]', text)
            for sentence in sentences:
                if any(keyword in sentence for keyword in project_keywords) and len(sentence.strip()) > 20:
                    projects.append({
                        'description': sentence.strip()[:200],
                        'date': msg.get('created_date', ''),
                        'creator': msg.get('creator', {}).get('name', 'Unknown')
                    })
                    break

    return projects

def generate_monthly_analysis(monthly_data):
    """월별 상세 분석 생성"""
    analysis = {}

    for month_str, data in monthly_data.items():
        month = int(month_str)  # 문자열을 정수로 변환
        messages = data['messages']
        month_name = calendar.month_name[month]

        # 주요 토픽 추출
        key_topics = extract_key_topics_from_messages(messages)

        # 반복 이슈 분석
        recurring_issues = analyze_recurring_issues(messages)

        # 프로젝트 추출
        projects = extract_projects_and_initiatives(messages)

        # 주요 대화 주제들
        conversation_topics = []
        seen_topics = set()

        for msg in messages:
            text = msg.get('text', '')
            creator = msg.get('creator', {}).get('name', 'Unknown')

            # 긴 메시지나 기술적 내용이 포함된 메시지 우선 선택
            if len(text) > 50 and creator not in seen_topics:
                conversation_topics.append({
                    'creator': creator,
                    'text': text[:300],
                    'date': msg.get('created_date', '')
                })
                seen_topics.add(creator)

                if len(conversation_topics) >= 10:  # 월별 최대 10개
                    break

        analysis[month] = {
            'month_name': month_name,
            'total_messages': data['count'],
            'total_conversations': len(data['conversations']),
            'key_topics': key_topics[:15],  # 상위 15개
            'recurring_issues': recurring_issues,
            'projects': projects[:10],  # 상위 10개
            'conversation_topics': conversation_topics,
            'categories': dict(data['categories']),
            'people': dict(data['people'])
        }

    return analysis

def main():
    # 분석 데이터 로드
    with open('/home/lips/2024_analysis_data.json', 'r', encoding='utf-8') as f:
        analysis_data = json.load(f)

    monthly_stats = analysis_data['monthly_stats']

    # 월별 상세 분석
    detailed_analysis = generate_monthly_analysis(monthly_stats)

    # 전체 분석 결과 저장
    final_analysis = {
        'summary': {
            'total_messages': analysis_data['total_messages'],
            'substantial_messages': analysis_data['substantial_messages'],
            'all_categories': analysis_data['all_categories'],
            'all_people': analysis_data['all_people'],
            'total_conversations': len(analysis_data['all_conversations'])
        },
        'monthly_analysis': detailed_analysis
    }

    # 상세 분석 데이터 저장
    with open('/home/lips/2024_detailed_analysis.json', 'w', encoding='utf-8') as f:
        json.dump(final_analysis, f, ensure_ascii=False, indent=2)

    print("상세 분석이 완료되었습니다.")
    print(f"결과 파일: /home/lips/2024_detailed_analysis.json")

    return final_analysis

if __name__ == "__main__":
    result = main()