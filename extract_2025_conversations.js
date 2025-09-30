const fs = require('fs');

console.log("Loading messages.json...");
const data = JSON.parse(fs.readFileSync('D:\\git\\myTest\\messages.json', 'utf-8'));
const messages = data.messages;
console.log(`Total messages loaded: ${messages.length}`);

// 2025년 메시지 필터링
console.log("Filtering 2025 messages...");
const messages2025 = messages.filter(msg =>
    msg.created_date && msg.created_date.startsWith('2025년')
);
console.log(`2025 messages found: ${messages2025.length}`);

// topic_id별로 그룹화
console.log("Grouping by topic_id...");
const topics = {};
messages2025.forEach(msg => {
    const topicId = msg.topic_id || 'no_topic';
    if (!topics[topicId]) {
        topics[topicId] = [];
    }
    topics[topicId].push(msg);
});

const topicCount = Object.keys(topics).length;
console.log(`Total topics: ${topicCount}`);

// 한국어 날짜 파싱 함수
function parseKoreanDate(dateStr) {
    try {
        // "2025년 1월 3일 금요일 오전 12시 30분 36초 UTC" 형식
        const parts = dateStr.split(' ');
        const year = parseInt(parts[0].replace('년', ''));
        const month = parseInt(parts[1].replace('월', ''));
        const day = parseInt(parts[2].replace('일', ''));

        const timePeriod = parts[4]; // 오전 or 오후
        const timeParts = parts[5].split('시');
        let hour = parseInt(timeParts[0]);

        const minuteParts = timeParts[1].split('분');
        const minute = parseInt(minuteParts[0]);

        const secondParts = minuteParts[1].split('초');
        const second = parseInt(secondParts[0]);

        // 오후 처리
        if (timePeriod === '오후' && hour !== 12) {
            hour += 12;
        } else if (timePeriod === '오전' && hour === 12) {
            hour = 0;
        }

        return new Date(year, month - 1, day, hour, minute, second);
    } catch (e) {
        return new Date(1900, 0, 1);
    }
}

// 각 토픽별로 시간순 정렬
console.log("Sorting messages by time within each topic...");
Object.keys(topics).forEach(topicId => {
    topics[topicId].sort((a, b) => {
        const dateA = parseKoreanDate(a.created_date || '');
        const dateB = parseKoreanDate(b.created_date || '');
        return dateA - dateB;
    });
});

// 토픽을 첫 메시지 시간 기준으로 정렬
const sortedTopics = Object.entries(topics).sort((a, b) => {
    const dateA = parseKoreanDate(a[1][0].created_date || '');
    const dateB = parseKoreanDate(b[1][0].created_date || '');
    return dateA - dateB;
});

// 결과 파일 작성
const outputFile = 'D:\\git\\myTest\\2025_conversations_organized.md';
console.log(`Writing organized conversations to ${outputFile}...`);

let output = "# 2025년 대화 내용 정리\n\n";
output += "## 개요\n";
output += `- **총 메시지 수**: ${messages2025.length}개\n`;
output += `- **총 대화 주제(Topic) 수**: ${topicCount}개\n`;
output += `- **정리 날짜**: 2025년 9월 30일\n\n`;
output += "---\n\n";

// 각 토픽별로 작성
sortedTopics.forEach(([topicId, msgs], idx) => {
    output += `## Topic ${idx + 1}: ${topicId}\n\n`;

    // 첫 메시지 정보
    const firstMsg = msgs[0];
    const creator = firstMsg.creator || {};
    const creatorName = creator.name || 'Unknown';
    const creatorEmail = creator.email || 'Unknown';
    const firstDate = firstMsg.created_date || 'Unknown';

    output += `**주제 시작자**: ${creatorName} (${creatorEmail})\n`;
    output += `**시작 시간**: ${firstDate}\n`;
    output += `**메시지 수**: ${msgs.length}개\n\n`;

    // 모든 메시지 작성
    output += "### 대화 내용\n\n";

    msgs.forEach((msg, msgIdx) => {
        const msgCreator = msg.creator || {};
        const msgName = msgCreator.name || 'Unknown';
        const msgEmail = msgCreator.email || 'Unknown';
        const msgDate = msg.created_date || 'Unknown';
        const msgText = msg.text || '';

        output += `#### 메시지 ${msgIdx + 1}\n`;
        output += `**작성자**: ${msgName} (${msgEmail})\n`;
        output += `**시간**: ${msgDate}\n\n`;

        if (msgText) {
            output += `**내용**:\n\`\`\`\n${msgText}\n\`\`\`\n\n`;
        } else {
            output += "**내용**: (텍스트 없음)\n\n";
        }

        // 첨부 파일 정보
        const attachedFiles = msg.attached_files || [];
        if (attachedFiles.length > 0) {
            output += "**첨부 파일**:\n";
            attachedFiles.forEach(file => {
                const originalName = file.original_name || 'Unknown';
                const exportName = file.export_name || 'Unknown';
                output += `- ${originalName} (내보내기: ${exportName})\n`;
            });
            output += "\n";
        }

        // 반응(reactions) 정보
        const reactions = msg.reactions || [];
        if (reactions.length > 0) {
            output += "**반응**:\n";
            reactions.forEach(reaction => {
                const emoji = (reaction.emoji && reaction.emoji.unicode) || '';
                const reactorEmails = reaction.reactor_emails || [];
                output += `- ${emoji} by ${reactorEmails.join(', ')}\n`;
            });
            output += "\n";
        }

        // 주석(annotations) 정보
        const annotations = msg.annotations || [];
        if (annotations.length > 0) {
            output += `**주석**: ${annotations.length}개의 서식 정보 포함\n\n`;
        }

        output += "---\n\n";
    });

    output += "\n\n";
});

fs.writeFileSync(outputFile, output, 'utf-8');
console.log("Done!");

// 주요 대화 주제 분석
console.log("\n=== 주요 대화 주제 분석 ===");

// 메시지 수가 많은 순으로 정렬
const sortedByCount = Object.entries(topics).sort((a, b) => b[1].length - a[1].length).slice(0, 20);

console.log("\n주요 대화 주제 (메시지 수가 많은 순):");
sortedByCount.forEach(([topicId, msgs]) => {
    const firstText = msgs[0].text || '';
    const summary = firstText.substring(0, 80).replace(/\n/g, ' ');
    console.log(`- ${topicId}: ${msgs.length}개 메시지 - ${summary}...`);
});

console.log(`\n총 결과:`);
console.log(`- 2025년 메시지 총 개수: ${messages2025.length}`);
console.log(`- 대화 주제(Topic) 개수: ${topicCount}`);
console.log(`- 출력 파일: ${outputFile}`);