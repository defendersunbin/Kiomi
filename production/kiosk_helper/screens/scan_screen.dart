import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // WriteBuffer 사용
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // ML Kit 추가
// path_provider는 더 이상 사용하지 않으므로 지워도 됩니다.

import '../models/set_menu_detector.dart';
import '../models/scan_result.dart';
import '../services/ocr_service.dart';
import '../services/voice_guide_service.dart';
import '../widgets/guide_overlay.dart';

/// 스캔 화면 — 실제 카메라 + 네이티브 OCR로 연속 자동 스캔
class ScanScreen extends StatefulWidget {
  final List<String> searchKeywords;
  final OrderGroup orderGroup;
  final List<String> originalKeywords;

  const ScanScreen({
    super.key,
    required this.searchKeywords,
    required this.orderGroup,
    required this.originalKeywords,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _cameraController;
  final _ocrService = OcrService();
  final _voiceGuide = VoiceGuideService();
  final GlobalKey _previewKey = GlobalKey();

  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isPaused = false;
  bool _cameraError = false;
  String _errorMessage = '';

  List<ScanResult>? _scanResults;

  Timer? _scanTimer;
  bool _hasSpokenMatch = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _voiceGuide.init().then((_) {
      _voiceGuide.speak('키오스크 화면을 비춰주세요. 자동으로 찾아드릴게요.');
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final backCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first);

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isInitialized = true);
        // 🚨 타이머 대신 카메라 스트림을 바로 켭니다!
        _cameraController!.startImageStream(_processCameraFrame);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _cameraError = true;
          _errorMessage = '카메라 오류: $e';
        });
    }
  }

  /// 실시간 스트림 프레임 처리 (소리 없음)
  Future<void> _processCameraFrame(CameraImage image) async {
    // 이미 처리 중이거나 일시정지 상태면 무시
    if (_isProcessing || _isPaused || !mounted) return;
    _isProcessing = true;

    try {
      final inputImage = _createInputImage(image);
      if (inputImage == null) return;

      final results = await _ocrService.scanImageStreamMulti(
        inputImage: inputImage,
        userQueries: widget.searchKeywords,
      );

      if (!mounted) return;

      final hasAnyMatch = results.any((r) => r.hasMatch);
      setState(() => _scanResults = results);

      if (hasAnyMatch && !_hasSpokenMatch) {
        _hasSpokenMatch = true;
        final matchedNames =
            results.where((r) => r.hasMatch).map((r) => r.userQuery).join(', ');
        await _voiceGuide.speak('$matchedNames 을 찾았습니다. 표시된 곳을 눌러주세요.');
      }
    } catch (e) {
      debugPrint('Stream Scan error: $e');
    } finally {
      // 프레임이 너무 빨리 돌아가서 기기에 과부하가 걸리지 않도록 0.5초 대기
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _isProcessing = false;
    }
  }

  /// CameraImage를 ML Kit이 읽을 수 있는 InputImage로 변환
  InputImage? _createInputImage(CameraImage image) {
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    final InputImageRotation? rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    // 🚨 해결된 부분: iOS에서는 자동 포맷 인식이 실패하므로 강제로 bgra8888 포맷을 지정합니다.
    final InputImageFormat format = Platform.isIOS
        ? InputImageFormat.bgra8888
        : InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;

    if (image.planes.isEmpty) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());

    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (!_isPaused) _hasSpokenMatch = false;
    });
    if (_isPaused) {
      _voiceGuide.speak('스캔을 일시정지했어요.');
    } else {
      _voiceGuide.speak('다시 찾고 있어요.');
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _cameraController?.dispose();
    _ocrService.dispose();
    _voiceGuide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(theme),
            Expanded(child: _buildCameraArea()),
            Container(
              color: const Color(0xDD000000),
              padding: const EdgeInsets.all(16),
              child: _buildBottomControls(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    final hasAnyMatch = _scanResults?.any((r) => r.hasMatch) ?? false;

    return Container(
      color: const Color(0xDD000000),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              ),
              const Spacer(),
              // 스캔 상태 표시
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isPaused
                      ? Colors.grey
                      : hasAnyMatch
                          ? Colors.green
                          : Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isPaused && !hasAnyMatch)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                    if (!_isPaused && !hasAnyMatch) const SizedBox(width: 6),
                    Text(
                      _isPaused
                          ? '일시정지'
                          : hasAnyMatch
                              ? '✅ 발견!'
                              : '분석 중',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 키워드별 찾음/찾는중 상태
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: widget.searchKeywords.map((kw) {
                final isFound =
                    _scanResults?.any((r) => r.userQuery == kw && r.hasMatch) ??
                        false;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isFound ? Colors.green : const Color(0x55FFFFFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isFound)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.check_circle,
                              color: Colors.white, size: 14),
                        ),
                      Text(
                        kw,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight:
                              isFound ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraArea() {
    // 카메라 에러
    if (_cameraError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined,
                  color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _cameraError = false;
                    _errorMessage = '';
                  });
                  _initCamera();
                },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    // 카메라 초기화 중
    if (!_isInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('카메라 준비 중...',
                style: TextStyle(color: Colors.white, fontSize: 20)),
          ],
        ),
      );
    }

    // 카메라 프리뷰 + 실시간 오버레이
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = Size(constraints.maxWidth, constraints.maxHeight);
        final hasAnyMatch = _scanResults?.any((r) => r.hasMatch) ?? false;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 카메라 프리뷰
            CameraPreview(_cameraController!),

            // OCR 매칭 바운딩 박스 오버레이
            if (hasAnyMatch && _scanResults != null)
              GuideOverlay(
                  scanResults: _scanResults!, previewSize: previewSize),

            // 가이드 프레임 (아직 매칭 없을 때)
            if (!hasAnyMatch)
              Center(
                child: Container(
                  width: 300,
                  height: 400,
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: const Color(0x8AFFFFFF), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        '키오스크 화면을\n이 안에 맞춰주세요',
                        style: TextStyle(
                            color: Color(0xB3FFFFFF),
                            fontSize: 18,
                            height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),

            // 분석 중 인디케이터 (우측 하단)
            if (_isProcessing)
              const Positioned(
                bottom: 16,
                right: 16,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
              ),

            // 매칭 결과 요약 (하단)
            if (hasAnyMatch && _scanResults != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: const Color(0xCC000000),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _buildMatchSummary(),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _buildMatchSummary() {
    if (_scanResults == null) return '';
    final matched = _scanResults!.where((r) => r.hasMatch).toList();
    final notMatched = _scanResults!.where((r) => !r.hasMatch).toList();
    final parts = <String>[];
    if (matched.isNotEmpty)
      parts.add('✅ ${matched.map((r) => r.userQuery).join(', ')}');
    if (notMatched.isNotEmpty)
      parts.add('🔍 찾는 중: ${notMatched.map((r) => r.userQuery).join(', ')}');
    return parts.join('  ');
  }

  Widget _buildBottomControls(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 24),
            label: const Text('돌아가기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF424242),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 60),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _togglePause,
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, size: 24),
            label: Text(_isPaused ? '다시 검색' : '일시정지'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isPaused ? Colors.green : Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 60),
            ),
          ),
        ),
      ],
    );
  }
}
