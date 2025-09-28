#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import calendar
from collections import Counter

def format_date_range(month):
    """월별 날짜 범위 표시"""
    month_name = calendar.month_name[month]
    return f"2024년 {month}월 ({month_name})"

def create_comprehensive_report():
    """2024년 종합 분석 보고서 생성"""

    # 상세 분석 데이터 로드
    with open('/home/lips/2024_detailed_analysis.json', 'r', encoding='utf-8') as f:
        analysis = json.load(f)

    summary = analysis['summary']
    monthly_analysis = analysis['monthly_analysis']

    report = []

    # 보고서 헤더
    report.append("# 2024년 메시지 종합 분석 보고서 (완전판)")
    report.append("")
    report.append("이 보고서는 2024년 전체 메시지를 체계적으로 분석하여 주요 기술적 이슈, 프로젝트, 인물들의 활동을 종합적으로 정리한 문서입니다.")
    report.append("")

    # 전체 요약
    report.append("## 📊 전체 요약")
    report.append("")
    report.append(f"- **총 메시지 수**: {summary['total_messages']:,}개")
    report.append(f"- **실질적 메시지**: {summary['substantial_messages']:,}개")
    report.append(f"- **비실질적 메시지**: {summary['total_messages'] - summary['substantial_messages']:,}개")
    report.append(f"- **참여 대화**: {summary['total_conversations']:,}개")
    report.append(f"- **분석 기간**: 2024년 1월 ~ 10월")
    report.append("")

    # 월별 분포
    report.append("## 📅 월별 메시지 분포")
    report.append("")
    report.append("| 월 | 메시지 수 | 대화 수 | 주요 특징 |")
    report.append("|---|---|---|---|")

    monthly_totals = {}
    for month_str, data in monthly_analysis.items():
        month = int(month_str)
        monthly_totals[month] = data

    for month in sorted(monthly_totals.keys()):
        data = monthly_totals[month]
        month_name = data['month_name']
        total_msg = data['total_messages']
        total_conv = data['total_conversations']

        # 주요 특징 추출
        top_categories = sorted(data['categories'].items(), key=lambda x: x[1], reverse=True)[:2]
        features = ", ".join([f"{cat}({count})" for cat, count in top_categories])

        report.append(f"| {month}월 | {total_msg} | {total_conv} | {features} |")

    report.append("")

    # 주요 기술 테마
    report.append("## 🔧 주요 기술 테마 분석")
    report.append("")
    sorted_categories = sorted(summary['all_categories'].items(), key=lambda x: x[1], reverse=True)

    category_descriptions = {
        'general': '일반적인 기술 토론 및 업무 협의',
        'network': '네트워크, 통신, API 관련 이슈',
        'troubleshooting': '장애 대응 및 문제 해결',
        'server': '서버, 시스템, 성능 관련',
        'database': '데이터베이스, SQL, 데이터 처리',
        'monitoring': '모니터링, 감시, 알림 시스템',
        'automation': '자동화, 스크립트, 배치 작업',
        'security': '보안, 권한, 인증 관련',
        'backup': '백업, 복구, 데이터 보호',
        'deployment': '배포, 릴리즈, 업데이트',
        'infrastructure': '인프라, 클라우드, 플랫폼'
    }

    for category, count in sorted_categories:
        description = category_descriptions.get(category, '기타 기술 관련')
        percentage = (count / summary['substantial_messages']) * 100
        report.append(f"- **{category.title()}**: {count}회 ({percentage:.1f}%) - {description}")

    report.append("")

    # 주요 인물 분석
    report.append("## 👥 주요 인물 및 역할")
    report.append("")
    sorted_people = sorted(summary['all_people'].items(), key=lambda x: x[1], reverse=True)[:15]

    for person, count in sorted_people:
        percentage = (count / summary['substantial_messages']) * 100
        report.append(f"- **{person}**: {count}회 언급 ({percentage:.1f}%)")

    report.append("")

    # 월별 상세 분석
    report.append("## 📝 월별 상세 분석")
    report.append("")

    for month in sorted(monthly_totals.keys()):
        data = monthly_totals[month]
        month_name = data['month_name']

        report.append(f"### {month}월 ({month_name}) - {data['total_messages']}개 메시지")
        report.append("")

        # 월별 주요 카테고리
        if data['categories']:
            report.append("**주요 기술 영역:**")
            sorted_cats = sorted(data['categories'].items(), key=lambda x: x[1], reverse=True)[:5]
            for cat, count in sorted_cats:
                report.append(f"- {cat}: {count}회")
            report.append("")

        # 월별 주요 인물
        if data['people']:
            report.append("**주요 참여자:**")
            sorted_people_month = sorted(data['people'].items(), key=lambda x: x[1], reverse=True)[:5]
            for person, count in sorted_people_month:
                report.append(f"- {person}: {count}회")
            report.append("")

        # 주요 기술적 토픽
        if data['key_topics']:
            report.append("**주요 기술적 이슈:**")
            for i, topic in enumerate(data['key_topics'][:8], 1):  # 상위 8개만
                text = topic['text'].replace('\n', ' ').strip()
                if len(text) > 100:
                    text = text[:97] + "..."
                creator = topic['creator']
                report.append(f"{i}. **{creator}**: {text}")
            report.append("")

        # 반복 이슈
        if data['recurring_issues']:
            report.append("**반복되는 기술적 이슈:**")
            for issue_type, issues in data['recurring_issues'].items():
                if issues:  # 이슈가 있는 경우만
                    report.append(f"- **{issue_type}**: {len(issues)}건")
                    # 첫 번째 이슈의 예시
                    if issues:
                        example = issues[0]['text'][:150].replace('\n', ' ')
                        report.append(f"  - 예시: {example}...")
            report.append("")

        # 프로젝트 및 이니셔티브
        if data['projects']:
            report.append("**주요 프로젝트/이니셔티브:**")
            for i, project in enumerate(data['projects'][:5], 1):  # 상위 5개
                desc = project['description'].replace('\n', ' ').strip()
                if len(desc) > 120:
                    desc = desc[:117] + "..."
                creator = project['creator']
                report.append(f"{i}. **{creator}**: {desc}")
            report.append("")

        report.append("---")
        report.append("")

    # 주요 반복 테마 분석
    report.append("## 🔄 2024년 주요 반복 기술 이슈")
    report.append("")

    # 모든 월의 반복 이슈를 수집
    all_recurring_issues = Counter()
    for month_data in monthly_totals.values():
        for issue_type, issues in month_data.get('recurring_issues', {}).items():
            all_recurring_issues[issue_type] += len(issues)

    if all_recurring_issues:
        report.append("2024년 동안 지속적으로 나타난 기술적 이슈들:")
        report.append("")
        for issue_type, total_count in all_recurring_issues.most_common(10):
            report.append(f"- **{issue_type}**: {total_count}건 (연중 반복)")
        report.append("")

    # 기술적 성과 및 도전과제
    report.append("## 🎯 기술적 성과 및 도전과제")
    report.append("")

    report.append("### 주요 성과")
    report.append("- 체계적인 기술 이슈 추적 및 해결")
    report.append("- 다양한 기술 영역에서의 협업 강화")
    report.append("- 실시간 모니터링 및 장애 대응 체계 운영")
    report.append("- 네트워크 및 시스템 안정성 개선")
    report.append("")

    report.append("### 주요 도전과제")
    report.append("- BGM 실적 수신 관련 지속적인 이슈")
    report.append("- 네트워크 연결 및 데이터 전송 안정성")
    report.append("- 시스템 간 통합 및 호환성 문제")
    report.append("- 실시간 데이터 처리 및 모니터링 최적화")
    report.append("")

    # 교훈 및 향후 방향
    report.append("## 💡 교훈 및 향후 방향")
    report.append("")
    report.append("### 주요 교훈")
    report.append("1. **지속적인 모니터링의 중요성**: 시스템 안정성을 위한 24/7 모니터링 필수")
    report.append("2. **신속한 협업 체계**: 기술 이슈 발생 시 즉각적인 전문가 간 협력")
    report.append("3. **문서화의 필요성**: 반복되는 이슈에 대한 체계적인 해결책 문서화")
    report.append("4. **예방적 접근**: 사후 대응보다는 사전 예방을 통한 안정성 확보")
    report.append("")

    report.append("### 향후 개선 방향")
    report.append("1. **자동화 강화**: 반복적인 기술 이슈의 자동 감지 및 대응")
    report.append("2. **통합 모니터링**: 시스템 전반의 통합적 모니터링 체계 구축")
    report.append("3. **기술 역량 강화**: 새로운 기술 동향에 대한 지속적인 학습 및 적용")
    report.append("4. **프로세스 개선**: 효율적인 기술 지원 및 문제 해결 프로세스 정립")
    report.append("")

    # 메타데이터
    report.append("---")
    report.append("")
    report.append("## 📋 보고서 메타데이터")
    report.append("")
    report.append(f"- **생성일**: 2024년 (재분석)")
    report.append(f"- **분석 대상**: 2024년 1월 ~ 10월 메시지")
    report.append(f"- **총 데이터**: {summary['total_messages']}개 메시지")
    report.append(f"- **분석 범위**: 실질적 기술 토론 및 이슈 해결")
    report.append(f"- **보고서 버전**: v2.0 (완전 재분석)")

    return "\n".join(report)

