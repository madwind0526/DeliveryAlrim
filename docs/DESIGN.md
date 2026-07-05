# CheckShipping Design

## 0. Direction Change

2026-07-05 기준으로 프로젝트 방향을 다음과 같이 변경한다.

1. **Supabase는 사용하지 않는다.**
2. **앱 로그인은 없앤다.** 멀티 유저를 지원하지 않고, 사용자는 한 명으로 가정한다.
3. 모든 자료는 로컬에 저장한다.
4. Android 앱으로 만든다. iOS는 나중에 확장한다.
5. Windows는 개발/테스트 목적이다. 먼저 Windows에서 테스트하고 문제가 없으면 Android로 확장한다.
6. User 메뉴는 앱 계정 로그인이 아니라, 모니터링할 이메일/SNS/외부 서비스 계정 설정을 담당한다.
7. 외부 계정 로그인 정보와 API 키는 로컬 보안 저장소에 항상 암호화해서 저장한다.
8. Google Play Store 배포는 현재 목표가 아니다. 개인용/sideload Android 앱 기준으로 권한과 자동화 범위를 판단한다.

기존 Supabase/RLS/Edge Function/pg_cron 설계는 폐기한다. 이미 작성된 Supabase 관련 파일은 이후 정리 대상이다.

## 1. Product Shape

CheckShipping은 온라인 쇼핑 배송을 자동으로 모아 보여주는 개인용 Android 앱이다.

핵심 목표:

- 내가 받을 배송을 한 화면에서 확인한다.
- 카카오 알림톡, SMS 앱 알림, 쇼핑몰 앱 알림, 이메일, SNS 등에서 배송 정보를 자동 수집한다.
- 업체별, 일별, 월별로 배송 현황을 확인한다.
- 서버 계정 없이 로컬에서만 동작한다.
- 외부 서비스 로그인 정보가 필요한 경우에도 내 기기 안에 항상 암호화 저장한다.

## 2. Runtime Architecture

```
Android notification listener
  → NotificationInbox (trigger + hint)
  → ChannelClassifier
  → Channel-specific content fetcher
  → RuleEngine
  → ParcelRepository (local drift SQLite)
  → Local tracking poller
  → Flutter UI
```

Windows 테스트 모드:

```
fixture text / debug insert
  → same RuleEngine
  → same local repository
  → same Flutter UI
```

설계 원칙:

- 서버는 없다.
- 알림은 배송 정보를 완성하는 원천이 아니라, **무엇을 더 읽어야 하는지 알려주는 트리거/힌트**다.
- 배송 관련 알림이 올라오면 즉시 원본을 저장하고, 배송 후보인지 판정한다.
- 알림 내용만으로 DB 생성이 가능한 경우만 즉시 저장한다.
- 대부분의 채널은 알림 이후에 채널별 본문 획득 작업을 수행해야 한다.
- 원본 캡처 텍스트는 로컬에만 저장한다.
- 백그라운드 작업은 Android 로컬 작업으로 처리한다.
- Windows에서는 Android 전용 기능을 fixture 또는 fake implementation으로 대체한다.
- 인터페이스는 유지하되 구현체는 local-first로 둔다.

채널별 현실적인 접근 방식:

| 채널 | 알림 역할 | 본문 획득 방식 | 신뢰도 |
|------|----------|----------------|--------|
| 이메일 | 새 배송 메일 도착 감지, 보낸 사람/제목/시간 힌트 | Gmail API, IMAP, 또는 제공자 공식 API로 실제 메일 본문 읽기 | 높음 |
| SMS/문자 | 배송 문자 도착 감지 | 기본 SMS 앱이 되거나 개인 sideload 빌드에서 직접 SMS 읽기 검토. 불가하면 알림 텍스트만 사용 | 중간 |
| 카카오톡/텔레그램/WhatsApp | 배송 알림톡/봇 메시지 도착 감지 | 1차는 알림 텍스트. 부족하면 사용자가 해당 알림/대화를 열었을 때 Accessibility/화면 텍스트 캡처를 보조 옵션으로 검토 | 낮음~중간 |
| 쇼핑몰/택배 앱 | 배송 상태 변경 감지 | 앱 deep link, 공식 API, 공유 기능, 접근성 기반 화면 텍스트 캡처 순으로 검토 | 앱별 상이 |

