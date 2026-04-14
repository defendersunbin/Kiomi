import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/set_menu_detector.dart';
import './scan_screen.dart';

/// 홈 화면 — 브랜드 선택 없이 바로 주문 입력
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

  // 상호 배타적 옵션 그룹
  static const _exclusiveGroups = [
    {'매장', '포장'},
  ];

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
      onError: (error) => debugPrint('STT Error: $error'),
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
      _showError('음성 인식을 사용할 수 없습니다. 마이크 권한을 확인해 주세요.');
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _addKeyword(String keyword) {
    if (keyword.isEmpty || _selectedKeywords.contains(keyword)) return;
    setState(() {
      // 배타 그룹 처리: 같은 그룹의 다른 항목 제거
      for (final group in _exclusiveGroups) {
        if (group.contains(keyword)) {
          _selectedKeywords
              .removeWhere((kw) => kw != keyword && group.contains(kw));
          break;
        }
      }
      _selectedKeywords.add(keyword);
    });
  }

  void _removeKeyword(String keyword) {
    setState(() {
      _selectedKeywords.remove(keyword);
    });
  }

  void _addFromTextField() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // 콤마, 공백 등으로 분리
    final parts = text
        .split(RegExp(r'[,、，\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);

    for (final part in parts) {
      _addKeyword(part);
    }
    _textController.clear();
  }

  void _goToScan() {
    // 텍스트 필드에 남은 내용도 추가
    _addFromTextField();

    if (_selectedKeywords.isEmpty) {
      _showError('원하시는 메뉴를 입력해주세요');
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
      SnackBar(content: Text(message, style: const TextStyle(fontSize: 18))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // ── 타이틀 ──
              Text(
                '무엇을 주문하시겠어요?',
                style: theme.textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '메뉴를 입력하면 키오스크에서\n어디를 눌러야 하는지 알려드려요',
                style:
                    TextStyle(fontSize: 18, color: Colors.black54, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // ── 입력창 ──
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          onSubmitted: (_) => _addFromTextField(),
                          style: const TextStyle(
                              fontSize: 22, color: Colors.black),
                          decoration: const InputDecoration(
                            hintText: '예: 빅맥, 감자튀김, 콜라',
                            hintStyle:
                                TextStyle(fontSize: 18, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _addFromTextField,
                        icon: Icon(Icons.add_circle,
                            size: 32, color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── 선택된 항목 칩 ──
              if (_selectedKeywords.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedKeywords.map((kw) {
                    final type = SetMenuDetector.classify(kw);
                    final typeColor = _getTypeColor(type, theme);
                    return Chip(
                      avatar: CircleAvatar(
                        backgroundColor: typeColor,
                        radius: 12,
                        child: Text(
                          _getTypeEmoji(type),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      label: Text(kw, style: const TextStyle(fontSize: 18)),
                      deleteIcon: const Icon(Icons.close, size: 20),
                      onDeleted: () => _removeKeyword(kw),
                      backgroundColor: typeColor.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 20),

              // ── 버튼: 말하기 + 스캔 ──
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isListening ? _stopListening : _startListening,
                      icon: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        size: 28,
                        color: Colors.white,
                      ),
                      label: Text(
                        _isListening ? '입력 중...' : '말하기',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isListening
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                        minimumSize: const Size(0, 64),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _goToScan,
                      icon: const Icon(Icons.camera_alt,
                          size: 28, color: Colors.white),
                      label: const Text(
                        '키오스크 스캔',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                        minimumSize: const Size(0, 64),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── 빠른 선택: 자주 쓰는 메뉴 ──
              Text('빠른 선택', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),

              _buildQuickSection(
                  '🍔 버거류', ['빅맥', '와퍼', '불고기버거', '치즈버거', '맥치킨'], theme),
              _buildQuickSection('🍟 사이드', ['감자튀김', '치킨너겟', '어니언링'], theme),
              _buildQuickSection(
                  '🥤 음료', ['콜라', '사이다', '아메리카노', '카페라떼'], theme),
              _buildQuickSection('⚙️ 옵션', ['매장', '포장', '세트', '단품'], theme),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSection(String title, List<String> items, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.map((item) {
              final isSelected = _selectedKeywords.contains(item);
              return FilterChip(
                label: Text(item),
                selected: isSelected,
                onSelected: (_) {
                  if (isSelected) {
                    _removeKeyword(item);
                  } else {
                    _addKeyword(item);
                  }
                },
                labelStyle: TextStyle(
                  fontSize: 18,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
                selectedColor: theme.colorScheme.primary,
                checkmarkColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(MenuType type, ThemeData theme) {
    switch (type) {
      case MenuType.main:
        return Colors.red;
      case MenuType.side:
        return Colors.orange;
      case MenuType.drink:
        return Colors.blue;
      case MenuType.dessert:
        return Colors.purple;
      case MenuType.option:
        return Colors.grey;
      case MenuType.unknown:
        return Colors.grey;
    }
  }

  String _getTypeEmoji(MenuType type) {
    switch (type) {
      case MenuType.main:
        return '🍔';
      case MenuType.side:
        return '🍟';
      case MenuType.drink:
        return '🥤';
      case MenuType.dessert:
        return '🍦';
      case MenuType.option:
        return '⚙';
      case MenuType.unknown:
        return '?';
    }
  }
}
