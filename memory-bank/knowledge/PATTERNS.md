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

<!-- 예시 형식:

## [패턴 이름]

**사용 시점:** [언제 이 패턴을 써야 하나]

```language
// 코드
```

-->
