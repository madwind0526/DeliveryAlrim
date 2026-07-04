# CheckShipping — Implementation Design

> 2026-07-04 설계 확정본. Wave 구현 시 이 문서를 기준으로 진행하고, 변경 사항은 이 문서에 반영한다.

## 0. Architecture Overview

```
[Android device]                                     [Supabase free tier]
카톡 알림톡 / SMS알림 / 쿠팡앱 알림 ─┐
                                    ├─ NotificationListenerService
직접 SMS 읽기 (optional, flagged) ──┤        │
Gmail API (on-device polling) ──────┘        ▼
                              Rule engine (DB-driven rules, bundled fallback)
                                             │ extract {courier, invoice, product, mall, status_hint}
                                             ▼
                              Local queue (drift) ──upsert──▶ parcels / tracking_events (RLS per user)
                                                                    ▲
                                        pg_cron ─▶ Edge Function `track-poll` ─▶ Sweet Tracker 조회 API
                                                                    │
                              Flutter UI (목록 / 일별·월별 캘린더) ◀─ Realtime + pull-to-refresh
```

Key decisions:

- **Gmail parsing runs on-device** (WorkManager periodic task), not in an Edge Function. Keeps the OAuth refresh token in `flutter_secure_storage` instead of the server, reuses the same Google sign-in, and saves Edge Function invocations for the tracking poller.
- **Raw notification text stays on-device** (local drift DB) for privacy; only extracted, structured parcel data goes to Supabase. The local raw store doubles as the replay/debug corpus.
- **Parse rules are DB-driven** (`parse_rules` table, synced to the app with a version number, bundled JSON fallback) so kakao/mall template changes ship without an app release.

## 1. Repository Structure

Feature-first layout (capture, tracking, calendar are sharply distinct features; keeps the gnarly capture code quarantined).

```
C:\Claude\CheckShipping\
├── memory-bank/
├── docs/DESIGN.md
├── app/                                  # Flutter project (flutter create --org com.checkshipping)
│   ├── android/app/src/main/AndroidManifest.xml   # listener service, POST_NOTIFICATIONS, (flagged) SMS perms
│   ├── assets/parse_rules_fallback.json  # bundled snapshot of parse_rules
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart                      # MaterialApp.router, ko_KR locale
│   │   ├── core/
│   │   │   ├── supabase_client.dart
│   │   │   ├── router.dart               # go_router, auth redirect
│   │   │   ├── theme.dart
│   │   │   ├── constants/couriers.dart   # fixed courier set + Sweet Tracker codes
│   │   │   └── local_db/local_db.dart    # drift: raw_captures, upload_queue, rule_cache
│   │   ├── features/
│   │   │   ├── auth/        (login_screen.dart, auth_repository.dart, auth_provider.dart)
│   │   │   ├── parcels/     (parcel_list_screen.dart, parcel_detail_screen.dart,
│   │   │   │                 parcel_repository.dart, models/parcel.dart, models/tracking_event.dart)
│   │   │   ├── calendar/    (calendar_screen.dart, daily_list_view.dart, calendar_provider.dart)
│   │   │   ├── capture/
│   │   │   │   ├── notification_capture_service.dart   # listener bootstrap + callback isolate
│   │   │   │   ├── sms_capture_service.dart            # optional, build-flag gated
│   │   │   │   ├── gmail_capture_service.dart          # WorkManager task
│   │   │   │   ├── parser/rule_engine.dart             # regex rules -> ExtractedParcel
│   │   │   │   ├── parser/tracking_number_validator.dart  # per-courier regex + CJ check digit
│   │   │   │   ├── parser/coupang_status_mapper.dart
│   │   │   │   ├── dedupe/parcel_upserter.dart         # local dedupe + Supabase upsert + retry queue
│   │   │   │   └── rules_sync.dart                     # parse_rules OTA sync
│   │   │   ├── settings/    (settings_screen.dart, onboarding_screen.dart, permission_guide/)
│   │   │   └── debug/       (replay_screen.dart, debug_insert_screen.dart)   # dev flavor only
│   │   └── core/strings_ko.dart          # all UI strings in Korean, centralized
│   └── pubspec.yaml
└── supabase/
    ├── config.toml
    ├── migrations/
    │   ├── 0001_init.sql                 # couriers, parcels, tracking_events, user_settings, RLS
    │   ├── 0002_parse_rules.sql
    │   └── 0003_cron.sql                 # pg_cron + pg_net schedule
    └── functions/
        ├── track-poll/index.ts           # scheduled poller
        └── _shared/sweettracker.ts       # API client + level→status mapping
```

