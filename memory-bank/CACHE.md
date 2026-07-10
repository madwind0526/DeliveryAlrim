# Cache

> 임시 발견사항 저장소. Wave 완료 후 knowledge/ 로 flush하고 이 섹션을 비울 것.
> Sub-agent는 작업 완료 후 발견사항을 아래에 추가한다.

## Active Findings

| 유형 | 발견사항 | 이동 대상 |
|------|----------|-----------|
| 코드 패턴 | 캘린더 일별 현황은 스냅샷 테이블 없이 TrackingEventRows 이벤트 로그로 재구성한다. `buildParcelDayIndex`(features/calendar/parcel_day_index.dart): 배송은 등록일~종결일(진행 중이면 오늘)까지 매일 carry-forward, D일 상태 = D일 자정 이전 마지막 이벤트. 미래 도착예정일은 preview 엔트리로 별도 표시 | `knowledge/PATTERNS.md` |
| 규칙/원칙 | 매일 자정 스냅샷 배치는 앱 미실행 날 구멍이 생기므로 금지. 일별 이력이 필요하면 이벤트 소싱으로 파생 계산한다 | `knowledge/RULES.md` |
| 규칙/원칙 | 스마트택배(스윗트래커) API 무료 키는 약 100건/일(월?) 제한 — 사용자 확인(2026-07-10). 지속 사용은 유료. 따라서 알림 기반이 항상 1차 경로이고, API는 수동 새로고침 + DailyQuotaStore(일일 한도 가드) 경유로만 호출한다 | `knowledge/RULES.md` |
| 규칙/원칙 | 앱은 메시지 본문 URL을 절대 열지/가져오지 않는다(피싱 원천 차단). 배송 조회는 추출된 (택배사, 운송장번호)로 공식 API만 사용. 원문 표시 UI는 링크화 없는 일반 Text만 사용 | `knowledge/RULES.md` |
| 코드 패턴 | 광고/피싱 스크리닝은 CaptureScreener를 RuleEngine.parse 입구에 두어 모든 채널이 단일 지점을 통과. 광고=법정 표기 하드마커만 즉시 거부, 피싱=신호 2개 이상 조합 시 격리함(QuarantineRows) 보관 후 사용자 검토. 자동 삭제 금지 | `knowledge/PATTERNS.md` |
| 코드 패턴 | 기존 배송 업데이트 E2E 테스트: tools/test_notify 모듈 재사용 + 운송장번호를 기존 배송 것으로 고정해 발송하면 병합 경로(상태 전진/도착예정 갱신)를 실기기에서 검증 가능. 2026-07-11 5종 시나리오(신규/완료 전환/역행 방지/광고/피싱) 전부 통과. 주의: 수신 메일을 PC에서 먼저 읽으면 폰 알림이 안 뜰 수 있음 | `knowledge/PATTERNS.md` |
| 버그/해결 | "메일 여러 통인데 일부만 반영" 증상은 유실이 아니라 타이밍: Gmail이 배치로 동기화하면 개별 알림 5건이 같은 초에 게시되고 리스너는 전부 큐에 담는다(삼성 실기기 확인). 앱은 열림/재개 시에만 큐를 처리하므로 마지막 캡처 후 앱을 다시 열어야 반영됨. 진단은 adb logcat -s CheckShippingNotify로 캡처 로그 확인 | `knowledge/trouble-shooting.md` |

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
