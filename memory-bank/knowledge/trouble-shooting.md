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

<!-- 예시 형식:

## [문제 제목]

### 증상

[어떤 에러 또는 현상이 나타났나]

### 원인

[왜 발생했나]

### 해결

[어떻게 고쳤나 — 코드/명령어 포함]

-->
