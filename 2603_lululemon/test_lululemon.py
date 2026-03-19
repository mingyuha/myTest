import cloudscraper
import re
import json

PRODUCT_URL = 'https://www.lululemon.co.kr/ko-kr/p/%ED%8C%A8%EC%8A%A4%ED%8A%B8-%EC%95%A4-%ED%94%84%EB%A6%AC-%ED%95%98%ED%94%84-%ED%83%80%EC%9D%B4%EC%B8%A0-8%22/prod11380319.html?dwvar_prod11380319_color=0001'
PRODUCT_NAME = '패스트 앤 프리 하프 타이츠 8'
TARGET_COLOR = 'Black'
TARGET_SIZE = 'M'


def check_lululemon_stock(product_url, target_color, target_size):
    scraper = cloudscraper.create_scraper()
    res = scraper.get(product_url)

    print(f"status_code: {res.status_code}")
    if res.status_code != 200:
        print(f"ERROR: {res.status_code}")
        return False

    # JSON-LD에서 hasVariant 파싱
    scripts = re.findall(r'<script type="application/ld\+json">(.*?)</script>', res.text, re.DOTALL)
    for s in scripts:
        try:
            data = json.loads(s)
        except Exception:
            continue

        if data.get('@type') != 'ProductGroup':
            continue

        variants = data.get('hasVariant', [])
        print(f"\n[사이즈 목록] color={target_color}")
        for v in variants:
            if v.get('color', '').lower() != target_color.lower():
                continue
            size = v.get('size', '')
            availability = v.get('offers', {}).get('availability', '')
            in_stock = availability == 'http://schema.org/InStock'
            print(f"  {size}: {'재고있음' if in_stock else '재고없음'}")
            if size.upper() == target_size.upper():
                return in_stock

    print("ERROR: 해당 사이즈를 찾을 수 없음")
    return False


if __name__ == '__main__':
    print(f"제품: {PRODUCT_NAME}")
    print(f"색상: {TARGET_COLOR} / 사이즈: {TARGET_SIZE}")
    print("-" * 40)

    available = check_lululemon_stock(PRODUCT_URL, TARGET_COLOR, TARGET_SIZE)

    print("-" * 40)
    if available:
        print(f"결과: {PRODUCT_NAME} {TARGET_SIZE} 재고있음")
    else:
        print(f"결과: {PRODUCT_NAME} {TARGET_SIZE} 재고없음")
