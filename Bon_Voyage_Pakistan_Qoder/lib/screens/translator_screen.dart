import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/translation_model.dart';
import '../services/translation_history_service.dart';
import '../services/translation_service.dart';
import '../services/translator_audio_handler.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/theme_toggle.dart';

class TranslatorScreen extends StatefulWidget {
  final String? initialText;
  final String initialSourceCode;
  final String initialTargetCode;

  const TranslatorScreen({
    super.key,
    this.initialText,
    this.initialSourceCode = 'auto',
    this.initialTargetCode = 'ur',
  });

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen>
    with TickerProviderStateMixin {
  // Selected Languages
  late LanguageOption _sourceLanguage;
  late LanguageOption _targetLanguage;

  // Controllers
  final TextEditingController _inputController = TextEditingController();

  // Audio controller
  final TranslatorAudioHandler _audioHandler = TranslatorAudioHandler();
  String _currentAudioBase64 = '';

  // Translation State
  String _translatedText = 'ٹائپ کریں یا بولیں...';
  String _romanizedPronunciation = 'Type karein ya bolein...';
  String _sourceRomanizedPronunciation = '';
  String _detectedLanguage = '';
  bool _isTranslating = false;
  bool _isListening = false;
  bool _isPlayingAudio = false;
  bool _hasUserInput = false;

  // Animations
  late AnimationController _swapAnimController;
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();

    _sourceLanguage = TranslationService.getLanguage(widget.initialSourceCode);
    _targetLanguage = TranslationService.getLanguage(widget.initialTargetCode);

    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _inputController.text = widget.initialText!;
      _hasUserInput = true;
    }

