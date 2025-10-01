const fs = require('fs');

// 한글 날짜 파싱
function parseKoreanDate(dateStr) {
    try {
        const match = dateStr.match(/(\d{4})년 (\d{1,2})월 (\d{1,2})일.*?(오전|오후) (\d{1,2})시 (\d{1,2})분/);
        if (match) {
            let [, year, month, day, ampm, hour, minute] = match;
            hour = parseInt(hour);
            if (ampm === '오후' && hour !== 12) hour += 12;
            if (ampm === '오전' && hour === 12) hour = 0;
            return `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')} ${hour.toString().padStart(2, '0')}:${minute.padStart(2, '0')}`;
        }
    } catch (e) {}
    return dateStr;
}

// 메시지 카테고리 분류
function categorizeMessage(text) {
    const textLower = text.toLowerCase();

    // PLC/통신 장애
    if (['plc', '통신', '연결', '끊', '수신', '미수신', 'kepserver', 'device', 'not responding'].some(k => textLower.includes(k))) {
        if (text.includes('1단조') || textLower.includes('1tan')) return ['PLC/통신 장애', '1단조'];
        if (text.includes('2단조') || textLower.includes('2tan')) return ['PLC/통신 장애', '2단조'];
        if (text.includes('소압') || textLower.includes('srl') || text.includes('소형압연')) {
            if (textLower.includes('dst')) return ['PLC/통신 장애', '소형압연 DST'];
            return ['PLC/통신 장애', '소형압연'];
        }
        if (text.includes('산세')) {
            if (text.includes('1산세')) return ['PLC/통신 장애', '1산세'];
            if (text.includes('2산세')) return ['PLC/통신 장애', '2산세'];
            return ['PLC/통신 장애', '산세'];
        }
        if (text.includes('소경')) return ['PLC/통신 장애', '소경'];
        if (text.includes('2제강') || textLower.includes('bgm')) return ['PLC/통신 장애', '2제강/BGM'];
        if (textLower.includes('quenching') || text.includes('퀜칭')) return ['PLC/통신 장애', 'QUENCHING'];
        if (textLower.includes('rfm')) return ['PLC/통신 장애', 'RFM'];
        return ['PLC/통신 장애', '기타'];
    }

    // 트래킹/데이터 수신 이슈
    if (['트래킹', 'tracking', '지시', '실적', '수신'].some(k => textLower.includes(k))) {
        if (text.includes('소경')) return ['트래킹/데이터', '소경'];
        if (text.includes('산세')) return ['트래킹/데이터', '산세'];
        if (text.includes('2제강') || text.includes('연주') || text.includes('빌렛')) return ['트래킹/데이터', '2제강/연주'];
        return ['트래킹/데이터', '기타'];
    }

    // 담당자 변경
    if (['담당자', '퇴사', '변경'].some(k => text.includes(k))) return ['조직/담당자 변경', '담당자 변경'];

    // 일반 문의
    if (['문의', '확인', '부탁', '질문'].some(k => text.includes(k))) return ['일반 문의', '기타'];

    return ['기타', '미분류'];
}

// 대화 유형 결정
function determineConversationType(messages) {
    if (!messages.length) return "기타";
    const firstText = (messages[0].text || '').toLowerCase();

    if (['확인 부탁', '문의', '질문'].some(k => firstText.includes(k))) return "질의응답";
    if (['장애', '미수신', '끊', '문제'].some(k => firstText.includes(k))) return "장애보고";
    if (['요청', '작업', '변경'].some(k => firstText.includes(k))) return "작업요청";
    if (['퇴사', '담당자', '변경'].some(k => firstText.includes(k))) return "정보공유";
    return "일반";
}

// 설비 추출
function extractEquipment(text) {
    const patterns = [
        /(\d+단조)/, /(소형압연)/, /(소압)/, /(\d+산세)/, /(산세)/,
        /(소경)/, /(\d+제강)/, /(BGM)/, /(RFM)/, /(DST)/,
        /(QUENCHING)/, /(퀜칭)/, /(연주)/, /(빌렛)/,
        /(PLC)/, /(KEPSERVER)/, /(Kepserver)/
    ];

    const equipment = new Set();
    patterns.forEach(pattern => {
        const matches = text.match(new RegExp(pattern, 'gi'));
        if (matches) matches.forEach(m => equipment.add(m));
    });

    return equipment.size ? Array.from(equipment) : ['명시되지 않음'];
}

