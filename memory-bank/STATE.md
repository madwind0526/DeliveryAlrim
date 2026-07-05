# State

## Current Wave

- **Wave:** 5
- **Status:** Wave 6 in progress (User 소스 추가/secure storage 로그인 저장 골격 완료, 실제 계정/권한 연결 남음)
- **Cache Status:** CLEAN
- **Last Checkpoint:** 2026-07-06 Wave 6 User 소스 추가 버튼 실기기 검증

## Wave History

| Wave | 작업 내용 | 상태 |
|------|-----------|------|
| 0 | 프로젝트 초기화 (CLAUDE.md, DESIGN.md, git) | Done |
| 1 | PC 모드 골격 (Flutter Win+Android, 로컬 인증/저장소, 목록 UI) | Done |
| 2 | 파싱 엔진 + fixture 코퍼스 15건 + 주입 디버그 화면 | Done |
| 3 | 상세 타임라인 + 일별/월별 캘린더 + 도착일 휴리스틱 + 하단 내비 | Done |
| 4 | Supabase 제거 + 로그인 제거 + 로컬 단일 사용자 모드 + 좌측 메뉴 UI | Done |
| 5 | Android 실기기: 카카오톡 접근성 캡처 + Flutter/네이티브 로컬 DB 브리지 + 사용자 동기화 UI | Done |
| 6 | 하드닝: SMS/이메일 입력, 계정 정보 암호화 저장, 배터리 최적화, 로컬 알림, 릴리즈 APK | In Progress |

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
- User 화면은 이메일/문자/SNS 모니터링 섹션을 구분해 표시하고, 소스 행은 `Gmail`, `SMS`, `카카오톡`처럼 이름만 표시한다.
- Gmail/SMS 자동 주입 버튼은 앱 내부 샘플을 생성해 `RuleEngine → ParcelRepository` 경로로 배송 DB에 등록한다.
- Android 실기기 검증: `Gmail 샘플 보내기`, `SMS 샘플 보내기` 실행 후 DB에 `cj / 641234567893 / gmail`, `hanjin / 512345678901 / sms`가 등록됨.
- 로그인/모니터링 관리는 소스 프로필 단위로 묶고, 비밀값은 SQLite가 아니라 Android Keystore/secure storage에 저장한다.
- Google Play Store 배포는 현재 목표가 아니며, 모니터링 앱 로그인/token/API key는 사용자가 끄는 옵션 없이 항상 로컬 secure storage에 저장한다.
- User 화면에서 `암호화 저장` 스위치를 제거하고 Gmail/카카오톡 로그인 정보 관리 다이얼로그와 secure storage `CredentialStore` 골격을 추가했다.
- 이메일/SNS `추가` 버튼은 소스 선택 다이얼로그를 열고, 선택한 소스를 켠 뒤 로그인 정보 입력으로 이어진다.
- Android 실기기에서 이메일 `추가` 버튼이 `Gmail`, `기타 이메일` 선택 다이얼로그를 여는 것을 확인했다. 사용자는 Gmail/카카오톡 계정 정보를 입력 완료했다.
