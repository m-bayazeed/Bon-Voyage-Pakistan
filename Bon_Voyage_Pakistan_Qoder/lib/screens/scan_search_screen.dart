import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/scan_item_model.dart';
import '../services/scan_history_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/theme_toggle.dart';
import 'ai_tour_planning_screen.dart';

/// Premium real-time AI Scan n Search Screen for Bon Voyage Pakistan.
class ScanSearchScreen extends StatefulWidget {
  const ScanSearchScreen({super.key});

  @override
  State<ScanSearchScreen> createState() => _ScanSearchScreenState();
}

class _ScanSearchScreenState extends State<ScanSearchScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Camera state ──
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _cameraLoading = true;
  bool _isInitializing = false;
  String? _cameraError;
  bool _isFlashOn = false;
  bool _isFrontCamera = false;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 4.0;
  Offset? _focusPoint;

  // ── Active Image Preview (from capture or gallery upload) ──
  String? _selectedImagePath;
  ScanType? _selectedScanType;

  // ── AI processing state ──
  bool _isAnalyzing = false;

  // ── Gallery picker ──
  final ImagePicker _picker = ImagePicker();

  // ── Persistent History ──
  List<ScanItem> _history = [];
  bool _historyLoading = true;

  // ── Animations ──
  late AnimationController _scanCtrl;
  late Animation<double> _scanAnim;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;
  late AnimationController _entranceCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAnimations();
    _entranceCtrl.forward();
    _loadHistory();
    _startCamera();
  }

  void _setupAnimations() {
    _scanCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    _scanAnim = CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOutSine);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.85, end: 1.2).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseOpacity = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
      _cameraController = null;
      if (mounted) setState(() => _cameraReady = false);
    } else if (state == AppLifecycleState.resumed && _cameras.isNotEmpty) {
      final targetIdx = _isFrontCamera
          ? _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front)
          : _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _initController(targetIdx != -1 ? targetIdx : 0);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _cameraController = null;
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────
  // CAMERA INITIALIZATION FLOW
  // ────────────────────────────────────────────
  Future<void> _startCamera() async {
    if (_isInitializing) return;
    _isInitializing = true;

    if (mounted) {
      setState(() {
        _cameraLoading = true;
        _cameraError = null;
      });
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint('CAMERA START ERROR: No cameras found on device.');
        if (mounted) {
          setState(() {
            _cameraError = 'No camera found on this device.';
            _cameraLoading = false;
            _cameraReady = false;
          });
        }
        _isInitializing = false;
        return;
      }

      // Prefer rear camera by default
      int rearIdx = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back);
      if (rearIdx == -1) rearIdx = 0;

      await _initController(rearIdx);
    } on CameraException catch (e, stackTrace) {
      debugPrint('CAMERA START ERROR: ${e.code} - ${e.description}');
      debugPrintStack(stackTrace: stackTrace);
      _handleCameraException(e);
    } catch (e, stackTrace) {
      debugPrint('CAMERA START ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _cameraError = 'Failed to access camera: $e';
          _cameraLoading = false;
          _cameraReady = false;
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _initController(int index) async {
    if (index < 0 || index >= _cameras.length) index = 0;

    // Safely dispose old controller before creating new
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }

    final cameraDesc = _cameras[index];
    final controller = CameraController(
      cameraDesc,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _cameraController = controller;

    try {
      await controller.initialize();
      if (!mounted) return;

      try {
        _minZoom = await controller.getMinZoomLevel();
        _maxZoom = await controller.getMaxZoomLevel();
      } catch (e) {
        debugPrint('ZOOM RANGE QUERY WARNING: $e');
        _minZoom = 1.0;
        _maxZoom = 4.0;
      }

      debugPrint('CAMERA INITIALIZED: ${cameraDesc.name} (${cameraDesc.lensDirection.name})');

      setState(() {
        _cameraReady = true;
        _cameraLoading = false;
        _cameraError = null;
        _isFrontCamera =
            cameraDesc.lensDirection == CameraLensDirection.front;
        _isFlashOn = false;
        _currentZoom = 1.0;
      });
    } on CameraException catch (e, stackTrace) {
      debugPrint('CAMERA INIT CONTROLLER ERROR: ${e.code} - ${e.description}');
      debugPrintStack(stackTrace: stackTrace);
      _handleCameraException(e);
    } catch (e, stackTrace) {
      debugPrint('CAMERA INIT CONTROLLER ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _cameraError = 'Camera initialization failed: $e';
          _cameraLoading = false;
          _cameraReady = false;
        });
      }
    }
  }

  void _handleCameraException(CameraException e) {
    if (!mounted) return;
    final isPermissionDenied = e.code == 'CameraAccessDenied' ||
        e.code == 'CameraAccessDeniedWithoutPrompt' ||
        e.code == 'cameraPermission';

    setState(() {
      _cameraError = isPermissionDenied
          ? 'Camera permission denied.\n\nPlease allow camera access in your device Settings to scan landmarks in real time.'
          : 'Camera error (${e.code}): ${e.description ?? 'Unable to connect to camera'}';
      _cameraLoading = false;
      _cameraReady = false;
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isInitializing) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedImagePath = null;
      _cameraReady = false;
      _cameraLoading = true;
    });

    final targetDir = _isFrontCamera
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    int idx = _cameras.indexWhere((c) => c.lensDirection == targetDir);
    if (idx == -1 && _cameraController != null) {
      idx = (_cameras.indexOf(_cameraController!.description) + 1) % _cameras.length;
    }
    await _initController(idx != -1 ? idx : 0);
  }

  Future<void> _toggleFlash() async {
    if (!_cameraReady || _cameraController == null) return;
    try {
      final next = !_isFlashOn;
      await _cameraController!.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      setState(() => _isFlashOn = next);
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('FLASH TOGGLE ERROR: $e');
    }
  }

  Future<void> _setZoom(double zoom) async {
    if (_cameraReady && _cameraController != null) {
      try {
        await _cameraController!.setZoomLevel(zoom.clamp(_minZoom, _maxZoom));
      } catch (e) {
        debugPrint('ZOOM ERROR: $e');
      }
    }
    setState(() => _currentZoom = zoom);
    HapticFeedback.selectionClick();
  }

  void _onTapFocus(TapDownDetails d, BoxConstraints c) {
    if (_selectedImagePath != null || !_cameraReady || _cameraController == null) return;
    setState(() => _focusPoint = d.localPosition);
    HapticFeedback.selectionClick();

    try {
      final point = Offset(
        (d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0),
        (d.localPosition.dy / c.maxHeight).clamp(0.0, 1.0),
      );
      _cameraController!.setFocusPoint(point);
      _cameraController!.setExposurePoint(point);
    } catch (e) {
      debugPrint('FOCUS SET ERROR: $e');
    }

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  // ────────────────────────────────────────────
  // CAPTURE FLOW (DECOUPLED FROM AI RECOGNITION)
  // ────────────────────────────────────────────
  Future<void> _capture() async {
    if (_isAnalyzing) return;

    // 1. If an image is already in preview, trigger AI analysis on it
    if (_selectedImagePath != null && File(_selectedImagePath!).existsSync()) {
      _runAiAnalysis(
        imagePath: _selectedImagePath!,
        isUpload: _selectedScanType == ScanType.upload,
      );
      return;
    }

    // 2. Camera capture
    if (!_cameraReady || _cameraController == null || !_cameraController!.value.isInitialized) {
      _showSnackbar('Camera is not ready yet. Please wait.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isAnalyzing = true);

    String? capturedPath;
    try {
      final xFile = await _cameraController!.takePicture();
      capturedPath = xFile.path;

      if (!await File(capturedPath).exists()) {
        throw Exception('Captured image file does not exist on disk at $capturedPath');
      }

      debugPrint('CAPTURED IMAGE: $capturedPath');

      setState(() {
        _selectedImagePath = capturedPath;
        _selectedScanType = ScanType.camera;
      });

      // 3. Decoupled Step: Save to persistent History immediately
      final initialItem = await ScanHistoryService.createAndSaveScan(
        rawImagePath: capturedPath,
        scanType: ScanType.camera,
        title: 'Camera Discovery',
        location: 'Pakistan',
      );

      // Refresh history list immediately
      _loadHistory();

      // 4. Run optional AI recognition
      await _runAiAnalysis(
        imagePath: capturedPath,
        isUpload: false,
        existingItem: initialItem,
      );
    } catch (e, stackTrace) {
      debugPrint('CAPTURE ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isAnalyzing = false);
        _showSnackbar('Failed to capture image: $e');
      }
    }
  }

  // ────────────────────────────────────────────
  // GALLERY UPLOAD FLOW (DECOUPLED FROM AI)
  // ────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    if (_isAnalyzing) return;
    HapticFeedback.lightImpact();

    try {
      final XFile? xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      // User cancelled picker
      if (xFile == null || !mounted) {
        debugPrint('GALLERY PICKER: Cancelled by user.');
        return;
      }

      if (!await File(xFile.path).exists()) {
        throw Exception('Picked image file was not found at ${xFile.path}');
      }

      debugPrint('GALLERY IMAGE SELECTED: ${xFile.path}');

      setState(() {
        _selectedImagePath = xFile.path;
        _selectedScanType = ScanType.upload;
        _isAnalyzing = true;
      });

      // Decoupled Step: Save to persistent History immediately
      final initialItem = await ScanHistoryService.createAndSaveScan(
        rawImagePath: xFile.path,
        scanType: ScanType.upload,
        title: 'Gallery Upload',
        location: 'Pakistan',
      );

      // Refresh history UI immediately
      _loadHistory();

      // Run optional AI recognition
      await _runAiAnalysis(
        imagePath: xFile.path,
        isUpload: true,
        existingItem: initialItem,
      );
    } catch (e, stackTrace) {
      debugPrint('GALLERY PICKER ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isAnalyzing = false);
        _showSnackbar('Failed to select image from gallery: $e');
      }
    }
  }

  // ────────────────────────────────────────────
  // AI RECOGNITION (SEPARATE STAGE)
  // ────────────────────────────────────────────
  Future<void> _runAiAnalysis({
    required String imagePath,
    required bool isUpload,
    ScanItem? existingItem,
  }) async {
    try {
      final resultItem = await ScanHistoryService.simulateAiRecognition(
        isUpload: isUpload,
        imagePath: imagePath,
        existingItem: existingItem,
      );

      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
        if (resultItem.imagePath != null) {
          _selectedImagePath = resultItem.imagePath;
        }
      });

      _loadHistory();
      _showResultSheet(resultItem);
    } catch (e, stackTrace) {
      debugPrint('AI ANALYSIS ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isAnalyzing = false);
        _showSnackbar('AI Recognition encountered an issue. Image is saved to History.');
      }
    }
  }

  void _returnToLiveCamera() {
    setState(() => _selectedImagePath = null);
    if (!_cameraReady && _cameras.isNotEmpty) {
      _startCamera();
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ────────────────────────────────────────────
  // HISTORY & BOTTOM SHEETS
  // ────────────────────────────────────────────
  Future<void> _loadHistory() async {
    try {
      final h = await ScanHistoryService.getScanHistory();
      if (mounted) {
        setState(() {
          _history = h;
          _historyLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('HISTORY LOAD ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  void _showResultSheet(ScanItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LandmarkDetailSheet(
        item: item,
        onFavoriteToggle: () async {
          await ScanHistoryService.toggleFavorite(item.id);
          _loadHistory();
        },
      ),
    );
  }

  void _showHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FullHistorySheet(
        history: _history,
        onSelect: (item) {
          Navigator.pop(ctx);
          _showResultSheet(item);
        },
        onClear: () async {
          await ScanHistoryService.clearHistory();
          _loadHistory();
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  // ────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ScanHeader(
                    onHistoryTap: _showHistoryModal,
                    hasHistory: _history.isNotEmpty,
                  ),
                  const SizedBox(height: 14),
                  _buildScannerBox(),
                  const SizedBox(height: 20),
                  _buildControls(),
                  const SizedBox(height: 24),
                  _RecentScansCard(
                    history: _history,
                    isLoading: _historyLoading,
                    onViewAll: _showHistoryModal,
                    onSelect: _showResultSheet,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  // SCANNER CONTAINER WIDGET
  // ────────────────────────────────────────────
  Widget _buildScannerBox() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenH = MediaQuery.of(context).size.height;
    final boxH = min(max(screenH * 0.44, 340.0), 460.0);

    return Container(
      width: double.infinity,
      height: boxH,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1010),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(isDark ? 0.15 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: LayoutBuilder(builder: (ctx, constraints) {
          return Stack(fit: StackFit.expand, children: [
            // ── 1. Content Layer (Live Camera or Selected Image) ──
            _buildCameraContent(constraints),

            // ── 2. Vignette Gradients (top/bottom darkness) ──
            if (_cameraReady || _selectedImagePath != null)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.45),
                        Colors.transparent,
                        Colors.black.withOpacity(0.55),
                      ],
                      stops: const [0, 0.5, 1],
                    ),
                  ),
                ),
              ),

            // ── 3. Corner Reticles ──
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CustomPaint(
                    painter: _ReticlePainter(
                        color: AppTheme.primary, scanning: _isAnalyzing),
                  ),
                ),
              ),
            ),

            // ── 4. Scanning Animated Line ──
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                  child: AnimatedBuilder(
                    animation: _scanAnim,
                    builder: (_, __) => CustomPaint(
                      painter: _ScanLinePainter(
                          progress: _scanAnim.value,
                          color: AppTheme.primary,
                          scanning: _isAnalyzing),
                    ),
                  ),
                ),
              ),
            ),

            // ── 5. Tap-to-Focus Indicator ──
            if (_focusPoint != null && _selectedImagePath == null)
              Positioned(
                left: _focusPoint!.dx - 28,
                top: _focusPoint!.dy - 28,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.4, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  builder: (_, v, __) => Transform.scale(
                    scale: v,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.amberAccent, width: 1.8),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.amberAccent.withOpacity(0.4),
                              blurRadius: 10)
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.add,
                            color: Colors.amberAccent, size: 14),
                      ),
                    ),
                  ),
                ),
              ),

            // ── 6. Top Controls Toolbar ──
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: _buildTopToolbar(),
            ),

            // ── 7. Bottom AI Status Badge ──
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Center(
                child: _AiStatusBadge(
                  scanning: _isAnalyzing,
                  hasPreview: _selectedImagePath != null,
                  pulseScale: _pulseScale,
                  pulseOpacity: _pulseOpacity,
                ),
              ),
            ),
          ]);
        }),
      ),
    );
  }

  // ────────────────────────────────────────────
  // CONTENT LAYER RENDERING
  // ────────────────────────────────────────────
  Widget _buildCameraContent(BoxConstraints constraints) {
    // 1. Captured or gallery image preview takes highest priority
    if (_selectedImagePath != null && File(_selectedImagePath!).existsSync()) {
      return GestureDetector(
        onTapDown: (d) => _onTapFocus(d, constraints),
        child: Image.file(
          File(_selectedImagePath!),
          fit: BoxFit.cover,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        ),
      );
    }

    // 2. Real-time Live CameraPreview
    if (_cameraReady &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      return GestureDetector(
        onTapDown: (d) => _onTapFocus(d, constraints),
        behavior: HitTestBehavior.opaque,
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _cameraController!.value.previewSize != null
                  ? _cameraController!.value.previewSize!.height
                  : constraints.maxWidth,
              height: _cameraController!.value.previewSize != null
                  ? _cameraController!.value.previewSize!.width
                  : constraints.maxHeight,
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),
      );
    }

    // 3. Loading state
    if (_cameraLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                color: AppTheme.primary, strokeWidth: 2.5),
            SizedBox(height: 12),
            Text('Starting camera...',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    // 4. Error / permission denied state
    return Container(
      color: const Color(0xFF101214),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_outlined,
                  color: AppTheme.primary, size: 34),
            ),
            const SizedBox(height: 12),
            const Text(
              'Camera Access Required',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _cameraError ??
                  'Allow camera access to scan real-world landmarks.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 12,
                  height: 1.45),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _startCamera,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry Camera',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopToolbar() {
    if (_selectedImagePath != null) {
      // Show "Return to Live Camera" button
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _returnToLiveCamera,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 8)
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_rounded,
                      color: AppTheme.onPrimary, size: 15),
                  SizedBox(width: 6),
                  Text('Live Camera',
                      style: TextStyle(
                          color: AppTheme.onPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (!_cameraReady) return const SizedBox.shrink();

    // Camera control toolbar
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Flash
        _GlassBtn(
          icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
          active: _isFlashOn,
          onTap: _toggleFlash,
        ),
        // Zoom presets (1x, 2x)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [1.0, 2.0].map((z) {
              final isSelected = _currentZoom == z;
              return GestureDetector(
                onTap: () => _setZoom(z),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('${z.toInt()}x',
                      style: TextStyle(
                          color: isSelected ? AppTheme.onPrimary : Colors.white70,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600)),
                ),
              );
            }).toList(),
          ),
        ),
        // Switch camera (front/back)
        _GlassBtn(
          icon: Icons.flip_camera_ios_rounded,
          active: _isFrontCamera,
          onTap: _cameras.length > 1 ? _switchCamera : () {},
        ),
      ],
    );
  }

  Widget _buildControls() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface =
        isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;

    return Column(
      children: [
        // Capture button
        _CaptureButton(isAnalyzing: _isAnalyzing, onTap: _capture),

        const SizedBox(height: 10),

        Text(
          _isAnalyzing
              ? 'Analyzing Landmark with AI...'
              : _selectedImagePath != null
                  ? 'Tap to analyze selected image'
                  : 'Tap to capture & search',
          style: TextStyle(
              color: onSurface, fontSize: 13, fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 16),

        // Gallery upload button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: Material(
            color: isDark ? surface.withOpacity(0.8) : surface,
            borderRadius: BorderRadius.circular(26),
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: _isAnalyzing ? null : _pickFromGallery,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.35), width: 1.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.photo_library_rounded,
                        size: 20, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    Text(
                      'Upload Picture from Gallery',
                      style: TextStyle(
                          color: onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER COMPONENT
// ─────────────────────────────────────────────────────────────────────────────
class _ScanHeader extends StatelessWidget {
  final VoidCallback onHistoryTap;
  final bool hasHistory;
  const _ScanHeader({required this.onHistoryTap, required this.hasHistory});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;
    final tp = ThemeProviderScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.06)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 10)
                  ],
                ),
                child:
                    Icon(Icons.arrow_back_ios_new_rounded, color: onBg, size: 18),
              ),
            ),
            Row(
              children: [
                if (hasHistory)
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.history_rounded,
                          color: AppTheme.primary, size: 20),
                    ),
                    onPressed: onHistoryTap,
                  ),
                const SizedBox(width: 4),
                ThemeToggle(
                    isDark: tp.isDark, onToggle: () => tp.toggleTheme()),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: AppTheme.primary, size: 14),
                  SizedBox(width: 6),
                  Text('AI VISION',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Landmark & Place Recognition',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: onVar, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Scan n Search',
            style: TextStyle(
                color: onBg,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6)),
        const SizedBox(height: 4),
        Text('"Point your camera at a place and let AI uncover its story."',
            style: TextStyle(
                color: onVar,
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAPTURE BUTTON COMPONENT
// ─────────────────────────────────────────────────────────────────────────────
class _CaptureButton extends StatefulWidget {
  final bool isAnalyzing;
  final VoidCallback onTap;
  const _CaptureButton({required this.isAnalyzing, required this.onTap});

  @override
  State<_CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<_CaptureButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                Border.all(color: AppTheme.primary.withOpacity(0.4), width: 4),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.primary.withOpacity(0.35),
                  blurRadius: 26,
                  spreadRadius: 2,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF739335),
                    AppTheme.primary,
                    Color(0xFF45581E),
                  ],
                ),
              ),
              child: Center(
                child: widget.isAnalyzing
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white)))
                    : const Icon(Icons.center_focus_strong_rounded,
                        color: Colors.white, size: 36),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI STATUS BADGE
