# State

## Current Wave

- **Wave:** 4
- **Status:** Ready (Supabase 실연결 — 사용자 콘솔 작업 필요)
- **Cache Status:** CLEAN
- **Last Checkpoint:** 2026-07-05 Wave 3 완료 커밋

## Wave History

| Wave | 작업 내용 | 상태 |
|------|-----------|------|
| 0 | 프로젝트 초기화 (CLAUDE.md, DESIGN.md, git) | Done |
| 1 | PC 모드 골격 (Flutter Win+Android, 로컬 인증/저장소, 목록 UI) | Done |
| 2 | 파싱 엔진 + fixture 코퍼스 15건 + 주입 디버그 화면 | Done |
| 3 | 상세 타임라인 + 일별/월별 캘린더 + 도착일 휴리스틱 + 하단 내비 | Done |
| 4 | Supabase 실연결 (RLS, 이메일→Google 로그인, track-poll) | Ready |

## Session Notes

- Wave 3 검증: 21 테스트 통과, analyze 무결점, Windows 빌드 성공
- Wave 4 시작 전 사용자 콘솔 작업 필요: ① Supabase 프로젝트 생성 ② 스마트택배 API 키 ③ (Google 로그인 단계에서) GCP OAuth