// 마크다운 생성
function generateMarkdown(conversations) {
    let output = [];
    output.push("# 2025년 대화 내용 주제별 정리\n");
    output.push(`생성일시: ${new Date().toLocaleString('ko-KR')}\n`);
    output.push("---\n\n");

    // 카테고리별 그룹화
    const byCategory = {};
    conversations.forEach(conv => {
        if (!byCategory[conv.category]) byCategory[conv.category] = [];
        byCategory[conv.category].push(conv);
    });

    const categoryOrder = [
        'PLC/통신 장애',
        '트래킹/데이터',
        '조직/담당자 변경',
        '일반 문의',
        '기타'
    ];

    // 통계 정보
    output.push("## 전체 통계\n\n");
    const totalConversations = conversations.length;
    const totalMessages = conversations.reduce((sum, c) => sum + c.messageCount, 0);
    output.push(`- **총 대화 건수**: ${totalConversations}건\n`);
    output.push(`- **총 메시지 수**: ${totalMessages}개\n\n`);

    output.push("### 카테고리별 통계\n\n");
    categoryOrder.forEach(cat => {
        if (byCategory[cat]) {
            const convs = byCategory[cat];
            const count = convs.length;
            const msgCount = convs.reduce((sum, c) => sum + c.messageCount, 0);
            output.push(`- **${cat}**: ${count}건 (${msgCount}개 메시지)\n`);

            // 서브카테고리 통계
            const subcats = {};
            convs.forEach(conv => {
                subcats[conv.subcategory] = (subcats[conv.subcategory] || 0) + 1;
            });

            Object.entries(subcats).sort((a, b) => b[1] - a[1]).forEach(([subcat, cnt]) => {
                output.push(`  - ${subcat}: ${cnt}건\n`);
            });
        }
    });

    output.push("\n---\n\n");

    // 목차 추가
    output.push("## 목차 (Table of Contents)\n\n");
    categoryOrder.forEach(cat => {
        if (byCategory[cat]) {
            output.push(`### [${cat}](#${cat.replace(/\//g, '').replace(/\s/g, '-').toLowerCase()})\n`);

            const bySubcat = {};
            byCategory[cat].forEach(conv => {
                if (!bySubcat[conv.subcategory]) bySubcat[conv.subcategory] = 0;
                bySubcat[conv.subcategory]++;
            });

            Object.entries(bySubcat).sort().forEach(([subcat, count]) => {
                output.push(`- [${subcat} (${count}건)](#${subcat.replace(/\//g, '').replace(/\s/g, '-').toLowerCase()})\n`);
            });
            output.push("\n");
        }
    });

    output.push("---\n\n");

    // 카테고리별 상세 내용
    categoryOrder.forEach(category => {
        if (!byCategory[category]) return;

        output.push(`# ${category}\n\n`);

        // 서브카테고리별 그룹화
        const bySubcat = {};
        byCategory[category].forEach(conv => {
            if (!bySubcat[conv.subcategory]) bySubcat[conv.subcategory] = [];
            bySubcat[conv.subcategory].push(conv);
        });

        Object.entries(bySubcat).sort().forEach(([subcategory, convs]) => {
            output.push(`## ${subcategory}\n\n`);

            convs.forEach((conv, idx) => {
                const messages = conv.messages;
                const firstMsg = conv.firstMessage;

                // 제목 생성
                const firstText = firstMsg.text || '';
                const titleLines = firstText.split('\n');
                const title = titleLines[0] ? titleLines[0].substring(0, 100) : "제목 없음";

                // 대화 유형
                const convType = determineConversationType(messages);

                // 설비 추출
                const equipment = extractEquipment(firstText);

                // 시간 파싱
                const dateStr = parseKoreanDate(firstMsg.created_date || '');

                output.push(`### [${idx + 1}] ${title}\n\n`);
                output.push(`**유형:** ${convType}\n\n`);
                output.push(`**관련 설비/시스템:** ${equipment.join(', ')}\n\n`);
                output.push(`**발생 일시:** ${dateStr}\n\n`);
                output.push(`**최초 보고자:** ${firstMsg.creator?.name || '알 수 없음'}\n\n`);

                output.push("#### 대화 내용\n\n");

                messages.forEach(msg => {
                    const creatorName = msg.creator?.name || '알 수 없음';
                    const text = msg.text || '';
                    const timeStr = parseKoreanDate(msg.created_date || '');

                    // 시간만 추출 (HH:MM)
                    const timeOnly = timeStr.split(' ')[1] || timeStr;

                    if (text) {
                        // 긴 텍스트는 들여쓰기
                        if (text.includes('\n')) {
                            output.push(`**${timeOnly} [${creatorName}]:**\n\`\`\`\n${text}\n\`\`\`\n\n`);
                        } else {
                            output.push(`- **${timeOnly} [${creatorName}]:** ${text}\n`);
                        }
                    }

                    // 첨부파일 정보
                    if (msg.attached_files && msg.attached_files.length) {
                        msg.attached_files.forEach(file => {
                            output.push(`  - 📎 첨부파일: ${file.original_name || '알 수 없음'}\n`);
                        });
                    }

                    output.push("\n");
                });

                output.push(`**관련 메시지 수:** ${conv.messageCount}개\n\n`);
                output.push(`**참여자:** ${conv.participants.join(', ')}\n\n`);
                output.push("---\n\n");
            });
        });
    });

    return output.join('');
}

