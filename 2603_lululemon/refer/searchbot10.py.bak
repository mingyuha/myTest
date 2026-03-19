import requests
from bs4 import BeautifulSoup
import telegram
import os
import datetime
import sys
from telegram.error import RetryAfter, TimedOut
import time
import logging
from pytz import timezone
import pytz
import configparser
import json
from apscheduler.schedulers.blocking import BlockingScheduler
import hmac
import hashlib
import base64

def telegram_send(message, logger):
    tries = 0
    max_tries = 10
    retry_delay = 10
    while tries < max_tries:
        try:
            _telegram_send(
                #'{}\n\rRe {}'.format(
                '{}'.format(
                    message
                )
            )
        except (RetryAfter, TimedOut) as e:
            logger.error("Message {} got exception {}".format(message, e))
            time.sleep(retry_delay)
            tries += 1
        else:
            break

def _telegram_send(message):
    bot = telegram.Bot(token = my_token)
    bot.send_message(chat_id=my_id, text=message)

def login_ananti_session(user_id, password):
    """
    아난티 로그인 및 세션 생성 (2025 새 API)
    Returns:
        requests.Session 객체 또는 None
    """
    session = requests.Session()

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
    }
    session.headers.update(headers)

    try:
        # 1. 로그인 페이지 방문 (쿠키 초기화)
        session.get("https://me.ananti.kr/user/signin")

        # 2. 로그인 요청 (정확한 파라미터명: cmUserId, cmUserPw)
        login_url = "https://me.ananti.kr/user/signin_proc"
        login_data = {
            'cmUserId': user_id,
            'cmUserPw': password,
            'saveId': ''
        }

        session.headers.update({
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Origin': 'https://me.ananti.kr',
            'Referer': 'https://me.ananti.kr/user/signin',
            'X-Requested-With': 'XMLHttpRequest'
        })

        response = session.post(login_url, data=login_data)

        data = response.json()
        if data.get('code') == '200':
            return session
        else:
            # 로그인 실패 - None 반환하여 함수가 스킵되도록
            return None

    except Exception as ex:
        return None

def getEmerson(fileName, logger, now1) :
    try:
        if os.path.exists(fileName):
            f = open(fileName,"r",encoding='utf8')
        else:
            f = open(fileName,"x",encoding='utf8')

        currentList = []
        newList = []

        for cl in f:
            currentList.append(cl.lstrip().rstrip())

        f.close()

        response = requests.get("https://ananti.kr/ko/joongang/board/gcJoin")
        soup = BeautifulSoup(response.text,'html.parser')
        numbers = [int(span.get_text(strip=True))-1 for span in soup.select('li span.page-text')]
        string_to_check = ['부부']
        is_string_check = False
        for number in numbers:
            response = requests.get(f"https://ananti.kr/ko/joongang/board/gcJoin?page={number}")
            soup = BeautifulSoup(response.text,'html.parser')
            rows = soup.find_all('tr')
            for row in rows:
                cols = row.find_all('td')
                data = [col.get_text(strip=True) for col in cols]
                is_string_check = False
                if len(data) > 0:
                    # 문자열을 datetime 객체로 변환
                    date_obj = datetime.datetime.strptime(data[1], "%Y-%m-%d")
                    # 요일 가져오기 (0: 월요일, 6: 일요일)
                    weekday_korean = ["월", "화", "수", "목", "금", "토", "일"][date_obj.weekday()]  # 한글 요일 이름
                    if weekday_korean in permitDays and data[3][:3] in arrange_time:
                        content = data[6].replace("\n", " ")
                        for check_str in string_to_check:
                            if check_str in content:
                                is_string_check = True
                                break    
                        if is_string_check:
                            continue
                        else:
                            message = ' '.join([data[1],weekday_korean, data[2],data[3],data[4],data[5],content])
                            newList.append(message.lstrip().rstrip())

        for message in newList:
            if not message in currentList:
                telegram_send(message, logger)
                #break

        f = open(fileName,"w",encoding='utf8')

        for line in newList:
            f.write(line+"\n")

        f.close()

        logger.info("Emerson end")
    except Exception as ex:
        logger.error("getEmerson error",ex)

