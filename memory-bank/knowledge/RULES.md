# Rules

> 이 프로젝트의 규칙과 컨벤션. 모든 sub-agent가 반드시 따라야 함.

## G-01: 코드 주석은 영어만 사용 (MANDATORY)

**규칙:** 모든 코드 주석(`//`, `/* */`, `///`)은 영어로 작성. 한글 주석 금지.
**이유:** 소스 파일 내 한글은 인코딩 문제 및 빌드 오류를 유발할 수 있음.
**적용 시점:** 코드 작성 또는 수정 시 항상. UI 텍스트(사용자에게 보이는 문자열)는 한국어 유지.

## 쿠팡 합성 키는 주문번호 우선

**규칙:** `cp:sha1('order:<주문번호>')`를 우선 사용, 주문번호 없을 때만 `product:<정규화 상품명>|<날짜버킷>`. 
**이유:** 실제 쿠팡 알림에 주문번호가 포함됨을 확인 (2026-07 실샘플). 같은 주문의 배송시작/완료 알림이 자동으로 한 건에 병합된다. DESIGN §5의 상품명+날짜 방식보다 안정적.
**적용 시점:** 쿠팡 관련 파싱/병합 로직 수정 시.

## CJ 운송장 check-digit 구현 금지

**규칙:** CJ 운송장 검증은 길이 regex + 택배사 키워드 동시출현만 사용. check-digit(앞자리 %7) 알고리즘을 구현하지 말 것.
**이유:** 실제 배달완료된 운송장 300211029394가 알려진 %7 알고리즘과 불일치 — 미검증 알고리즘은 정상 운송장을 거부하는 오류를 만든다.
**적용 시점:** tracking number 검증 로직 수정 시.

## Dart 3.12 lint: 다중 언더스코어 금지

**규칙:** 미사용 파라미터가 여러 개면 `(_, __)`가 아니라 `(_, _)` (와일드카드 변수 사용).
**이유:** Dart 3.7+ 와일드카드 변수 도입으로 `unnecessary_underscores` lint 발동.
**적용 시점:** 콜백/빌더 시그니처 작성 시.

## 플랫폼 의존 기능은 인터페이스 뒤에 격리

**규칙:** `CaptureSource`, `ParcelRepository`, `AuthRepository` 인터페이스를 통해서만 플랫폼/백엔드 기능에 접근. 화면 코드는 구현체를 직접 import하지 않는다.
**이유:** PC-first 개발 전략 — Windows에서 가짜 구현으로 검증 후 Android/Supabase 구현으로 교체 (docs/DESIGN.md §0).
**적용 시점:** 새 플랫폼 의존 기능(알림, SMS, Gmail, 서버) 추가 시.

## Supabase/Auth 없이 로컬 단일 사용자 앱

**규칙:** Supabase, 서버 계정, 앱 로그인, 멀티 유저 기능을 만들지 않는다. 모든 배송 데이터와 설정은 로컬 저장소에 둔다.
**이유:** 사용자가 개인용 Android 로컬 앱으로 방향을 변경했다. 외부 동기화보다 개인정보 보호와 단순한 로컬 운용을 우선한다.
**적용 시점:** 저장소, 라우팅, 인증, 설정, 배포 범위 수정 시.

## 알림은 trigger + hint로 취급

**규칙:** Android 알림은 완성 데이터가 아니라 본문 획득 작업을 시작하는 trigger + hint로 저장한다. 실제 배송 DB는 공식 API, IMAP, 공유/내보내기, 접근성 보조 캡처, 알림 텍스트 순서로 확보한 본문을 기준으로 만든다.
**이유:** 알림만으로는 운송장/상품/상태가 부족한 경우가 많다. 채널별 본문 획득을 분리해야 배송 DB 품질을 유지할 수 있다.
**적용 시점:** NotificationListener, capture pipeline, parser, pending capture 상태 설계 시.

## User 메뉴는 모니터링 소스 관리 전용