// ─────────────────────────────────────────────────────────────────────────────
class _AiStatusBadge extends StatelessWidget {
  final bool scanning;
  final bool hasPreview;
  final Animation<double> pulseScale;
  final Animation<double> pulseOpacity;
  const _AiStatusBadge(
      {required this.scanning,
      required this.hasPreview,
      required this.pulseScale,
      required this.pulseOpacity});

  @override
  Widget build(BuildContext context) {
    final text = scanning
        ? 'Analyzing Landmark with AI...'
        : hasPreview
            ? 'Preview Loaded • Ready to Search'
            : 'AI Scanner Ready • Live';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: scanning ? AppTheme.primary : Colors.white.withOpacity(0.18),
            width: 1.2),
        boxShadow: [
          BoxShadow(
              color: (scanning ? AppTheme.primary : Colors.black)
                  .withOpacity(scanning ? 0.35 : 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulseScale,
            builder: (_, __) => Transform.scale(
              scale: scanning ? 1.0 : pulseScale.value,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scanning ? Colors.amberAccent : AppTheme.primary,
                  boxShadow: [
                    BoxShadow(
                        color: (scanning ? Colors.amberAccent : AppTheme.primary)
                            .withOpacity(pulseOpacity.value),
                        blurRadius: 8,
                        spreadRadius: 2)
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT SCANS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _RecentScansCard extends StatelessWidget {
  final List<ScanItem> history;
  final bool isLoading;
  final VoidCallback onViewAll;
  final ValueChanged<ScanItem> onSelect;
  const _RecentScansCard(
      {required this.history,
      required this.isLoading,
      required this.onViewAll,
      required this.onSelect});

  Widget _thumb(ScanItem item) {
    if (item.imagePath != null && File(item.imagePath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(File(item.imagePath!),
            width: 38, height: 38, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _assetThumb(item)),
      );
    }
    return _assetThumb(item);
  }

  Widget _assetThumb(ScanItem item) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(item.imagePlaceholderAsset,
            width: 38, height: 38, fit: BoxFit.cover),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface =
        isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.history_rounded,
                        color: AppTheme.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text('Recent AI Discoveries',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              if (history.isNotEmpty)
                GestureDetector(
                  onTap: onViewAll,
                  child: const Row(children: [
                    Text('View History',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    SizedBox(width: 3),
                    Icon(Icons.arrow_forward_ios_rounded,
                        color: AppTheme.primary, size: 11),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (isLoading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary)))
          else if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: Text(
                      'No scans yet. Capture a landmark to see its AI story!',
                      style:
                          TextStyle(color: onVar, fontSize: 12.5))),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: history.take(6).length,
                itemBuilder: (_, i) {
                  final item = history[i];
                  return GestureDetector(
                    onTap: () => onSelect(item),
                    child: Container(
                      width: 185,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSurfaceVariant.withValues(alpha: 0.4)
                            : AppTheme.lightSurfaceVariant.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            _thumb(item),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: onSurface,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 2),
                                  Text(
                                      item.scanType == ScanType.camera
                                          ? '📷 Camera'
                                          : '🖼️ Gallery',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.location_on_rounded,
                                color: AppTheme.primary, size: 12),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(item.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: onVar,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LANDMARK DETAIL BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _LandmarkDetailSheet extends StatefulWidget {
  final ScanItem item;
  final VoidCallback onFavoriteToggle;
  const _LandmarkDetailSheet(
      {required this.item, required this.onFavoriteToggle});

  @override
  State<_LandmarkDetailSheet> createState() => _LandmarkDetailSheetState();
}

class _LandmarkDetailSheetState extends State<_LandmarkDetailSheet> {
  bool _audioPlaying = false;

  Widget _heroImage() {
    final item = widget.item;
    if (item.imagePath != null && File(item.imagePath!).existsSync()) {
      return Image.file(File(item.imagePath!),
          height: 190, width: double.infinity, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(item.imagePlaceholderAsset,
              height: 190, width: double.infinity, fit: BoxFit.cover));
    }
    return Image.asset(item.imagePlaceholderAsset,
        height: 190, width: double.infinity, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onS = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onV = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;
    final item = widget.item;

    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
              blurRadius: 30,
              offset: const Offset(0, -5))
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                  color: onV.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(children: [
                    _heroImage(),
                    Container(
                        height: 190,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.75)
                            ]))),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: AppTheme.primary.withOpacity(0.4),
                                blurRadius: 10)
                          ],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.verified_rounded,
                              color: AppTheme.onPrimary, size: 14),
                          const SizedBox(width: 5),
                          Text(
                              '${(item.confidenceScore * 100).toStringAsFixed(1)}% Match',
                              style: const TextStyle(
                                  color: AppTheme.onPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: widget.onFavoriteToggle,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              shape: BoxShape.circle),
                          child: Icon(
                              item.isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: item.isFavorite
                                  ? Colors.redAccent
                                  : Colors.white,
                              size: 20),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 14,
                      left: 14,
                      right: 14,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.category.toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6)),
                            const SizedBox(height: 2),
                            Text(item.title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900)),
                          ]),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                Row(children: [
                  const Icon(Icons.location_on_rounded,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(item.location,
                          style: TextStyle(
                              color: onV,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600))),
                ]),

                const SizedBox(height: 16),

                // Audio tour preview bar
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.primary.withOpacity(0.12)
                        : AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () {
                        setState(() => _audioPlaying = !_audioPlaying);
                        HapticFeedback.lightImpact();
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                            color: AppTheme.primary, shape: BoxShape.circle),
                        child: Icon(
                            _audioPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: AppTheme.onPrimary,
                            size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              _audioPlaying
                                  ? 'Playing AI Voice Guide...'
                                  : 'Listen to AI Audio Story',
                              style: TextStyle(
                                  color: onS,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('2-min narrated summary with cultural lore',
                              style: TextStyle(color: onV, fontSize: 11)),
                        ])),
                    const Icon(Icons.headphones_rounded,
                        color: AppTheme.primary, size: 20),
                  ]),
                ),

