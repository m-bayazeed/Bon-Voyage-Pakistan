import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/translation_model.dart';
import '../services/translation_history_service.dart';
import '../services/translation_service.dart';
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
    this.initialSourceCode = 'en',
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

  // Translation State
  String _translatedText = 'ٹائپ کریں یا بولیں...';
  String _romanizedPronunciation = 'Type karein ya bolein...';
  bool _isTranslating = false;
  bool _isListening = false;
  bool _isPlayingAudio = false;
  bool _hasUserInput = false;
  List<String> _aiAlternatives = [];

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
      duration: const Duration(milliseconds: 1500),
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

    if (_hasUserInput) {
      _performTranslation();
    }
  }

  @override
  void dispose() {
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
      final temp = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = temp;

      if (_hasUserInput && _translatedText != 'ٹائپ کریں یا بولیں...') {
        _inputController.text = _translatedText;
        _performTranslation();
      }
    });
  }

  // ──────────────────────────────────────────────
  // Translation Core
  // ──────────────────────────────────────────────
  Future<void> _performTranslation() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _translatedText = _targetLanguage.code == 'ur'
            ? 'ٹائپ کریں یا بولیں...'
            : 'Type or speak...';
        _romanizedPronunciation = '';
        _aiAlternatives = [];
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

    // Generate alternatives
    final alternatives = _generateAlternatives(text, translated);

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
      _aiAlternatives = alternatives;
      _isTranslating = false;
    });
  }

  List<String> _generateAlternatives(String text, String translated) {
    if (_targetLanguage.code == 'ur') {
      return [
        'روایتی انداز: $translated',
        'مختصر و شائستہ: براہ کرم رہنمائی فرمائیں۔',
        'عام بول چال: کیا یہ ممکن ہے؟',
      ];
    } else {
      return [
        'Formal: Would you kindly assist me with this?',
        'Casual: Can you help me out with this?',
        'Quick Tourist: Excuse me, how much for this?',
      ];
    }
  }

  // ──────────────────────────────────────────────
  // Mic Voice Input Simulation
  // ──────────────────────────────────────────────
  Future<void> _handleMicPress() async {
    if (_isListening) {
      _stopListening();
      return;
    }

    setState(() => _isListening = true);
    _pulseController.repeat(reverse: true);

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    _stopListening();

    final samples = [
      'Where is the best scenic view of Rakaposhi Mountain?',
      'How much does a round trip jeep to Attabad Lake cost?',
      'Can you please recommend clean traditional food here?',
      'Thank you so much for your warm hospitality!',
      'Where can I find pure bottled drinking water?',
    ];
    final picked = samples[DateTime.now().second % samples.length];

    _inputController.text = picked;
    _performTranslation();
  }

  void _stopListening() {
    if (mounted) {
      setState(() => _isListening = false);
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  // ──────────────────────────────────────────────
  // Audio Playback Simulation
  // ──────────────────────────────────────────────
  Future<void> _playAudio() async {
    if (_translatedText.isEmpty || _isPlayingAudio) return;

    setState(() => _isPlayingAudio = true);
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() => _isPlayingAudio = false);
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
      _aiAlternatives = [];
    });
  }

  // ──────────────────────────────────────────────
  // AI Alternatives Modal
  // ──────────────────────────────────────────────
  void _showAlternativesSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVariant = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final containerColor = isDark ? const Color(0xFF282A2A) : const Color(0xFFF0F2F5);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(top: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'AI Tone & Context Variations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_aiAlternatives.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Type or speak a phrase first to see intelligent variations.',
                      style: TextStyle(color: onVariant, fontSize: 13),
                    ),
                  ),
                )
              else
                ..._aiAlternatives.map((alt) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: onVariant.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            alt,
                            style: TextStyle(color: onSurface, fontSize: 14, height: 1.3),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: AppTheme.primary, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: alt));
                            Navigator.pop(sheetContext);
                          },
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = TranslationService.supportedLanguages.where((l) {
              final q = query.toLowerCase();
              return l.name.toLowerCase().contains(q) || l.nativeName.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
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
                    isSource ? 'Select Source Language' : 'Select Target Language',
                    style: TextStyle(color: onSurface, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) => setSheetState(() => query = val),
                    style: TextStyle(color: onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search (e.g. Urdu, English, Pashto)...',
                      hintStyle: TextStyle(color: onVariant),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary, size: 20),
                      filled: true,
                      fillColor: containerColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
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
                              if (lang.isPakistaniRegional) ...[
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
                          subtitle: Text(lang.nativeName, style: TextStyle(color: onVariant, fontSize: 13)),
                          trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary) : null,
                          onTap: () {
                            setState(() {
                              if (isSource) {
                                _sourceLanguage = lang;
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
  // 1. TOP APP BAR (Back Button + PakTravel AI + ThemeToggle)
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

          // ── Big Pulsing Microphone Button ──
          _buildBigMicButton(isDark),

          const SizedBox(height: 24),
        ],
      ),
    );
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  Flexible(
                    child: Text(
                      _sourceLanguage.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.expand_more_rounded, color: onVariant, size: 20),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Swap Circular Button
        RotationTransition(
          turns: _swapAnimController,
          child: GestureDetector(
            onTap: _swapLanguages,
            child: Container(
              width: 48,
              height: 48,
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
                size: 24,
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Target Pill
        Expanded(
          child: GestureDetector(
            onTap: () => _openLanguagePicker(isSource: false),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  Flexible(
                    child: Text(
                      _targetLanguage.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.expand_more_rounded, color: AppTheme.primary, size: 20),
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
            onChanged: (_) => _performTranslation(),
          ),
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
                      icon: const Icon(Icons.close_rounded, color: AppTheme.primary, size: 20),
                      onPressed: _clearInput,
                    ),
                  IconButton(
                    icon: Icon(_isListening ? Icons.stop_circle_rounded : Icons.mic_rounded, color: AppTheme.primary, size: 20),
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

  // ── Translated Card (with AppTheme.primary) ──
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
          Align(
            alignment: _targetLanguage.code == 'ur' ? Alignment.centerRight : Alignment.centerLeft,
            child: _isTranslating
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Translating...',
                        style: TextStyle(color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
                : Text(
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
            Text(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // AI Alternatives trigger
              GestureDetector(
                onTap: _showAlternativesSheet,
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'AI Alternatives',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions (Copy, Audio Speaker)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.content_copy_rounded, color: AppTheme.primary, size: 20),
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
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
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
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF739335),
                AppTheme.primary,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.35),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.mic_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}
