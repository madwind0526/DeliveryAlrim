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
| 버그/해결 | 커스텀 Dart headless entrypoint(예: NotificationListenerService에서 띄우는 별도 FlutterEngine)를 릴리즈(AOT) 빌드에서 executeDartEntrypoint로 실행하면 "Dart_LookupLibrary: library '...' not found" 로 실패한다. AOT는 main.dart에서 import로 도달 가능한 라이브러리만 스냅샷에 포함하므로, @pragma('vm:entry-point')만으로는 부족하고 main.dart에 `// ignore: unused_import`로 해당 파일을 반드시 import해야 함(app/lib/main.dart, app/lib/background_sync.dart 참고) | `knowledge/trouble-shooting.md` |
| 코드 패턴 | 헤드리스 백그라운드 동기화(알림 도착 시 앱을 안 열어도 파싱/저장): 네이티브가 이미 떠 있는 포그라운드 Flutter 엔진에 syncNow를 위임하거나(MainActivity.requestForegroundSync), 없으면 4초 디바운스 후 임시 FlutterEngine을 띄워 동일한 kakaoCaptureSyncProvider 경로를 실행하고 backgroundSyncDone 콜백으로 즉시 종료. path_provider_android처럼 dartPluginClass 기반 federated 플러그인은 main() 래퍼가 없는 커스텀 entrypoint에서 자동 등록되지 않으므로 PathProviderAndroid.registerWith()를 직접 호출해야 함(background_sync.dart). 콜드 엔진 기동은 실기기에서 알림→반영까지 약 27초 소요(Vulkan/Impeller 드라이버 초기화 포함), 60초 타임아웃 안전장치 있음. 2026-07-11 실기기 검증: 앱 강제종료 상태에서 메일만으로 자동 등록 확인 | `knowledge/PATTERNS.md` |
| 코드 패턴 | 카드결제 알림 기반 "주문 내역" 등록(2026-07-12): 카드사를 하드코딩하지 않고 `titleMatch: "카드\\s*$"` 정규식 규칙(card_order_generic, priority 5, courierCode "card_order") 하나로 모든 발급사를 커버. RuleEngine.parse에 쿠팡 다이렉트와 동일한 특수분기 추가, `_extractCardOrder`가 본문 전체 해시로 합성 트래킹키(`card:...`) 생성해 재게시 알림은 dedupe, 실제 구매건은 구분. status는 항상 registered 고정, 실제 배송 알림이 와도 자동 병합 안 함(별도 행). `Couriers.cardOrder`(코드 card_order, isDirect true)로 courierListProvider/필터/설정 화면에 자연스럽게 노출(coupangDirect와 동일 패턴). 합성 트래킹넘버 숨김 처리는 `Parcel.hasSyntheticTrackingNumber` getter로 통일(cp:/card: 접두사) | `knowledge/PATTERNS.md` |
| 규칙/원칙 | 카드결제로 등록된 주문(registered, 항상 non-terminal)은 buildParcelDayIndex의 carry-forward 규칙상 오늘까지 매일 캘린더에 계속 표시된다 — 자동 완료/만료 시점이 없어 캘린더가 점점 붐빌 수 있음. → 2026-07-12 해결: mallName/productName 텍스트 겹침으로 이후 등록된 실제 배송과 매칭되면 그 배송일부터 carry-forward 중단(과거 날짜는 유지). `_resolvedEndDay`/`_looksLikeSamePurchase`(parcel_day_index.dart) 참고. DB 행은 병합하지 않고 캘린더 표시만 조정 | `knowledge/RULES.md` |
| 버그/해결 | 카카오 알림 캡처가 새 빌드를 설치해도 재처리되지 않는 경우: (1) Android가 앱 재설치마다 접근성 권한을 자동으로 꺼버림 — `adb shell settings get secure enabled_accessibility_services`로 확인, Setting에서 재활성화 필요. (2) 권한이 켜져 있어도 KakaoAccessibilityService의 `seenTexts`(인메모리 LinkedHashSet)가 서비스 프로세스 생존 기간 내내 동일 텍스트를 "이미 처리함"으로 기억해 새 규칙이 추가된 빌드에서도 재평가를 건너뜀 — 접근성 권한을 껐다 켜서 서비스를 완전히 재시작해야 캐시가 비워짐 | `knowledge/trouble-shooting.md` |
| 코드 패턴 | 카카오 알림톡/SMS/이메일에서 배송 키워드가 전혀 없는 새 캡처 유형(카드결제, 몰 주문완료 등)을 추가할 때는 항상 3곳을 함께 수정해야 한다: (1) Dart RuleEngine의 JSON 규칙+특수분기, (2) CheckShippingNotificationListenerService의 looksLikeDelivery 사전필터(SMS/Gmail), (3) KakaoAccessibilityService의 invoice 전용 게이트(카카오). 하나라도 빠지면 네이티브 단계에서 조용히 버려져 Dart까지 도달하지 못한다. `adb shell uiautomator dump`로 실제 화면 텍스트/뷰ID를 직접 확인 후 정규식을 설계할 것 — 뷰ID 추측은 위험 | `knowledge/PATTERNS.md` |
| 코드 패턴 | 같은 거래가 여러 채널(SMS+카카오 등)로 각각 다른 문구로 올 수 있는 경우, dedupe 키는 원문 해시 대신 채널 무관하게 일정한 "거래 사실"(발급사/상호+금액+MM/DD HH:MM 등)로 합성해야 중복 등록을 막을 수 있다 (`_extractCardOrder`의 datetime 기반 키 참고) | `knowledge/PATTERNS.md` |

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
