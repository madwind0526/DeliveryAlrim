/// Centralized Korean UI strings.
/// All user-visible text lives here (global rule G-02).
abstract final class StringsKo {
  static const appTitle = '배송알리미';

  // Parcel list
  static const parcelListTitle = '내 배송';
  static const tabActive = '진행중';
  static const tabDone = '완료';
  static const emptyActive = '진행 중인 배송이 없습니다';
  static const emptyDone = '완료된 배송이 없습니다';
  static const unknownProduct = '(상품명 미확인)';
  static const arrivalToday = '오늘 도착 예정';
  static const arrivalTomorrow = '내일 도착 예정';

  // Navigation
  static const navCompany = '업체별';
  static const navDaily = '일별';
  static const navMonthly = '월별';
  static const navFilter = '필터';
  static const navSetting = '설정';
  static const navUser = '사용자';

  // Parcel detail
  static const detailTitle = '배송 상세';
  static const timelineTitle = '배송 이력';
  static const noEvents = '이력이 없습니다';
  static const channelsHeader = '수집 채널';
  static const parcelNotFound = '배송 정보를 찾을 수 없습니다';
  static const deleteParcel = '삭제';
  static const deleteConfirmTitle = '배송 삭제';
  static const deleteConfirmBody = '이 배송을 목록에서 삭제할까요?';
  static const cancel = '취소';

  // Calendar
  static const calendarTitle = '배송 캘린더';
  static const dailyTitle = '일별 배송';
  static const monthlyTitle = '월별 배송';
  static const dayEmpty = '이 날짜의 배송이 없습니다';
  static const calendarFormatMonth = '월';
  static const calendarFormatWeek = '주';
  static const todaySummaryTitle = '오늘 배송 현황';
  static const todayOrdered = '주문 내역';
  static const todayInTransit = '배송 내역';
  static const todayCompleted = '오늘 완료';
  static const todayDue = '오늘 배달 예정';
  static const todayAllClear = '오늘 확인할 배송이 없습니다';
  static const todaySectionEmpty = '해당 배송이 없습니다';
  static const expectedBadge = '도착 예정';
  static const deliveredBadge = '배달완료';

  // Filter / Setting / User
  static const filterTitle = '필터';
  static const filterCourier = '업체';
  static const filterDateRange = '날짜 기간';
  static const filterStatus = '배송 상태';
  static const filterApply = '적용';
  static const filterReset = '초기화';
  static const filterOrdered = '주문';
  static const filterInTransit = '배송중';
  static const filterDelivered = '배달완료';
  static const filterPickedUp = '집하';
  static const filterSelectCourier = '업체 선택';
  static const filterSelectStatus = '배송 상태 선택';
  static const filterNotAppliedHint = '조건을 선택하고 적용을 눌러주세요';
  static const allCouriers = '전체 업체';
  static const allStatuses = '전체 상태';
  static const settingTitle = '설정';
  static const settingCourierList = '업체 목록';
  static const settingCourierHint = '배송 조회에 사용할 택배사 목록입니다. 없는 업체는 추가하고, 안 쓰는 업체는 목록에서 지울 수 있습니다.';
  static const settingCourierAddHint = '새 업체명 입력';
  static const settingCourierEmpty = '등록된 업체가 없습니다';
  static const settingMode = '모드';
  static const settingModeLocal = '로컬';
  static const settingModeDebug = '테스트';
  static const settingNotifications = '알림 접근 권한';
  static const settingAccessibility = '카카오톡 접근성 수집';
  static const settingTestSection = '테스트';
  static const settingPermissionOn = '시스템 설정에서 허용됨';
  static const settingPermissionOff = '시스템 설정에서 허용 필요';
  static const settingNotificationSystemHint =
      'Android 설정 > 알림 접근에서 배송알리미를 허용합니다. Gmail, 네이버 메일, SMS 알림을 배송 후보로 수집합니다.';
  static const settingAccessibilitySystemHint =
      'Android 설정 > 접근성 > 설치된 앱에서 배송알리미 카카오톡 수집을 켜야 합니다.';
  static const settingOpenSettingsFailed = '시스템 설정 화면을 열 수 없습니다';
  static const sendAppToBackground = '홈 화면으로';
  static const userTitle = '사용자';
  static const userEmailSection = '이메일 모니터링';
  static const userSmsSection = '문자 모니터링';
  static const userSnsSection = 'SNS 모니터링';
  static const userCredentialSaved = '로그인 저장됨';
  static const userCredentialMissing = '로그인 필요';
  static const userCredentialButton = '로그인 정보';
  static const userCredentialTitle = '로그인 정보';
  static const userCredentialAccount = '계정';
  static const userCredentialSecret = '비밀번호 또는 토큰';
  static const userCredentialShowSecret = '비밀번호 보기';
  static const userCredentialHideSecret = '비밀번호 숨기기';
  static const userCredentialSave = '저장';
  static const userCredentialDelete = '삭제';
  static const userCredentialSavedSnack = '로그인 정보를 암호화 저장했습니다';
  static const userCredentialDeletedSnack = '로그인 정보를 삭제했습니다';
  static const userCredentialRequired = '계정과 비밀번호/토큰을 입력해 주세요';
  static const userSecureStorageNotice = '로그인 정보는 항상 이 기기에 암호화 저장됩니다';
  static const userKakaoSync = '알림 동기화';
  static const activeNotificationRescan = '현재 알림 다시 스캔';
  static const userKakaoSyncDone = '알림 배송 정보를 동기화했습니다';
  static const userKakaoSyncEmpty = '새 알림 배송 정보가 없습니다';
  static const addSource = '추가';
  static const addSourceTitle = '소스 추가';
  static const sourceDisplayName = '표시 이름';
  static const sourceDisplayNameHint = '예: 회사 메일';
  static const sourceDisplayNameRequired = '표시 이름을 입력해 주세요';
  static const sourceAddedSnack = '모니터링 소스를 추가했습니다';
  static const sourceEnabled = '사용';
  static const sourceDisabled = '사용 안 함';
  static const companyPickerTitle = '업체 선택';

