import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/set_menu_detector.dart';
import '../models/scan_result.dart';
import '../services/ocr_service.dart';
import '../services/voice_guide_service.dart';
import '../widgets/guide_overlay.dart';

// 키오미 색상 (scan_screen 내에서도 동일 토큰 사용)
const _kPrimary = Color(0xFF3D8FE0);
const _kAccent = Color(0xFFF5A623);
const _kPrimaryDark = Color(0xFF185FA5);

/// 스캔 화면 — 실시간 카메라 + OCR 자동 스캔 (키오미 디자인 적용)
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

  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isPaused = false;
  bool _cameraError = false;
  String _errorMessage = '';

  final ValueNotifier<List<ScanResult>?> _scanResultsNotifier = ValueNotifier(null);

  bool _hasSpokenMatch = false;
  Offset? _focusPoint;
  Timer? _focusTimer;

  int _frameCount = 0;
  int get _processEveryN => Platform.isAndroid ? 3 : 1;

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
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        Platform.isAndroid ? ResolutionPreset.medium : ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
      );
      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isInitialized = true);
        _cameraController!.startImageStream(_processCameraFrame);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = true;
          _errorMessage = '카메라 오류: $e';
        });
      }
    }
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isProcessing || _isPaused || !mounted) return;

    _frameCount++;
    if (_frameCount % _processEveryN != 0) return;

    _isProcessing = true;
    try {
      final inputImage = _createInputImage(image);
      if (inputImage == null) return;

      final results = await _ocrService.scanImageStreamMulti(
        inputImage: inputImage,
        userQueries: widget.searchKeywords,
      );

      if (!mounted) return;
      _scanResultsNotifier.value = results;

      final hasAnyMatch = results.any((r) => r.hasMatch);
      if (hasAnyMatch && !_hasSpokenMatch) {
        _hasSpokenMatch = true;
        final matchedNames = results.where((r) => r.hasMatch).map((r) => r.userQuery).join(', ');
        await _voiceGuide.speak('$matchedNames 을 찾았습니다. 표시된 곳을 눌러주세요.');
      }
    } catch (e) {
      debugPrint('Stream Scan error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _createInputImage(CameraImage image) {
    final camera = _cameraController!.description;
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    final format = Platform.isIOS
        ? InputImageFormat.bgra8888
        : InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

    if (image.planes.isEmpty) return null;

    final Uint8List bytes;
    if (Platform.isAndroid) {
      bytes = image.planes[0].bytes;
    } else {
      final allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      bytes = allBytes.done().buffer.asUint8List();
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (!_isPaused) _hasSpokenMatch = false;
    });
    _voiceGuide.speak(_isPaused ? '스캔을 일시정지했어요.' : '다시 찾고 있어요.');
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _scanResultsNotifier.dispose();
    _cameraController?.dispose();
    _ocrService.dispose();
    _voiceGuide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildCameraArea()),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  // ── 상단 바 (키오미 스타일) ──
  Widget _buildTopBar() {
    return ValueListenableBuilder<List<ScanResult>?>(
      valueListenable: _scanResultsNotifier,
      builder: (context, scanResults, _) {
        final hasAnyMatch = scanResults?.any((r) => r.hasMatch) ?? false;

        return Container(
          color: const Color(0xEE0D1B2E),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  // 뒤로 버튼
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                  ),
                  // 키오미 로고 텍스트
                  const Text(
                    '키오미',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  // 상태 배지
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isPaused
                          ? Colors.grey.shade700
                          : hasAnyMatch
                              ? const Color(0xFF2ECC71)
                              : _kAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isPaused && !hasAnyMatch)
                          const SizedBox(
                            width: 13, height: 13,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2,
                            ),
                          ),
                        if (!_isPaused && !hasAnyMatch) const SizedBox(width: 6),
                        Text(
                          _isPaused ? '일시정지' : hasAnyMatch ? '✓ 발견!' : '찾는 중',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 키워드 태그 목록
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.searchKeywords.map((kw) {
                    final isFound = scanResults?.any((r) => r.userQuery == kw && r.hasMatch) ?? false;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: isFound ? const Color(0xFF2ECC71) : _kPrimary.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: isFound ? null : Border.all(color: _kPrimary.withOpacity(0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isFound) ...[
                            const Icon(Icons.check_circle, color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            kw,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: isFound ? FontWeight.bold : FontWeight.normal,
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
      },
    );
  }

  // ── 카메라 영역 ──
  Widget _buildCameraArea() {
    if (_cameraError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined, color: _kPrimary.withOpacity(0.6), size: 72),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() { _cameraError = false; _errorMessage = ''; });
                  _initCamera();
                },
                style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _kPrimary),
            SizedBox(height: 16),
            Text('카메라 준비 중...', style: TextStyle(color: Colors.white70, fontSize: 20)),
          ],
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: CameraPreview(
          _cameraController!,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final previewSize = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) async {
                  if (_cameraController == null || !_cameraController!.value.isInitialized) return;
                  setState(() => _focusPoint = details.localPosition);
                  _focusTimer?.cancel();
                  _focusTimer = Timer(const Duration(seconds: 2), () {
                    if (mounted) setState(() => _focusPoint = null);
                  });
                  final offset = Offset(
                    details.localPosition.dx / constraints.maxWidth,
                    details.localPosition.dy / constraints.maxHeight,
                  );
                  try {
                    await _cameraController!.setFocusPoint(offset);
                    await _cameraController!.setExposurePoint(offset);
                    await _cameraController!.setFocusMode(FocusMode.auto);
                  } catch (_) {}
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 포커스 표시 (키오미 블루 테두리)
                    if (_focusPoint != null)
                      Positioned(
                        left: _focusPoint!.dx - 32,
                        top: _focusPoint!.dy - 32,
                        child: Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            border: Border.all(color: _kPrimary, width: 2),
                            borderRadius: BorderRadius.circular(8),
                            color: _kPrimary.withOpacity(0.08),
                          ),
                        ),
                      ),

                    // OCR 오버레이
                    ValueListenableBuilder<List<ScanResult>?>(
                      valueListenable: _scanResultsNotifier,
                      builder: (context, scanResults, _) {
                        final hasAnyMatch = scanResults?.any((r) => r.hasMatch) ?? false;
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            if (hasAnyMatch && scanResults != null)
                              GuideOverlay(
                                scanResults: scanResults,
                                previewSize: previewSize,
                              ),
                            // 가이드 프레임 (매칭 없을 때) — 키오미 블루 테두리
                            if (!hasAnyMatch)
                              Center(
                                child: Container(
                                  width: 300, height: 400,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: _kPrimary.withOpacity(0.7), width: 2),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: EdgeInsets.all(14),
                                      child: Text(
                                        '키오스크 화면을 이 안에 맞춰주세요\n(흐릿하면 화면을 터치해 초점을 맞추세요)',
                                        style: TextStyle(
                                          color: Color(0xCCFFFFFF),
                                          fontSize: 16,
                                          height: 1.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── 하단 컨트롤 ──
  Widget _buildBottomControls() {
    return Container(
      color: const Color(0xEE0D1B2E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              label: const Text('돌아가기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A3A50),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _togglePause,
              icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 24),
              label: Text(_isPaused ? '다시 검색' : '일시정지'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isPaused ? const Color(0xFF2ECC71) : _kAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
