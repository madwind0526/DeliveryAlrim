# CheckShipping Code Review — 2026-07-07 (Update 5)

> 커밋 `48f9768 fix: route kakao captures through flutter parser`가 카카오톡 캡처 파이프라인을 네이티브 파싱에서 Flutter `RuleEngine` 경유로 재구성하면서, 남아있던 구조적 이슈 대부분이 한 번에 해소됨. 2026-07-07 추가 확인에서는 마지막으로 남아 있던 User 화면 secure-storage 전체 재조회 비효율까지 수정했다.

## 프로젝트 상태 점검

- **브랜치**: `main`
- **Wave 상태**: Wave 6 진행 중
- **이번 리뷰 범위**: `211d548..HEAD` (`82b35d9`)
  - `LocalParcelSqliteStore.kt` **전체 삭제** (네이티브 SQLite 직접 쓰기 경로 제거)
  - `KakaoAccessibilityService.kt`가 courier/status 분류를 그만두고 원문 메시지(raw body)만 캡처해 전달하도록 축소
  - `kakao_capture_bridge.dart`/`kakao_capture_sync.dart`가 원문을 `RuleEngine`으로 파싱해 `Gmail/SMS`와 동일한 파이프라인 사용
  - `router.dart` 하단 내비게이션 라벨 복원, `parcel.dart`의 `merge()` deliveredAt 우선순위 수정 (+회귀 테스트 추가)
  - `user_sources_screen.dart`/`secure_credentials.dart`에 `MonitorSourceStore` 추가로 소스 on/off 스위치가 실제 자동 동기화를 제어하도록 연결

## 이번 커밋에서 확인된 결과: 6건 완전 수정, 1건 부분 수정 → 사실상 해소

### ✅ FIXED — 네이티브(Kotlin)/Drift 동일 SQLite 파일 동시 쓰기 (1차 리뷰 #1)
`LocalParcelSqliteStore.kt` 파일 자체가 삭제됨. 네이티브 코드는 더 이상 SQLite에 쓰지 않고 `SharedPreferences`에 원문 메시지(`last_body`, `last_channel`, `last_package`)만 남긴다. 이중 쓰기 경로가 원천적으로 사라졌다.

### ✅ FIXED — 접근성 이벤트 스레드 동기 DB I/O + 매 이벤트 스키마 재검증 (1차 리뷰 #2)
같은 이유로 해소 — `ensureSchema()`/`upsert()` 자체가 더 이상 존재하지 않는다.

### ✅ FIXED — `deliveredAt` 재캡처 시 무조건 "지금"으로 덮어쓰기 (1차 리뷰 #3)
`app/lib/features/parcels/models/parcel.dart:117`: `merge()`의 우선순위가 `other.deliveredAt ?? deliveredAt` → **`deliveredAt ?? other.deliveredAt`**로 뒤집혀, 기존에 기록된 완료 시각이 있으면 신규 캡처가 절대 덮어쓰지 못한다. `app/test/parcel_repository_test.dart`에 "delivered 상태 재캡처 시 원래 deliveredAt 유지" 회귀 테스트도 추가되어 있어 검증됨. 네이티브 파싱 경로 자체가 사라져 예전에 존재하던 Kotlin 쪽 중복 버그도 함께 소멸.

### ✅ FIXED — Kotlin/Dart 키워드 분류 발산 + 택배사 키워드 동시출현 게이트 없음 (1차 리뷰 #5)
`KakaoAccessibilityService.kt`가 courier/status 분류 로직을 완전히 제거하고 원문 텍스트만 전달하도록 바뀌었고, `kakao_capture_sync.dart`가 이제 Gmail/SMS와 동일하게 `RuleEngine.parse()`를 호출한다. `RuleEngine`은 이미 택배사 키워드 미검출 시 `ParseRejectReason.noCourier`로 거부하는 게이트를 갖고 있으므로(1차 리뷰 당시 발견), 카카오 채널도 이제 같은 게이트를 통과해야 한다. 두 언어 간 키워드 세트가 두 벌로 존재하던 근본 원인(중복 구현)이 사라짐 — 예전에 Kotlin에만 있던 발신자 추출 정규식도 `rule_engine.dart:49`의 `_mallRe`(`보내는(?:분|곳)...`)와 동일해 기능 손실 없음을 확인.