결론: 알림만으로는 완전한 배송 트래커를 만들 수 없다. 알림은 "지금 이 채널을 확인해야 한다"는 신호로 쓰고, 실제 배송 DB는 채널별 본문 획득 결과를 기준으로 만든다.

카카오톡 특정 채널(CJ대한통운 등)의 경우:

- Kakao Developers의 카카오톡 채널/메시지 API는 사용자의 카카오톡 앱 안에 있는 특정 채널 대화 내용을 읽는 API가 아니다.
- 공식 API로 "내 휴대폰의 CJ대한통운 채널 대화 내역을 조회"하는 안정 경로는 현재 설계 기준에서 없음으로 본다.
- Android 앱 샌드박스 때문에 일반 앱은 카카오톡 내부 DB를 직접 열어 읽을 수 없다.
- 가능한 현실 경로는 NotificationListener + AccessibilityService 조합이다.
- 이 방식은 사용자가 명시적으로 접근성 권한을 켜야 하며, 카카오톡 화면에 실제로 표시되는 텍스트를 읽고 필요하면 스크롤하며 수집한다.
- 따라서 개인용/sideload 앱의 핵심 기능으로는 검토 가능하지만, Play Store 배포용 안정 기능이나 공식 연동으로 보기는 어렵다.
- 이 프로젝트는 카카오톡 배송 채널 수집 가능성을 Wave 5의 Android PoC 게이트로 둔다. PoC에서 CJ대한통운 채널의 최근 배송 메시지를 접근성 기반으로 안정 추출하지 못하면 프로젝트 범위를 재검토한다.
- Samsung Card channel PoC: Android `uiautomator dump`에서 카카오톡 알림톡 말풍선 본문이 `com.kakao.talk:id/alimtalk_title` TextView의 `text` 속성으로 노출됨을 확인했다. 주문번호, 상품명, 금액, 주문일, 상세 URL을 자동 추출할 수 있었다.
- CJ대한통운 channel PoC: Android `uiautomator dump`에서 CJ대한통운 알림톡 본문도 동일한 `com.kakao.talk:id/alimtalk_title` TextView의 `text` 속성으로 노출됨을 확인했다. 운송장번호, 보내는곳, 배송사원 존재 여부, 배송완료 상태를 자동 추출했다. 이 결과 기준으로 프로젝트는 진행 가능하다.

## 3. Local Data Model

로컬 SQLite(drift)에 저장할 주요 데이터:

| 테이블 | 역할 |
|--------|------|
| `parcels` | 배송 단위. 업체, 운송장번호, 상태, 상품명, 쇼핑몰, 예상 도착일, 완료일 |
| `tracking_events` | 배송 상세 타임라인 |
| `raw_captures` | 알림/메일/SNS 원본 캡처 및 파싱 결과 |
| `notification_inbox` | Android 알림 리스너가 받은 모든 후보 알림의 원본/패키지/시간 |
| `parse_rules` | 로컬 파싱 규칙 |
| `monitor_accounts` | 모니터링할 이메일/SNS/외부 서비스 계정 메타데이터 |
| `monitor_sources` | 어떤 앱/채널/패키지를 감시할지에 대한 설정 |
| `app_settings` | 앱 모드, 필터 기본값, 권한 상태, UI 설정 |

민감 정보 저장:

- 이메일/SNS/API 로그인 토큰, 비밀번호, API 키는 SQLite 일반 테이블에 저장하지 않는다.
- `flutter_secure_storage` 또는 Android Keystore 기반 보안 저장소에 저장한다.
- SQLite에는 보안 저장소 key alias, 계정 표시명, 활성화 여부 등 비민감 메타데이터만 둔다.

