const fs = require('fs');

console.log("Loading messages.json...");
const data = JSON.parse(fs.readFileSync('D:\\git\\myTest\\messages.json', 'utf-8'));
const messages = data.messages;

// 2025년 메시지 필터링
const messages2025 = messages.filter(msg =>
    msg.created_date && msg.created_date.startsWith('2025년')
);

// topic_id별로 그룹화
const topics = {};
messages2025.forEach(msg => {
    const topicId = msg.topic_id || 'no_topic';
    if (!topics[topicId]) {
        topics[topicId] = [];
    }
    topics[topicId].push(msg);
});

// 한국어 날짜 파싱 함수
function parseKoreanDate(dateStr) {
    try {
        const parts = dateStr.split(' ');
        const year = parseInt(parts[0].replace('년', ''));
        const month = parseInt(parts[1].replace('월', ''));
        const day = parseInt(parts[2].replace('일', ''));
        const timePeriod = parts[4];
        const timeParts = parts[5].split('시');
        let hour = parseInt(timeParts[0]);
        const minuteParts = timeParts[1].split('분');
        const minute = parseInt(minuteParts[0]);
        const secondParts = minuteParts[1].split('초');
        const second = parseInt(secondParts[0]);

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
Object.keys(topics).forEach(topicId => {
    topics[topicId].sort((a, b) => {
        const dateA = parseKoreanDate(a.created_date || '');
        const dateB = parseKoreanDate(b.created_date || '');
        return dateA - dateB;
    });
});

// 주제별 분류 키워드
const keywords = {
    'PLC/통신장애': ['PLC', 'plc', '통신', '연결', '접속', '네트워크', '수신', '미수신', '안되고'],
    '트래킹/실적': ['트래킹', 'trking', 'TRKING', '실적', 'L2실적', '소재ID'],
    '지시/작업지시': ['지시', '작업지시'],
    '제강': ['제강', '2제강', '3제강', '전기로'],
    '산세': ['산세', '1산세', '2산세'],
    '압연': ['압연', '소형압연', '소압', '조압연', '중간압연', '사상압연', 'roughmill', 'bgm'],
    '소경': ['소경'],
    '빌렛연주': ['빌렛연주', '빌렛'],
    '1단조': ['1단조', '단조'],
    '정기수리/점검': ['정기수리', '점검', '수리'],
    '그라파나/대시보드': ['그라파나', 'Grafana', '대시보드'],
    '공수등록': ['공수', '수주번호'],
    '기타': []
};

// 각 토픽을 카테고리별로 분류
const categorizedTopics = {};
Object.keys(keywords).forEach(category => {
    categorizedTopics[category] = [];
});

Object.entries(topics).forEach(([topicId, msgs]) => {
    const firstText = msgs[0].text || '';
    let categorized = false;

    // 키워드 매칭
    for (const [category, keywordList] of Object.entries(keywords)) {
        if (category === '기타') continue;

        for (const keyword of keywordList) {
            if (firstText.includes(keyword)) {
                categorizedTopics[category].push([topicId, msgs]);
                categorized = true;
                break;
            }
        }
        if (categorized) break;
    }

    if (!categorized) {
        categorizedTopics['기타'].push([topicId, msgs]);
    }
});

// 결과 출력
console.log("\n=== 2025년 대화 내용 주제별 분류 ===\n");

const sortedCategories = Object.entries(categorizedTopics)
    .sort((a, b) => b[1].length - a[1].length);

let totalMessages = 0;
sortedCategories.forEach(([category, topicsList]) => {
    const count = topicsList.length;
    const msgCount = topicsList.reduce((sum, [_, msgs]) => sum + msgs.length, 0);
    totalMessages += msgCount;

    if (count > 0) {
        console.log(`\n## ${category} (${count}개 토픽, ${msgCount}개 메시지)`);
        console.log("---");

        // 메시지 수가 많은 순으로 정렬하여 상위 5개만 표시
        const sortedTopics = topicsList.sort((a, b) => b[1].length - a[1].length).slice(0, 5);

        sortedTopics.forEach(([topicId, msgs], idx) => {
            const firstText = msgs[0].text || '(텍스트 없음)';
            const summary = firstText.substring(0, 100).replace(/\n/g, ' ').trim();
            const creator = msgs[0].creator ? msgs[0].creator.name : 'Unknown';
            const date = msgs[0].created_date || 'Unknown';

            console.log(`${idx + 1}. [${msgs.length}개 메시지] ${summary}...`);
            console.log(`   작성자: ${creator} | ${date}`);
        });

        if (topicsList.length > 5) {
            console.log(`   ... 외 ${topicsList.length - 5}개 토픽 더 있음`);
        }
    }
});

console.log("\n\n=== 월별 메시지 분포 ===\n");
const monthlyStats = {};
messages2025.forEach(msg => {
    const dateStr = msg.created_date || '';
    const match = dateStr.match(/2025년 (\d+)월/);
    if (match) {
        const month = match[1] + '월';
        monthlyStats[month] = (monthlyStats[month] || 0) + 1;
    }
});

Object.entries(monthlyStats)
    .sort((a, b) => parseInt(a[0]) - parseInt(b[0]))
    .forEach(([month, count]) => {
        const bar = '█'.repeat(Math.ceil(count / 10));
        console.log(`${month.padEnd(4)}: ${bar} ${count}개`);
    });

console.log("\n\n=== 활동적인 사용자 Top 10 ===\n");
const userStats = {};
messages2025.forEach(msg => {
    const creator = msg.creator;
    if (creator && creator.name) {
        const name = creator.name;
        userStats[name] = (userStats[name] || 0) + 1;
    }
});

Object.entries(userStats)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .forEach(([name, count], idx) => {
        console.log(`${(idx + 1).toString().padStart(2)}. ${name.padEnd(20)}: ${count}개 메시지`);
    });

console.log("\n\n=== 종합 통계 ===");
console.log(`- 총 메시지 수: ${messages2025.length}개`);
console.log(`- 총 대화 주제(Topic) 수: ${Object.keys(topics).length}개`);
console.log(`- 평균 토픽당 메시지 수: ${(messages2025.length / Object.keys(topics).length).toFixed(2)}개`);
console.log(`- 기간: 2025년 1월 ~ 9월`);