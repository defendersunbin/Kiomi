import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/set_menu_detector.dart';
import './scan_screen.dart';

// ── 키오미 디자인 토큰 ──
class KiomiColors {
  static const primary = Color(0xFF3D8FE0);       // 키오미 블루
  static const primaryLight = Color(0xFFBDD9F5);  // 연한 블루
  static const primaryDark = Color(0xFF185FA5);   // 진한 블루
  static const accent = Color(0xFFF5A623);        // 골드 (플러스 배지)
  static const surface = Color(0xFFF4F8FD);       // 배경 서피스
  static const cardBg = Colors.white;
  static const textPrimary = Color(0xFF1A2A3A);
  static const textSecondary = Color(0xFF5A7A9A);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _textController = TextEditingController();
  final _speech = stt.SpeechToText();
  bool _isListening = false;
  final List<String> _selectedKeywords = [];

  String _selectedPlace = '홈';
  final List<String> _places = ['홈', '음식', '동사무소', '영화관'];

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
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

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
    for (final part in parts) {
      _addKeyword(part);
    }
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
        content: Text(message, style: const TextStyle(fontSize: 18)),
        backgroundColor: KiomiColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KiomiColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _buildHeader(),
              const SizedBox(height: 20),
              _buildPlaceTabs(),
              const SizedBox(height: 20),
              _buildInputCard(),
              const SizedBox(height: 12),
              if (_selectedKeywords.isNotEmpty) ...[
                _buildSelectedChips(),
                const SizedBox(height: 12),
              ],
              _buildActionButtons(),
              const SizedBox(height: 28),
              if (_selectedPlace == '홈')
                _buildGuideSection()
              else ...[
                _buildSectionTitle('빠른 선택'),
                const SizedBox(height: 12),
                ..._placeKeywordsData[_selectedPlace]!.entries.map(
                  (entry) => _buildQuickSection(entry.key, entry.value),
                ),
              ],

              Center(
                child: TextButton(
                  onPressed: () {
                    showLicensePage(
                      context: context,
                      applicationName: '키오미',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '© 2026 키오미. All rights reserved.',
                    );
                  },
                  child: const Text(
                    '오픈소스 라이선스',
                    style: TextStyle(
                      fontSize: 13,
                      color: KiomiColors.textSecondary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── 헤더: 키오미 로고 + 타이틀 ──
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: KiomiColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // 흰 모니터 미니 아이콘
              Positioned(
                left: 8, top: 7,
                child: Container(
                  width: 28, height: 21,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.sentiment_satisfied_alt, color: Color(0xFF3D8FE0), size: 16),
                ),
              ),
              // 골드 플러스 배지
              Positioned(
                right: 4, bottom: 4,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5A623),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '키오미',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: KiomiColors.primary,
                height: 1.1,
              ),
            ),
            const Text(
              '키오스크, 이제 쉬워요',
              style: TextStyle(fontSize: 13, color: KiomiColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  // ── 장소 탭 ──
  Widget _buildPlaceTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KiomiColors.primaryLight, width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: _places.map((place) {
          final isSelected = _selectedPlace == place;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPlace = place;
                  _selectedKeywords.clear();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? KiomiColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    place,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : KiomiColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 입력 카드 ──
  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KiomiColors.primaryLight, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              onSubmitted: (_) => _addFromTextField(),
              style: const TextStyle(fontSize: 20, color: KiomiColors.textPrimary),
              decoration: InputDecoration(
                hintText: '예: ${_getHintText()}',
                hintStyle: const TextStyle(fontSize: 17, color: KiomiColors.textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              onPressed: _addFromTextField,
              icon: const Icon(Icons.add_circle_rounded, size: 34, color: KiomiColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  // ── 선택된 키워드 칩 ──
  Widget _buildSelectedChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _selectedKeywords.map((kw) {
        final type = SetMenuDetector.classify(kw);
        final typeColor = _getTypeColor(type);
        return Chip(
          avatar: CircleAvatar(
            backgroundColor: typeColor,
            radius: 13,
            child: Text(_getTypeEmoji(type), style: const TextStyle(fontSize: 12)),
          ),
          label: Text(kw, style: const TextStyle(fontSize: 17, color: KiomiColors.textPrimary)),
          deleteIcon: const Icon(Icons.close_rounded, size: 18, color: KiomiColors.textSecondary),
          onDeleted: () => _removeKeyword(kw),
          backgroundColor: typeColor.withOpacity(0.1),
          side: BorderSide(color: typeColor.withOpacity(0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        );
      }).toList(),
    );
  }

  // ── 말하기 + 스캔 버튼 ──
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isListening ? _stopListening : _startListening,
            icon: Icon(
              _isListening ? Icons.stop_rounded : Icons.mic_rounded,
              size: 26, color: Colors.white,
            ),
            label: Text(
              _isListening ? '입력 중...' : '말하기',
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isListening
                  ? Colors.redAccent
                  : KiomiColors.primaryDark,
              minimumSize: const Size(0, 62),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _goToScan,
            icon: const Icon(Icons.camera_alt_rounded, size: 26, color: Colors.white),
            label: const Text('스캔 시작', style: TextStyle(fontSize: 18, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: KiomiColors.accent,
              minimumSize: const Size(0, 62),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  // ── 사용 안내 ──
  Widget _buildGuideSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('사용 안내'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KiomiColors.primaryLight),
          ),
          child: Column(
            children: [
              _buildGuideRow('1', _richText('찾을 단어를 입력하고 ', '골드 + 버튼', '을 눌러요')),
              _buildDivider(),
              _buildGuideRow('2', _plainText("'말하기'를 눌러 말로 입력할 수도 있어요")),
              _buildDivider(),
              _buildGuideRow('3', _plainText("'스캔 시작'을 눌러요")),
              _buildDivider(),
              _buildGuideRow('4', _plainText("키오스크 화면을 비추면 자동으로 찾아드려요")),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuideRow(String number, Widget content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30, height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: KiomiColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(width: 14),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildDivider() => Divider(color: KiomiColors.primaryLight, height: 1);

  Widget _richText(String before, String bold, String after) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 18, color: KiomiColors.textPrimary, height: 1.5),
        children: [
          TextSpan(text: before),
          TextSpan(text: bold, style: const TextStyle(fontWeight: FontWeight.bold, color: KiomiColors.accent)),
          TextSpan(text: after),
        ],
      ),
    );
  }

  Widget _plainText(String text) {
    return Text(text, style: const TextStyle(fontSize: 18, color: KiomiColors.textPrimary, height: 1.5));
  }

  // ── 빠른 선택 섹션 ──
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: KiomiColors.textPrimary),
    );
  }

  Widget _buildQuickSection(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: KiomiColors.textSecondary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.map((item) {
              final isSelected = _selectedKeywords.contains(item);
              return FilterChip(
                label: Text(item),
                selected: isSelected,
                onSelected: (_) => isSelected ? _removeKeyword(item) : _addKeyword(item),
                labelStyle: TextStyle(
                  fontSize: 17,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : KiomiColors.textPrimary,
                ),
                selectedColor: KiomiColors.primary,
                checkmarkColor: Colors.white,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected ? KiomiColors.primary : KiomiColors.primaryLight,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

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
      case MenuType.main: return Colors.red;
      case MenuType.side: return Colors.orange;
      case MenuType.drink: return KiomiColors.primary;
      case MenuType.dessert: return Colors.purple;
      case MenuType.document: return Colors.teal;
      case MenuType.ticket: return Colors.indigo;
      case MenuType.snack: return Colors.amber;
      default: return Colors.grey;
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
