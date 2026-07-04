# CheckShipping

> **Working directory: `C:\Claude\CheckShipping`**

## Project Overview

온라인 쇼핑 배송 자동 추적 Android 앱. 쇼핑몰별 구매 내역을 추적하는 대신, **고정된 소수의 택배사**를 이용한다는 점을 활용해 "지금 무엇이 배송 중이고 언제 도착하는지"를 한 화면에서 보여준다.

- 운송장번호 수집은 **전부 자동**: Android 알림 파싱(카카오 알림톡/SMS 알림/쇼핑몰 앱) + Gmail 이메일 파싱. 수동 입력은 디버그용만.
- 배송 상태는 스마트택배(Sweet Tracker) 조회 API를 Supabase pg_cron + Edge Function으로 주기 폴링하여 갱신.
- 쿠팡 로켓배송은 공개 API가 없어 쿠팡 앱/알림톡 알림 텍스트에서 상태를 추론 (운송장 없음 → 상품명+날짜 기반 합성 키).
- 일별/월별 도착 현황 캘린더 제공. Google + 이메일/비밀번호 로그인 (Supabase Auth).

상세 아키텍처/스키마/파이프라인 설계는 [docs/DESIGN.md](docs/DESIGN.md) 참조.

## Tech Stack

- **App**: Flutter (Android 우선, iOS 확장 예정) — riverpod, go_router, drift(로컬 DB), workmanager, table_calendar
- **Capture**: flutter_notification_listener (NotificationListenerService), googleapis (Gmail API)
- **Backend**: Supabase 무료 티어 — Auth(Google+이메일), Postgres+RLS, Edge Functions(Deno), pg_cron/pg_net
- **Tracking API**: 스마트택배(Sweet Tracker) 조회 API — 무료 키, 택배사코드+운송장번호 기반

## Commands

```bash
# Flutter app (app/)
cd app
flutter run -d windows           # PC-mode dev run (primary during Waves 1-4)
flutter run                      # dev run on connected Android device
flutter build apk --release     # release APK (sideload)
flutter test                     # parser fixture corpus tests

# Supabase (supabase/)
supabase db push                 # apply migrations
supabase functions deploy track-poll
supabase functions serve track-poll   # local test
```

## Architecture Summary

```
알림/SMS/Gmail → 온디바이스 규칙 엔진(DB 기반, OTA 갱신) → 검증/중복제거
  → Supabase parcels upsert (사용자별 RLS)
  → pg_cron(30분) → Edge Function track-poll → 스마트택배 API → 상태/이벤트 갱신
  → Flutter UI (진행중 목록 / 상세 타임라인 / 일별·월별 캘린더)
```

- 알림 원본 텍스트는 개인정보 보호를 위해 **기기에만 저장** (drift `raw_captures` — 파싱 디버그/재생 코퍼스 겸용). 서버에는 구조화된 배송 데이터만 올린다.
- 파싱 규칙은 `parse_rules` 테이블에서 OTA 동기화 — 알림 문구가 바뀌어도 앱 재배포 불필요.
- 상태 머신은 단조 증가(역행 금지): 등록됨→상품준비→집화→배송중→배송출발→배달완료. 배달완료/만료/번호오류는 폴링 제외.

## Wave Roadmap (PC-first)

BlueTooth-Comm(`C:\Claude\BlueTooth-Comm`) 패턴: Windows+Android 이중 타깃, 플랫폼 의존 기능은 인터페이스 뒤에 격리(`CaptureSource`, `ParcelRepository`, `AuthRepository`), PC에서 fixture로 검증 후 실기기/실서버 연결.

| Wave | 내용 | 환경 |
|------|------|------|
| 0 | 초기화: CLAUDE.md, git, 설계 | 완료 |
| 1 | Flutter(Win+Android) + 로컬 인증/저장소 + 배송 목록 UI | PC |
| 2 | 파싱 엔진 + fixture 코퍼스 + 주입 디버그 화면 + 단위 테스트 | PC |
| 3 | 상태 머신 + 일별/월별 캘린더 + 상세 타임라인 + 쿠팡 매퍼 | PC |
| 4 | Supabase 실연결(RLS) + 이메일→Google 로그인 + track-poll | PC→서버 |
| 5 | Android 실기기: 알림 리스너 + 온보딩 + Gmail API | 폰 |
| 6 | 하드닝 (배터리 최적화, 감시, 소크 테스트) | 폰 |

## Key Conventions

- **UI 텍스트는 한국어, 코드 주석은 영어만** (글로벌 규칙 G-01/G-02)
- 배송 데이터는 사용자별 RLS 필수 — 모든 테이블에 정책 작성 후 두 계정으로 교차 접근 검증
- 파싱 규칙은 하드코딩 금지 → `parse_rules` 테이블 + 번들 fallback JSON
- API 키/시크릿은 `.env` / `--dart-define`으로 분리, 커밋 금지
- 운송장번호 추출 시 택배사 키워드 동시 출현 필수 (전화번호/주문번호 오탐 방지)

## Memory Bank

이 프로젝트는 `memory-bank/` 시스템을 사용합니다.

| 파일 | 용도 |
|------|------|
| `memory-bank/active-context.md` | 현재 작업 포커스 |
| `memory-bank/STATE.md` | Wave 진행 상태 |
| `memory-bank/CACHE.md` | 세션 중 임시 발견사항 |
| `memory-bank/knowledge/PATTERNS.md` | 재사용 코드 패턴 |
| `memory-bank/knowledge/RULES.md` | 프로젝트 규칙 |
| `memory-bank/knowledge/trouble-shooting.md` | 버그 해결 기록 |

**세션 시작 시**: `active-context.md` → `STATE.md` 순으로 읽고 현재 상태를 파악할 것.
