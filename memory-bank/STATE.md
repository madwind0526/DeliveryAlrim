# State

## Current Wave

- **Wave:** 5
- **Status:** Wave 5 complete (카카오톡 접근성 캡처가 로컬 SQLite DB까지 백그라운드 저장됨)
- **Cache Status:** CLEAN
- **Last Checkpoint:** 2026-07-05 Wave 5 Android DB 브리지 검증

## Wave History

| Wave | 작업 내용 | 상태 |
|------|-----------|------|
| 0 | 프로젝트 초기화 (CLAUDE.md, DESIGN.md, git) | Done |
| 1 | PC 모드 골격 (Flutter Win+Android, 로컬 인증/저장소, 목록 UI) | Done |
| 2 | 파싱 엔진 + fixture 코퍼스 15건 + 주입 디버그 화면 | Done |
| 3 | 상세 타임라인 + 일별/월별 캘린더 + 도착일 휴리스틱 + 하단 내비 | Done |
| 4 | Supabase 제거 + 로그인 제거 + 로컬 단일 사용자 모드 + 좌측 메뉴 UI | Done |
| 5 | Android 실기기: 카카오톡 접근성 캡처 + Flutter/네이티브 로컬 DB 브리지 + 사용자 동기화 UI | Done |
| 6 | 하드닝: SMS/이메일 입력, 계정 정보 암호화 저장, 배터리 최적화, 로컬 알림, 릴리즈 APK | Planned |

## Session Notes

- 사용자가 Supabase 사용 계획을 철회함.
- 앱 자체 로그인과 멀티 유저 지원은 제거한다.
- 모든 자료는 로컬 저장소에 보관한다.
- User 메뉴는 외부 모니터링 계정 설정용이며, 필요한 로그인 정보는 암호화 저장한다.
- 모든 입력은 알림 리스너를 trigger + hint로 사용하고, 실제 배송 DB는 채널별 본문 획득 결과를 기준으로 만든다.
- 카카오톡 특정 채널 읽기는 공식 API가 아니라 접근성 기반으로 진행한다. 삼성카드/CJ대한통운 알림톡 본문 추출 PoC 성공.
- 2026-07-05 알림/접근성 PoC 발견사항을 knowledge로 flush 완료.
- Supabase/Auth 제거 후 `flutter analyze`, `flutter test`, Windows build 성공.
- Android `KakaoAccessibilityService` 추가 후 debug APK 빌드/설치 성공.
- 접근성 서비스 라벨은 `체크쉬핑 카카오톡 수집`으로 표시됨.
- CJ대한통운 채팅방 실서비스 검증: logcat `captured courier=cj invoice=594239221744 status=delivered sender=삼성전자`, SharedPreferences 저장 확인.
- Android 네이티브 SQLite 직접 저장 검증: logcat `persisted capture to local sqlite invoice=594239221744`, DB `parcel_rows` 1건 유지 확인.
- Flutter 앱 시작/복귀 및 User 화면 `카카오톡 동기화` 버튼에서 SharedPreferences 최신 캡처를 DB로 backfill한다.
- Windows에서 먼저 검증하고 Android로 확장한다.
