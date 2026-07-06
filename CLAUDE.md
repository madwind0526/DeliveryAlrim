# 배송알리미

> **Working directory: `C:\Claude\CheckShipping`**

## Project Overview

온라인 쇼핑 배송 자동 추적 Android 앱. 이제 이 프로젝트는 **Supabase 없이, 로그인 없이, 단일 사용자 로컬 앱**으로 진행한다.

- 앱 사용자는 한 명으로 가정한다. 멀티 유저, 서버 계정, 동기화는 지원하지 않는다.
- 모든 배송 데이터, 원본 캡처, 파싱 결과, 설정은 기기 로컬에 저장한다.
- Android 앱을 최종 타깃으로 만든다. iOS는 나중에 확장할 수 있지만 현재 범위가 아니다.
- Windows 빌드는 개발/테스트 목적이다. 먼저 Windows에서 fixture와 UI를 검증하고, 문제가 없으면 Android 실기기로 확장한다.
- 운송장번호 수집은 자동화를 목표로 한다: Android 알림 파싱(카카오 알림톡/SMS/쇼핑몰 앱) + 이메일/SNS 모니터링 설정.
- 사용자에게 보이는 앱 UI 텍스트는 한국어로 작성한다.

상세 설계와 방향 전환 기록은 [docs/DESIGN.md](docs/DESIGN.md) 참조.

## Tech Stack

- **App**: Flutter (Android 우선, Windows는 테스트 전용)
- **State/UI**: riverpod, go_router, table_calendar
- **Local storage**: drift(SQLite), flutter_secure_storage
- **Capture**: Android NotificationListenerService 계열 플러그인, Gmail/메일/SNS 연동은 로컬 설정 기반으로 확장
- **Background work**: workmanager 또는 Android 네이티브 백그라운드 작업
- **Tracking API**: 스마트택배(Sweet Tracker) 조회 API는 기기 로컬에서 호출하는 방향으로 검토

## Commands

```bash
# Flutter app (app/)
cd app
flutter run -d windows          # Windows test run
flutter test                    # parser/repository fixture tests
flutter analyze                 # static analysis gate
flutter run                     # connected Android device
flutter build apk --release     # release APK for personal install
```

## Architecture Summary

```
Android 알림 리스너
  → 알림 원본 저장/배송 후보 분류 (trigger + hint)
  → 채널별 본문 획득
  → 로컬 규칙 엔진
  → 로컬 SQLite 저장/중복제거/상태 병합
  → 로컬 백그라운드 배송 조회
  → Flutter UI (업체별 / 일별 / 월별 / 필터 / 설정 / 사용자 모니터링)
```

- Supabase, 서버 DB, RLS, Edge Function, pg_cron은 사용하지 않는다.
- 앱 로그인은 없다. 앱 자체는 단일 사용자 로컬 모드로 바로 진입한다.
- "User" 영역은 앱 로그인용이 아니라, 모니터링할 이메일/SNS/외부 계정의 연결과 암호화 저장 설정을 담당한다.
- 로그인 정보나 API 키가 필요한 외부 서비스 정보는 `flutter_secure_storage` 등 OS 보안 저장소에 암호화 저장한다.
- 모든 채널은 알림을 공통 진입점으로 사용한다. 단, 알림은 완성 데이터가 아니라 어떤 채널을 더 읽어야 하는지 알려주는 트리거/힌트다.
- 이메일은 Gmail API/IMAP로 실제 본문을 읽고, SMS/SNS/쇼핑몰 앱은 공식 API, 공유, 접근성 기반 화면 텍스트 캡처, 알림만 사용 순서로 채널별 전략을 둔다.
- 카카오톡 특정 채널(CJ대한통운 등)은 공식 읽기 API가 없으므로 Android 접근성 기반 PoC가 필수 게이트다.
- 원본 알림/메일 텍스트는 개인정보 보호를 위해 로컬에만 저장한다.

## Target UI

왼쪽에는 고정 메뉴, 오른쪽에는 메인 윈도우가 있는 구조를 우선 설계한다. 모바일 Android에서는 같은 정보 구조를 바텀 내비게이션/드로어로 재배치할 수 있다.

왼쪽 메뉴:

- **업체별**: 누르면 스크롤 가능한 팝업 또는 패널이 열리고, 업체를 선택할 수 있다.
- **일별**: 선택한 날짜의 배송 현황을 표시한다.
- **월별**: 월 캘린더와 날짜별 배송 현황을 표시한다.
- **Filter**: 업체 선택, 날짜 기간 선택, 상태 선택 등 필터를 제공한다.
- **Setting**: 모드 선택과 기타 설정을 둔다. 세부 항목은 나중에 확정한다.
- **User**: 모니터링할 이메일, SNS, 기타 외부 계정의 추가/설정/로그인 입력란을 제공한다. 저장 정보는 암호화한다.
  SNS 항목은 감시할 앱 선택, 계정 표시, 권한 상태, 공식 API/공유/접근성 보조 캡처 사용 여부를 관리한다.

## Wave Roadmap

| Wave | 내용 | 환경 |
|------|------|------|
| 0 | 초기화: CLAUDE.md, DESIGN.md, git | 완료 |
| 1 | Flutter(Windows+Android) + 로컬 저장소 + 배송 목록 UI | 완료 |
| 2 | 파싱 엔진 + fixture 코퍼스 + 주입 디버그 화면 + 단위 테스트 | 완료 |
| 3 | 상세 타임라인 + 일별/월별 캘린더 + 도착일 휴리스틱 | 완료 |
| 4 | Supabase 제거/무로그인 로컬 모드 정리 + 좌측 메뉴 기반 UI 재설계 | 진행 예정 |
| 5 | Android 실기기: 알림 리스너 + 카카오톡 채널 접근성 PoC + 이메일/SNS 설정 + 보안 저장소 | 예정 |
| 6 | 하드닝: 백그라운드 안정성, 배터리 최적화, 로컬 알림, 릴리즈 APK | 예정 |

## Key Conventions

- **UI 텍스트는 한국어, 코드 주석은 영어만** (글로벌 규칙 G-01/G-02)
- Supabase는 사용하지 않는다.
- 앱 로그인은 만들지 않는다. 단일 사용자 로컬 앱으로 바로 실행한다.
- 외부 계정 로그인 정보는 User 메뉴에서 관리하고, 로컬 보안 저장소에 암호화 저장한다.
- Windows는 테스트용이고 Android가 실제 배포 타깃이다.
- 파싱 규칙은 가능하면 데이터화한다. 초기에는 번들 JSON/로컬 DB를 사용하고, 서버 OTA는 도입하지 않는다.
- 운송장번호 추출 시 택배사 키워드 동시 출현을 우선해 전화번호/주문번호 오탐을 줄인다.

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
