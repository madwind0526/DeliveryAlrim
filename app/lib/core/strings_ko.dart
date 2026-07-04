/// Centralized Korean UI strings.
/// All user-visible text lives here (global rule G-02).
abstract final class StringsKo {
  static const appTitle = '체크쉬핑';

  // Auth
  static const loginTitle = '시작하기';
  static const loginSubtitle = '배송 현황을 한 곳에서 확인하세요';
  static const displayNameLabel = '프로필 이름';
  static const displayNameHint = '예: 홍길동';
  static const displayNameEmpty = '프로필 이름을 입력해 주세요';
  static const startLocalButton = '로컬 프로필로 시작';
  static const localModeNotice = 'PC 평가 모드 — 서버 로그인은 이후 연결됩니다';
  static const logout = '로그아웃';

  // Parcel list
  static const parcelListTitle = '내 배송';
  static const tabActive = '진행중';
  static const tabDone = '완료';
  static const emptyActive = '진행 중인 배송이 없습니다';
  static const emptyDone = '완료된 배송이 없습니다';
  static const unknownProduct = '(상품명 미확인)';
  static const arrivalToday = '오늘 도착 예정';
  static const arrivalTomorrow = '내일 도착 예정';

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