def getEmersonMemDay(fileName, mdate, logger, now1, session, mem_no):
    """
    아난티 골프 예약 가능 시간 조회 (2025 새 API)
    Args:
        fileName: 저장 파일명
        mdate: 날짜 (YYYYMMDD 형식)
        logger: 로거
        now1: 현재 시간
        session: 로그인된 requests.Session 객체
        mem_no: 회원번호
    """
    try:
        if os.path.exists(fileName):
            f = open(fileName,"r",encoding='utf8')
        else:
            f = open(fileName,"x",encoding='utf8')

        currentList = []
        newList = []
        writeList = []

        for cl in f:
            currentList.append(cl.lstrip().rstrip())
        f.close()

        nowstr = datetime.datetime.now().strftime('%Y%m%d')

        # 과거 메시지 중 유효한 것만 유지
        for old_msg in currentList:
            if mdate not in old_msg:
                datestr = old_msg[-8:]
                if datestr > nowstr:
                    writeList.append(old_msg)

        # 예약 페이지 접근 및 CSRF 토큰 추출
        golf_page_url = f'https://ananti.kr/ko/reservation/joongang/golf?memNo={mem_no}&arr=&dep='
        resp = session.get(golf_page_url)

        # CSRF 토큰 찾기
        csrf_token = None
        import re
        match = re.search(r'<meta\s+name=["\']_csrf["\']\s+content=["\']([^"\']+)["\']', resp.text, re.IGNORECASE)
        if match:
            csrf_token = match.group(1)

        # 새 API 호출
        url = "https://ananti.kr/reservation/joongang/ajax/golf-course"

        headers = {
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'Content-Type': 'application/json',
            'Origin': 'https://ananti.kr',
            'Referer': golf_page_url,
            'X-Requested-With': 'XMLHttpRequest',
        }

        # CSRF 토큰 추가
        if csrf_token:
            headers['X-CSRF-Token'] = csrf_token

        course_names = {1: "마운틴", 2: "레이크", 3: "스카이"}

        # 3개 코스 모두 조회
        for course_num, course_name in course_names.items():
            payload = {
                "memNo": mem_no,
                "date": mdate,
                "course": course_num,
                "golfType": "GG",
                "bsns": "22"
            }

            res = session.post(url, headers=headers, json=payload)

            if res.status_code == 200:
                json_dic = json.loads(res.text)

                if json_dic.get('code') == 200:
                    array_list = json_dic.get('data', [])

                    # 원하는 시간대 필터링
                    for sen in array_list:
                        r_time = sen.get('rtime', '')[:3]
                        if r_time in arrange_time:
                            # 날짜 형식 변환: YYYYMMDD -> YYYY-MM-DD
                            formatted_date = f"{mdate[:4]}-{mdate[4:6]}-{mdate[6:]}"
                            message = f"{sen.get('rtime')}: {course_name} {formatted_date}"
                            newList.append(message.lstrip().rstrip())

        # 새로운 메시지 텔레그램 전송 및 저장
        for message in newList:
            writeList.append(message)
            if not message in currentList:
                telegram_send(message + " opened", logger)

        # 파일 저장
        f = open(fileName,"w",encoding='utf8')
        for line in writeList:
            f.write(line+"\n")
        f.close()
        logger.info("Emerson Day end")

    except Exception as ex:
        logger.error(f"EmersonMemDay error: {ex}", exc_info=True)

def generate_cgv_signature(pathname, body, timestamp):
    """
    CGV API x-signature 생성
    pathname: URL pathname (예: /cnm/atkt/searchMovScnInfo)
    body: request body (GET이면 빈 문자열)
    timestamp: Unix timestamp (문자열)

    주의: Secret key는 CGV가 언제든 변경할 수 있습니다.
    401 에러 발생 시 cgv_js_files/1453-*.js 파일에서 새 키를 찾아야 합니다.
    검색 키워드: "HmacSHA256" 또는 "ydqXY0ocnFLmJGHr"
    """
    # TODO: 이 키가 변경되면 업데이트 필요 (2025-10-07 기준)
    secret_key = "ydqXY0ocnFLmJGHr_zNzFcpjwAsXq_8JcBNURAkRscg"

    message = f"{timestamp}|{pathname}|{body}"
    signature = hmac.new(
        secret_key.encode('utf-8'),
        message.encode('utf-8'),
        hashlib.sha256
    ).digest()
    return base64.b64encode(signature).decode('utf-8')

