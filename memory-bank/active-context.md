# Active Context

## Current Focus

- 방향 전환 확정: Supabase 미사용, 앱 로그인 제거, 단일 사용자 로컬 저장 앱으로 진행
- Android가 실제 타깃이고 Windows는 테스트 전용
- UI 골격: 좌측/하단 아이콘 메뉴, 업체별/오늘 현황/월별/필터/설정/사용자 화면 구현됨
- 핵심 수집 구조: 알림은 trigger + hint이고, 실제 배송 DB는 채널별 본문 획득 후 생성
- Android 카카오톡 삼성카드/CJ대한통운 채널 모두 `com.kakao.talk:id/alimtalk_title`에서 알림톡 본문 추출 성공
- 접근성 서비스 `체크쉬핑 카카오톡 수집` 활성화 및 CJ대한통운 실서비스 캡처 검증 완료
- 캡처 결과는 네이티브 SharedPreferences와 `app_flutter/check_shipping.sqlite`에 즉시 저장됨
- Flutter 앱 시작/복귀 및 User 화면 `카카오톡 동기화` 버튼에서 최신 캡처를 DB로 backfill함
- `일별`은 캘린더가 아니라 오늘 기준 주문/준비, 배달 중, 오늘 배달 예정 현황 화면으로 사용함
- 다음: SMS/이메일 입력 경로, 계정 정보 암호화 저장, 배터리 최적화/릴리즈 APK 하드닝

<!-- 
규칙:
- 최근 작업 10개만 유지 (오래된 항목은 삭제)
- 완료된 Wave의 내용은 CACHE.md로 이동 후 삭제
- 이 파일은 "지금 무엇을 하고 있나" 스냅샷, 히스토리 아님
-->
