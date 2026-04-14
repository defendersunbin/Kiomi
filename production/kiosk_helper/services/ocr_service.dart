import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/scan_result.dart';
import 'dart:ui' as ui;

class OcrService {
  // 한국어 텍스트 인식기 초기화
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.korean);

  /// 실시간 카메라 프레임(InputImage)을 받아서 여러 키워드를 스캔
  Future<List<ScanResult>> scanImageStreamMulti({
    required InputImage inputImage,
    required List<String> userQueries,
  }) async {
    try {
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      final blocks = <(OcrBlock, int, int)>[];
      // 스트림 메타데이터에서 원본 이미지 해상도 추출
      final int imgWidth = inputImage.metadata?.size.width.toInt() ?? 600;
      final int imgHeight = inputImage.metadata?.size.height.toInt() ?? 800;

      for (TextBlock textBlock in recognizedText.blocks) {
        final text = textBlock.text.trim();
        if (text.isNotEmpty) {
          blocks.add((
            OcrBlock(
              text: text,
              boundingBox: textBlock.boundingBox,
            ),
            imgWidth,
            imgHeight,
          ));
        }
      }

      final results = <ScanResult>[];
      for (final query in userQueries) {
        final ocrBlocks = blocks.map((b) => b.$1).toList();
        final matched = _findMatches(ocrBlocks, query);
        results.add(ScanResult(
          allBlocks: ocrBlocks,
          matchedBlocks: matched,
          userQuery: query,
          imageWidth: imgWidth,
          imageHeight: imgHeight,
        ));
      }
      return results;
    } catch (e) {
      debugPrint('ML Kit Stream OCR Error: $e');
      return [];
    }
  }

  // 매칭 로직 — 기존과 완벽하게 동일
  List<OcrBlock> _findMatches(List<OcrBlock> blocks, String query) {
    if (query.isEmpty) return [];

    final normalizedQuery = _normalize(query);
    final results = <OcrBlock>[];

    for (final block in blocks) {
      final normalizedText = _normalize(block.text);
      if (normalizedText == normalizedQuery ||
          normalizedText.contains(normalizedQuery) ||
          normalizedQuery.contains(normalizedText)) {
        results.add(block);
      }
    }
    if (results.isNotEmpty) return results;

    final keywords =
        normalizedQuery.split(RegExp(r'\s+')).where((k) => k.length >= 2);
    for (final block in blocks) {
      final t = _normalize(block.text);
      if (keywords.any((kw) => t.contains(kw) || kw.contains(t))) {
        results.add(block);
      }
    }
    if (results.isNotEmpty) return results;

    if (normalizedQuery.length >= 2) {
      final scored = <MapEntry<OcrBlock, double>>[];
      for (final block in blocks) {
        final score = _similarity(_normalize(block.text), normalizedQuery);
        if (score > 0.5) scored.add(MapEntry(block, score));
      }
      scored.sort((a, b) => b.value.compareTo(a.value));
      results.addAll(scored.take(2).map((e) => e.key));
    }
    return results;
  }

  String _normalize(String text) =>
      text.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final setA = a.split('').toSet();
    final setB = b.split('').toSet();
    return setA.intersection(setB).length / setA.union(setB).length;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
