"""Random shipping-notification content generator.

Mirrors the courier/status vocabulary the app's RuleEngine actually
recognizes (app/lib/core/constants/couriers.dart,
app/assets/parse_rules_fallback.json) so generated test messages are
realistic enough to exercise the real notification capture path.
"""

import random
import string

# (display name, courier code, min tracking digits, max tracking digits)
COURIERS = [
    ("CJ대한통운", "cj", 10, 12),
    ("한진택배", "hanjin", 10, 14),
    ("롯데택배", "lotte", 10, 13),
    ("우체국택배", "epost", 13, 13),
    ("로젠택배", "logen", 11, 11),
]

STATUS_PHRASES = {
    "registered": "주문이 접수되었습니다",
    "preparing": "상품 준비 중입니다",
    "picked_up": "택배 상품을 집화하였습니다",
    "in_transit": "상품이 배송 중입니다",
    "out_for_delivery": "상품이 배송 출발하였습니다. 금일 중 도착 예정입니다",
    "delivered": "상품이 배송 완료되었습니다",
}

PRODUCTS = [
    "여름 이불 세트 Q",
    "캠핑 접이식 의자 2개 세트",
    "무선 이어폰",
    "런닝화 270",
    "커피 원두 1kg",
    "전기 주전자",
    "블루투스 스피커",
    "겨울 패딩 점퍼",
    "핸드크림 3종 세트",
    "노트북 파우치",
]

MALLS = ["11번가", "지마켓", "네이버쇼핑", "카카오톡선물하기", "옥션"]

INVOICE_LABELS = ["운송장번호", "송장번호", "등기번호"]


def _random_tracking_number(min_len: int, max_len: int) -> str:
    length = random.randint(min_len, max_len)
    return "".join(random.choices(string.digits, k=length))


def random_shipment() -> dict:
    name, code, min_len, max_len = random.choice(COURIERS)
    status_code = random.choice(list(STATUS_PHRASES))
    return {
        "courier_name": name,
        "courier_code": code,
        "status_code": status_code,
        "status_phrase": STATUS_PHRASES[status_code],
        "tracking": _random_tracking_number(min_len, max_len),
        "invoice_label": random.choice(INVOICE_LABELS),
        "product": random.choice(PRODUCTS),
        "mall": random.choice(MALLS),
    }


def email_subject(shipment: dict) -> str:
    return f"[{shipment['mall']}] {shipment['status_phrase']}"


def email_body(shipment: dict) -> str:
    return (
        "고객님, 주문하신 상품 배송 안내입니다.\n\n"
        f"상품명 : {shipment['product']}\n"
        f"택배사 : {shipment['courier_name']}\n"
        f"{shipment['invoice_label']} : {shipment['tracking']}\n"
        f"현재 상태 : {shipment['status_phrase']}\n\n"
        "본 메일은 CheckShipping 테스트 발송 도구(tools/test_notify)로 보낸 "
        "테스트 메일입니다.\n"
        "감사합니다."
    )


def sms_body(shipment: dict) -> str:
    return (
        "[Web발신]\n"
        f"[{shipment['courier_name']}] 고객님의 {shipment['status_phrase']}\n"
        f"■ {shipment['invoice_label']}: {shipment['tracking']}\n"
        f"■ 상품명: {shipment['product']}\n"
        "(CheckShipping 테스트 발송)"
    )