### ✅ FIXED — 하단 내비게이션 접근성 라벨 (1차 리뷰 #6)
`app/lib/core/router.dart:147`: `label: ''` → `label: d.label`로 복원. TalkBack이 다시 각 탭의 한국어 이름을 읽는다.

### ✅ FIXED — `rootInActiveWindow` 노드 recycle 누락 (1차 리뷰 #9)
`KakaoAccessibilityService.kt:12-17`: `collectAlimtalkMessages(root, messages)` 호출을 `try { ... } finally { root.recycle() }`으로 감싸 최상위 노드도 반환하도록 수정.

### ✅ 사실상 FIXED — 소스 on/off 스위치가 실제 동기화를 제어하지 않음 (1차 리뷰 #8)
`secure_credentials.dart`에 `MonitorSource`/`MonitorSourceStore`(`isEnabled`/`setEnabled`, secure storage 기반)가 추가됨. `app.dart:47-50`의 자동 동기화가 이제 `monitorSourceStoreProvider.isEnabled(MonitorSource.kakao, defaultValue: true)`를 확인한 뒤에만 `syncLatest()`를 호출하고, `user_sources_screen.dart`의 모든 `_SwitchRow.onChanged`가 `_setMonitorEnabled()`를 통해 상태를 secure storage에 실제로 persist한다. Gmail/기타이메일/SMS/카카오/텔레그램/WhatsApp 6개 전부 `MonitorSource` enum에 포함(SMS도 포함됨). 다만 `CredentialSource` enum에는 여전히 `sms` 항목이 없어 SMS는 계정 자격증명을 저장할 수 없는데, SMS는 애초에 로그인이 필요 없는 채널이라 별도 버그는 아닌 것으로 판단.

---

## 추가 확인 및 수정된 항목

| # | 항목 | 파일 | 상태 |
|---|------|------|------|
| 10 | 자격증명/모니터 소스 상태를 1건 변경 후에도 전체를 다시 읽음 | `user_sources_screen.dart` | FIXED — 초기 진입 때만 전체 상태를 읽고, 저장/삭제/추가 후에는 변경된 소스 상태만 로컬 setState로 반영 |

**#10 수정 내용**: `_openCredentialDialog()`와 `_openAddSourceDialog()`에서 더 이상 `_loadCredentialStates()`를 다시 호출하지 않는다. 대신 `_setCredentialStored()`, `_setSourceLabel()`, `_syncOptionalVisibility()`로 변경된 credential/label/optional-row 표시 상태만 갱신한다. `_loadCredentialStates()`는 화면 최초 진입 시 전체 상태를 구성하는 용도로만 남는다.

---

## 낮은 우선순위 정리 항목 (변경 없음, 참고용)

- `user_sources_screen.dart`의 시크릿 입력 필드/`_KeyboardSafeDialogShell`이 여러 다이얼로그에 복붙됨, 소스별 `_xEnabled`/`_xVisible` boolean 쌍이 데이터 기반 모델 대신 여전히 하드코딩됨
- `settings_screen.dart`의 busy-flag 가드 패턴 반복
- `android_settings_bridge.dart`가 권한별로 메서드를 하드코딩 (배터리 최적화 등 추가 시 확장 필요)
- `MainActivity.kt`의 권한 상태 조회가 앱 재개마다 동기 실행 (빈도 낮아 경미)
- MethodChannel 이름(`check_shipping/kakao_capture`) 등 문자열이 여러 파일에 하드코딩 중복
- `today_dashboard_screen.dart`의 반복 필터 스캐폴딩 등 사소한 중복

## 종합

1차 리뷰에서 지적된 구조적 이슈는 모두 해소되었고, 남은 것은 재사용/단순화 성격의 낮은 우선순위 정리 항목뿐이다. 카카오 캡처 경로를 Gmail/SMS와 동일한 `RuleEngine`으로 통합한 것이 이번 라운드의 핵심 개선이며, 네이티브 이중 저장소·파싱 로직 발산 문제를 근본적으로 제거했다.