## 4. User And Accounts

앱 자체 로그인:

- 없음.
- 앱 시작 시 바로 메인 화면으로 진입한다.
- 멀티 유저 전환, 로그아웃, 서버 계정 삭제는 만들지 않는다.

User 메뉴:

- 모니터링할 이메일 계정 추가/수정/삭제
- SNS 또는 쇼핑몰 계정 추가/수정/삭제
- 모니터링할 앱 패키지 선택: Gmail, 카카오톡, 텔레그램, WhatsApp, SMS 앱, 쇼핑몰 앱 등
- 각 계정의 로그인 입력란 또는 연결 상태 표시
- 계정별 모니터링 on/off
- 채널별 접근 방식 표시: 알림만 사용, 공식 API 사용, IMAP 사용, 직접 읽기 사용 안 함
- 마지막 동기화 시간, 실패 상태, 재시도 버튼
- 저장된 인증 정보 초기화

User 메뉴의 "로그인"은 외부 서비스를 읽기 위한 로그인이지, 앱 사용자를 인증하기 위한 로그인은 아니다.
다만 SNS 로그인 정보가 있다고 해서 앱이 모든 SNS 대화 내용을 직접 읽을 수 있는 것은 아니다. 메신저류는 기본적으로 알림에 노출된 배송 관련 텍스트를 수집하고, 공식 API가 있는 채널만 별도 어댑터로 확장한다.

### Source profile model

로그인 관리와 모니터링 관리는 별도 화면으로 쪼개지 않고, User 메뉴의 "소스 프로필" 단위로 합친다.
Google Play Store 배포를 전제로 하지 않으므로, 자동 로그인이 되어 있는 앱도 필요한 경우 CheckShipping 안에 별도 로컬 인증 정보를 저장한다. 저장 여부를 사용자가 선택하는 구조로 만들지 않고, 모든 비밀값은 항상 secure storage에 저장한다.

소스 프로필 하나는 다음 정보를 가진다.

| 항목 | 예시 | 저장 위치 |
|------|------|-----------|
| 소스 종류 | Gmail, SMS, 카카오톡, 텔레그램 | SQLite |
| 표시 이름 | Gmail, 개인 Gmail, 카카오톡 CJ대한통운 | SQLite |
| 모니터링 여부 | 켬/끔 | SQLite |
| 접근 방식 | Gmail API, IMAP, Android SMS, 알림, 접근성 | SQLite |
| 인증 상태 | 연결됨, 필요함, 만료됨 | SQLite |
| 인증 비밀값 | OAuth refresh token, IMAP app password, API key | Android Keystore/secure storage |
| 마지막 수집 결과 | 성공, 실패 이유, 마지막 시간 | SQLite |
| 테스트 결과 | 마지막 자동 테스트 성공/실패 | SQLite |

채널별 권장안:

- Gmail: OAuth/Gmail API를 1순위로 둔다. 개인 테스트와 간단한 계정은 IMAP app password fallback을 둘 수 있다. 필요한 token/password는 secure storage에 저장한다.
- 다른 이메일: IMAP/POP/OAuth 계정 정보를 소스 프로필로 관리하고 secure storage에 저장한다.
- SMS: 로그인은 없다. Android SMS 읽기 권한 또는 기본 SMS 앱 전환이 필요하므로, 개인 sideload 빌드에서 먼저 검증한다.
- 카카오톡: 카카오톡 앱의 자동 로그인 상태를 직접 빌려 쓸 수 없으므로, 필요한 경우 사용자 입력 인증 정보를 secure storage에 저장할 수 있게 둔다. 실제 메시지 수집은 접근성 권한과 알림/화면 텍스트 캡처를 기본 경로로 사용한다.
- Telegram/WhatsApp: 계정/token/API key가 필요한 adapter는 소스 프로필로 관리하고 secure storage에 저장한다. 공식 API가 없으면 알림/접근성 기반 수집으로 처리한다.