**규칙:** User 메뉴는 앱 로그인용이 아니라 이메일/SNS/앱 패키지 모니터링 설정과 외부 계정 인증 정보 관리용이다. 민감 정보는 보안 저장소에 저장한다.
**이유:** 앱 자체는 단일 사용자 로컬 모드이고, User 메뉴의 로그인은 Gmail/IMAP/SNS 등 외부 소스 접근 설정을 뜻한다.
**적용 시점:** User 화면, settings schema, secure storage 연동 시.

## 모니터링과 인증은 소스 프로필 단위로 묶기

**규칙:** Gmail, SMS, 카카오톡 같은 소스마다 하나의 소스 프로필을 두고, 모니터링 on/off, 접근 방식, 인증 상태, 마지막 수집/테스트 결과를 함께 관리한다. OAuth token, app password, API key 등 비밀값은 SQLite에 저장하지 않고 Android Keystore/secure storage에 둔다.
**이유:** 사용자는 "로그인 관리"와 "모니터링 관리"를 별도 개념으로 느끼지 않는다. 소스별로 연결 상태와 수집 상태를 함께 봐야 설정 실수가 줄어든다.
**적용 시점:** Gmail/IMAP/SMS/Telegram/WhatsApp adapter, User 화면, monitor source schema 구현 시.

## 모니터링 앱 로그인 정보는 항상 암호화 저장

**규칙:** Google Play Store 배포를 현재 목표로 보지 않는다. Gmail, 다른 이메일, SNS, 쇼핑몰 등 모니터링 adapter에 필요한 로그인/token/API key는 사용자가 선택하는 옵션 없이 항상 로컬 secure storage에 저장한다. 암호화 저장 on/off 체크박스는 만들지 않는다.
**이유:** 개인용/sideload 앱에서는 앱 내부 로그인 정보를 로컬에서 관리하는 편이 자동 수집에 유리하고, 비밀값 저장 정책은 사용자가 실수로 끌 수 있는 옵션이 아니어야 한다.
**적용 시점:** User 화면, credential store, Gmail/IMAP/SNS adapter 구현 시.

## 카카오톡 채널은 접근성 기반으로 수집

**규칙:** 카카오톡 특정 채널 대화 읽기는 공식 API가 아니라 NotificationListenerService + AccessibilityService 조합으로 구현한다. 카카오톡 내부 DB 직접 접근은 사용하지 않는다.
**이유:** 공식 API로 사용자의 카카오톡 채널 대화 내역을 읽는 안정 경로가 없고, Android app sandbox 때문에 일반 앱은 카카오톡 private DB를 읽을 수 없다. 실기기 PoC에서 알림톡 본문 노드 추출은 성공했다.
**적용 시점:** Kakao capture, Android accessibility service, channel fetcher 구현 시.

## Flutter 입력 다이얼로그는 키보드 안전 구조 필수

**규칙:** `AlertDialog`, modal, bottom sheet, form dialog에 텍스트 입력이 있거나 폼 필드가 2개 이상이면 본문을 `ConstrainedBox` + `SingleChildScrollView`로 감싼다. 높이는 `MediaQuery.viewInsets.bottom`을 반영해 키보드가 올라온 상태에서도 overflow가 나지 않게 제한한다.
**이유:** Android 실기기에서 키보드와 큰 시스템 글꼴이 함께 적용되면 고정 `Column(mainAxisSize: min)` 다이얼로그가 반복적으로 `BOTTOM OVERFLOWED` 오류를 만든다.
**적용 시점:** Flutter 입력 다이얼로그, 계정/비밀번호 입력, 소스 추가/수정, 필터/설정 입력 UI를 만들거나 수정할 때 항상.

<!-- 예시 형식:

## [규칙 이름]

**규칙:** [한 줄 요약]
**이유:** [왜 이 규칙이 필요한가]
**적용 시점:** [언제 이 규칙이 발동되나]

-->
