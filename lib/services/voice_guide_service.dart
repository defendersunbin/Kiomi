import 'package:flutter_tts/flutter_tts.dart';

/// 음성 안내 서비스
class VoiceGuideService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.4);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    await init();
    await _tts.speak(text);
  }

  Future<void> guideMatch(String menuName) async {
    await speak('화면에서 $menuName 을 찾았습니다. 빨간 표시된 곳을 눌러주세요.');
  }

  Future<void> guideNoMatch(String menuName) async {
    await speak('화면에서 $menuName 을 찾지 못했습니다. 다시 한번 카메라로 비춰주세요.');
  }

  Future<void> guideSetMenu(String setName) async {
    await speak('세트 메뉴로 주문하시면 더 저렴합니다. $setName 버튼을 찾아보세요.');
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  void dispose() {
    _tts.stop();
  }
}
