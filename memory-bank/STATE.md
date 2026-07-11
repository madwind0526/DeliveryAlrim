# State

## Current Wave

- **Wave:** 6
- **Status:** In Progress
- **Cache Status:** DIRTY
- **Last Checkpoint:** 2026-07-12 카드사 이름을 하드코딩하지 않고 "제목이 카드로 끝남" 정규식 하나로 모든 카드 결제 알림을 "주문 내역"(registered)으로 등록하는 기능 추가, 테스트 51건 통과. 이전 체크포인트: 헤드리스 백그라운드 동기화(앱 안 열어도 자동 반영) 실기기 검증 완료, E2E 5종 시나리오 전부 통과, 캘린더 날짜별 스냅샷/월·주 토글 실기기 확인

## Wave History

| Wave | 작업 내용 | 상태 |
|------|-----------|------|
| 0 | 프로젝트 초기화(CLAUDE.md, DESIGN.md, git) | Done |
| 1 | PC 모드 골격(Flutter Windows+Android, 로컬 저장소, 목록 UI) | Done |
| 2 | 파싱 엔진 + fixture 코퍼스 + 주입 디버그 화면 | Done |
| 3 | 상세 타임라인 + 일별/월별 캘린더 + 필터 프리셋 + 하단 네비게이션 | Done |
| 4 | Supabase/Auth 제거 + 로컬 단일 사용자 모드 + 좌측 메뉴 UI | Done |
| 5 | Android 실기기 카카오톡 접근성 캡처 + Flutter/네이티브 로컬 DB 브리지 + 사용자 동기화 UI | Done |
| 6 | 하드웨어 SMS/이메일 입력, 계정 정보 암호화 저장, 배터리 최적화, 로컬 알림, 릴리즈 APK | In Progress |

## Session Notes

- Supabase, 서버 로그인, 멀티 유저 기능은 사용하지 않는다.
- 앱 표시 이름은 배송알리미다. 내부 패키지명, DB 파일명, MethodChannel 이름은 호환성을 위해 유지한다.
- 앱 자체 로그인은 제거하고, 외부 모니터링 소스의 인증 정보만 User 화면에서 관리한다.
- 모니터링 소스 비밀값은 SQLite가 아니라 Android secure storage에 저장한다.
- Settings > 로컬에는 알림 접근/카카오톡 접근성 수집 상태와 Android 시스템 설정 이동을 둔다.
- Settings > 테스트에는 Gmail/SMS 샘플과 카카오톡 동기화, 알림 주입 테스트만 둔다.
- 배송 수동 등록은 자동 수집 보완용 정식 기능이며 홈 배송 목록 `+` FAB에서 연다.
- Android 업데이트는 `adb install -r`로 진행해 secure storage의 기존 로그인 정보를 보존한다.
- `code-review.md` 기준 수정된 항목: secure storage 실패 방어, 수동 등록 운송장 패턴 검증, 카카오 최신 캡처 clear, 릴리즈 빌드 테스트 주입 UI 숨김, 네이티브/Drift 동일 SQLite 동시 쓰기 제거, deliveredAt 보존, 접근성 root recycle, 하단 네비게이션 접근성 label 복구, User 화면 저장/삭제/추가 후 secure-storage 전체 재조회 제거.
- User 소스 on/off 상태는 secure storage에 저장하며, 카카오톡 자동 동기화는 카카오톡 on/off 상태를 따른다.
- 실기기에서 Gmail 앱의 기존 배송 알림을 NotificationListener가 캡처하고 Flutter 동기화 후 `parcel_rows`에 `gmail` 소스 4건이 등록되는 것을 확인했다.
- 남은 구조 이슈: 외부 Gmail/Naver/SMS 알림 실기기 E2E 검증, Gmail/IMAP 직접 수집 여부 결정, 카카오톡 계정 적용 범위 정리, 배터리 최적화 대응.
