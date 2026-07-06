# CheckShipping Agent Instructions

이 파일은 CheckShipping 프로젝트에서 Codex가 항상 따라야 하는 프로젝트 규칙이다.

## Mandatory Project Rules

- 코드 주석은 영어만 사용한다. UI 텍스트는 한국어로 작성한다.
- Supabase, 앱 로그인, 멀티 유저 기능은 사용하지 않는다. CheckShipping은 단일 사용자 로컬 저장 Android 앱이다.
- Android가 실제 타깃이고 Windows는 테스트 전용이다.
- Gmail, 기타 이메일, SNS, 쇼핑몰 등 외부 모니터링 소스의 계정/token/API key는 항상 로컬 secure storage에 암호화 저장한다.
- User 화면은 앱 로그인 화면이 아니라 모니터링 소스와 해당 소스의 인증 정보를 관리하는 화면이다.

## Keyboard-Safe Dialog Rule

모든 Flutter `AlertDialog`, modal, bottom sheet, form dialog는 키보드가 올라온 상태와 큰 시스템 글꼴을 기준으로 검증한다.

폼 필드가 2개 이상 있거나 텍스트 입력이 포함된 다이얼로그는 본문을 고정 `Column`만으로 만들지 않는다. 다음 구조를 기본으로 사용한다.

```dart
final media = MediaQuery.of(context);
final maxContentHeight = (media.size.height - media.viewInsets.bottom - 220)
    .clamp(220.0, 420.0);

return AlertDialog(
  insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
  content: ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxContentHeight),
    child: SingleChildScrollView(
      child: Form(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // form fields
          ],
        ),
      ),
    ),
  ),
);
```

작업 완료 전에는 작은 화면, 큰 시스템 글꼴, 키보드 표시 상태에서 overflow가 없는지 반드시 확인한다.

## Memory-Bank

세션 시작 시 `memory-bank/active-context.md`와 `memory-bank/STATE.md`를 먼저 확인한다.
프로젝트 전반에 반복 적용할 규칙은 `memory-bank/knowledge/RULES.md`에도 남긴다.
