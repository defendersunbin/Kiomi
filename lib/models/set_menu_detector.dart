/// 세트 메뉴 감지 및 주문 그룹핑 모델
///
/// 사용자가 선택한 키워드들을 분석하여:
/// - 세트 메뉴 조합인지 판단 (메인 + 사이드 + 음료)
/// - 단품 vs 세트 추천
/// - OCR 결과에서 우선 탐색할 키워드 결정

/// 메뉴 아이템의 카테고리 분류
enum MenuType {
  main, // 메인 메뉴 (버거, 치킨, 피자 등)
  side, // 사이드 (감자튀김, 너겟 등)
  drink, // 음료 (콜라, 사이다, 커피 등)
  dessert, // 디저트
  option, // 옵션 (포장, 매장, 사이즈 등)
  document, // 동사무소 서류 (새로 추가)
  ticket, // 영화관 티켓 (새로 추가)
  snack, // 영화관 스낵류 (새로 추가)
  unknown, // 분류 불가
}

class OrderItem {
  final String keyword;
  final MenuType type;

  const OrderItem({required this.keyword, required this.type});

  @override
  String toString() => '$keyword($type)';
}

/// 주문 그룹 (세트 또는 단품)
class OrderGroup {
  final bool isSet; // 세트 메뉴 여부
  final List<OrderItem> items; // 포함된 아이템들
  final String? setName; // 세트로 인식된 경우 세트명 추천
  final String suggestion; // 사용자에게 보여줄 안내 문구

  const OrderGroup({
    required this.isSet,
    required this.items,
    this.setName,
    required this.suggestion,
  });
}

class SetMenuDetector {
  // ── 카테고리별 키워드 매핑 (장소별 확장) ──
  static const Map<String, MenuType> _keywordMap = {
    // 🍔 음식 메인
    '빅맥': MenuType.main,
    '맥치킨': MenuType.main,
    '와퍼': MenuType.main,
    '불고기버거': MenuType.main,
    '치즈버거': MenuType.main,
    '햄버거': MenuType.main,
    '피자': MenuType.main,
    '치킨': MenuType.main,
    '아메리카노': MenuType.main,
    '카페라떼': MenuType.main,

    // 🍟 음식 사이드
    '감자튀김': MenuType.side,
    '치킨너겟': MenuType.side,
    '어니언링': MenuType.side,

    // 🥤 음식 음료/디저트
    '콜라': MenuType.drink,
    '사이다': MenuType.drink,
    '에이드': MenuType.drink,
    '아이스크림': MenuType.dessert,

    // 🏛️ 동사무소 서류
    '주민등록등본': MenuType.document,
    '주민등록초본': MenuType.document,
    '가족관계증명서': MenuType.document,
    '인감증명서': MenuType.document,
    '복지카드': MenuType.document,
    '전입신고': MenuType.document,
    '증명서 출력': MenuType.document,

    // 🎬 영화관 티켓
    '예매 티켓 출력': MenuType.ticket,
    '티켓 구매': MenuType.ticket,
    '현장 발권': MenuType.ticket,
    '상영작': MenuType.ticket,

    // 🍿 영화관 스낵
    '팝콘': MenuType.snack,
    '나초': MenuType.snack,
    '오징어': MenuType.snack,

    // ⚙️ 범용 및 결제 옵션
    '매장': MenuType.option,
    '포장': MenuType.option,
    '결제하기': MenuType.option,
    '카드결제': MenuType.option,
    '신용카드': MenuType.option,
    '세트': MenuType.option,
    '단품': MenuType.option,
    '확인': MenuType.option,
    '취소': MenuType.option,
    '지문인식': MenuType.option,
    '수수료 결제': MenuType.option,
    '무료': MenuType.option,
    '좌석 선택': MenuType.option,
    '할인/포인트': MenuType.option,
  };

  /// 키워드를 카테고리로 분류
  static MenuType classify(String keyword) {
    final normalized = keyword.replaceAll(' ', '').toLowerCase();

    // 정확 매칭
    for (final entry in _keywordMap.entries) {
      if (entry.key.replaceAll(' ', '').toLowerCase() == normalized) {
        return entry.value;
      }
    }

    // 부분 매칭
    for (final entry in _keywordMap.entries) {
      final key = entry.key.replaceAll(' ', '').toLowerCase();
      if (normalized.contains(key) || key.contains(normalized)) {
        return entry.value;
      }
    }

    // 패턴 기반 추론
    if (normalized.contains('증명서') || normalized.contains('등본'))
      return MenuType.document;
    if (normalized.contains('티켓') || normalized.contains('예매'))
      return MenuType.ticket;
    if (normalized.contains('버거') || normalized.contains('피자'))
      return MenuType.main;
    if (normalized.contains('콜라') || normalized.contains('음료'))
      return MenuType.drink;

    return MenuType.unknown;
  }

  /// 사용자가 선택한 키워드들을 분석하여 안내 문구 생성
  static OrderGroup analyzeOrder(List<String> keywords) {
    if (keywords.isEmpty) {
      return const OrderGroup(
        isSet: false,
        items: [],
        suggestion: '찾으실 항목을 입력해주세요.',
      );
    }

    final items = keywords
        .map((kw) => OrderItem(keyword: kw, type: classify(kw)))
        .toList();

    // 기존의 세트 메뉴 판단 로직 유지 (음식 카테고리에 유효함)
    final hasMain = items.any((i) => i.type == MenuType.main);
    final hasSide = items.any((i) => i.type == MenuType.side);
    final hasDrink = items.any((i) => i.type == MenuType.drink);

    if (hasMain && (hasSide || hasDrink)) {
      final mainItems = items.where((i) => i.type == MenuType.main).toList();
      final mainName = mainItems.first.keyword;
      return OrderGroup(
        isSet: true,
        items: items,
        setName: '$mainName 세트',
        suggestion: '🍱 세트 메뉴로 주문하시면 더 저렴해요!\n"$mainName 세트" 버튼을 찾아보세요.',
      );
    }

    // 문서나 티켓 등 개별 항목 탐색
    return OrderGroup(
      isSet: false,
      items: items,
      suggestion: '선택하신 ${items.length}개 항목을 화면에서 찾아드릴게요.\n'
          '키오스크 화면을 스캔해주세요.',
    );
  }

  static List<String> buildSearchKeywords(OrderGroup group) {
    final keywords = <String>[];
    if (group.isSet && group.setName != null) {
      keywords.add(group.setName!);
      keywords.add('세트');
    }
    for (final item in group.items) {
      if (!keywords.contains(item.keyword)) {
        keywords.add(item.keyword);
      }
    }
    return keywords;
  }
}