## 2. Supabase Schema (DDL sketch)

```sql
-- Fixed courier registry (seeded; readable by all authenticated users)
create table couriers (
  code text primary key,            -- 'cj', 'hanjin', 'lotte', 'epost', 'logen', 'coupang_direct'
  name_ko text not null,            -- 'CJ대한통운'
  sweettracker_code text,           -- '04' for CJ etc; NULL => not pollable (coupang_direct)
  invoice_regex text not null,      -- e.g. '^[0-9]{10,12}$'
  is_direct boolean not null default false   -- true => status from notifications only
);

create type parcel_status as enum
  ('registered','preparing','picked_up','in_transit','out_for_delivery','delivered','expired','invalid');
-- UI labels: 등록됨/상품준비/집화/배송중/배송출발/배달완료/만료/번호오류

create table parcels (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  courier_code text not null references couriers,
  tracking_number text not null,    -- for coupang_direct: synthesized key 'cp:<sha1(product|date)>'
  status parcel_status not null default 'registered',
  product_name text, mall_name text,
  source_channels text[] not null default '{}',   -- {'kakao','sms','gmail','coupang_app','manual'}
  expected_arrival_date date,       -- drives 일별/월별 views
  delivered_at timestamptz,
  registered_at timestamptz not null default now(),
  last_polled_at timestamptz, poll_fail_count int not null default 0,
  unique (user_id, courier_code, tracking_number)   -- dedupe backstop
);

create table tracking_events (
  id bigint generated always as identity primary key,
  parcel_id uuid not null references parcels on delete cascade,
  event_time timestamptz not null,
  location text, status_level int,  -- Sweet Tracker level 1..6
  description text,
  unique (parcel_id, event_time, description)       -- idempotent upsert from poller
);

create table user_settings (
  user_id uuid primary key references auth.users on delete cascade,
  kakao_capture_enabled bool default true,
  sms_capture_enabled bool default false,
  gmail_connected bool default false,
  updated_at timestamptz default now()
);

-- OTA parse rules
create table parse_rules (
  id int primary key,
  rules_version int not null,       -- monotonically increasing; app caches highest seen
  source_type text not null,        -- 'kakao' | 'sms' | 'mall_app' | 'gmail'
  package_name text,                -- 'com.kakao.talk', 'com.coupang.mobile'; NULL for sms/gmail
  sender_match text,                -- SMS sender number regex / Gmail 'from' regex
  title_match text,                 -- regex on notification title / email subject
  body_regex text not null,         -- named groups: courier / invoice / product / mall
  courier_code text,                -- force courier when regex can't capture it
  status_hint text,                 -- for coupang_direct rules: maps to parcel_status
  priority int not null default 100,
  active bool not null default true
);

-- Indexes
create index parcels_user_active_idx on parcels (user_id, status);
create index parcels_user_arrival_idx on parcels (user_id, expected_arrival_date);   -- daily/monthly
create index parcels_user_delivered_idx on parcels (user_id, delivered_at);          -- monthly history
create index parcels_pollable_idx on parcels (last_polled_at)
  where status not in ('delivered','expired','invalid');                             -- poller scan
create index tracking_events_parcel_idx on tracking_events (parcel_id, event_time desc);

-- RLS
alter table parcels enable row level security;
create policy parcels_own on parcels for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
alter table tracking_events enable row level security;
create policy events_own on tracking_events for select
  using (exists (select 1 from parcels p where p.id = parcel_id and p.user_id = auth.uid()));
-- inserts to tracking_events come only from the Edge Function (service_role bypasses RLS)
alter table user_settings enable row level security;
create policy settings_own on user_settings for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
alter table couriers enable row level security;
create policy couriers_read on couriers for select using (auth.role() = 'authenticated');
alter table parse_rules enable row level security;
create policy rules_read on parse_rules for select using (auth.role() = 'authenticated');
-- parse_rules writes: service_role / dashboard only
```

