# Active Context

## Current Focus

- 방향 전환 확정: Supabase 미사용, 앱 로그인 제거, 단일 사용자 로컬 저장 앱으로 진행
- Android가 실제 타깃이고 Windows는 테스트 전용
- 다음: Wave 4 — 기존 Supabase/Auth 흔적 정리, 무로그인 로컬 모드 복구, 좌측 메뉴+우측 메인 UI 재설계
- User 메뉴는 앱 로그인 대신 이메일/SNS/외부 계정 모니터링 설정과 암호화 저장을 담당
- 핵심 수집 구조: 알림은 trigger + hint이고, 실제 배송 DB는 채널별 본문 획득 후 생성
- 본문 획득 우선순위: 공식 API → IMAP/표준 프로토콜 → 공유/내보내기 → 접근성 보조 캡처 → 알림만 사용
- Android 카카오톡 삼성카드/CJ대한통운 채널 모두 `com.kakao.talk:id/alimtalk_title`에서 알림톡 본문 추출 성공
- 2026-07-05 PoC 발견사항은 knowledge로 flush 완료, CACHE clean

<!-- 
규칙:
- 최근 작업 10개만 유지 (오래된 항목은 삭제)
- 완료된 Wave의 내용은 CACHE.md로 이동 후 삭제
- 이 파일은 "지금 무엇을 하고 있나" 스냅샷, 히스토리 아님
-->