자동 테스트는 소스 프로필과 같은 파이프라인을 통과해야 한다. 현재 구현은 Gmail/SMS 샘플을 앱 내부에서 `RawCapture`로 생성해 `RuleEngine → ParcelRepository`까지 자동 주입한다. 이후 실제 Gmail 전송/수신 또는 Android SMS 전송/수신이 붙더라도 테스트 결과는 같은 DB 등록 경로로 검증한다.

## 5. UI Layout

기본 정보 구조는 왼쪽 메뉴 + 오른쪽 메인 윈도우다.

### Left Menu

상단 주요 메뉴:

- **업체별**
- **일별**
- **월별**

하단 보조 메뉴:

- **Filter**
- **Setting**
- **User**

### Main Window

오른쪽 메인 영역은 선택한 메뉴에 따라 바뀐다.

업체별:

- 메뉴 선택 시 스크롤 가능한 팝업/패널을 띄운다.
- 업체 목록에서 하나 또는 여러 업체를 선택할 수 있다.
- 선택 결과에 따라 오른쪽 메인 영역에 배송 목록을 표시한다.

일별:

- 날짜 선택 또는 오늘 기준 배송 현황을 표시한다.
- 해당 날짜 예상 도착, 배송출발, 배달완료 항목을 구분한다.

월별:

- 월 캘린더를 표시한다.
- 날짜별 배송 건수 배지 또는 상태 표시를 제공한다.
- 날짜 선택 시 해당 날짜의 배송 목록을 보여준다.

Filter:

- 업체 선택
- 날짜 기간 선택
- 배송 상태 선택
- 출처 채널 선택
- 적용/초기화

Setting:

- 모드 선택
- 알림/백그라운드/표시 관련 설정
- 세부 항목은 추후 결정한다.

User:

- 이메일, SNS, 쇼핑몰 등 모니터링 계정 설정
- 로그인 입력/연동/해제
- 로그인 정보는 항상 암호화 저장 안내 표시

Android 화면에서는 같은 정보 구조를 드로어, 내비게이션 레일, 바텀 내비게이션 중 적절한 형태로 재배치한다.

## 6. Capture And Parsing

### Trigger-first pipeline

모든 입력은 먼저 Android 알림으로 감지하지만, 알림 텍스트만을 최종 데이터로 보지 않는다.

1. 알림 리스너가 새 알림을 받는다.
2. 패키지명, 앱 이름, 제목, 본문, bigText/textLines, 알림 시간, deep link 후보를 저장한다.
3. `monitor_sources`에 등록된 앱인지 확인한다.
4. 배송 키워드와 negative keyword를 기준으로 배송 후보를 빠르게 분류한다.
5. 배송 후보면 `raw_captures`에 저장한다.
6. 알림만으로 `courier_code + tracking_number` 또는 `direct_delivery_key`가 충분히 확정되는지 판단한다.
7. 충분하면 규칙 엔진 결과로 `parcel`을 생성/병합한다.
8. 부족하면 채널별 본문 획득 작업을 예약하고, 알림은 pending capture로 남긴다.
9. 본문 획득이 완료되면 규칙 엔진을 다시 실행해 배송 DB를 만든다.

### Content acquisition tiers

본문 획득은 아래 우선순위로 시도한다.

1. **공식 API**: Gmail API, 쇼핑몰/택배사 API, Telegram Bot API처럼 문서화된 접근 경로.
2. **표준 프로토콜**: IMAP 등 사용자가 명시적으로 입력한 계정으로 접근 가능한 방식.
3. **사용자 주도 공유/내보내기**: 메일/메신저/쇼핑몰 앱에서 공유하기로 CheckShipping에 전달.
4. **접근성 기반 보조 캡처**: 사용자가 직접 알림이나 대화를 열면 현재 화면의 텍스트를 읽어 배송 정보를 추출.
5. **알림만 사용**: 위 방법이 없거나 실패한 경우. 이때는 불완전 후보로 저장하고 사용자 확인을 요구한다.

