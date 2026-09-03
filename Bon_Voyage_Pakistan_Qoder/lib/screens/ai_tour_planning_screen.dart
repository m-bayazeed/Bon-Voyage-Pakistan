import 'package:flutter/material.dart';
import '../models/trip_checklist_item_model.dart';
import '../models/trip_plan_model.dart';
import '../services/trip_checklist_service.dart';
import '../services/trip_history_service.dart';
import '../services/trip_api_service.dart';
import '../widgets/formatted_ai_text.dart';
import '../theme/app_theme.dart';
import 'trip_checklist_screen.dart';


/// Screen state modes: 0 = Form, 1 = AI Chat Planning, 2 = Saved Trip History
enum AiPlanningMode { form, chat, history }

class AiTourPlanningScreen extends StatefulWidget {
  final TripPlan? initialPlan;
  final bool openHistoryDirectly;

  const AiTourPlanningScreen({
    super.key,
    this.initialPlan,
    this.openHistoryDirectly = false,
  });

  @override
  State<AiTourPlanningScreen> createState() => _AiTourPlanningScreenState();
}

class _AiTourPlanningScreenState extends State<AiTourPlanningScreen>
    with TickerProviderStateMixin {
  late AiPlanningMode _currentMode;

  // ── Form Inputs ──
  String _selectedDeparting = 'Islamabad';
  String _selectedDestination = 'Hunza Valley';
  bool _isCustomDeparting = false;
  bool _isCustomDestination = false;

  final TextEditingController _customDepartingController = TextEditingController();
  final TextEditingController _customDestinationController = TextEditingController();
  final TextEditingController _specialReqsController = TextEditingController();

  int _days = 5;

  final Set<String> _selectedInterests = {
    'Nature & Lakes',
    'Mountain Adventure',
    'Photography & Stargazing',
  };

  bool _isGenerating = false;

  // ── Chat State ──
  TripPlan? _activeTripPlan;
  final List<ChatMessage> _chatMessages = [];
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isAiReplying = false;

  // ── History State ──
  List<TripPlan> _savedPlans = [];
  bool _isLoadingHistory = false;

  // ── Animations ──
  late AnimationController _modeTransitionController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ── Preset Dropdown Data ──
  static const String otherOption = 'Other (Enter Custom)';

  final List<String> _popularDepartingCities = [
    'Islamabad',
    'Rawalpindi',
    'Lahore',
    'Karachi',
    'Peshawar',
    'Multan',
    'Faisalabad',
    'Quetta',
    'Sialkot',
    'Gilgit',
    otherOption,
  ];

  final List<String> _popularDestinations = [
    'Hunza Valley',
    'Skardu & Deosai',
    'Swat & Kalam',
    'Naran & Kaghan',
    'Fairy Meadows',
    'Neelum Valley AJK',
    'Gwadar & Makran',
    'Lahore Heritage',
    'Kumrat Valley',
    'Chitral & Kalash',
    otherOption,
  ];

  final List<Map<String, dynamic>> _interestsList = [
    {'name': 'Nature & Lakes', 'icon': Icons.eco_rounded},
    {'name': 'Mountain Adventure', 'icon': Icons.terrain_rounded},
    {'name': 'History & Heritage', 'icon': Icons.museum_rounded},
    {'name': 'Local Cuisine & Food', 'icon': Icons.restaurant_rounded},
    {'name': 'Cultural Festivals', 'icon': Icons.celebration_rounded},
    {'name': 'Photography & Stargazing', 'icon': Icons.camera_alt_rounded},
    {'name': 'Luxury & Wellness', 'icon': Icons.spa_rounded},
    {'name': 'Trekking & Camping', 'icon': Icons.nights_stay_rounded},
  ];

  @override
  void initState() {
    super.initState();

    _currentMode = widget.openHistoryDirectly
        ? AiPlanningMode.history
        : (widget.initialPlan != null ? AiPlanningMode.chat : AiPlanningMode.form);

    _modeTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _modeTransitionController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _modeTransitionController,
      curve: Curves.easeOutCubic,
    ));

    _modeTransitionController.forward();

    if (widget.initialPlan != null) {
      _activeTripPlan = widget.initialPlan;
      _initChatWithPlan(widget.initialPlan!);
    }

    _loadSavedPlans();
  }

  @override
  void dispose() {
    _modeTransitionController.dispose();
    _customDepartingController.dispose();
    _customDestinationController.dispose();
    _specialReqsController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPlans() async {
    setState(() => _isLoadingHistory = true);
    final plans = await TripHistoryService.getSavedTripPlans();
    if (mounted) {
      setState(() {
        _savedPlans = plans;
        _isLoadingHistory = false;
      });
    }
  }

  void _switchMode(AiPlanningMode newMode) {
    if (_currentMode == newMode) return;
    _modeTransitionController.reverse().then((_) {
      setState(() => _currentMode = newMode);
      _modeTransitionController.forward();
      if (newMode == AiPlanningMode.history) {
        _loadSavedPlans();
      }
    });
  }

  // ──────────────────────────────────────────────
  // AI Tour Generator Logic (Spots & Interest Focused)
  // ──────────────────────────────────────────────

  Future<void> _generateAiPlan() async {
    FocusScope.of(context).unfocus();

    final dept = _isCustomDeparting
        ? (_customDepartingController.text.trim().isNotEmpty
            ? _customDepartingController.text.trim()
            : 'Islamabad')
        : _selectedDeparting;

    final dest = _isCustomDestination
        ? (_customDestinationController.text.trim().isNotEmpty
            ? _customDestinationController.text.trim()
            : 'Hunza Valley')
        : _selectedDestination;

    // Clear previous trip state & chat context
    setState(() {
      _isGenerating = true;
      _activeTripPlan = null;
      _chatMessages.clear();
    });

    try {
      final result = await TripApiService.generateTripPlan(
        departingCity: dept,
        destinationCity: dest,
        days: _days,
        interests: _selectedInterests.toList(),
        specialRequirements: _specialReqsController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _activeTripPlan = result.plan;
        _isGenerating = false;
        _initChatWithPlan(result.plan, result.introMessage);
        _currentMode = AiPlanningMode.chat;
      });

      _modeTransitionController.forward(from: 0);
    } on TripIncompatibleException catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      _showIncompatibleInterestsDialog(e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating tour plan: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showIncompatibleInterestsDialog(TripIncompatibleException exception) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          content: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9100).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF9100).withValues(alpha: 0.4), width: 2),
                  ),
                  child: const Icon(
                    Icons.explore_off_rounded,
                    color: Color(0xFFE65100),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Interest Compatibility',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceVariant.withValues(alpha: 0.4) : AppTheme.lightSurfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
                  ),
                  child: FormattedAiText(
                    text: exception.message,
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Adjust Interests', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Change Destination', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _initChatWithPlan(TripPlan plan, [String? introMessage]) {
    _chatMessages.clear();
    _activeTripPlan = plan;

    final interestsStr = plan.interests.isNotEmpty ? plan.interests.join(', ') : 'Sightseeing & Culture';
    final introText = introMessage ??
        "Salam & welcome! 🇵🇰 I have prepared your personalized <b>${plan.days}-Day ${plan.destinationCity}</b> trip plan departing from <b>${plan.departingCity}</b> focusing on <b>$interestsStr</b>.\n\n"
        "<b><u>Trip Overview:</u></b>\n"
        "• <b>Route:</b> ${plan.departingCity} ➔ ${plan.destinationCity}\n"
        "• <b>Duration:</b> ${plan.days} Days\n"
        "• <b>Interests:</b> $interestsStr\n\n"
        "You can chat with me to fine-tune spots, adjust pace, or add specific attractions. When you're ready, tap <b>Review Plan Summary & Finalize</b> below to review your detailed day-by-day itinerary and save your trip!";

    _chatMessages.add(ChatMessage(
      id: 'ai-intro',
      isAi: true,
      text: introText,
    ));
  }

  // ──────────────────────────────────────────────
  // Interactive Chat AI Assistant (Groq AI Powered)
  // ──────────────────────────────────────────────

  Future<void> _handleSendMessage([String? overrideText]) async {
    final text = overrideText ?? _chatInputController.text.trim();
    if (text.isEmpty || _isAiReplying) return;

    _chatInputController.clear();
    FocusScope.of(context).unfocus();

    final userMsg = ChatMessage(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isAi: false,
    );

    setState(() {
      _chatMessages.add(userMsg);
      _isAiReplying = true;
    });

    _scrollChatToBottom();

    // Check for explicit local checklist commands (e.g. "add hiking boots to day 2 checklist")
    final lower = text.toLowerCase();
    if (lower.startsWith('add ') && lower.contains('checklist') || lower.contains('remind me to ') || lower.startsWith('add to day ')) {
      // Parse day number if present
      final dayMatch = RegExp(r'day\s*(\d+)', caseSensitive: false).firstMatch(text);
      int? dayNum;
      if (dayMatch != null) {
        dayNum = int.tryParse(dayMatch.group(1) ?? '');
      }

      // Extract title
      String taskTitle = text
          .replaceAll(RegExp(r'^(add|remind me to)\s+', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+to\s+(day\s*\d+\s+)?checklist', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+to\s+day\s*\d+', caseSensitive: false), '')
          .trim();

      if (taskTitle.isNotEmpty) {
        // Automatically add or offer confirmation
        final added = await TripChecklistService.addItem(
          title: taskTitle,
          category: ChecklistCategory.task,
          dayNumber: dayNum,
          explicitPlanId: _activeTripPlan?.id,
        );

        if (!mounted) return;

        final aiReply = ChatMessage(
          id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
          text: added != null
              ? "I have added <b>\"$taskTitle\"</b> to your ${dayNum != null ? 'Day $dayNum' : 'Trip-wide'} checklist! You can view or check it off anytime in <b>Trip Checklist & Notes</b>."
              : "I've noted that! Would you like to add <b>\"$taskTitle\"</b> to your Trip Checklist?",
          isAi: true,
          checklistActionTitle: added == null ? taskTitle : null,
          checklistActionDayNumber: dayNum,
        );

        setState(() {
          _chatMessages.add(aiReply);
          _isAiReplying = false;
        });

        _scrollChatToBottom();
        return;
      }
    }

    try {
      final chatResult = await TripApiService.sendChatMessage(
        message: text,
        currentPlan: _activeTripPlan,
        chatHistory: _chatMessages,
      );

      if (!mounted) return;

      if (chatResult.updatedPlan != null) {
        _activeTripPlan = chatResult.updatedPlan;
      }

      final aiMsg = ChatMessage(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
        text: chatResult.message,
        isAi: true,
      );

      setState(() {
        _chatMessages.add(aiMsg);
        _isAiReplying = false;
      });
    } catch (e) {
      if (!mounted) return;
      final aiMsg = ChatMessage(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
        text: "Got it! I have customized your spots and itinerary for <b>$text</b>. Tap <b>Review Plan Summary & Finalize</b> below to review the updated schedule.",
        isAi: true,
      );

      setState(() {
        _chatMessages.add(aiMsg);
        _isAiReplying = false;
      });
    }

    _scrollChatToBottom();
  }


  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ──────────────────────────────────────────────
  // Finalize Trip & History
  // ──────────────────────────────────────────────

  Future<void> _finalizeTrip() async {
    if (_activeTripPlan == null) return;

    final finalized = _activeTripPlan!.copyWith(isFinalized: true);
    await TripHistoryService.saveTripPlan(finalized);
    
    // Automatically initialize plan-aware checklist in SQLite
    await TripChecklistService.initializeChecklistForPlan(finalized);

    if (!mounted) return;

    setState(() {
      _activeTripPlan = finalized;
    });

    _showFinalizeSuccessDialog(finalized);
  }

  void _showFinalizeSuccessDialog(TripPlan plan) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVariant = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          content: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withOpacity(0.14),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 2),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: AppTheme.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tour Plan Finalized! 🎉',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your trip plan has been saved and your plan-aware Trip Checklist & Notes has been activated with day-by-day activities, stays, and recommendations.',
                  style: TextStyle(
                    color: onVariant,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Plan ID:',
                          style: TextStyle(color: onVariant, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          plan.id,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Trip Checklist Direct Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TripChecklistScreen()),
                      );
                    },
                    icon: const Icon(Icons.checklist_rounded, size: 18),
                    label: const Text('Open Trip Checklist & Notes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A7328),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _switchMode(AiPlanningMode.history);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('View History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Keep Chatting', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: onBg, size: 20),
          onPressed: () {
            if (_currentMode == AiPlanningMode.chat) {
              _switchMode(AiPlanningMode.form);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                _currentMode == AiPlanningMode.chat
                    ? 'AI Trip Assistant'
                    : (_currentMode == AiPlanningMode.history ? 'Saved Trip History' : 'AI Tour Planning'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onBg,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _currentMode == AiPlanningMode.history ? 'New Plan' : 'Saved Plans',
            icon: Icon(
              _currentMode == AiPlanningMode.history ? Icons.add_circle_outline_rounded : Icons.history_rounded,
              color: AppTheme.primary,
              size: 24,
            ),
            onPressed: () {
              if (_currentMode == AiPlanningMode.history) {
                _switchMode(AiPlanningMode.form);
              } else {
                _switchMode(AiPlanningMode.history);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: _buildCurrentView(),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentMode) {
      case AiPlanningMode.form:
        return _buildPlanningFormView();
      case AiPlanningMode.chat:
        return _buildChatbotView();
      case AiPlanningMode.history:
        return _buildHistoryView();
    }
  }

  // ──────────────────────────────────────────────
  // VIEW 1: PLANNING FORM (Streamlined & Spot Focused)
  // ──────────────────────────────────────────────

  Widget _buildPlanningFormView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVariant = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Hero Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primary.withOpacity(isDark ? 0.22 : 0.12),
                  surface,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'AI-POWERED',
                              style: TextStyle(
                                color: AppTheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Pakistan Explorer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: onVariant, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Discover Top Spots',
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select your departing city, destination, and interests to generate an intelligent spot-by-spot itinerary.',
                        style: TextStyle(color: onVariant, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withOpacity(0.18),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.explore_rounded, color: AppTheme.primary, size: 26),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 1. ROUTE & CITIES (DROPDOWNS WITH 'OTHER' OPTION)
          _buildSectionHeader(
            icon: Icons.alt_route_rounded,
            title: 'Where Are You Traveling?',
            subtitle: 'Select departing and destination cities in Pakistan',
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEPARTING FROM',
                  style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceVariant.withOpacity(0.4) : AppTheme.lightSurfaceVariant.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedDeparting,
                    isExpanded: true,
                    dropdownColor: surface,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primary),
                    style: TextStyle(color: onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.flight_takeoff_rounded, color: AppTheme.primary, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: _popularDepartingCities.map((city) {
                      return DropdownMenuItem<String>(
                        value: city,
                        child: Text(
                          city,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: city == otherOption ? AppTheme.primary : onSurface,
                            fontWeight: city == otherOption ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedDeparting = val;
                          _isCustomDeparting = val == otherOption;
                        });
                      }
                    },
                  ),
                ),

                // Custom departing input if 'Other' is chosen
                if (_isCustomDeparting) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _customDepartingController,
                    autofocus: true,
                    style: TextStyle(color: onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter custom departing city (e.g. Hyderabad, Sialkot)',
                      hintStyle: TextStyle(color: onVariant.withOpacity(0.7), fontSize: 13),
                      prefixIcon: const Icon(Icons.edit_location_alt_rounded, color: AppTheme.primary, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurfaceVariant.withOpacity(0.5) : AppTheme.lightSurfaceVariant.withOpacity(0.8),
                    ),
                  ),
                ],

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1),
                ),

                Text(
                  'DESTINATION REGION / SPOTS',
                  style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceVariant.withOpacity(0.4) : AppTheme.lightSurfaceVariant.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedDestination,
                    isExpanded: true,
                    dropdownColor: surface,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primary),
                    style: TextStyle(color: onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.place_rounded, color: AppTheme.primary, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: _popularDestinations.map((dest) {
                      return DropdownMenuItem<String>(
                        value: dest,
                        child: Text(
                          dest,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: dest == otherOption ? AppTheme.primary : onSurface,
                            fontWeight: dest == otherOption ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedDestination = val;
                          _isCustomDestination = val == otherOption;
                        });
                      }
                    },
                  ),
                ),

                // Custom destination input if 'Other' is chosen
                if (_isCustomDestination) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _customDestinationController,
                    autofocus: true,
                    style: TextStyle(color: onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter custom destination (e.g. Gorakh Hill, Kumrat, Kalash)',
                      hintStyle: TextStyle(color: onVariant.withOpacity(0.7), fontSize: 13),
                      prefixIcon: const Icon(Icons.add_location_alt_rounded, color: AppTheme.primary, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurfaceVariant.withOpacity(0.5) : AppTheme.lightSurfaceVariant.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. TRIP SCOPE (DURATION ONLY)
          _buildSectionHeader(
            icon: Icons.calendar_today_rounded,
            title: 'Trip Scope',
            subtitle: 'Set number of days for your expedition',
          ),
          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL DURATION',
                      style: TextStyle(color: onVariant, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_days ${_days == 1 ? 'Day' : 'Days'}',
                      style: TextStyle(color: onSurface, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildPillButton(
                      icon: Icons.remove,
                      onTap: _days > 1 ? () => setState(() => _days--) : null,
                    ),
                    const SizedBox(width: 12),
                    _buildPillButton(
                      icon: Icons.add,
                      onTap: _days < 21 ? () => setState(() => _days++) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. TRAVEL INTERESTS
          _buildSectionHeader(
            icon: Icons.local_activity_rounded,
            title: 'Travel Interests',
            subtitle: 'Pick what matters most to your journey',
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _interestsList.map((item) {
              final name = item['name'] as String;
              final icon = item['icon'] as IconData;
              final isSelected = _selectedInterests.contains(name);

              return FilterChip(
                avatar: Icon(
                  icon,
                  size: 16,
                  color: isSelected ? AppTheme.onPrimary : AppTheme.primary,
                ),
                label: Text(name),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedInterests.add(name);
                    } else if (_selectedInterests.length > 1) {
                      _selectedInterests.remove(name);
                    }
                  });
                },
                selectedColor: AppTheme.primary,
                backgroundColor: surface,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.onPrimary : onSurface,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                showCheckmark: false,
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // 4. SPECIAL REQUIREMENTS
          _buildSectionHeader(
            icon: Icons.note_alt_rounded,
            title: 'Special Requirements',
            subtitle: 'Any specific spots, physical, or personal preferences?',
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _specialReqsController,
            maxLines: 3,
            style: TextStyle(color: onSurface, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. Traveling with family, prefer quiet photography viewpoints, vegetarian food, easy walking trails...',
              hintStyle: TextStyle(color: onVariant.withOpacity(0.7), fontSize: 13),
              filled: true,
              fillColor: surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(18),
            ),
          ),

          const SizedBox(height: 32),

          // ── PROMINENT CTA BUTTON ──
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _isGenerating ? null : _generateAiPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 4,
                shadowColor: AppTheme.primary.withOpacity(0.4),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _isGenerating
                    ? const Row(
                        key: ValueKey('generating'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(AppTheme.onPrimary)),
                          ),
                          SizedBox(width: 14),
                          Flexible(
                            child: Text(
                              'Synthesizing Pakistan Itinerary...',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        key: ValueKey('cta'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 22),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Create My AI Tour Plan',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title, required String subtitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVariant = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: onSurface, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: onVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPillButton({required IconData icon, VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: onTap == null
              ? (isDark ? AppTheme.darkSurfaceVariant.withOpacity(0.3) : Colors.grey.withOpacity(0.2))
              : AppTheme.primary.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? Colors.grey : AppTheme.primary,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // VIEW 2: AI PLANNING RESULT & CHATBOT INTERFACE
  // ──────────────────────────────────────────────

  Widget _buildChatbotView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVariant = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    return Column(
      children: [
        // Top Floating Summary Banner (Clean, without top-right finalize button)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: surface,
            border: Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.explore_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activeTripPlan?.title ?? 'Active AI Plan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_activeTripPlan?.days ?? 5} Days • ${_activeTripPlan?.destinationCity ?? ''} Tour',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Chat Message Stream
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
              final message = _chatMessages[index];
              return _buildChatMessageBubble(message);
            },
          ),
        ),

        // AI Typing Indicator
        if (_isAiReplying)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppTheme.primary)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'AI Travel Specialist is analyzing spots...',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: onVariant, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),

        // Bottom Action Bar: Prominent Contrasting Review & Finalize Button + Chat Input
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          decoration: BoxDecoration(
            color: surface,
            border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── PROMINENT CONTRASTING ACTION BUTTON ──
                Container(
                  width: double.infinity,
                  height: 48,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE65100), Color(0xFFFF9100)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE65100).withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showReviewAndFinalizeModal,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.assignment_outlined, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Review Plan Summary & Finalize',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 13),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Chat Input Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurfaceVariant.withOpacity(0.6) : AppTheme.lightSurfaceVariant.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: TextField(
                          controller: _chatInputController,
                          style: TextStyle(color: onSurface, fontSize: 14),
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _handleSendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Ask AI to modify spots, pace, meals...',
                            hintStyle: TextStyle(color: onVariant.withOpacity(0.7), fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () => _handleSendMessage(),
                        icon: const Icon(Icons.send_rounded, color: AppTheme.onPrimary, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // REVIEW PLAN SUMMARY & FINALIZE MODAL
  // ──────────────────────────────────────────────

  void _showReviewAndFinalizeModal() {
    if (_activeTripPlan == null) return;
    final plan = _activeTripPlan!;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVariant = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top header bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.assignment_outlined, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Trip Plan Summary',
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: onVariant),
                      onPressed: () => Navigator.pop(bottomSheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable Itinerary Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header info card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.title,
                              style: TextStyle(
                                color: onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.place_rounded, size: 14, color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${plan.departingCity} ➔ ${plan.destinationCity} • ${plan.days} Days',
                                    style: TextStyle(color: onVariant, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            if (plan.interests.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: plan.interests.map((interest) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTheme.darkSurfaceVariant : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      interest,
                                      style: TextStyle(color: onSurface, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Day-by-Day itinerary cards
                      _buildItineraryCard(plan),
                    ],
                  ),
                ),
              ),

              // Bottom Finalize Trip Button
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05))),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                        _finalizeTrip();
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text(
                        'Finalize & Save Trip',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatMessageBubble(ChatMessage msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVariant = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    if (!msg.isAi) {

      // User message bubble
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(6),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              color: AppTheme.onPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    // AI clean message bubble (text only, without duplicating day cards)
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Header with avatar
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 16),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Bon Voyage AI',
                  style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // AI text card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(22),
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FormattedAiText(
                    text: msg.text,
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 14,
                      height: 1.48,
                    ),
                  ),
                  if (msg.checklistActionTitle != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.checklist_rounded, size: 18, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Add "${msg.checklistActionTitle}" to ${msg.checklistActionDayNumber != null ? "Day ${msg.checklistActionDayNumber}" : "Checklist"}?',
                              style: TextStyle(color: onSurface, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!msg.isChecklistActionAdded)
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              await TripChecklistService.addItem(
                                title: msg.checklistActionTitle!,
                                category: ChecklistCategory.task,
                                dayNumber: msg.checklistActionDayNumber,
                                explicitPlanId: _activeTripPlan?.id,
                              );
                              setState(() {
                                final idx = _chatMessages.indexOf(msg);
                                if (idx != -1) {
                                  _chatMessages[idx] = msg.copyWith(isChecklistActionAdded: true);
                                }
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added "${msg.checklistActionTitle}" to Trip Checklist!'),
                                    backgroundColor: const Color(0xFF5A7328),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check, size: 14),
                            label: const Text('Add to Checklist', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: AppTheme.onPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                final idx = _chatMessages.indexOf(msg);
                                if (idx != -1) {
                                  _chatMessages[idx] = msg.copyWith(isChecklistActionAdded: true);
                                }
                              });
                            },
                            child: Text('Not now', style: TextStyle(color: onVariant, fontSize: 12)),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 15, color: Colors.green),
                          const SizedBox(width: 5),
                          Text('Added to Trip Checklist', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildItineraryCard(TripPlan plan) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVariant = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceVariant.withOpacity(0.3) : AppTheme.lightSurfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'DAY-BY-DAY SPOTS & SIGHTS',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...plan.daysPlan.map((day) {
            return Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'DAY ${day.dayNumber}',
                          style: const TextStyle(color: AppTheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          day.title,
                          style: TextStyle(color: onSurface, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Route & Timing
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.route_rounded, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          day.route,
                          style: TextStyle(color: onVariant, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          day.timing,
                          style: TextStyle(color: onVariant, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Attractions / Sights Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: day.attractions.map((attr) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('📍 $attr', style: TextStyle(color: onSurface, fontSize: 11, fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),

                  // Food & Stay Highlights
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.restaurant_rounded, size: 14, color: AppTheme.secondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: FormattedAiText(
                                text: '<b>Food:</b> ${day.foodRecommendation}',
                                style: TextStyle(color: onSurface, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.hotel_rounded, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: FormattedAiText(
                                text: '<b>Stay Tip:</b> ${day.stayRecommendation}',
                                style: TextStyle(color: onSurface, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // VIEW 3: SAVED TRIP HISTORY
  // ──────────────────────────────────────────────

  Widget _buildHistoryView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVariant = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (_savedPlans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.12),
                ),
                child: const Icon(Icons.luggage_rounded, color: AppTheme.primary, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                'No Saved Tour Plans Yet',
                style: TextStyle(color: onSurface, fontSize: 19, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Create your first AI trip plan and finalize it to access your saved routes anytime.',
                style: TextStyle(color: onVariant, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _switchMode(AiPlanningMode.form),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create New Plan', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: _savedPlans.length,
      itemBuilder: (context, index) {
        final plan = _savedPlans[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${plan.days} DAYS TOUR',
                      style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    onPressed: () async {
                      await TripHistoryService.deleteTripPlan(plan.id);
                      _loadSavedPlans();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                plan.title,
                style: TextStyle(color: onSurface, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.route_rounded, size: 16, color: onVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${plan.departingCity} ➔ ${plan.destinationCity}',
                      style: TextStyle(color: onVariant, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (plan.interests.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: plan.interests.take(3).map((interest) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        interest,
                        style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _activeTripPlan = plan;
                          _initChatWithPlan(plan);
                          _currentMode = AiPlanningMode.chat;
                        });
                        _modeTransitionController.forward(from: 0);
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      label: const Text('Open in AI Chat', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
