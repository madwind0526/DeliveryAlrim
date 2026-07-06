# CheckShipping Code Review — 2026-07-06 (Update 3)

> 이전 리뷰 두 차례(`29e28ed..b616095`, `b616095..1f163dd`)에서 지적한 항목 중 일부가 커밋 `211d548 fix: address confirmed review issues`로 수정됨. 이번 업데이트는 그 수정 커밋(`1f163dd..HEAD`, 7개 파일 / +87 -44줄)을 검증하고 전체 항목의 최신 상태를 정리한다.

## 프로젝트 상태 점검

- **브랜치**: `main`, working tree clean
- **Wave 상태**: Wave 6 진행 중 — 체크포인트 "code-review.md 지적사항 중 즉시 수정 가능한 항목 반영 및 debug/release 빌드 검증"
- **이번 리뷰 범위**: `1f163dd..HEAD` (`211d548`) — `secure_credentials.dart`, `strings_ko.dart`, `kakao_capture_sync.dart`, `manual_insert_screen.dart`, `settings_screen.dart` 및 memory-bank 문서

## 이번 수정 커밋에서 확인된 결과: 4건 완전히 수정, 1건 정보성으로 완화

### ✅ FIXED — `SecureSourceLabelStore.read()` 의 `await` 누락 (이전 업데이트 N1)
`app/lib/core/secure_credentials.dart:120`: `return _storage.read(...)` → `return await _storage.read(...)`로 수정 확인. 이제 `catch`가 실제로 예외를 잡는다. 또한 이번 수정으로 `SecureCredentialStore.has()`/`write()`/`delete()`, `SecureSourceLabelStore.write()`/`delete()`까지 전부 try/catch가 추가되어, **이전 1차 리뷰 finding #7 "Secure storage 예외 처리 없음"도 이번 커밋으로 완전히 FIXED** 되었다 (read/write/delete/has 전부 커버).

### ✅ FIXED — 수동 소포 등록의 운송장번호 검증 우회 (이전 업데이트 N2)
`app/lib/features/parcels/manual_insert_screen.dart:180-190`에 `_validateTrackingNumber`/`_normalizedTrackingNumber`가 추가되어 `RuleEngine`과 동일하게 택배사별 `invoicePattern` 정규식으로 검증하고, 대시/공백을 제거하는 정규화도 `rule_engine.dart:67`의 `invoiceRaw.replaceAll('-', '')`와 동일한 방식으로 맞췄다. 코드상 직접입력 전용 택배사(`isDirect == true`, 예: 쿠팡 캡처 전용 코드)는 드롭다운에서 제외되어 해당 패턴과의 충돌도 없다. 검증 완료.

### ✅ FIXED — `clearLatestCapture()` 미호출로 인한 소포 부활 (1차 리뷰 finding #4)
`app/lib/features/capture/kakao_capture_sync.dart:42`: `upsert()` 성공 직후 `await bridge.clearLatestCapture();` 호출이 추가됨. `kakao_capture_bridge.dart`의 `clearLatestCapture()`는 `MissingPluginException`/`PlatformException`을 이미 처리하므로 실패해도 `syncLatest()`를 깨뜨리지 않는다. 검증 완료.

### ✅ FIXED — 디버그 테스트 도구가 릴리즈 빌드에 노출 (이전 업데이트 N4)
`app/lib/features/preferences/settings_screen.dart:115-140`: `import 'package:flutter/foundation.dart'`를 추가하고 `final mode = kDebugMode ? _mode : StringsKo.settingModeLocal;`로 강제, 세그먼트 버튼 자체도 `if (kDebugMode) ...[...]`로 감싸 릴리즈 빌드에서는 "테스트" 탭이 아예 렌더링되지 않는다. 검증 완료.