    _swapAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseScale = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _hasUserInput) {
        setState(() {
          _hasUserInput = hasText;
        });
      }
    });

    _audioHandler.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    });

    if (_hasUserInput) {
      _performTranslation();
    }
  }

  @override
  void dispose() {
    _audioHandler.dispose();
    _swapAnimController.dispose();
    _pulseController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // Language Swap
  // ──────────────────────────────────────────────
  void _swapLanguages() {
    _swapAnimController.forward(from: 0);
    setState(() {
      if (_sourceLanguage.code == 'auto') {
        // When swapping from auto, set source to current target and toggle target between Urdu and English
        if (_targetLanguage.code == 'ur') {
          _sourceLanguage = TranslationService.getLanguage('ur');
          _targetLanguage = TranslationService.getLanguage('en');
        } else {
          _sourceLanguage = TranslationService.getLanguage('en');
          _targetLanguage = TranslationService.getLanguage('ur');
        }
      } else {
        final previousSource = _sourceLanguage;
        _sourceLanguage = _targetLanguage;
        // Output language must be either Urdu or English
        _targetLanguage = (previousSource.code == 'ur' || previousSource.code == 'en')
            ? previousSource
            : TranslationService.getLanguage('ur');
      }

      final tempRom = _romanizedPronunciation;
      _romanizedPronunciation = _sourceRomanizedPronunciation;
      _sourceRomanizedPronunciation = tempRom;
      _detectedLanguage = '';

      if (_hasUserInput &&
          _translatedText != 'ٹائپ کریں یا بولیں...' &&
          _translatedText != 'Type or speak...') {
        _inputController.text = _translatedText;
        _performTranslation();
      }
    });
  }

  // ──────────────────────────────────────────────
  // Translation Core (Text)
  // ──────────────────────────────────────────────
  Future<void> _performTranslation() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _translatedText = _targetLanguage.code == 'ur'
            ? 'ٹائپ کریں یا بولیں...'
            : 'Type or speak...';
        _romanizedPronunciation = '';
        _sourceRomanizedPronunciation = '';
        _currentAudioBase64 = '';
        _detectedLanguage = '';
      });
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    final result = await TranslationService.translateText(
      text: text,
      sourceCode: _sourceLanguage.code,
      targetCode: _targetLanguage.code,
    );

    if (!mounted) return;

    final translated = result['translated'] ?? '';
    final romanized = result['romanized'] ?? '';
    final sourceRomanized = result['source_romanized'] ?? '';
    final audioBase64 = result['audio_base64'] ?? '';
    final detected = result['detected_language'] ?? '';

    // Save to history
    final item = TranslationItem(
      id: 'TRANS-${DateTime.now().millisecondsSinceEpoch}',
      sourceText: text,
      translatedText: translated,
      romanizedPronunciation: romanized,
      sourceLanguageCode: _sourceLanguage.code,
      targetLanguageCode: _targetLanguage.code,
      timestamp: DateTime.now(),
    );
    await TranslationHistoryService.saveTranslation(item);

    setState(() {
      _translatedText = translated;
      _romanizedPronunciation = romanized;
      _sourceRomanizedPronunciation = sourceRomanized;
      _currentAudioBase64 = audioBase64;
      if (detected.isNotEmpty) {
        _detectedLanguage = detected;
      }
      _isTranslating = false;
    });
  }

  // ──────────────────────────────────────────────
  // Real-Time Microphone Voice Input & Speech-to-Text
  // ──────────────────────────────────────────────
  Future<void> _handleMicPress() async {
    if (_audioHandler.isRecording) {
      await _stopRecordingAndTranslate();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      await _audioHandler.startRecording();
      setState(() {
        _isListening = true;
      });
      _pulseController.repeat(reverse: true);
    } catch (e) {
      debugPrint('Error starting microphone recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _stopRecordingAndTranslate() async {
    String? recordedPath;
    try {
      recordedPath = await _audioHandler.stopRecording();
      _stopListeningAnimation();

      if (recordedPath == null || recordedPath.isEmpty) return;

      setState(() {
        _isTranslating = true;
      });

      final result = await TranslationService.translateVoiceFile(
        filePath: recordedPath,
        sourceCode: _sourceLanguage.code,
        targetCode: _targetLanguage.code,
      );

      // Clean up temporary audio file after upload
      await TranslatorAudioHandler.cleanupTempFile(recordedPath);

      if (!mounted) return;

      final transcript = result['transcript'] ?? '';
      final translated = result['translated'] ?? '';
      final romanized = result['romanized'] ?? '';
      final sourceRomanized = result['source_romanized'] ?? '';
      final audioBase64 = result['audio_base64'] ?? '';
      final detected = result['detected_language'] ?? '';

      if (transcript.isNotEmpty) {
        _inputController.text = transcript;
      }

      setState(() {
        _translatedText = translated;
        _romanizedPronunciation = romanized;
        _sourceRomanizedPronunciation = sourceRomanized;
        _currentAudioBase64 = audioBase64;
        if (detected.isNotEmpty) {
          _detectedLanguage = detected;
        }
        _isTranslating = false;
      });

      if (_sourceLanguage.code == 'auto' && detected.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppTheme.onPrimary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Detected spoken language: $detected',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.onPrimary),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }

      if (audioBase64.isNotEmpty) {
        setState(() => _isPlayingAudio = true);
        await _audioHandler.playBase64Audio(audioBase64);
      }
    } catch (e) {
      debugPrint('Error in voice translation: $e');
      if (recordedPath != null) {
        await TranslatorAudioHandler.cleanupTempFile(recordedPath);
      }
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice translation failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _stopListeningAnimation() {
    if (mounted) {
      setState(() => _isListening = false);
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  // ──────────────────────────────────────────────
  // Real Audio Playback (Edge-TTS Base64)
  // ──────────────────────────────────────────────
  Future<void> _playAudio() async {
    if (_isPlayingAudio) {
      await _audioHandler.stopPlayback();
      setState(() => _isPlayingAudio = false);
      return;
    }

    if (_currentAudioBase64.isNotEmpty) {
      try {
        setState(() => _isPlayingAudio = true);
        await _audioHandler.playBase64Audio(_currentAudioBase64);
      } catch (e) {
        if (mounted) setState(() => _isPlayingAudio = false);
      }
      return;
    }

    final cleanText = _translatedText.trim();
    if (cleanText.isEmpty || cleanText.contains('...')) return;

    setState(() => _isPlayingAudio = true);

    try {
      final b64 = await TranslationService.synthesizeSpeech(
        text: cleanText,
        languageCode: _targetLanguage.code,
      );

      if (!mounted) return;

      if (b64.isNotEmpty) {
        _currentAudioBase64 = b64;
        await _audioHandler.playBase64Audio(b64);
      } else {
        setState(() => _isPlayingAudio = false);
      }
    } catch (e) {
      debugPrint('Audio synthesis error: $e');
      if (mounted) setState(() => _isPlayingAudio = false);
    }
  }

  // ──────────────────────────────────────────────
  // Clipboard
  // ──────────────────────────────────────────────
  void _copyTranslation() {
    if (_translatedText.isEmpty || _translatedText.contains('...')) return;
    Clipboard.setData(ClipboardData(text: _translatedText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
            SizedBox(width: 10),
            Text('Copied translation to clipboard', style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: const Color(0xFF1E2020),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _clearInput() {
    _inputController.clear();
    setState(() {
      _translatedText = _targetLanguage.code == 'ur'
          ? 'ٹائپ کریں یا بولیں...'
          : 'Type or speak...';
      _romanizedPronunciation = '';
      _sourceRomanizedPronunciation = '';
      _currentAudioBase64 = '';
      _detectedLanguage = '';
    });
  }

  // ──────────────────────────────────────────────
  // Language Picker Bottom Sheet
  // ──────────────────────────────────────────────
  void _openLanguagePicker({required bool isSource}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVariant = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final containerColor = isDark ? const Color(0xFF282A2A) : const Color(0xFFF0F2F5);

    // Source languages has Auto Detect + all global languages
    // Output target language ONLY has Urdu and English
    final availableLanguages = isSource
        ? TranslationService.sourceLanguages
        : TranslationService.targetLanguages;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = availableLanguages.where((l) {
              final q = query.toLowerCase();
              return l.name.toLowerCase().contains(q) || l.nativeName.toLowerCase().contains(q);
            }).toList();

            final sheetHeight = isSource
                ? MediaQuery.of(context).size.height * 0.72
                : 260.0;

            return Container(
              height: sheetHeight,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border(top: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: onVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isSource ? 'Select Source Language' : 'Select Output Language',
                    style: TextStyle(color: onSurface, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  if (isSource) ...[
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (val) => setSheetState(() => query = val),
                      style: TextStyle(color: onSurface, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search (e.g. Urdu, English, French)...',
                        hintStyle: TextStyle(color: onVariant),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary, size: 20),
                        filled: true,
                        fillColor: containerColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: onVariant.withValues(alpha: 0.1)),
                      itemBuilder: (context, index) {
                        final lang = filtered[index];
                        final isSelected = isSource
                            ? _sourceLanguage.code == lang.code
                            : _targetLanguage.code == lang.code;

                        final isAuto = lang.code == 'auto';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: Text(lang.flag, style: const TextStyle(fontSize: 24)),
                          title: Row(
                            children: [
                              Text(
                                lang.name,
                                style: TextStyle(
                                  color: isSelected ? AppTheme.primary : onSurface,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              if (isAuto) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'AUTO',
                                    style: TextStyle(color: AppTheme.primary, fontSize: 9, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ] else if (lang.isPakistaniRegional) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'PAKISTAN',
                                    style: TextStyle(color: AppTheme.primary, fontSize: 9, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            isAuto ? 'Automatically detect input language' : lang.nativeName,
                            style: TextStyle(color: onVariant, fontSize: 13),
                          ),
                          trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary) : null,
                          onTap: () {
                            setState(() {
                              if (isSource) {
                                _sourceLanguage = lang;
                                _detectedLanguage = '';
                              } else {
                                _targetLanguage = lang;
                              }
                            });
                            Navigator.pop(sheetContext);
                            if (_hasUserInput) {
                              _performTranslation();
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────
  // BUILD METHOD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top App Bar (Back Button on left, Brand Title, ThemeToggle on right) ──
            _buildTopAppBar(isDark),

            // ── Main Canvas (Scrollable so it never overflows) ──
            Expanded(
              child: _buildMainTranslatorView(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 1. TOP APP BAR
  // ──────────────────────────────────────────────
  Widget _buildTopAppBar(bool isDark) {
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final themeProvider = ThemeProviderScope.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Left Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: onBg,
                size: 18,
              ),
            ),
          ),

          // Brand Title
          const Text(
            'Bon Voyage Pakistan',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),

          // Top Right Dark / Light Mode Toggle Button
          ThemeToggle(
            isDark: themeProvider.isDark,
            onToggle: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 2. MAIN TRANSLATOR CANVAS
  // ──────────────────────────────────────────────
  Widget _buildMainTranslatorView(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          // ── Language Selection Header ──
          _buildLanguageSelectionHeader(isDark),

          const SizedBox(height: 18),

          // ── Source Input Box ──
          _buildSourceCard(isDark),

          const SizedBox(height: 18),

          // ── Translated Result Box ──
          _buildTranslatedCard(isDark),

          const SizedBox(height: 32),

          // ── Big Pulsing Microphone Button (Real Recording) ──
          _buildBigMicButton(isDark),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _getFlagForLanguage(String langName) {
    final lower = langName.toLowerCase().trim();
    if (lower.contains('urdu') ||
        lower.contains('pakistan') ||
        lower.contains('punjabi') ||
        lower.contains('pashto') ||
        lower.contains('sindhi') ||
        lower.contains('balochi') ||
        lower.contains('kashmiri') ||
        lower.contains('shina') ||
        lower.contains('balti')) {
      return '🇵🇰';
    }
    if (lower.contains('english')) return '🇬🇧';
    if (lower.contains('arabic')) return '🇸🇦';
    if (lower.contains('french')) return '🇫🇷';
    if (lower.contains('german')) return '🇩🇪';
    if (lower.contains('chinese')) return '🇨🇳';
    if (lower.contains('spanish')) return '🇪🇸';
    if (lower.contains('russian')) return '🇷🇺';
    if (lower.contains('hindi')) return '🇮🇳';
    if (lower.contains('persian') || lower.contains('farsi')) return '🇮🇷';
    if (lower.contains('turkish')) return '🇹🇷';
    if (lower.contains('italian')) return '🇮🇹';
    if (lower.contains('japanese')) return '🇯🇵';
    return '🌐';
  }

  String _getSourceFlag() {
    if (_sourceLanguage.code == 'auto' && _detectedLanguage.isNotEmpty && _hasUserInput) {
      return _getFlagForLanguage(_detectedLanguage);
    }
    return _sourceLanguage.flag;
  }

  // ── Source Title on Face of Dropdown ──
  String _getSourcePillTitle() {
    if (_sourceLanguage.code == 'auto') {
      if (_detectedLanguage.isNotEmpty && _hasUserInput) {
        return 'Auto: $_detectedLanguage';
      }
      return 'Auto Detect';
    }
    return _sourceLanguage.name;
  }

  // ── Language Selection Row ──
  Widget _buildLanguageSelectionHeader(bool isDark) {
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVariant = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    return Row(
      children: [
        // Source Pill
        Expanded(
          child: GestureDetector(
            onTap: () => _openLanguagePicker(isSource: true),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_getSourceFlag(), style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _getSourcePillTitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more_rounded, color: onVariant, size: 18),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Swap Circular Button
        RotationTransition(
          turns: _swapAnimController,
          child: GestureDetector(
            onTap: _swapLanguages,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: AppTheme.primary,
                size: 22,
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Target Pill
        Expanded(
          child: GestureDetector(
            onTap: () => _openLanguagePicker(isSource: false),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: isDark ? 0.1 : 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_targetLanguage.flag, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _targetLanguage.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more_rounded, color: AppTheme.primary, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Source Card ──
  Widget _buildSourceCard(bool isDark) {
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVariant = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    return Container(
      constraints: const BoxConstraints(minHeight: 160),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_sourceLanguage.code == 'auto' && _detectedLanguage.isNotEmpty && _hasUserInput) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    'Detected Language: $_detectedLanguage',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
          TextField(
            controller: _inputController,
            maxLines: 4,
            minLines: 3,
            style: TextStyle(
              color: onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
            decoration: InputDecoration(
              hintText: 'Type or speak...',
              hintStyle: TextStyle(
                color: onVariant.withValues(alpha: 0.6),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: (_) => _performTranslation(),
          ),
          if (_sourceRomanizedPronunciation.isNotEmpty && _hasUserInput) ...[
            const SizedBox(height: 8),
            SelectableText(
              '🗣️ $_sourceRomanizedPronunciation',
              style: TextStyle(
                color: onVariant,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_inputController.text.length} / 5000',
                style: TextStyle(color: onVariant, fontSize: 12),
              ),
              Row(
                children: [
                  if (_hasUserInput)
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppTheme.primary, size: 20),
                      tooltip: 'Translate',
                      onPressed: _performTranslation,
                    ),
                  if (_hasUserInput)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.primary, size: 20),
                      tooltip: 'Clear',
                      onPressed: _clearInput,
                    ),
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                      color: _isListening ? Colors.redAccent : AppTheme.primary,
                      size: 22,
                    ),
                    tooltip: _isListening ? 'Stop recording' : 'Record voice',
                    onPressed: _handleMicPress,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Translated Card ──
  Widget _buildTranslatedCard(bool isDark) {
    final onVariant = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    return Container(
      constraints: const BoxConstraints(minHeight: 160),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_sourceLanguage.code == 'auto' && _detectedLanguage.isNotEmpty && _hasUserInput && !_isTranslating) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_detectedLanguage  ➔  ${_targetLanguage.name}',
                  style: TextStyle(
                    color: onVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          Align(
            alignment: _targetLanguage.code == 'ur' ? Alignment.centerRight : Alignment.centerLeft,
            child: _isTranslating
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Translating with AI...',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                : SelectableText(
                    _translatedText,
                    textDirection: _targetLanguage.code == 'ur' ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
          ),
          if (_romanizedPronunciation.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              '🗣️ $_romanizedPronunciation',
              style: TextStyle(
                color: onVariant,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.content_copy_rounded, color: AppTheme.primary, size: 20),
                tooltip: 'Copy',
                onPressed: _copyTranslation,
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _playAudio,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlayingAudio ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                    color: _isPlayingAudio ? Colors.greenAccent : AppTheme.primary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Big Pulsing Microphone Button ──
  Widget _buildBigMicButton(bool isDark) {
    return ScaleTransition(
      scale: _isListening ? _pulseScale : const AlwaysStoppedAnimation(1.0),
      child: GestureDetector(
        onTap: _handleMicPress,
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _isListening
                  ? [
                      const Color(0xFFE53935),
                      const Color(0xFFC62828),
                    ]
                  : [
                      const Color(0xFF739335),
                      AppTheme.primary,
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: (_isListening ? Colors.redAccent : AppTheme.primary).withValues(alpha: 0.35),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              _isListening ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}