일별 뷰 쿼리: `parcels where user_id=me and (expected_arrival_date = :day or delivered_at::date = :day)`. 월별: 동일 조건 range + 날짜별 count 집계로 캘린더 배지 표시.

## 3. Collection Pipeline

All on-device until the final upsert:

1. **Capture.** `flutter_notification_listener` background callback receives `(packageName, title, text, bigText/extras)`. Filter by package allowlist derived from active `parse_rules` (`com.kakao.talk`, `com.coupang.mobile`, `com.samsung.android.messaging`, `com.google.android.apps.messaging`, courier apps). Every allowlisted notification is written to local `raw_captures` (drift) with timestamp + parse outcome — the replay corpus.
2. **Extract.** `rule_engine.dart` runs rules ordered by priority: match `package_name` + `title_match`, then `body_regex` with named groups over `title + '\n' + (bigText ?? text)`. First match wins. Courier resolution: explicit `courier` group keyword → `couriers.name_ko` lookup; else rule's `courier_code`.
3. **Validate.** Per-courier `invoice_regex` from `couriers`; CJ additionally gets the mod-7 check-digit test. A bare 10–14 digit number with no courier keyword in the same text is **rejected** (kills phone numbers/order numbers).
4. **Dedupe.** Local: drift cache of `(courier_code, tracking_number)` seen in last 60 days → if seen, merge (add source channel, fill null product/mall). Remote backstop: upsert on `unique(user_id, courier_code, tracking_number)` with `on conflict` merging `source_channels` and coalescing null fields.
5. **Upsert with offline queue.** Writes go through `parcel_upserter.dart`; failures (no network, Supabase paused) land in a drift `upload_queue` flushed by WorkManager.

**Gmail path:** WorkManager task every ~1h: `users.messages.list` with query `newer_than:7d {from:cjlogistics.com from:hanjin.co.kr from:epost.go.kr subject:(운송장 OR 배송)}` (query string itself stored as a `gmail` parse_rule → OTA-updatable), then `messages.get`, strip HTML, run the same rule engine.

**SMS direct-read path:** compile-time flag (`--dart-define=ENABLE_SMS_READ=true`) + settings toggle, default off. The notification listener already sees SMS-app notifications (Play-policy-safe default); direct READ_SMS is for the sideloaded personal build only.

**Rules distribution:** `rules_sync.dart` on app start fetches `parse_rules where rules_version > cachedVersion`, stores in drift `rule_cache`; the background isolate reads only the cache (never network). `assets/parse_rules_fallback.json` seeds first run.

Example seed rules:
- kakao / CJ 알림톡: title `.*CJ대한통운.*`, body `운송장\s*(번호)?[:\s]*(?<invoice>\d{10,12})` + optional `상품명[:\s]*(?<product>.+)`
- SMS 한진: sender `^15880011`, body `(?<invoice>\d{10,14}).*(배송|출고)`
- Coupang app: package `com.coupang.mobile`, body `(?<product>.+?)\s*(상품이|배송)` with per-rule `status_hint`

## 4. Status Update Loop (pg_cron → Edge Function → Sweet Tracker)

```sql
select cron.schedule('track-poll', '*/30 * * * *',
  $$ select net.http_post(
       url := 'https://<ref>.supabase.co/functions/v1/track-poll',
       headers := jsonb_build_object('Authorization', 'Bearer ' || <service key from vault>)
     ) $$);
```

`track-poll/index.ts` (service_role client, batch ≤ 50/run):