### ℹ️ 정보성으로 완화 — `CheckShippingNotificationListenerService` 스텁 (이전 업데이트 N3)
코드 자체(`onNotificationPosted` 미구현)는 그대로지만, `strings_ko.dart:68`의 안내 문구가 `'Android 설정 > 알림 접근에서 배송알리미를 허용합니다. 알림 자동 분류는 구현 중입니다.'`로 바뀌어 사용자에게 "허용은 됐지만 자동 분류는 아직"이라는 상태를 정직하게 알린다. 리뷰에서 권고한 완화안(구현 전까지 상태 고지)과 일치하므로 이슈로서는 해소된 것으로 처리. 실제 캡처 로직 구현은 로드맵상 남은 작업.

---

## 여전히 남아있는 항목 (파일 미변경, 재확인만 수행)

| # | 항목 | 파일 | 상태 |
|---|------|------|------|
| 1 | 네이티브(Kotlin)/Drift가 동일 SQLite 파일에 조율 없이 동시 쓰기 | `LocalParcelSqliteStore.kt`, `local_db.dart` | STILL PRESENT |
| 2 | 접근성 이벤트 스레드 동기 DB I/O + 매 이벤트 스키마 재검증 | `KakaoAccessibilityService.kt`, `LocalParcelSqliteStore.kt` | STILL PRESENT |
| 3 | `deliveredAt` 재캡처 시 무조건 "지금"으로 덮어쓰기 | `LocalParcelSqliteStore.kt:176-178`, `kakao_capture_sync.dart:35` | STILL PRESENT — 단, 아래 참고 |
| 5 | Kotlin/Dart 키워드 분류 발산 + 택배사 키워드 동시출현 게이트 없음 | `KakaoAccessibilityService.kt`, `rule_engine.dart` | STILL PRESENT |
| 6 | 하단 내비게이션 접근성 라벨(`label: ''`) | `router.dart:133-150` | STILL PRESENT |
| 8 | 소스 on/off 스위치가 실제 동기화를 제어하지 않음 + SMS 자격증명 모델 없음 | `user_sources_screen.dart`, `app.dart` | STILL PRESENT |
| 9 | `rootInActiveWindow` 노드 recycle 누락 | `KakaoAccessibilityService.kt:13` | STILL PRESENT |
| 10 | 자격증명 1건 저장/삭제 후 5개 소스 전부 재조회 | `user_sources_screen.dart` | STILL PRESENT |

**#3 관련 참고**: `clearLatestCapture()`가 이번에 추가되면서, 예전처럼 "앱을 재개할 때마다 같은 캡처가 반복 동기화되어 매번 `deliveredAt`을 지금 시각으로 덮어쓰는" 경로는 막혔다. 다만 근본 원인 — `Parcel.merge()`(`parcel.dart:117`, `deliveredAt: other.deliveredAt ?? deliveredAt`)와 `kakao_capture_sync.dart:35`가 신규 캡처의 `deliveredAt`을 기존 값 유무와 상관없이 그대로 덮어쓰는 로직 — 은 그대로다. 접근성 서비스가 이미 배송완료 처리된 메시지를 (서비스 재시작 등으로) 다시 새 캡처로 인식하면 여전히 같은 문제가 재현된다. 발생 빈도는 낮아졌지만 미해결.

---

## 낮은 우선순위 정리 항목 (변경 없음, 참고용)

- `user_sources_screen.dart`의 시크릿 입력 필드/`_KeyboardSafeDialogShell` 중복, `settings_screen.dart`의 busy-flag 가드 패턴 반복
- `android_settings_bridge.dart`가 권한별로 메서드를 하드코딩 (배터리 최적화 등 추가 시 확장 필요)
- `MainActivity.kt`의 권한 상태 조회가 앱 재개마다 동기 실행 (빈도 낮아 경미)
- MethodChannel/SharedPreferences 이름 문자열이 여러 파일에 하드코딩 중복
- `router.dart`의 `_NavItem.selectedIcon`, `today_dashboard_screen.dart`의 반복 필터 스캐폴딩 등 사소한 중복
