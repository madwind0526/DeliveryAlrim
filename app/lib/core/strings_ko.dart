/// Centralized Korean UI strings.
/// All user-visible text lives here (global rule G-02).
abstract final class StringsKo {
  static const appTitle = '체크쉬핑';

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
  static const allCouriers = '전체 업체';
  static const allStatuses = '전체 상태';
  static const settingTitle = '설정';
  static const settingMode = '모드';
  static const settingModeLocal = '로컬';
  static const settingModeDebug = '테스트';
  static const settingNotifications = '알림 수집';
  static const settingAccessibility = '카카오톡 접근성 수집';
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
  static const userCredentialSave = '저장';
  static const userCredentialDelete = '삭제';
  static const userCredentialSavedSnack = '로그인 정보를 암호화 저장했습니다';
  static const userCredentialDeletedSnack = '로그인 정보를 삭제했습니다';
  static const userCredentialRequired = '계정과 비밀번호/토큰을 입력해 주세요';
  static const userSecureStorageNotice = '로그인 정보는 항상 이 기기에 암호화 저장됩니다';
  static const userKakaoSync = '카카오톡 동기화';
  static const userKakaoSyncDone = '카카오톡 배송 정보를 동기화했습니다';
  static const userKakaoSyncEmpty = '새 카카오톡 배송 정보가 없습니다';
  static const addSource = '추가';
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

  // Debug insert
  static const debugInsertTitle = '배송 수동 등록 (디버그)';
  static const courierLabel = '택배사';
  static const trackingNumberLabel = '운송장번호';
  static const trackingNumberEmpty = '운송장번호를 입력해 주세요';
  static const productNameLabel = '상품명 (선택)';
  static const mallNameLabel = '쇼핑몰 (선택)';
  static const statusLabel = '배송 상태';
  static const expectedArrivalLabel = '도착 예정일 (선택)';
  static const pickDate = '날짜 선택';
  static const clearDate = '지우기';
  static const insertButton = '등록';
  static const insertDone = '등록되었습니다';
}