def getCGVMx(dateStr, fileName, logger, now1):
    """
    CGV 특수관 상영 시간 조회 (2025 새 API)
    아이맥스 또는 4DX 상영 시간 조회
    """
    try:
        if os.path.exists(fileName):
            f = open(fileName,"r",encoding='utf8')
        else:
            f = open(fileName,"x",encoding='utf8')

        currentList = []
        newList = []

        for cl in f:
            currentList += cl.lstrip().rstrip().split(' ')

        f.close()

        # 새 API 호출
        url = f'https://api-mobile.cgv.co.kr/cnm/atkt/searchMovScnInfo?coCd=A420&siteNo=0013&scnYmd={dateStr}&rtctlScopCd=08'
        pathname = '/cnm/atkt/searchMovScnInfo'
        timestamp = str(int(time.time()))
        signature = generate_cgv_signature(pathname, '', timestamp)

        headers = {
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Origin': 'https://cgv.co.kr',
            'Referer': 'https://cgv.co.kr/',
            'X-TIMESTAMP': timestamp,
            'X-SIGNATURE': signature
        }

        response = requests.get(url, headers=headers)

        if response.status_code == 401:
            logger.error(f"CGVMx API 401 Unauthorized - Secret key가 변경되었을 수 있습니다!")
            logger.error(f"cgv_js_files/ 폴더의 JS 파일에서 새 키를 찾아 업데이트하세요.")
            return
        elif response.status_code != 200:
            logger.warning(f"CGVMx API error: {response.status_code}")
            return

        data = response.json()

        if data.get('statusCode') != 0:
            logger.warning(f"CGVMx no data: {data.get('statusMessage')}")
            return

        # 특수관 상영 시간 추출 (아이맥스 또는 4DX)
        timeStr = ''
        for item in data.get('data', []):
            if item.get('tcscnsGradNm') in ['아이맥스', '4DX']:
                scnsrt_time = item.get('scnsrtTm', '')
                if scnsrt_time:
                    # 0720 -> 07:20 형식으로 변환
                    formatted_time = scnsrt_time[:2] + ':' + scnsrt_time[2:]
                    timeStr += formatted_time + ' '

        if len(timeStr):
            timeStr = timeStr.lstrip().rstrip()
            newList = timeStr.split(' ')

        for message in newList:
            if not message in currentList:
                telegram_send(f"CGV 특수관 opened in {dateStr} {timeStr}", logger)
                f = open(fileName,"w",encoding='utf8')
                f.write(timeStr+"\n")
                f.close()
                break

        logger.info(f"CGVMx end")

    except Exception as ex:
        logger.error(f"CGVMx error", ex)