def main():
    print("2024년 종합 분석 보고서 생성 중...")

    # 보고서 생성
    report_content = create_comprehensive_report()

    # 파일로 저장
    output_file = '/home/lips/2024_messages_comprehensive_summary_v2.md'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(report_content)

    print(f"종합 분석 보고서가 생성되었습니다: {output_file}")

    # 기본 통계 출력
    with open('/home/lips/2024_detailed_analysis.json', 'r', encoding='utf-8') as f:
        analysis = json.load(f)

    summary = analysis['summary']
    monthly_analysis = analysis['monthly_analysis']

    print("\n=== 최종 분석 결과 요약 ===")
    print(f"📊 발견된 2024년 메시지 총 개수: {summary['total_messages']}")
    print(f"✅ 실질적 메시지 수: {summary['substantial_messages']}")
    print(f"❌ 비실질적 메시지 수: {summary['total_messages'] - summary['substantial_messages']}")
    print(f"📅 월별 분포: 1월~10월 (10개월간)")
    print(f"👥 식별된 주요 인물: {len(summary['all_people'])}명")
    print(f"🔧 주요 기술 테마: {len(summary['all_categories'])}개 영역")
    print(f"📄 종합 분석 파일: {output_file}")

    return output_file

if __name__ == "__main__":
    result = main()