1. Select pollable parcels — `status not in ('delivered','expired','invalid') and sweettracker_code is not null` — with **adaptive intervals**: `out_for_delivery` every run (30m), `in_transit`/`picked_up` if `last_polled_at < now()-'1h'`, `registered`/`preparing` if `< now()-'3h'`.
2. For each: `GET /api/v1/trackingInfo?t_key=...&t_code=<code>&t_invoice=<num>`.
3. Map Sweet Tracker `level` → status: 1→preparing, 2→picked_up, 3/4→in_transit, 5→out_for_delivery, 6→delivered. Insert `trackingDetails[]` into `tracking_events` (idempotent via unique constraint). Set `delivered_at` at level 6; `expected_arrival_date` = date of level-5 event, else heuristic `pickup_date + 2 days`.
4. Stop conditions: delivered/expired/invalid never selected again (partial index). "invalid tracking number" → `poll_fail_count++`; after 5 → `invalid`. `registered_at < now() - 30 days` and not delivered → `expired`.
5. State machine is **monotonic**: never move status backward.

Client freshness: Realtime subscription on `parcels` while foregrounded + pull-to-refresh; `flutter_local_notifications` fires on out_for_delivery/delivered transitions observed during WorkManager sync (no FCM needed).

## 5. Coupang Special Case

- Courier row: `('coupang_direct','쿠팡 로켓배송', NULL, '^cp:[0-9a-f]{40}$', true)` — poller skips entirely; status only from notifications.
- **Identity:** Coupang notifications carry no tracking number → synthesize stable key `'cp:' + sha1(normalizedProductName + '|' + orderDateBucket)`; normalize product name (strip "외 2건" etc); ±2-day fuzzy match against existing open coupang parcels before creating a new one.
- **Status keyword map** (stored as `parse_rules` rows with `status_hint`): `주문.*완료|결제` → registered; `상품.*준비|출고` → preparing; `배송.*시작|출발했` → out_for_delivery; `배송.*완료|문 앞` → delivered (sets `delivered_at` = capture time).
- Monotonic guard applies; open coupang parcels auto-expire after 7 days without a delivered event.

## 6. Flutter Screens

| Route | Screen | Notes |
|---|---|---|
| `/login` | 로그인 | Google 버튼 + 이메일/비밀번호. `signInWithIdToken` via `google_sign_in` (Gmail scope는 나중에 incremental 요청) |
| `/onboarding` | 권한 온보딩 | ① 알림 접근 허용 (설정 딥링크 + 스크린샷 가이드) ② 배터리 최적화 제외 ③ (선택) Gmail 연동. 권한 회수 감지 시 재표시 |
| `/` | 배송 목록 | 진행중/완료 탭. 카드: 상품명, 택배사, 상태 chip, 도착 예정 D-day. 수동 등록 FAB는 dev flavor만 |
| `/parcel/:id` | 배송 상세 | tracking_events 타임라인 + 수집 채널 badge |
| `/calendar` | 일별·월별 | table_calendar 월 그리드 + 날짜별 도착 건수 배지, 날짜 탭 시 해당일 목록 |
| `/settings` | 설정 | 채널 토글, 권한 상태, Gmail 연동/해제, 로그아웃, 계정 삭제 |
| `/debug/replay` | 알림 재생 | dev flavor 전용 (§10) |

Navigation: `go_router` + auth redirect. State: `flutter_riverpod`.

## 7. Key Packages

| Package | Why |
|---|---|
| `supabase_flutter` | Auth + Postgrest + Realtime |
| `flutter_notification_listener` | 알림 캡처; `notification_capture_service.dart` 뒤에 격리해 교체 가능하게 (fallback: `notification_listener_service`) |
| `google_sign_in` + `googleapis` + `extension_google_sign_in_as_googleapis_auth` | 로그인 + Gmail API |
| `flutter_riverpod`, `go_router` | 상태/라우팅 |
| `drift` | raw_captures / rule_cache / upload_queue |
| `table_calendar` | 월 캘린더 + ko locale |
| `workmanager` | Gmail 폴링, 큐 flush, 권한 헬스체크 |
| `flutter_secure_storage` | Gmail 토큰 |
| `flutter_local_notifications` | 배송출발/배달완료 알림 |
| `intl`, `freezed`, `json_serializable` | 포맷/모델 |
| (flag) `another_telephony` | 직접 SMS 읽기 (사이드로드 빌드 전용) |

## 8. Wave Breakdown (검증 기준 포함)