  // Debug replay (parse injection)
  static const replayTitle = '알림 주입 테스트 (디버그)';
  static const channelLabel = '채널';
  static const packageNameLabel = '패키지명 (선택)';
  static const senderLabel = '발신자 (선택)';
  static const notifTitleLabel = '제목 (선택)';
  static const bodyLabel = '본문';
  static const bodyEmpty = '본문을 입력해 주세요';
  static const runParse = '파싱 실행';
  static const autoTestTitle = '자동 주입 테스트';
  static const sendGmailTest = 'Gmail 샘플 보내기';
  static const sendSmsTest = 'SMS 샘플 보내기';
  static const testSendRegistered = '테스트 배송을 등록했습니다';
  static const testSendRejected = '테스트 샘플을 배송으로 인식하지 못했습니다';
  static const parseMatched = '인식 성공';
  static const parseRejected = '인식 실패';
  static const matchedRuleLabel = '규칙';
  static const registerParcelButton = '배송으로 등록';
  static const registeredSnack = '배송 목록에 등록되었습니다';
  static const rulesLoadError = '파싱 규칙을 불러오지 못했습니다';

  // Sweet Tracker query API (optional feature)
  static const trackingApiSection = '스마트택배 조회 API (선택)';
  static const trackingApiHint =
      '스마트택배(스윗트래커) API 키를 등록하면 배송 상세와 목록에서 수동 조회를 사용할 수 있습니다. '
      '키가 없어도 알림 기반 추적은 그대로 동작합니다. 무료 키는 하루 약 100건까지만 조회됩니다.';
  static const trackingApiKeyInputHint = 'API 키 입력';
  static const trackingApiKeySaved = 'API 키를 암호화 저장했습니다';
  static const trackingApiKeyDeleted = 'API 키를 삭제했습니다';
  static const trackingApiKeyRegistered = 'API 키 등록됨';
  static const trackingApiKeyMissing = 'API 키 미등록';
  static const trackingApiUsageToday = '오늘 사용량';
  static const trackingRefresh = '배송 조회';
  static const trackingRefreshAll = '전체 배송 조회';
  static const trackingRefreshUpdated = '배송 상태를 갱신했습니다';
  static const trackingRefreshNoChange = '변동 없음 — 이미 최신 상태입니다';
  static const trackingRefreshUnsupported = '이 택배사는 API 조회를 지원하지 않습니다';
  static const trackingRefreshAlreadyDone = '이미 완료된 배송입니다';
  static const trackingRefreshMissingKey = 'API 키가 없습니다. 설정에서 등록해 주세요';
  static const trackingQuotaExceeded = '오늘 조회 한도를 모두 사용했습니다';
  static const trackingRefreshFailed = '조회 실패';
  static const trackingQuotaReached = '오늘 조회 한도 도달';

  static String trackingRefreshSummary({
    required int updated,
    required int unchanged,
    required int failed,
  }) {
    return [
      '갱신 $updated건',
      '변동 없음 $unchanged건',
      if (failed > 0) '실패 $failed건',
    ].join(' · ');
  }

  // Phishing quarantine
  static const quarantineTitle = '피싱 의심 보관함';
  static const quarantineEmpty = '피싱 의심 메시지가 없습니다';
  static const quarantineWarning =
      '피싱이 의심되어 배송으로 등록하지 않은 메시지입니다. 본문 속 링크나 첨부를 절대 열지 마세요.';
  static const quarantineReasonLabel = '의심 사유';
  static const quarantineDelete = '삭제';
  static const quarantineDeleted = '삭제했습니다';
  static const quarantineSettingHint = '피싱으로 의심되는 메시지는 배송 목록 대신 여기 보관됩니다';

  // Manual insert
  static const manualInsertTitle = '배송 수동 등록';
  static const courierLabel = '택배사';
  static const trackingNumberLabel = '운송장번호';
  static const trackingNumberEmpty = '운송장번호를 입력해 주세요';
  static const trackingNumberInvalid = '택배사에 맞는 운송장번호 형식이 아닙니다';
  static const productNameLabel = '상품명 (선택)';
  static const mallNameLabel = '쇼핑몰 (선택)';
  static const statusLabel = '배송 상태';
  static const expectedArrivalLabel = '도착 예정일 (선택)';
  static const pickDate = '날짜 선택';
  static const clearDate = '지우기';
  static const insertButton = '등록';
  static const insertDone = '등록되었습니다';
}
