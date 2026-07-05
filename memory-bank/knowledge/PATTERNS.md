# Patterns

> 검증된 코드 패턴. 복붙 바로 가능한 형태로 유지.

## drift_flutter 크로스플랫폼 DB 오픈

**사용 시점:** Windows+Android 이중 타깃에서 drift DB를 열 때

```dart
// drift_flutter handles per-platform sqlite3 setup (Windows/Android/iOS).
// No manual sqfliteFfiInit() needed (that is a sqflite-only requirement).
static QueryExecutor _openConnection() {
  return driftDatabase(name: 'check_shipping');
}

// Tests: AppDatabase.forTesting(NativeDatabase.memory()) with drift/native.dart
```

## go_router 인증 리다이렉트 (Stream 기반)

**사용 시점:** auth 상태 Stream 변화에 따라 라우터가 자동으로 /login ↔ / 리다이렉트해야 할 때

```dart
class _StreamListenable extends ChangeNotifier {
  late final StreamSubscription<Object?> _sub;
  _StreamListenable(Stream<Object?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  @override
  void dispose() { _sub.cancel(); super.dispose(); }
}
// GoRouter(refreshListenable: _StreamListenable(authRepo.watchUser()),
//   redirect: (_, state) { ... ref.read(authStateProvider).value ... })
```

## 파싱 규칙: 라벨 앵커 + 키워드 동시출현으로 오탐 차단

**사용 시점:** 자유 텍스트에서 운송장번호 추출 규칙 작성 시

```
// Invoice must follow an explicit label — bare digits are never captured:
"(?:운송장|송장|등기)\\s*번호\\s*[:：]?\\s*(?<invoice>\\d[\\d\\-]{8,15}\\d)"
// AND a courier keyword must co-occur in the same text (engine-level guard),
// otherwise reject with noCourier. Kills OTP/order-number/phone false positives.
// Status keywords checked terminal-first: 배송완료 → 배송출발 → 배송중 → 집화 → 준비 → 주문
```

네거티브 fixture(은행 OTP, 광고, 운송장 없는 주문완료)를 코퍼스에 유지해 회귀를 방지한다.

## 중복제거 upsert (다채널 병합)

**사용 시점:** 같은 배송이 여러 채널(카카오/SMS/메일)에서 캡처될 때. Wave 4 Supabase 구현도 동일 로직 사용할 것.

```dart
// Dedupe key: unique (courierCode, trackingNumber)
// Merge policy (Parcel.merge): union sourceChannels, coalesce null fields,
// advance status only forward (monotonic guard via enum index).
Parcel merge(Parcel other) => copyWith(
  status: status.canTransitionTo(other.status) ? other.status : status,
  productName: productName ?? other.productName,
  sourceChannels: {...sourceChannels, ...other.sourceChannels},
  // ...
);
```

## Windows 카카오톡 채팅방 복사 fallback

**사용 시점:** Windows 테스트에서 카카오톡 알림톡 fixture를 확보해야 할 때

Windows 카카오톡은 말풍선 텍스트가 UI Automation/Win32 텍스트 트리에 노출되지 않았다. 다만 채팅 영역을 포커스한 뒤 `Ctrl+A` / `Ctrl+C`를 보내면 현재 채팅방 대화가 평문으로 복사되는 것을 확인했다. 이 경로는 Windows fixture 수집용 fallback으로만 사용하고, Android 구현 경로로 간주하지 않는다.

## Android 카카오톡 알림톡 접근성 노드

**사용 시점:** 카카오톡 알림톡 채널에서 배송/주문 본문을 추출할 때

삼성카드와 CJ대한통운 채널 실기기 PoC에서 알림톡 본문이 `com.kakao.talk:id/alimtalk_title` TextView의 `text` 속성에 노출됐다. 1차 수집은 이 resource-id를 우선 탐색하고, 다른 말풍선 타입은 `message`, `content-desc`, visible text 순서로 fallback 처리한다.
실제 `KakaoAccessibilityService`에서도 CJ대한통운 채팅방에서 `courier=cj`, `invoice=594239221744`, `status=delivered`, `sender=삼성전자`를 logcat과 SharedPreferences에 저장하는 것을 확인했다.

```text
primaryResourceId = "com.kakao.talk:id/alimtalk_title"
fallbackResourceIds = [
  "com.kakao.talk:id/message",
]
```

## Android 접근성 캡처 → 로컬 SQLite 즉시 저장

**사용 시점:** Flutter UI가 떠 있지 않아도 알림톡 캡처 결과를 배송 DB에 남겨야 할 때

`AccessibilityService`는 캡처 직후 두 경로에 기록한다.

1. `SharedPreferences("kakao_accessibility")`: Flutter `MethodChannel` backfill용 최신 스냅샷
2. `app_flutter/check_shipping.sqlite`: Drift와 같은 SQLite 파일에 네이티브 직접 upsert

검증 결과:

- 카카오톡 CJ대한통운 채팅방을 열면 `CheckShippingKakao: persisted capture to local sqlite invoice=594239221744` 로그가 찍힘
- Android DB `parcel_rows`에는 `cj / 594239221744 / delivered / 삼성전자 / kakao`가 1 row로 유지됨
- 같은 운송장을 다시 캡처하면 중복 row를 만들지 않고 `delivered_at` 등 최신 필드만 갱신됨

주의:

- Drift의 Android DateTime 저장값은 초 단위 integer라 네이티브에서도 `millis / 1000`으로 저장한다.
- 서비스가 앱 최초 실행 전 DB를 만들 수도 있으므로 `parcel_rows`, `tracking_event_rows`, `local_profile_rows`와 `PRAGMA user_version = 2`를 함께 보장한다.

## Gmail/SMS 자동 주입 테스트 러너

**사용 시점:** 실제 Gmail OAuth/SMS 권한 연결 전에도 파싱 엔진과 로컬 DB 등록 경로를 자동 검증해야 할 때

Gmail/SMS 테스트 버튼은 외부 앱을 직접 조작하지 않고, 앱 내부에서 동일한 `RawCapture`를 생성해 운영 파이프라인과 같은 경로를 통과시킨다.

```text
CaptureTestSample
  → CaptureTestRunner.send()
  → RuleEngine.parse()
  → ParcelRepository.upsert()
  → parcel_rows source_channels = gmail | sms
```

검증 결과:

- User 화면에서 `Gmail 샘플 보내기`, `SMS 샘플 보내기` 버튼을 눌러 스낵바 성공 확인
- Android 앱 내부 SQLite 조회 결과 `cj / 641234567893 / gmail`, `hanjin / 512345678901 / sms` 등록 확인
- `app/test/debug/capture_test_runner_test.dart`에서 같은 경로를 in-memory DB로 자동 회귀 테스트함

<!-- 예시 형식:

## [패턴 이름]

**사용 시점:** [언제 이 패턴을 써야 하나]

```language
// 코드
```

-->
