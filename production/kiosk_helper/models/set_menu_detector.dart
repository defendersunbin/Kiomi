/// 세트 메뉴 감지 및 주문 그룹핑 모델
///
/// 사용자가 선택한 키워드들을 분석하여:
/// - 세트 메뉴 조합인지 판단 (메인 + 사이드 + 음료)
/// - 단품 vs 세트 추천
/// - OCR 결과에서 우선 탐색할 키워드 결정

/// 메뉴 아이템의 카테고리 분류
enum MenuType {
  main, // 메인 메뉴 (버거, 치킨 등)
  side, // 사이드 (감자튀김, 너겟 등)
  drink, // 음료 (콜라, 사이다, 커피 등)
  dessert, // 디저트
  option, // 옵션 (포장, 매장, 사이즈 등)
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
  // ── 카테고리별 키워드 매핑 ──
  static const Map<String, MenuType> _keywordMap = {
    // 메인 (버거류)
    '빅맥': MenuType.main,
    '맥치킨': MenuType.main,
    '와퍼': MenuType.main,
    '치즈와퍼': MenuType.main,
    '불고기버거': MenuType.main,
    '치즈버거': MenuType.main,
    '쿼터파운더': MenuType.main,
    '1955버거': MenuType.main,
    '맥스파이시': MenuType.main,
    '콰트로치즈와퍼': MenuType.main,
    '통새우와퍼': MenuType.main,
    '햄버거': MenuType.main,
    '버거': MenuType.main,
    '치킨': MenuType.main,
    '샌드위치': MenuType.main,

    // 커피/음료 메인 (카페에서는 이게 메인)
    '아메리카노': MenuType.main,
    '카페라떼': MenuType.main,
    '카푸치노': MenuType.main,
    '바닐라라떼': MenuType.main,
    '카라멜마끼아또': MenuType.main,
    '프라푸치노': MenuType.main,
    '아이스티': MenuType.main,
    '초코라떼': MenuType.main,
    '딸기라떼': MenuType.main,
    '레몬에이드': MenuType.main,

    // 사이드
    '감자튀김': MenuType.side,
    '프렌치프라이': MenuType.side,
    '프라이': MenuType.side,
    '치킨너겟': MenuType.side,
    '너겟': MenuType.side,
    '맥윙': MenuType.side,
    '어니언링': MenuType.side,
    '해시브라운': MenuType.side,
    '사이드': MenuType.side,
    '크로와상': MenuType.side,
    '케이크': MenuType.side,
    '소금빵': MenuType.side,

    // 음료
    '콜라': MenuType.drink,
    '사이다': MenuType.drink,
    '오렌지주스': MenuType.drink,
    '스프라이트': MenuType.drink,
    '제로콜라': MenuType.drink,
    '음료': MenuType.drink,
    '물': MenuType.drink,

    // 디저트
    '맥플러리': MenuType.dessert,
    '아이스크림': MenuType.dessert,
    '아이스크림콘': MenuType.dessert,
    '애플파이': MenuType.dessert,
    '선데이': MenuType.dessert,

    // 옵션
    '매장': MenuType.option,
    '포장': MenuType.option,
    '결제하기': MenuType.option,
    '카드결제': MenuType.option,
    '간편결제': MenuType.option,
    '세트': MenuType.option,
    '세트메뉴': MenuType.option,
    '단품': MenuType.option,
    'HOT': MenuType.option,
    'ICE': MenuType.option,
    '톨': MenuType.option,
    '그란데': MenuType.option,
    '벤티': MenuType.option,
    '미디엄': MenuType.option,
    '라지': MenuType.option,
    '레귤러': MenuType.option,
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
    if (normalized.contains('버거') ||
        normalized.contains('와퍼') ||
        normalized.contains('치킨')) {
      return MenuType.main;
    }
    if (normalized.contains('튀김') ||
        normalized.contains('너겟') ||
        normalized.contains('사이드')) {
      return MenuType.side;
    }
    if (normalized.contains('콜라') ||
        normalized.contains('주스') ||
        normalized.contains('음료')) {
      return MenuType.drink;
    }
    if (normalized.contains('라떼') ||
        normalized.contains('커피') ||
        normalized.contains('아메')) {
      return MenuType.main;
    }

    return MenuType.unknown;
  }

  /// 사용자가 선택한 키워드들을 분석하여 주문 그룹 생성
  static OrderGroup analyzeOrder(List<String> keywords) {
    if (keywords.isEmpty) {
      return const OrderGroup(
        isSet: false,
        items: [],
        suggestion: '주문할 메뉴를 입력해주세요.',
      );
    }

    final items = keywords
        .map((kw) => OrderItem(
              keyword: kw,
              type: classify(kw),
            ))
        .toList();

    final hasMain = items.any((i) => i.type == MenuType.main);
    final hasSide = items.any((i) => i.type == MenuType.side);
    final hasDrink = items.any((i) => i.type == MenuType.drink);
    final mainItems = items.where((i) => i.type == MenuType.main).toList();
    final sideItems = items.where((i) => i.type == MenuType.side).toList();
    final drinkItems = items.where((i) => i.type == MenuType.drink).toList();

    // 세트 메뉴 조건: 메인 + (사이드 or 음료) 이상
    if (hasMain && (hasSide || hasDrink)) {
      final mainName = mainItems.first.keyword;
      final components = <String>[mainName];
      if (hasSide) components.add(sideItems.first.keyword);
      if (hasDrink) components.add(drinkItems.first.keyword);

      // 세트 조합 (메인+사이드+음료 = 풀세트)
      if (hasSide && hasDrink) {
        return OrderGroup(
          isSet: true,
          items: items,
          setName: '$mainName 세트',
          suggestion: '🍱 세트 메뉴로 주문하시면 더 저렴해요!\n'
              '"$mainName 세트" 버튼을 찾아보세요.\n'
              '세트에 ${sideItems.first.keyword}와 ${drinkItems.first.keyword}가 포함됩니다.',
        );
      }

      // 메인 + 사이드 또는 메인 + 음료
      return OrderGroup(
        isSet: true,
        items: items,
        setName: '$mainName 세트',
        suggestion: '🍱 세트 메뉴를 추천해요!\n'
            '"$mainName 세트"를 선택하면 ${hasSide ? sideItems.first.keyword : drinkItems.first.keyword}가 포함됩니다.',
      );
    }

    // 단품 주문
    if (hasMain && mainItems.length == 1) {
      return OrderGroup(
        isSet: false,
        items: items,
        suggestion: '${mainItems.first.keyword} 단품으로 주문할게요.\n'
            '키오스크 화면을 스캔해주세요.',
      );
    }

    // 여러 항목 개별 주문
    return OrderGroup(
      isSet: false,
      items: items,
      suggestion: '선택하신 ${items.length}개 항목을 화면에서 찾아드릴게요.\n'
          '키오스크 화면을 스캔해주세요.',
    );
  }

  /// 세트 메뉴일 때 OCR에서 우선 탐색할 키워드 목록 생성
  /// (세트라면 "세트" 키워드를 함께 탐색)
  static List<String> buildSearchKeywords(OrderGroup group) {
    final keywords = <String>[];

    if (group.isSet && group.setName != null) {
      // 세트 메뉴: "빅맥 세트" 같은 세트명 우선 탐색
      keywords.add(group.setName!);
      keywords.add('세트');
    }

    // 개별 아이템 키워드 추가
    for (final item in group.items) {
      if (!keywords.contains(item.keyword)) {
        keywords.add(item.keyword);
      }
    }

    return keywords;
  }
}
