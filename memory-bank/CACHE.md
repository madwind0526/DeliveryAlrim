# Cache

> 임시 발견사항 저장소. Wave 완료 후 knowledge/ 로 flush하고 이 섹션을 비울 것.
> Sub-agent는 작업 완료 후 발견사항을 아래에 추가한다.

## Active Findings

| 유형 | 발견사항 | 이동 대상 |
|------|----------|-----------|
| 규칙 | 쿠팡 합성 키는 주문번호 우선: `cp:sha1('order:<주문번호>')`, 주문번호 없을 때만 상품명+날짜 버킷. 실샘플에서 쿠팡 알림에 주문번호가 항상 포함됨을 확인 → 설계(DESIGN §5)보다 개선된 방식 | RULES |
| 규칙 | CJ check-digit 알고리즘(앞자리 %7) 미검증 — 실제 운송장 300211029394에서 불일치. 구현하지 말 것. 길이 regex + 택배사 키워드 동시출현으로 충분 | RULES |
| 코드 패턴 | 파싱 규칙 JSON: named group `(?<invoice>)` + 라벨 앵커(운송장/송장/등기 번호)로 오탐 차단. 은행 OTP/광고/주문완료(운송장 없음) 네거티브 fixture로 회귀 방지 | PATTERNS |
| 코드 패턴 | 상태 키워드 테이블은 terminal 우선 순서로 검사 (배송완료 → 배송출발 → 배송중 → 집화 → 준비 → 주문) | PATTERNS |

---

## 유형 분류

| 유형 | 이동 대상 |
|------|-----------|
| 코드 패턴 | `knowledge/PATTERNS.md` |
| 규칙/원칙 | `knowledge/RULES.md` |
| 버그/해결 | `knowledge/trouble-shooting.md` |

---

## Flush 방법

Wave 완료 시:
1. 각 항목을 위 표에 따라 `knowledge/` 파일로 이동
2. Active Findings 테이블 비우기
3. `STATE.md`의 Cache Status → `CLEAN`으로 업데이트
