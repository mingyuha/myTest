#!/usr/bin/env python3
import json
import re
from datetime import datetime
from collections import defaultdict

def extract_2023_messages(file_path):
    """
    Extract all 2023 messages from the JSON file and organize them chronologically
    """

    # Store messages by month for organization
    messages_by_month = defaultdict(list)

    # Lists to track different types of content
    technical_discussions = []
    substantive_messages = []

    # Korean month mapping
    month_mapping = {
        '1월': '01', '2월': '02', '3월': '03', '4월': '04',
        '5월': '05', '6월': '06', '7월': '07', '8월': '08',
        '9월': '09', '10월': '10', '11월': '11', '12월': '12'
    }

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        message_count = 0

        # Extract messages from the data structure
        messages = data.get('messages', [])

        for message in messages:
            created_date = message.get('created_date', '')

            # Check if message is from 2023
            if '2023년' in created_date:
                message_count += 1

                # Extract month information
                month_match = re.search(r'2023년 (\d+월)', created_date)
                if month_match:
                    month = month_match.group(1)

                    # Parse the message details
                    creator = message.get('creator', {})
                    creator_name = creator.get('name', 'Unknown')
                    creator_email = creator.get('email', '')

                    text_content = message.get('text', '')
                    attached_files = message.get('attached_files', [])
                    annotations = message.get('annotations', [])

                    # Skip very short or greeting-only messages
                    skip_patterns = [
                        r'^안녕하세요\.?$',
                        r'^감사합니다\.?$',
                        r'^넵\.?$',
                        r'^네\.?$',
                        r'^ㅋㅋ$',
                        r'^아\.+$',
                        r'^넵\.+$'
                    ]

                    is_substantive = True
                    if text_content:
                        text_stripped = text_content.strip()
                        if len(text_stripped) < 10:
                            is_substantive = False
                        for pattern in skip_patterns:
                            if re.match(pattern, text_stripped):
                                is_substantive = False
                                break

                    # Check for technical content indicators
                    technical_keywords = [
                        'tag', 'kepserver', 'plc', 'address', 'iba', 'grafana',
                        '압연', '설비', '연결', '데이터', '수집', '확인',
                        '가동', '공장', '실적', '절단', 'cpu', 'rack',
                        '통신', '상태', 'bad', 'good', '시스템'
                    ]

                    is_technical = False
                    if text_content:
                        text_lower = text_content.lower()
                        for keyword in technical_keywords:
                            if keyword.lower() in text_lower:
                                is_technical = True
                                break

                    # Check for attachments or links
                    has_attachments = len(attached_files) > 0 or len(annotations) > 0

                    message_info = {
                        'date': created_date,
                        'creator_name': creator_name,
                        'creator_email': creator_email,
                        'text': text_content,
                        'attached_files': attached_files,
                        'annotations': annotations,
                        'topic_id': message.get('topic_id', ''),
                        'message_id': message.get('message_id', ''),
                        'is_substantive': is_substantive,
                        'is_technical': is_technical,
                        'has_attachments': has_attachments
                    }

                    messages_by_month[month].append(message_info)

                    if is_substantive:
                        substantive_messages.append(message_info)

                    if is_technical:
                        technical_discussions.append(message_info)

        print(f"Total 2023 messages found: {message_count}")
        print(f"Substantive messages: {len(substantive_messages)}")
        print(f"Technical discussions: {len(technical_discussions)}")
        print()

        # Sort messages by month
        sorted_months = sorted(messages_by_month.keys(), key=lambda x: int(x.replace('월', '')))

        # Print summary by month
        for month in sorted_months:
            month_messages = messages_by_month[month]
            substantive_count = sum(1 for msg in month_messages if msg['is_substantive'])
            technical_count = sum(1 for msg in month_messages if msg['is_technical'])

            print(f"2023년 {month}:")
            print(f"  Total messages: {len(month_messages)}")
            print(f"  Substantive: {substantive_count}")
            print(f"  Technical: {technical_count}")
            print()

        return messages_by_month, substantive_messages, technical_discussions

    except Exception as e:
        print(f"Error processing file: {e}")
        return {}, [], []

def analyze_conversations_by_topic(messages_by_month):
    """
    Group messages by topic to identify conversation threads
    """
    topics = defaultdict(list)

    for month, month_messages in messages_by_month.items():
        for message in month_messages:
            topic_id = message['topic_id']
            if topic_id:
                topics[topic_id].append(message)

    # Find topics with multiple substantive messages (conversations)
    conversation_topics = {}
    for topic_id, topic_messages in topics.items():
        substantive_messages = [msg for msg in topic_messages if msg['is_substantive']]
        if len(substantive_messages) >= 2:  # At least 2 substantive messages = conversation
            conversation_topics[topic_id] = substantive_messages

    return conversation_topics

