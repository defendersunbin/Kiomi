import 'dart:ui' show Rect;

/// OCR로 인식된 개별 텍스트 블록
class OcrBlock {
  final String text;
  final Rect boundingBox;

  const OcrBlock({
    required this.text,
    required this.boundingBox,
  });

  bool containsQuery(String query) {
    final normalizedText = text.replaceAll(' ', '').toLowerCase();
    final normalizedQuery = query.replaceAll(' ', '').toLowerCase();
    return normalizedText.contains(normalizedQuery);
  }

  @override
  String toString() => 'OcrBlock("$text", $boundingBox)';
}

/// 전체 스캔 결과
class ScanResult {
  final List<OcrBlock> allBlocks;
  final List<OcrBlock> matchedBlocks;
  final String userQuery;
  final int imageWidth;
  final int imageHeight;

  const ScanResult({
    required this.allBlocks,
    required this.matchedBlocks,
    required this.userQuery,
    required this.imageWidth,
    required this.imageHeight,
  });

  bool get hasMatch => matchedBlocks.isNotEmpty;
  OcrBlock? get bestMatch => matchedBlocks.isNotEmpty ? matchedBlocks.first : null;
}
