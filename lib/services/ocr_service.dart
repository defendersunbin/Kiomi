import 'dart:io';
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
      int imgWidth = inputImage.metadata?.size.width.toInt() ?? 600;
      int imgHeight = inputImage.metadata?.size.height.toInt() ?? 800;

      if (Platform.isAndroid) {
        final rotation = inputImage.metadata?.rotation;
        if (rotation == InputImageRotation.rotation90deg ||
            rotation == InputImageRotation.rotation270deg) {
          final temp = imgWidth;
          imgWidth = imgHeight;
          imgHeight = temp;
        }
      }

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
      debugPrint('OCR Error: $e');
      return [];
    }
  }

  // ── 매칭 알고리즘 ──
  List<OcrBlock> _findMatches(List<OcrBlock> blocks, String query) {
    final normalizedQuery = _normalize(query);
    final results = <OcrBlock>[];

    // 1단계: 완전 일치 또는 포함
    for (final block in blocks) {
      final normalizedText = _normalize(block.text);
      if (normalizedText == normalizedQuery ||
          normalizedText.contains(normalizedQuery) ||
          normalizedQuery.contains(normalizedText)) {
        results.add(block);
      }
    }
    if (results.isNotEmpty) return results;

    // 2단계: 키워드 분리 교차 검색
    final keywords =
    normalizedQuery.split(RegExp(r'\s+')).where((k) => k.length >= 2);
    for (final block in blocks) {
      final t = _normalize(block.text);
      if (keywords.any((kw) => t.contains(kw) || kw.contains(t))) {
        results.add(block);
      }
    }
    if (results.isNotEmpty) return results;

    // 3단계: 유사도 검사 (오타 보정)
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
    final aChars = a.runes.toSet();
    final bChars = b.runes.toSet();
    final intersection = aChars.intersection(bChars).length;
    final union = aChars.union(bChars).length;
    return union == 0 ? 0.0 : intersection / union;
  }
  void dispose() {
    _textRecognizer.close();
  }
}