접근성 기반 보조 캡처는 강력하지만 민감하고 앱별 UI 변화에 약하다. Play 배포용 기본 기능이 아니라 개인용/명시적 동의 기반 보조 옵션으로 둔다.

### Channel content fetchers

이메일:

- Gmail 알림이 배송 후보로 감지되면 User 메뉴에 등록된 Gmail 계정으로 Gmail API를 조회한다.
- Gmail API를 쓸 수 없는 계정은 IMAP/app password 방식을 검토한다.
- 알림의 보낸 사람, 제목, 시간대와 메일 검색 결과를 매칭해 실제 메일 본문을 읽는다.
- 메일 본문에서 운송장번호, 업체, 상품명, 쇼핑몰을 재추출한다.

SMS/문자:

- 알림만으로 충분하지 않은 경우가 많으므로 직접 SMS 읽기 전략을 별도로 둔다.
- Play 배포를 염두에 두면 SMS 권한은 제약이 크다.
- 개인용 sideload 빌드에서는 기본 SMS 앱 전환 또는 직접 SMS 읽기 플래그를 검토할 수 있다.
- 직접 읽기가 불가능하면 알림 텍스트 + 사용자 확인으로 처리한다.

SNS/메신저:

- 카카오톡, 텔레그램, WhatsApp 등은 알림을 트리거로 사용한다.
- 일반 앱 권한으로 각 앱의 내부 메시지 DB를 직접 열어 읽는 설계는 채택하지 않는다.
- 공식 API가 있는 채널은 전용 fetcher를 만든다.
- 공식 API가 없고 알림만으로 부족하면, 사용자가 대화를 열었을 때 접근성 기반 화면 텍스트 캡처를 보조 옵션으로 검토한다.
- User 메뉴의 SNS 항목은 감시할 앱 선택, 알림 권한 상태, 계정 표시명, 공식 연동/접근성 보조 캡처 사용 여부를 관리한다.
- 카카오톡 특정 채널은 공식 읽기 API가 없으므로 `KakaoAccessibilityFetcher` PoC를 먼저 만든다. 대상 채널명, 메시지 시간, 말풍선 텍스트, 운송장 후보를 화면 노드에서 읽을 수 있는지 실기기에서 검증한다.
- 1차 구현은 `com.kakao.talk:id/alimtalk_title` 텍스트 노드를 우선 읽는다. 삼성카드와 CJ대한통운 알림톡 모두 이 노드에서 본문 추출을 확인했다. 다른 말풍선 타입은 `message`, `content-desc`, visible text를 fallback으로 수집한다.

쇼핑몰/택배 앱:

- 앱 알림에서 배송 상태와 상품명을 추출한다.
- 알림에 deep link가 있으면 저장한다.
- 공식 API나 안정적인 공유/내보내기 경로가 있으면 그 경로를 우선한다.
- 사용자가 앱 화면을 열었을 때 접근성 기반 화면 텍스트 캡처로 배송 상세를 보강하는 옵션을 검토한다.
- 자동으로 다른 앱 UI를 조작해 스크래핑하는 방식은 fragile path로 분류하고 기본 경로로 의존하지 않는다.

### User-managed monitoring sources

User 메뉴에서 관리할 항목:

- 모니터링할 이메일 계정
- 이메일 접근 방식: Gmail API, IMAP, 사용 안 함
- 모니터링할 SNS/메신저 앱
- 모니터링할 SMS 앱
- 모니터링할 쇼핑몰/택배 앱
- 채널별 본문 획득 방식: 공식 API, IMAP, 공유, 접근성 보조 캡처, 알림만
- 계정별 인증 정보 입력 및 삭제
- 보안 저장소 저장 상태
- 마지막 알림 감지 시간
- 마지막 보강 작업 결과