def getMegaBoxMx(dateStr, URL_Megabox, data_Mx, fileNameMx,logger, now1):

    try:

        if os.path.exists(fileNameMx):
            f = open(fileNameMx,"r",encoding='utf8')
        else:
            f = open(fileNameMx,"x",encoding='utf8')

        currentList = []

        newList = []
        
        checkType = [
            'DBC',
            'MX4D'
        ]

        for cl in f:
            currentList += cl.lstrip().rstrip().split(' ')
        f.close()

        header={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'}
        res = requests.post(URL_Megabox, data=data_Mx, headers=header)
        #print(res.text)

        json_dic = json.loads(res.text)

        array_list = json_dic['megaMap']['movieFormList']

        timeStr = ''
        for sen in array_list:
            if sen['theabKindCd'] in checkType:
                timeStr += sen['playStartTime']+' '

        if len(timeStr):
            timeStr = timeStr.lstrip().rstrip()
            newList = timeStr.split(' ')

        for message in newList:
            if not message in currentList:
                telegram_send("MX opened in " + dateStr+ " "+timeStr, logger)
                f = open(fileNameMx,"w",encoding='utf8')
                f.write(timeStr+"\n")
                f.close()
                break

        logger.info("MegaBoxMx end")
    except Exception as ex:
        logger.error("MegaBoxMx error", ex)

def getMegaBoxTitle(dateStr, megaTitle, URL_Megabox, data_Title, fileNameMegaBoxTitle,logger, now1):

    try:

        if os.path.exists(fileNameMegaBoxTitle):
            f = open(fileNameMegaBoxTitle,"r",encoding='utf8')
        else:
            f = open(fileNameMegaBoxTitle,"x",encoding='utf8')

        currentList = []

        newList = []

        for cl in f:
            currentList += cl.lstrip().rstrip().split(' ')

        f.close()
        header={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'}
        res = requests.post(URL_Megabox, data=data_Title,headers=header)

        json_dic = json.loads(res.text)

        array_list = json_dic['megaMap']['movieFormList']

        timeStr = ''
        movieTitleFull = megaTitle

        for sen in array_list:
            if megaTitle in sen['movieNm']:
                timeStr += sen['playStartTime']+' '
                movieTitleFull = sen['movieNm']

        if len(timeStr):
            timeStr = timeStr.lstrip().rstrip()
            newList = timeStr.split(' ')

        for message in newList:
            if not message in currentList:
                telegram_send("MEGABOX " + movieTitleFull + " opened in " + dateStr+ " "+timeStr, logger)
                f = open(fileNameMegaBoxTitle,"w",encoding='utf8')
                f.write(timeStr+"\n")
                f.close()
                break

        logger.info("MegaBoxTitle end")
    except Exception as ex:
        logger.error("MegaBoxTitle error", ex)

def getUpdate(configParam, configId, logger, now1):

    try:

        updateId = configId['DEFAULT']['updateId']
        updateIdInt = int(updateId)

        bot = telegram.Bot(token = my_token)
        updates = bot.getUpdates(offset=updateId)
        isChanged = False
        for u in updates:
            if u.update_id > updateIdInt:
                configId['DEFAULT']['updateId'] = str(u.update_id)
                #text 비교
                try :
                    message = u.message.text
                    if message is None:
                        continue 
                except Exception as ex:
                    logger.error("update error",ex)
                    continue 

                mlist = message.split('/')

                if len(mlist) == 2 and mlist[0] == 'help':
                    message = [
            'updememdt/yyyyMMdd[,yyyyMMdd]',
			'updemejoindt/yyyyMMdd',
			'upd/mxdt/yyyyMMdd',
			'updmega/제목/yyyyMMdd',
            'upd/cgvmxdt/yyyyMMdd'
			]
                    for meg in message:
                        telegram_send(meg, logger)

                elif len(mlist) == 2 and mlist[0] == 'updememdt':
                    configParam['DEFAULT']['ememdt'] = mlist[1]
                    isChanged = True
                elif len(mlist) == 2 and mlist[0] == 'updemejoindt':
                    configParam['DEFAULT']['emejoindt'] = mlist[1]
                    isChanged = True

                #수집 대상 항목 변경
                elif len(mlist) == 3 and mlist[0] == 'upd':
                    if mlist[1] in configParam['DEFAULT']:
                        configParam['DEFAULT'][mlist[1]] = mlist[2]
                        isChanged = True
                    else:
                        telegram_send('no key found : '+mlist[1], logger)

                elif len(mlist) == 3 and mlist[0] == 'upda':
                    configParam['DEFAULT']['megat'] = mlist[1]
                    configParam['DEFAULT']['megatdt'] = mlist[2]
                    configParam['DEFAULT']['mxdt'] = mlist[2]
                    configParam['DEFAULT']['cgvmxdt'] = mlist[2]
                    isChanged = True

                elif len(mlist) == 3 and mlist[0] == 'updmega':
                    configParam['DEFAULT']['megat'] = mlist[1]
                    configParam['DEFAULT']['megatdt'] = mlist[2]
                    configParam['DEFAULT']['mxdt'] = mlist[2]
                    isChanged = True

                elif len(mlist) == 2 and mlist[0] == 'list':
                    message = 'megat:'+configParam['DEFAULT']['megat']+'\n\rmegatdt:'+configParam['DEFAULT']['megatdt']+'\n\rmxdt:'+configParam['DEFAULT']['mxdt']+'\n\rcgvmxdt:'+configParam['DEFAULT']['cgvmxdt']+'\n\rememdt:'+configParam['DEFAULT']['ememdt']+'\n\remejoindt:'+configParam['DEFAULT']['emejoindt']
                    telegram_send(message, logger)

        if updateId != configId['DEFAULT']['updateId']:
            with open(confIdFile,'w',encoding='utf-8') as f:
                configId.write(f)
        if isChanged:
            with open(confParamFile,'w',encoding='utf-8') as f:
                configParam.write(f)
            message = 'megat:'+configParam['DEFAULT']['megat']+'\n\rmegatdt:'+configParam['DEFAULT']['megatdt']+'\n\rmxdt:'+configParam['DEFAULT']['mxdt']+'\n\rcgvmxdt:'+configParam['DEFAULT']['cgvmxdt']+'\n\rememdt:'+configParam['DEFAULT']['ememdt']+'\n\remejoindt:'+configParam['DEFAULT']['emejoindt']
            telegram_send(message, logger)

        logger.info("getUpdate end")
    except Exception as ex:
        logger.error("getUpdate error",ex)

def job():

    fileNameLog = config[session]['fileNameLog']

    fileNameEmerson = config[session]['fileNameEmerson']

    fileNameMx = config[session]['fileNameMx']

    fileNameMegaBoxTitle = config[session]['fileNameMegaBoxTitle']

    fileNameEmemDay = config[session]['fileNameEmemDay']

    fileNameCGVMx = config[session]['fileNameCGVMx']

    # logging.basicConfig(level=logging.INFO,
    #                     format='%(asctime)s:%(message)s',
    #                     filename=fileNameLog,
    #                     filemode='w'
    #                     )
    # logger = logging.getLogger()

    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s:%(message)s')
    file_handler = logging.FileHandler(fileNameLog, mode='w')
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    UTC = pytz.utc
    KTC = timezone('Asia/Seoul')

    now1 = datetime.datetime.now(KTC)
    c_date = datetime.datetime(now1.year,now1.month,now1.day, tzinfo=UTC).astimezone(KTC)
    now_str = str(now1.strftime('%Y%m%d'))

    #telegram_send("테스트",logger)
    #설정 변경
    getUpdate(configParam, configId, logger, now1)
    
    ememdt1 = configParam['DEFAULT']['ememdt']

    emejoindt = configParam['DEFAULT']['emejoindt']
    
    mxDateStr = configParam['DEFAULT']['mxdt']    
    
    megaTitle = configParam['DEFAULT']['megat']

    megaTitleDate = configParam['DEFAULT']['megatdt']

    cgvMxDateStr = configParam['DEFAULT']['cgvmxdt']

    target_date = datetime.datetime.strptime(emejoindt, '%Y%m%d').replace(tzinfo=UTC).astimezone(KTC)
    delta = target_date - c_date
    if delta.days > 0:
        getEmerson(fileNameEmerson, logger, now1)

    URL_Megabox='https://www.megabox.co.kr/on/oh/ohc/Brch/schedulePage.do'
    data_Mx = {'masterType':'brch','brchNo':'1351','brchNm':'코엑스','firstAt':'N','playDe':str(mxDateStr),'brchNo1':'1351','crtDe':str(now_str)}
    data_Title = {'masterType':'brch','brchNo':'1351','brchNm':'코엑스','firstAt':'N','playDe':megaTitleDate,'brchNo1':'1351','crtDe':now_str}

    # 아난티 골프 예약 조회 (2025 새 API)
    ememdt_arr = ememdt1.lstrip().rstrip().split(',')

    if len(ememdt_arr) > 0 and ememdt_arr[0]:
        # 먼저 유효한 날짜가 있는지 체크
        valid_dates = []
        for ememdt in ememdt_arr:
            target_date = datetime.datetime.strptime(ememdt, '%Y%m%d').replace(tzinfo=UTC).astimezone(KTC)
            delta = target_date - c_date
            if delta.days > 0:
                valid_dates.append(ememdt)

        # 유효한 날짜가 있을 때만 로그인 세션 생성
        if len(valid_dates) > 0:
            ananti_user_id = config['DEFAULT'].get('ananti_user_id', '2211027500')
            ananti_password = config['DEFAULT'].get('ananti_password', '')

            ananti_session = None
            if ananti_password:
                ananti_session = login_ananti_session(ananti_user_id, ananti_password)
                if ananti_session:
                    logger.info("Ananti login success")
                else:
                    logger.warning("Ananti login failed - skipping golf reservation check")

            # 유효한 날짜들만 조회
            if ananti_session:
                for ememdt in valid_dates:
                    getEmersonMemDay(fileNameEmemDay, ememdt, logger, now1, ananti_session, ananti_user_id)

    target_date = datetime.datetime.strptime(mxDateStr,'%Y%m%d').replace(tzinfo=UTC).astimezone(KTC)
    delta = target_date - c_date
    if delta.days > 0:
#        logger.info(f'mxDateStr:{mxDateStr}, URL_Megabox:{URL_Megabox}, data_Mx:{data_Mx}, fileNameMx:{fileNameMx}')
        getMegaBoxMx(mxDateStr, URL_Megabox, data_Mx, fileNameMx,logger, now1)

    target_date = datetime.datetime.strptime(megaTitleDate,'%Y%m%d').replace(tzinfo=UTC).astimezone(KTC)
    delta = target_date - c_date
    if delta.days > 0:
        getMegaBoxTitle(megaTitleDate, megaTitle, URL_Megabox, data_Title, fileNameMegaBoxTitle,logger, now1)

    target_date = datetime.datetime.strptime(cgvMxDateStr,'%Y%m%d').replace(tzinfo=UTC).astimezone(KTC)
    delta = target_date - c_date
    if delta.days > 0:
        getCGVMx(cgvMxDateStr, fileNameCGVMx, logger, now1)


    logger.handlers.clear()

if __name__ == '__main__':

    # nowhour = (datetime.datetime.now().hour+9) % 24
    nowhour = datetime.datetime.now(timezone('Asia/Seoul')).hour
    #print(nowhour)
    if nowhour >= 22 or nowhour <= 6:
         sys.exit(1)

    session = 'SERVER'  # SERVER, LOCAL

    # SERVER
    confFile = '/root/searchInfo/config.ini'
    confParamFile = '/root/searchInfo/config_param.ini'
    confIdFile = '/root/searchInfo/config_id.ini'

    # LOCAL
    if session == 'LOCAL':
        confFile = "C:\\Users\\leeps\\PycharmProjects\\searchInfo\\config.ini"
        confParamFile = "C:\\Users\\leeps\\PycharmProjects\\searchInfo\\config_param.ini"
        confIdFile = "C:\\Users\\leeps\\PycharmProjects\\searchInfo\\config_id.ini"

    if len(sys.argv) > 2 and sys.argv[1]:
        confFile = sys.argv[1]

    if len(sys.argv) > 3 and sys.argv[2]:
        confParamFile = sys.argv[2]

    config = configparser.ConfigParser()
    config.read(confFile, encoding='utf-8')

    configParam = configparser.ConfigParser()
    configParam.read(confParamFile, encoding='utf-8')

    configId = configparser.ConfigParser()
    configId.read(confIdFile, encoding='utf-8')

    permitDays = {'토','일','금'}
    #permitDays = {'수','목','월','화','금','토','일'}

    #arrange_time = {'06:'}
    arrange_time = {'06:','07:', '08:','09:','11:'}

    my_token = config['DEFAULT']['my_token']

    my_id = config['DEFAULT']['my_id']

    job()
    
    sys.exit(0)

    #sched = BlockingScheduler()
    #sched.add_job(job, 'cron', minute="*/5", hour="7-22")
    #sched.start()
