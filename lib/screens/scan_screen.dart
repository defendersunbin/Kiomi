import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/set_menu_detector.dart';
import '../models/scan_result.dart';
import '../services/ocr_service.dart';
import '../widgets/guide_overlay.dart';

const _kPrimary     = Color(0xFF5B6EF5);
const _kAccent      = Color(0xFFFF8C61);
const _kPrimaryDark = Color(0xFF3D52D0);

/// 스캔 화면 — 실시간 카메라 + OCR (모던 리뉴얼, 로직 100% 유지)
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

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  final _ocrService = OcrService();

  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isPaused = false;
  bool _cameraError = false;
  String _errorMessage = '';

  final ValueNotifier<List<ScanResult>?> _scanResultsNotifier = ValueNotifier(null);
  Offset? _focusPoint;
  Timer? _focusTimer;

  int _frameCount = 0;
  int get _processEveryN => Platform.isAndroid ? 3 : 1;

  // 발견 축하 애니메이션
  late AnimationController _foundCtrl;
  late Animation<double> _foundAnim;
  bool _showFoundBurst = false;

  @override
  void initState() {
    super.initState();
    _foundCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _foundAnim = CurvedAnimation(parent: _foundCtrl, curve: Curves.elasticOut);
    _initCamera();
  }

  // ── 기존 카메라/OCR 로직 100% 유지 ──

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
        setState(() { _cameraError = true; _errorMessage = '카메라 오류: $e'; });
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
      final hadMatch = _scanResultsNotifier.value?.any((r) => r.hasMatch) ?? false;
      final hasMatch = results.any((r) => r.hasMatch);
      _scanResultsNotifier.value = results;
      // 새로 발견된 순간 애니메이션
      if (!hadMatch && hasMatch) {
        setState(() => _showFoundBurst = true);
        _foundCtrl.forward(from: 0);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showFoundBurst = false);
        });
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
      for (final plane in image.planes) { allBytes.putUint8List(plane.bytes); }
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

  void _togglePause() => setState(() => _isPaused = !_isPaused);

  @override
  void dispose() {
    _focusTimer?.cancel();
    _scanResultsNotifier.dispose();
    _cameraController?.dispose();
    _ocrService.dispose();
    _foundCtrl.dispose();
    super.dispose();
  }

  // ── UI 빌드 ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildCameraArea()),
                _buildBottomControls(),
              ],
            ),
            // 발견! 플로팅 토스트
            if (_showFoundBurst)
              Positioned(
                top: 90,
                left: 0, right: 0,
                child: Center(
                  child: ScaleTransition(
                    scale: _foundAnim,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2ECC71).withOpacity(0.4),
                            blurRadius: 16, offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            '찾았어요!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 상단 바 ──
  Widget _buildTopBar() {
    return ValueListenableBuilder<List<ScanResult>?>(
      valueListenable: _scanResultsNotifier,
      builder: (context, scanResults, _) {
        final hasAnyMatch = scanResults?.any((r) => r.hasMatch) ?? false;
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D0B1E), Color(0xFF1A1640)],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(0),
              bottomRight: Radius.circular(0),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  // 뒤로 버튼
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  // 타이틀
                  const Text(
                    '키도리',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  // 상태 배지
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isPaused
                            ? [Colors.grey.shade700, Colors.grey.shade600]
                            : hasAnyMatch
                            ? [const Color(0xFF27AE60), const Color(0xFF2ECC71)]
                            : [const Color(0xFFFF7043), const Color(0xFFFFB347)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: (_isPaused
                              ? Colors.grey
                              : hasAnyMatch
                              ? const Color(0xFF2ECC71)
                              : const Color(0xFFFF7043))
                              .withOpacity(0.4),
                          blurRadius: 10, offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isPaused && !hasAnyMatch)
                          const SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2,
                            ),
                          )
                        else
                          Icon(
                            _isPaused
                                ? Icons.pause_rounded
                                : hasAnyMatch
                                ? Icons.check_rounded
                                : Icons.search_rounded,
                            color: Colors.white, size: 14,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          _isPaused
                              ? '일시정지'
                              : hasAnyMatch
                              ? '발견!'
                              : '탐색 중',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 키워드 태그
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.searchKeywords.map((kw) {
                    final isFound = scanResults?.any(
                          (r) => r.userQuery == kw && r.hasMatch,
                    ) ?? false;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: isFound
                            ? const LinearGradient(
                          colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
                        )
                            : LinearGradient(
                          colors: [
                            _kPrimary.withOpacity(0.3),
                            _kPrimary.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: isFound
                            ? null
                            : Border.all(
                          color: _kPrimary.withOpacity(0.5), width: 1,
                        ),
                        boxShadow: isFound
                            ? [BoxShadow(
                          color: const Color(0xFF2ECC71).withOpacity(0.3),
                          blurRadius: 8, offset: const Offset(0, 2),
                        )]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isFound) ...[
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            kw,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: isFound ? FontWeight.w700 : FontWeight.w500,
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
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt_outlined,
                    color: _kPrimary.withOpacity(0.7), size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  setState(() { _cameraError = false; _errorMessage = ''; });
                  _initCamera();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kPrimaryDark, _kPrimary],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    '다시 시도',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _cameraController == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kPrimaryDark, _kPrimary]),
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              ),
            ),
            const SizedBox(height: 16),
            const Text('카메라 준비 중...',
                style: TextStyle(color: Colors.white70, fontSize: 17, fontWeight: FontWeight.w500)),
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
                    // 포커스 링 (모던)
                    if (_focusPoint != null)
                      Positioned(
                        left: _focusPoint!.dx - 36,
                        top: _focusPoint!.dy - 36,
                        child: Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            border: Border.all(color: _kPrimary, width: 2),
                            borderRadius: BorderRadius.circular(36),
                          ),
                          child: Center(
                            child: Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                color: _kPrimary, shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),

                    ValueListenableBuilder<List<ScanResult>?>(
                      valueListenable: _scanResultsNotifier,
                      builder: (context, scanResults, _) {
                        final hasAnyMatch = scanResults?.any((r) => r.hasMatch) ?? false;
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // OCR 오버레이 (기존 로직)
                            if (hasAnyMatch && scanResults != null)
                              GuideOverlay(
                                scanResults: scanResults,
                                previewSize: previewSize,
                              ),
                            // 가이드 프레임 (모던 코너 스타일)
                            if (!hasAnyMatch)
                              Center(
                                child: SizedBox(
                                  width: 280, height: 380,
                                  child: Stack(
                                    children: [
                                      // 4 코너
                                      ..._buildCorners(),
                                      // 힌트 텍스트
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.55),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            '키오스크 화면을 이 안에 맞춰주세요\n흐릿하면 화면을 터치해 초점을 맞추세요',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              height: 1.5,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ],
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

  List<Widget> _buildCorners() {
    const size = 26.0;
    const thick = 3.0;
    const color = _kPrimary;
    const r = 4.0;
    return [
      // TL
      Positioned(
        top: 0, left: 0,
        child: Container(
          width: size, height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: thick),
              left: BorderSide(color: color, width: thick),
            ),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(r)),
          ),
        ),
      ),
      // TR
      Positioned(
        top: 0, right: 0,
        child: Container(
          width: size, height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: thick),
              right: BorderSide(color: color, width: thick),
            ),
            borderRadius: BorderRadius.only(topRight: Radius.circular(r)),
          ),
        ),
      ),
      // BL
      Positioned(
        bottom: 0, left: 0,
        child: Container(
          width: size, height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: thick),
              left: BorderSide(color: color, width: thick),
            ),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(r)),
          ),
        ),
      ),
      // BR
      Positioned(
        bottom: 0, right: 0,
        child: Container(
          width: size, height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: thick),
              right: BorderSide(color: color, width: thick),
            ),
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(r)),
          ),
        ),
      ),
    ];
  }

  // ── 하단 컨트롤 ──
  Widget _buildBottomControls() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D0B1E), Color(0xFF1A1640)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _buildBottomBtn(
              label: '돌아가기',
              icon: Icons.arrow_back_ios_new_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF2A2D4E), Color(0xFF3A3D5E)],
              ),
              onTap: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildBottomBtn(
              label: _isPaused ? '다시 검색' : '일시정지',
              icon: _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              gradient: _isPaused
                  ? const LinearGradient(
                colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
              )
                  : const LinearGradient(
                colors: [Color(0xFFFF7043), Color(0xFFFFB347)],
              ),
              onTap: _togglePause,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBtn({
    required String label,
    required IconData icon,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 10, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}