- **Wave 1 — Walking skeleton**: Supabase 프로젝트 + 0001_init.sql, Flutter scaffold, 로그인, 목록, 디버그 삽입. *검증*: 두 계정 RLS 교차 확인.
- **Wave 2 — Tracking loop**: sweettracker.ts, track-poll, 0003_cron.sql, 상태 머신, 상세 타임라인. *검증*: 실제 CJ 운송장으로 하루 동안 상태 진행 확인, 배달완료 후 폴링 중단 확인.
- **Wave 3 — Notification capture**: 0002_parse_rules.sql + seed, 리스너 서비스, 규칙 엔진, 검증기, 업서터+오프라인 큐, 재생 화면, 온보딩. *검증*: 실제 알림톡/SMS가 자동 등록, 2채널 → 1행 병합.
- **Wave 4 — Gmail + Coupang**: Gmail incremental scope + WorkManager, 쿠팡 매퍼. *검증*: 배송 메일 파싱, 재생 화면으로 쿠팡 시퀀스 registered→delivered.
- **Wave 5 — 캘린더 + 알림**: table_calendar, 배지, 로컬 알림, expected_arrival 휴리스틱. *검증*: 날짜 셀 정확성, explain으로 인덱스 사용 확인.
- **Wave 6 — Hardening**: 배터리 최적화 가이드, 리스너 감시(24h 무캡처 → 리바인드+경고 배너), 만료 정리 cron, 주간 heartbeat cron, 릴리즈 빌드. *검증*: 삼성 기기 48h 소크 테스트.

## 9. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| OEM(삼성)이 리스너 종료 | Foreground service + 배터리 최적화 제외 요청 + 삼성 절전 가이드 화면 + WorkManager 감시(24h 무캡처 시 리바인드/경고). 일단 운송장이 잡히면 상태는 서버 폴러가 책임 → 기기 의존 최소화 |
| 알림톡 텍스트 잘림 | `bigText`/`textLines` extras 파싱; 운송장번호 앵커 우선; 상품명은 optional (Sweet Tracker `itemName`이 첫 폴링에서 보강) |
| 운송장 오탐 | 택배사 키워드 동시 출현 필수 + 길이 regex + CJ check digit + 서버 검증(invalid 5회 → 숨김) |
| Supabase 7일 정지 | 30분 cron 자체가 활동 + 주간 heartbeat cron + 오프라인 큐로 데이터 유실 방지 |
| Sweet Tracker 한도/장애 | 배치 ≤50 + 적응 폴링 간격 + 5xx 시 백오프 |
| Play SMS 정책 | 직접 SMS 읽기는 컴파일 플래그, 기본 off |
| Gmail 토큰 만료 | WorkManager에서 silent 재인증; 실패 시 `gmail_connected=false` + 재연동 안내 |
| 알림톡 템플릿 변경 | OTA parse_rules + 미파싱 캡처 flag → 실제 텍스트 보고 규칙 추가 후 대시보드 배포 |

## 10. Verification Plan

- **재생 디버그 화면** (`/debug/replay`): raw_captures 목록(파싱 결과/거부 사유), "다시 파싱"(규칙 갱신 후 재실행), "가짜 알림 주입"(텍스트 붙여넣기로 시뮬레이션), 코퍼스 JSON export.
- **Unit tests** (`app/test/parser/`): 실제 캡처 export 기반 fixture 코퍼스로 규칙 엔진+검증기 회귀 테스트. check digit / 오탐 거부 케이스 포함.
- **Edge Function 로컬 테스트**: `supabase functions serve track-poll` + curl, 실운송장, 2회 실행 시 이벤트 중복 없음(멱등성).
- **실기기 게이트**: Wave 3+는 카카오톡 로그인된 실기기 필요. 실제 소액 주문 1건/택배사로 진짜 알림톡 템플릿을 코퍼스에 수집.
- **RLS 테스트**: 테스트 계정 2개 교차 조회 → 빈 결과 확인.
- **소크 테스트** (Wave 6): 삼성 기기 기본 배터리 설정으로 48h; 캡처 누락 0 또는 경고 배너 표시.
