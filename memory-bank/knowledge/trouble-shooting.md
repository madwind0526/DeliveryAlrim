# Trouble Shooting

> 발생했던 버그와 해결 방법. 같은 문제를 두 번 겪지 않기 위한 기록.

## Riverpod 3.x: AsyncValue.valueOrNull 제거됨

### 증상

`flutter analyze` 에러: `The getter 'valueOrNull' isn't defined for the type 'AsyncValue<...>'`

### 원인

Riverpod 3.0에서 `valueOrNull`이 제거되고 `.value`가 null-safe 접근으로 통합됨 (2.x의 `.value`는 값 없으면 throw였음).

### 해결

`ref.read(provider).valueOrNull` → `ref.read(provider).value`

## flutter_localizations 추가 시 intl 버전 충돌

### 증상

`flutter pub add flutter_localizations --sdk=flutter` 실패: `version solving failed` (intl 직접 의존성과 충돌)

### 원인

flutter_localizations는 SDK가 intl 버전을 고정하는데, `flutter pub add intl`로 넣은 캐럿 제약(^0.20.3)과 충돌.

### 해결

pubspec.yaml에서 `intl: any`로 변경해 SDK 핀을 따라가게 한다.

```yaml
flutter_localizations:
  sdk: flutter
# Pinned by flutter_localizations; keep `any` to follow the SDK.
intl: any
```

## drift 이벤트 정렬 테스트에서 동일 타임스탬프 함정

### 증상

`orderBy desc(eventTime)` 스트림 테스트에서 기대 순서와 다른 행이 first로 나옴.

### 원인

테스트 헬퍼가 모든 행에 같은 `DateTime`을 넣어 정렬 키가 동률 → SQLite가 임의 순서 반환.

### 해결

테스트 데이터에 시간 오프셋을 명시적으로 다르게 부여한다 (`DateTime(2026,7,4,9)`, `...,10)`, `...,11)`).

## table_calendar 한국어 로케일

### 증상/주의

`locale: 'ko_KR'` 지정 시 intl 데이터가 'ko'만 초기화되어 있으면 위험.

### 해결

`initializeDateFormatting('ko')` + `TableCalendar(locale: 'ko')`로 통일하면 안전. intl fallback은 'ko_KR'→'ko' 방향만 동작한다.

## Windows 카카오톡 UI Automation 말풍선 미노출

### 증상

Windows 카카오톡 채팅창을 UI Automation/Win32 child window text로 조회해도 말풍선 본문이 나오지 않는다. 현재 열린 채팅창은 `EVA_VH_ListControl_Dblclk` 커스텀 컨트롤로 보였고, 접근성에서 읽힌 텍스트는 입력창 placeholder뿐이었다.

### 원인

PC 카카오톡 말풍선 목록이 표준 TextView/Document 아이템으로 노출되지 않는 커스텀 컨트롤로 렌더링된다.

### 해결

Windows에서는 채팅 영역 `Ctrl+A` / `Ctrl+C` 복사를 fixture 수집 fallback으로만 사용한다. 실제 Android 구현은 AccessibilityService에서 카카오톡 말풍선 노드를 직접 읽는다.

## PowerShell adb exec-out PNG 리다이렉션 깨짐

### 증상

`adb exec-out screencap -p > user_sources.png`로 만든 파일을 이미지 뷰어가 읽지 못한다.

### 원인

Windows PowerShell 리다이렉션이 바이너리 PNG 스트림을 텍스트 출력처럼 다루며 파일을 손상시킬 수 있다.

### 해결

기기 안에 먼저 저장한 뒤 `adb pull`로 가져온다.

```powershell
adb shell screencap -p /sdcard/user_sources.png
adb pull /sdcard/user_sources.png user_sources.png
```

<!-- 예시 형식:

## [문제 제목]

### 증상

[어떤 에러 또는 현상이 나타났나]

### 원인

[왜 발생했나]

### 해결

[어떻게 고쳤나 — 코드/명령어 포함]

-->
