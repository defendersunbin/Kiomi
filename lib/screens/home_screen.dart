import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/set_menu_detector.dart';
import './scan_screen.dart';

// ── 키도리 디자인 토큰 (모던 리뉴얼) ──
class KidoriColors {
  static const primary       = Color(0xFF5B6EF5);   // 인디고 블루
  static const primaryLight  = Color(0xFFBFC9FF);
  static const primaryDark   = Color(0xFF3D52D0);
  static const accent        = Color(0xFFFF8C61);   // 코랄 (스캔)
  static const accentVoice   = Color(0xFF5B6EF5);   // 말하기
  static const surface       = Color(0xFFF5F6FF);   // 배경
  static const cardBg        = Colors.white;
  static const textPrimary   = Color(0xFF1C1F3D);
  static const textSecondary = Color(0xFF7B82B0);

  // 장소별 색상
  static const foodColor     = Color(0xFFFF8C61);
  static const govColor      = Color(0xFF2ECC71);
  static const movieColor    = Color(0xFF9B59B6);
  static const homeColor     = Color(0xFF5B6EF5);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _speech = stt.SpeechToText();
  bool _isListening = false;
  final List<String> _selectedKeywords = [];

  String _selectedPlace = '홈';
  final List<String> _places = ['홈', '음식', '동사무소', '영화관'];

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final Map<String, Map<String, List<String>>> _placeKeywordsData = {
    '음식': {
      '🍔 버거/피자': ['빅맥', '와퍼', '불고기버거', '피자', '햄버거'],
      '🍟 사이드/음료': ['감자튀김', '치킨너겟', '콜라', '사이다', '아메리카노'],
      '⚙️ 결제/옵션': ['매장', '포장', '세트', '단품', '카드결제'],
    },
    '동사무소': {
      '📄 증명서 발급': ['주민등록등본', '주민등록초본', '가족관계증명서', '인감증명서'],
      '💳 복지/기타': ['복지카드', '전입신고', '증명서 출력'],
      '⚙️ 진행/옵션': ['확인', '취소', '지문인식', '수수료 결제', '무료'],
    },
    '영화관': {
      '🎟️ 티켓': ['예매 티켓 출력', '티켓 구매', '현장 발권', '상영작'],
      '🍿 스낵/음료': ['팝콘', '나초', '오징어', '콜라', '에이드'],
      '⚙️ 결제/옵션': ['좌석 선택', '할인/포인트', '신용카드', '결제하기'],
    },
  };

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── 기존 로직 100% 유지 ──

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done') setState(() => _isListening = false);
      },
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() => _textController.text = result.recognizedWords);
        },
        localeId: 'ko_KR',
      );
    } else {
      _showError('음성 인식을 사용할 수 없습니다.');
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _addKeyword(String keyword) {
    if (keyword.isEmpty || _selectedKeywords.contains(keyword)) return;
    setState(() => _selectedKeywords.add(keyword));
  }

  void _removeKeyword(String keyword) {
    setState(() => _selectedKeywords.remove(keyword));
  }

  void _addFromTextField() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final parts = text.split(RegExp(r'[,、，\s]+')).map((s) => s.trim()).where((s) => s.isNotEmpty);
    for (final part in parts) { _addKeyword(part); }
    _textController.clear();
  }

  void _goToScan() {
    _addFromTextField();
    if (_selectedKeywords.isEmpty) {
      _showError('원하시는 항목을 선택하거나 입력해주세요');
      return;
    }
    final group = SetMenuDetector.analyzeOrder(_selectedKeywords);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          searchKeywords: List.from(_selectedKeywords),
          orderGroup: group,
          originalKeywords: List.from(_selectedKeywords),
        ),
      ),
    ).then((_) {
      setState(() {
        _selectedKeywords.clear();
        _textController.clear();
      });
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        backgroundColor: KidoriColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── 빌드 ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KidoriColors.surface,
      body: Column(
        children: [
          _buildGradientHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  _buildInputCard(),
                  const SizedBox(height: 10),
                  if (_selectedKeywords.isNotEmpty) ...[
                    _buildSelectedChips(),
                    const SizedBox(height: 10),
                  ],
                  _buildActionButtons(),
                  const SizedBox(height: 28),
                  if (_selectedPlace == '홈')
                    _buildGuideSection()
                  else ...[
                    _buildSectionTitle('빠른 선택'),
                    const SizedBox(height: 14),
                    ..._placeKeywordsData[_selectedPlace]!.entries.map(
                          (entry) => _buildQuickSection(entry.key, entry.value),
                    ),
                  ],
                  Center(
                    child: TextButton(
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: '키도리',
                        applicationVersion: '1.0.0',
                        applicationLegalese: '© 2026 키도리. All rights reserved.',
                      ),
                      child: const Text(
                        '오픈소스 라이선스',
                        style: TextStyle(fontSize: 13, color: KidoriColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 그라디언트 헤더 (로고 + 탭) ──
  Widget _buildGradientHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A5CE8), Color(0xFF6B7FF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 로고 행
              Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: const Icon(Icons.sentiment_satisfied_alt_rounded,
                              color: Colors.white, size: 22),
                        ),
                        Positioned(
                          right: 4, bottom: 4,
                          child: Container(
                            width: 14, height: 14,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFB347),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '키도리',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '키오스크, 이제 쉬워요',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // 탭 선택
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: _places.map((place) {
                    final isSelected = _selectedPlace == place;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedPlace = place),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            place,
                            style: TextStyle(
                              color: isSelected ? KidoriColors.primaryDark : Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 입력 카드 ──
  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: KidoriColors.primary.withOpacity(0.10),
            blurRadius: 16, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              onSubmitted: (_) => _addFromTextField(),
              style: const TextStyle(fontSize: 17, color: KidoriColors.textPrimary, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: '예: ${_getHintText()}',
                hintStyle: TextStyle(fontSize: 15, color: KidoriColors.textSecondary.withOpacity(0.7)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _addFromTextField,
              child: Container(
                width: 38, height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFB347),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 선택된 키워드 칩 ──
  Widget _buildSelectedChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: KidoriColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KidoriColors.primaryLight.withOpacity(0.6)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _selectedKeywords.map((kw) {
          final type = SetMenuDetector.classify(kw);
          final typeColor = _getTypeColor(type);
          return GestureDetector(
            onTap: () => _removeKeyword(kw),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: typeColor.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_getTypeEmoji(type), style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Text(
                    kw,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: typeColor.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(Icons.close_rounded, size: 14, color: typeColor.withOpacity(0.7)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 말하기 + 스캔 버튼 ──
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionBtn(
            label: _isListening ? '입력 중...' : '말하기',
            icon: _isListening ? Icons.stop_rounded : Icons.mic_rounded,
            gradient: _isListening
                ? const LinearGradient(colors: [Color(0xFFE74C3C), Color(0xFFFF6B6B)])
                : const LinearGradient(colors: [Color(0xFF3D52D0), Color(0xFF5B6EF5)]),
            onTap: _isListening ? _stopListening : _startListening,
            leading: _isListening
                ? ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionBtn(
            label: '스캔 시작',
            icon: Icons.camera_alt_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7043), Color(0xFFFFB347)],
            ),
            onTap: _goToScan,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn({
    required String label,
    required IconData icon,
    required LinearGradient gradient,
    required VoidCallback onTap,
    Widget? leading,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.35),
              blurRadius: 12, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 7)],
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 사용 안내 (홈) ──
  Widget _buildGuideSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('사용 안내'),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: KidoriColors.primary.withOpacity(0.08),
                blurRadius: 14, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildGuideRow('1', _richText('찾을 단어를 입력하고 ', '+ 버튼', '을 눌러요'), isFirst: true),
              _buildGuideRow('2', _plainText("'말하기'를 눌러 말로 입력할 수도 있어요")),
              _buildGuideRow('3', _plainText("'스캔 시작'을 눌러요")),
              _buildGuideRow('4', _plainText("키오스크 화면을 비추면 자동으로 찾아드려요"), isLast: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuideRow(String number, Widget content, {bool isFirst = false, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          bottom: BorderSide(color: KidoriColors.primaryLight.withOpacity(0.4), width: 0.8),
        ),
        borderRadius: isFirst
            ? const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))
            : isLast
            ? const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A5CE8), Color(0xFF6B7FF5)],
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _richText(String before, String bold, String after) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 16, color: KidoriColors.textPrimary, height: 1.5),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: bold,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFB347)),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  Widget _plainText(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, color: KidoriColors.textPrimary, height: 1.5),
    );
  }

  // ── 빠른 선택 섹션 ──
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: KidoriColors.textPrimary,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildQuickSection(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: KidoriColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: KidoriColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              final isSelected = _selectedKeywords.contains(item);
              return GestureDetector(
                onTap: () => isSelected ? _removeKeyword(item) : _addKeyword(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: isSelected ? KidoriColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? KidoriColors.primary : KidoriColors.primaryLight,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(
                      color: KidoriColors.primary.withOpacity(0.25),
                      blurRadius: 8, offset: const Offset(0, 3),
                    )]
                        : [BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4, offset: const Offset(0, 2),
                    )],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        item,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : KidoriColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── 유틸 ──
  String _getHintText() {
    switch (_selectedPlace) {
      case '동사무소': return '주민등록등본, 전입신고';
      case '영화관': return '현장 발권, 팝콘';
      case '홈': return '원하시는 단어를 직접 입력하세요';
      default: return '빅맥, 감자튀김, 콜라';
    }
  }

  Color _getTypeColor(MenuType type) {
    switch (type) {
      case MenuType.main: return const Color(0xFFE74C3C);
      case MenuType.side: return const Color(0xFFFF8C00);
      case MenuType.drink: return KidoriColors.primary;
      case MenuType.dessert: return const Color(0xFF9B59B6);
      case MenuType.document: return const Color(0xFF27AE60);
      case MenuType.ticket: return const Color(0xFF6C3483);
      case MenuType.snack: return const Color(0xFFE67E22);
      default: return KidoriColors.textSecondary;
    }
  }

  String _getTypeEmoji(MenuType type) {
    switch (type) {
      case MenuType.main: return '🍔';
      case MenuType.side: return '🍟';
      case MenuType.drink: return '🥤';
      case MenuType.dessert: return '🍦';
      case MenuType.document: return '📄';
      case MenuType.ticket: return '🎟️';
      case MenuType.snack: return '🍿';
      case MenuType.option: return '⚙️';
      default: return '❓';
    }
  }
}