# Active Context

## Current Focus

- 앱 방향은 Supabase/Auth 없는 로컬 단일 사용자 Android 앱이다.
- 앱 이름은 `배송알리미`를 사용한다.
- Windows는 세로형 디버그 창으로 먼저 검증하고, Android 실기기에서 최종 확인한다.
- 모든 배송 데이터와 모니터링 설정은 로컬 저장소에 둔다.
- Gmail/문자/SNS 모니터링 소스의 로그인 정보는 항상 secure storage에 암호화 저장한다.
- 카카오톡 배송 정보 수집은 NotificationListenerService + AccessibilityService 조합으로 진행한다.
- User 화면은 이메일/SMS/SNS 모니터링 소스와 로그인 정보 관리용이다.
- Settings 화면은 로컬/테스트 세그먼트로 분리한다. 로컬에는 알림 접근/접근성 시스템 설정 이동을, 테스트에는 Gmail/SMS 샘플, 카카오톡 동기화, 알림 주입 테스트만 둔다.
- 배송 수동 등록은 홈 배송 목록의 `+` FAB에서 여는 정식 기능이다.
- 다음 주요 작업은 실제 Gmail/IMAP 연결, Android SMS 권한/수신 연결, 카카오톡 계정 적용 범위 정리, 배터리 최적화 대응, 릴리즈 APK 준비다.
