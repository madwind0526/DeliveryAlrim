# 알림 테스트 발송 도구 (test_notify)

CheckShipping 앱과는 별개의 로컬 개발용 스크립트입니다. 실제 이메일/SMS를 발송해서
폰에 배송 알림이 정상적으로 뜨는지 눈으로 확인하는 용도입니다.

> **주의**: 이 도구는 앱 밖에서 실제 이메일/SMS를 발송합니다. 배송알리미의 알림
> 접근 권한이 켜져 있고 Gmail/Naver/SMS 모니터링 소스가 활성화되어 있어야 앱이
> 해당 알림을 배송 후보로 수집할 수 있습니다.

## 요구 사항

- Python 3.10+ (이미 설치되어 있으면 됨, 이 저장소에서 확인된 버전: 3.14)
- 추가 pip 설치 불필요 — 표준 라이브러리만 사용합니다.

## 1. 설정 파일 준비

```bash
cd tools/test_notify
cp example.env .env
```

`.env`는 저장소 루트 `.gitignore`에 이미 포함되어 있어(`.env`, `.env.*` 패턴)
커밋되지 않습니다. `example.env`만 저장소에 커밋된 템플릿입니다.

## 2. 이메일 발송 설정 (Gmail SMTP)

발신은 Gmail SMTP 릴레이 하나로 통일했습니다 — Gmail 계정으로 Naver 수신 주소로도
보낼 수 있어서, 수신 계정마다 별도 발신 계정을 만들 필요가 없습니다.

1. 발신용 Gmail 계정에서 **2단계 인증**을 켭니다 (설정 안 하면 앱 비밀번호 메뉴 자체가 없음).
2. 구글 계정 관리 > 보안 > "앱 비밀번호"에서 16자리 앱 비밀번호를 생성합니다.
3. `.env`에 다음을 채웁니다.
   - `SENDER_GMAIL_ADDRESS`: 발신용 Gmail 주소
   - `SENDER_GMAIL_APP_PASSWORD`: 방금 만든 16자리 앱 비밀번호 (공백 제거)
   - `RECIPIENT_GMAIL`: 앱에서 모니터링할 수신용 Gmail 주소
   - `RECIPIENT_NAVER`: 앱에서 모니터링할 수신용 Naver 주소

### 실행

```bash
python send_email.py --to gmail
python send_email.py --to naver --count 3
python send_email.py --to gmail --courier hanjin --status delivered
```

매 실행마다 택배사/상태/운송장번호/상품명을 무작위로 섞은 배송 안내 메일을 만들어
보냅니다. `--courier`/`--status`로 고정값을 지정할 수도 있습니다.

## 3. SMS 발송 설정 (Naver Cloud Platform SENS)

문자 발송 API 중 조건 없이 완전 무료인 곳은 없습니다. Naver Cloud Platform(NCP)의
SENS는 신규 가입 시 프로모션 크레딧을 주는 경우가 있어 초기 테스트 몇 건은 크레딧으로
처리될 수 있지만, 크레딧 소진 후에는 건당 과금됩니다(대략 SMS 9~15원 수준, 정확한
단가는 NCP 콘솔에서 확인).

설정 순서:

1. https://console.ncloud.com 가입 (본인 인증 필요).
2. 콘솔에서 **Simple & Easy Notification Service(SENS) > SMS** 프로젝트를 생성하고
   **Service ID**를 확인합니다.
3. 해당 프로젝트에서 **발신번호 사전등록**을 진행합니다. 본인 명의 휴대폰 인증이
   필요하고 승인까지 시간이 걸릴 수 있습니다. 이 단계가 끝나야 실제 발송이 가능합니다.
4. 마이페이지 > 계정 관리 > 인증키 관리에서 **Access Key / Secret Key**를 발급합니다.
5. `.env`에 다음을 채웁니다.
   - `NCP_ACCESS_KEY`, `NCP_SECRET_KEY`
   - `NCP_SENS_SERVICE_ID`
   - `NCP_SENS_SENDER_PHONE`: 사전등록한 발신번호 (하이픈 없이)
   - `RECIPIENT_PHONE`: 테스트 수신 번호 (하이픈 없이)

### 실행

```bash
python send_sms.py
python send_sms.py --courier lotte --status out_for_delivery
```

401/403 에러가 나면 대부분 서명 오류(Access/Secret Key 오타) 또는 발신번호 미승인
상태입니다. 오류 메시지에 NCP가 반환한 원문 응답이 그대로 출력됩니다.

## 파일 구성

| 파일 | 역할 |
|------|------|
| `samples.py` | 택배사/상태/상품명 무작위 조합으로 테스트 메시지 본문 생성 |
| `send_email.py` | Gmail SMTP로 테스트 메일 발송 |
| `send_sms.py` | Naver Cloud SENS API로 테스트 SMS 발송 |
| `env_loader.py` | `.env` 파일을 읽어 환경변수로 로드하는 헬퍼 |
| `example.env` | `.env` 템플릿 (커밋됨, 실제 값은 없음) |