def print_detailed_analysis(messages_by_month, conversation_topics):
    """
    Print detailed analysis of 2023 messages
    """
    print("\n" + "="*80)
    print("COMPREHENSIVE 2023 MESSAGE ANALYSIS")
    print("="*80)

    # Sort months chronologically
    sorted_months = sorted(messages_by_month.keys(), key=lambda x: int(x.replace('월', '')))

    for month in sorted_months:
        month_messages = messages_by_month[month]
        substantive_messages = [msg for msg in month_messages if msg['is_substantive']]
        technical_messages = [msg for msg in month_messages if msg['is_technical']]

        print(f"\n{'='*50}")
        print(f"2023년 {month}")
        print(f"{'='*50}")
        print(f"Total messages: {len(month_messages)}")
        print(f"Substantive messages: {len(substantive_messages)}")
        print(f"Technical discussions: {len(technical_messages)}")

        if substantive_messages:
            print(f"\nKey Substantive Discussions:")
            print("-" * 30)

            # Group by creator for better organization
            by_creator = defaultdict(list)
            for msg in substantive_messages:
                by_creator[msg['creator_name']].append(msg)

            for creator, creator_messages in by_creator.items():
                if len(creator_messages) >= 2:  # Multiple messages from same person
                    print(f"\n{creator}:")
                    for msg in creator_messages[:5]:  # Limit to first 5 messages
                        text_preview = msg['text'][:100] + "..." if len(msg['text']) > 100 else msg['text']
                        print(f"  - {msg['date'][:20]}: {text_preview}")

        # Show key technical discussions
        if technical_messages:
            print(f"\nKey Technical Discussions:")
            print("-" * 30)
            shown_count = 0
            for msg in technical_messages:
                if shown_count >= 10:  # Limit output
                    break
                if msg['is_substantive']:
                    text_preview = msg['text'][:100] + "..." if len(msg['text']) > 100 else msg['text']
                    print(f"  {msg['creator_name']}: {text_preview}")
                    shown_count += 1

    # Analyze conversation topics
    print(f"\n{'='*50}")
    print("MAJOR CONVERSATION TOPICS")
    print(f"{'='*50}")

    # Sort topics by number of messages
    sorted_topics = sorted(conversation_topics.items(), key=lambda x: len(x[1]), reverse=True)

    for i, (topic_id, topic_messages) in enumerate(sorted_topics[:20]):  # Top 20 topics
        print(f"\nTopic {i+1} (ID: {topic_id[-8:]}):")
        print(f"Messages: {len(topic_messages)}")

        # Get date range
        dates = [msg['date'] for msg in topic_messages]
        first_date = min(dates)[:20]
        last_date = max(dates)[:20]
        print(f"Duration: {first_date} to {last_date}")

        # Show participants
        participants = set(msg['creator_name'] for msg in topic_messages)
        print(f"Participants: {', '.join(list(participants)[:5])}")

        # Show key messages
        print("Key messages:")
        for msg in topic_messages[:3]:  # First 3 messages
            text_preview = msg['text'][:80] + "..." if len(msg['text']) > 80 else msg['text']
            print(f"  {msg['creator_name']}: {text_preview}")

if __name__ == "__main__":
    file_path = "/home/lips/messages.json"

    print("Analyzing 2023 messages from messages.json...")
    print("This may take a moment for large files...\n")

    messages_by_month, substantive_messages, technical_discussions = extract_2023_messages(file_path)

    if messages_by_month:
        conversation_topics = analyze_conversations_by_topic(messages_by_month)
        print_detailed_analysis(messages_by_month, conversation_topics)

        # Save detailed results to file
        output_file = "/home/lips/2023_messages_analysis.json"

        analysis_results = {
            'summary': {
                'total_months': len(messages_by_month),
                'total_messages': sum(len(msgs) for msgs in messages_by_month.values()),
                'substantive_messages': len(substantive_messages),
                'technical_discussions': len(technical_discussions),
                'conversation_topics': len(conversation_topics)
            },
            'messages_by_month': messages_by_month,
            'conversation_topics': conversation_topics
        }

        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(analysis_results, f, ensure_ascii=False, indent=2)

        print(f"\n\nDetailed analysis saved to: {output_file}")
        print("Analysis complete!")
    else:
        print("No 2023 messages found or error occurred.")