오탐 방지:

- 운송장번호처럼 보이는 숫자만으로 배송을 생성하지 않는다.
- 택배사/배송 키워드와 함께 등장할 때만 후보로 인정한다.
- 은행 OTP, 광고, 주문번호는 negative fixture로 유지한다.

## 7. Tracking Refresh

Supabase cron 대신 로컬 백그라운드 작업을 사용한다.

후보:

- `workmanager`
- Android 네이티브 WorkManager bridge
- 앱 foreground 상태에서 수동 새로고침

정책:

- 배송 완료/만료/번호오류는 조회하지 않는다.
- 배송중/배송출발은 더 자주 확인한다.
- 등록됨/상품준비는 더 느리게 확인한다.
- 네트워크 실패 시 다음 주기에 재시도한다.
- API 키는 User 또는 Setting 영역에서 입력하고 보안 저장소에 암호화 저장한다.

## 8. Development Flow

1. Windows에서 UI와 로컬 DB, parser fixture를 먼저 검증한다.
2. `flutter analyze`와 `flutter test`를 통과시킨다.
3. Windows fixture로 업체별/일별/월별/필터/User 화면을 검증한다.
4. Android 실기기에서 알림 리스너와 보안 저장소를 연결한다.
5. 실제 알림을 먼저 수집하고, 알림만으로 부족한 이메일은 Gmail API/IMAP 보강을 연결한다.
6. 카카오톡/SMS/쇼핑몰/택배 앱 알림 샘플을 fixture에 추가한다.
7. SNS는 알림 기반 수집을 기본으로 검증하고, 공식 API가 있는 경우에만 보강한다.
8. 릴리즈 APK를 만든다.

## 9. Wave Roadmap

| Wave | 내용 | 환경 |
|------|------|------|
| 0 | 프로젝트 초기화 | 완료 |
| 1 | Windows+Android Flutter 골격, 로컬 저장소, 목록 UI | 완료 |
| 2 | 파싱 엔진, fixture 코퍼스, 주입 디버그 화면 | 완료 |
| 3 | 상세 타임라인, 일별/월별 캘린더, 도착일 휴리스틱 | 완료 |
| 4 | Supabase 제거, 로그인 제거, 단일 사용자 로컬 모드, 좌측 메뉴 UI 재설계 | Windows |
| 5 | Android 알림 리스너, User 계정 모니터링, 보안 저장소 | Android |
| 6 | 백그라운드 조회, 안정화, 배터리 최적화, 릴리즈 APK | Android |

## 10. Verification Gates

Windows gate:

- `flutter analyze` 통과
- `flutter test` 통과
- fixture 삽입 후 업체별/일별/월별 화면 표시
- 필터 조건 적용/초기화 확인
- User 화면에서 계정 메타데이터 저장 동작 확인

Android gate:

- 알림 리스너 권한 안내 및 상태 표시
- 실제 알림 캡처
- 배송 관련 알림 후보 분류
- 알림 원본의 로컬 저장
- 이메일 알림 감지 후 공식 API/IMAP 보강
- 카카오톡 CJ대한통운 채널 접근성 PoC: 채널 화면 진입, 최근 메시지 텍스트 추출, 운송장/상품/상태 파싱
- SNS/메신저는 공식 API 또는 접근성 PoC가 성공한 채널만 자동 수집 대상으로 승격
- 보안 저장소 저장/삭제 확인
- 백그라운드 작업 재시작 확인
- 릴리즈 APK 설치 확인

## 11. Removed Scope

다음은 현재 범위에서 제거한다.

- Supabase Auth
- Supabase Postgres
- RLS 정책
- Edge Function
- pg_cron/pg_net
- 서버 Realtime
- 서버 계정 기반 멀티 유저
- iOS 구현
