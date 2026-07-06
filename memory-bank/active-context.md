# Active Context

## Current Focus

- 방향 전환 확정: Supabase 미사용, 앱 로그인 제거, 단일 사용자 로컬 저장 앱으로 진행
- Android가 실제 타깃이고 Windows는 테스트 전용
- UI 골격: 좌측/하단 아이콘 메뉴, 업체별/오늘 현황/월별/필터/설정/사용자 화면 구현됨
- 핵심 수집 구조: 알림은 trigger + hint이고, 실제 배송 DB는 채널별 본문 획득 후 생성
- 카카오톡 삼성카드/CJ대한통운 접근성 캡처와 네이티브 SQLite 즉시 저장은 실기기 검증 완료
- Gmail/SMS 샘플 자동 주입 테스트가 User 화면과 디버그 주입 화면에서 같은 `RuleEngine → ParcelRepository` 경로로 동작함
- User 화면 초기 표시는 Gmail/카카오톡만 유지하고, 기타 이메일/SMS/텔레그램/WhatsApp은 `추가` 버튼 선택 후 표시됨
- 이메일/SNS 추가 다이얼로그는 소스 선택과 로그인 정보 입력을 한 번에 처리하고, 기존 행의 로그인 버튼은 수정/삭제용으로 유지됨
- Windows 테스트 창은 휴대폰 세로 화면에 가깝게 430x932 기본 크기로 실행됨
- Play Store 배포는 현재 목표가 아니며, 모니터링 앱 로그인 정보는 로컬 secure storage에 항상 암호화 저장
- Gmail/카카오톡 secure storage key 존재를 Android 실기기에서 확인했고, 저장 상태 UI는 값 복호화가 아니라 key 존재 여부로 판단함
- 다음: 실제 Gmail OAuth/IMAP 연결, Android SMS 권한/수신 연결, 카카오톡 계정 활용 범위 정리, 배터리 최적화/릴리즈 APK 하드닝

<!-- 
규칙:
- 최근 작업 10개만 유지 (오래된 항목은 삭제)
- 완료된 Wave의 내용은 CACHE.md로 이동 후 삭제
- 이 파일은 "지금 무엇을 하고 있나" 스냅샷, 히스토리 아님
-->