// 메인 실행
console.log("2025년 데이터 분석 시작...");

// JSON 파일 읽기
const data = JSON.parse(fs.readFileSync('messages.json', 'utf-8'));
console.log(`전체 메시지 수: ${data.messages.length}`);

// 2025년 메시지 필터링
const messages2025 = data.messages.filter(msg => msg.created_date && msg.created_date.includes('2025년'));
console.log(`2025년 메시지 수: ${messages2025.length}`);

// topic_id로 그룹화
const topicGroups = {};
messages2025.forEach(msg => {
    const topicId = msg.topic_id || 'unknown';
    if (!topicGroups[topicId]) topicGroups[topicId] = [];
    topicGroups[topicId].push(msg);
});

console.log(`고유 topic 수: ${Object.keys(topicGroups).length}`);

// 각 대화 분석
const conversations = [];
Object.entries(topicGroups).forEach(([topicId, messages]) => {
    if (!messages.length) return;

    // 시간순 정렬
    messages.sort((a, b) => (a.created_date || '').localeCompare(b.created_date || ''));

    const firstMsg = messages[0];
    const firstText = firstMsg.text || '';

    // 카테고리 분류
    const [category, subcategory] = categorizeMessage(firstText);

    // 참여자 추출
    const participants = new Set();
    messages.forEach(msg => {
        const name = msg.creator?.name;
        if (name) participants.add(name);
    });

    conversations.push({
        category,
        subcategory,
        firstMessage: firstMsg,
        messages,
        participants: Array.from(participants).sort(),
        messageCount: messages.length
    });
});

console.log(`분석된 대화 수: ${conversations.length}`);

// 마크다운 생성
const markdownContent = generateMarkdown(conversations);

// 파일 저장
const outputFile = '2025_conversations_by_topic.md';
fs.writeFileSync(outputFile, markdownContent, 'utf-8');

console.log(`\n마크다운 파일 생성 완료: ${outputFile}`);

// 통계 출력
console.log("\n=== 주제별 케이스 개수 ===");
const byCategory = {};
conversations.forEach(conv => {
    if (!byCategory[conv.category]) byCategory[conv.category] = [];
    byCategory[conv.category].push(conv);
});

Object.entries(byCategory).sort().forEach(([category, convs]) => {
    console.log(`${category}: ${convs.length}건`);

    // 서브카테고리별
    const bySubcat = {};
    convs.forEach(conv => {
        bySubcat[conv.subcategory] = (bySubcat[conv.subcategory] || 0) + 1;
    });

    Object.entries(bySubcat).sort((a, b) => b[1] - a[1]).forEach(([subcat, count]) => {
        console.log(`  - ${subcat}: ${count}건`);
    });
});

console.log("\n작업 완료!");