                const SizedBox(height: 20),

                Text('Uncovered AI Story',
                    style: TextStyle(
                        color: onS,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                    item.historicalStory.isNotEmpty
                        ? item.historicalStory
                        : item.shortDescription,
                    style:
                        TextStyle(color: onS, fontSize: 13.5, height: 1.5)),

                if (item.keyFacts.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Key Facts & Architecture',
                      style: TextStyle(
                          color: onS,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ...item.keyFacts.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900)),
                              Expanded(
                                  child: Text(f,
                                      style: TextStyle(
                                          color: onV,
                                          fontSize: 13,
                                          height: 1.35))),
                            ]),
                      )),
                ],

                if (item.recommendedActivities.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('Top Things to Do',
                      style: TextStyle(
                          color: onS,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ...item.recommendedActivities.map((a) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkSurfaceVariant.withOpacity(0.4)
                              : AppTheme.lightSurfaceVariant.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle_outline_rounded,
                              color: AppTheme.primary, size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(a,
                                  style: TextStyle(
                                      color: onS,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600))),
                        ]),
                      )),
                ],

                const SizedBox(height: 18),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceVariant.withOpacity(0.3)
                        : AppTheme.lightSurfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    const Icon(Icons.wb_sunny_outlined,
                        color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Best Time to Visit',
                              style: TextStyle(
                                  color: onV,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(item.bestTimeToVisit,
                              style: TextStyle(
                                  color: onS,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600)),
                        ])),
                  ]),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AiTourPlanningScreen()));
                    },
                    icon: const Icon(Icons.map_rounded),
                    label: Text('Plan Tour with ${item.title}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FULL HISTORY SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _FullHistorySheet extends StatelessWidget {
  final List<ScanItem> history;
  final ValueChanged<ScanItem> onSelect;
  final VoidCallback onClear;
  const _FullHistorySheet(
      {required this.history, required this.onSelect, required this.onClear});

  Widget _thumb(ScanItem item) {
    if (item.imagePath != null && File(item.imagePath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(File(item.imagePath!),
            width: 44, height: 44, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _asset(item)),
      );
    }
    return _asset(item);
  }

  Widget _asset(ScanItem item) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(item.imagePlaceholderAsset,
            width: 44, height: 44, fit: BoxFit.cover),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onS = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onV = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                  color: onV.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Scan n Search History',
                  style: TextStyle(
                      color: onS,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              if (history.isNotEmpty)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 16, color: Colors.redAccent),
                  label: const Text('Clear All',
                      style: TextStyle(
                          color: Colors.redAccent, fontSize: 12)),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: history.isEmpty
              ? Center(
                  child: Text('No scan history yet',
                      style: TextStyle(color: onV)))
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: history.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final item = history[i];
                    return ListTile(
                      onTap: () => onSelect(item),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      tileColor: isDark
                          ? AppTheme.darkSurfaceVariant.withOpacity(0.4)
                          : AppTheme.lightSurfaceVariant.withOpacity(0.6),
                      leading: _thumb(item),
                      title: Text(item.title,
                          style: TextStyle(
                              color: onS,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      subtitle: Text(
                          '${item.location} • ${item.scanType == ScanType.camera ? 'Camera' : 'Gallery'}',
                          style:
                              TextStyle(color: onV, fontSize: 11.5)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded,
                          color: AppTheme.primary, size: 14),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI UTILITY WIDGETS & PAINTERS
// ─────────────────────────────────────────────────────────────────────────────
class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _GlassBtn(
      {required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              active ? AppTheme.primary : Colors.black.withOpacity(0.55),
          border: Border.all(
              color: active
                  ? AppTheme.primary
                  : Colors.white.withOpacity(0.18)),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: AppTheme.primary.withOpacity(0.5),
                      blurRadius: 12)
                ]
              : [],
        ),
        child: Icon(icon,
            color: active ? AppTheme.onPrimary : Colors.white, size: 20),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final Color color;
  final bool scanning;
  _ReticlePainter({required this.color, required this.scanning});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = scanning ? Colors.amberAccent : color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const L = 28.0;
    canvas.drawLine(Offset.zero, const Offset(L, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, L), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - L, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, L), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(L, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(0, size.height - L), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - L, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - L), paint);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter old) =>
      old.scanning != scanning;
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool scanning;
  _ScanLinePainter(
      {required this.progress, required this.color, required this.scanning});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final c = scanning ? Colors.amberAccent : color;

    final line = Paint()
      ..shader = LinearGradient(colors: [
        Colors.transparent,
        c.withOpacity(0.9),
        Colors.white,
        c.withOpacity(0.9),
        Colors.transparent,
      ], stops: const [
        0,
        0.25,
        0.5,
        0.75,
        1
      ]).createShader(Rect.fromLTWH(0, y - 2, size.width, 4))
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), line);

    final glow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [c.withOpacity(0.25), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, y - 30, size.width, 30));

    canvas.drawRect(Rect.fromLTWH(0, y - 30, size.width, 30), glow);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter old) =>
      old.progress != progress || old.scanning != scanning;
}
