import 'dart:async';
import 'package:flutter/material.dart';
import '../models/trip_checklist_item_model.dart';
import '../models/trip_plan_model.dart';
import '../services/trip_checklist_service.dart';
import '../services/trip_history_service.dart';
import '../theme/app_theme.dart';
import 'ai_tour_planning_screen.dart';

/// Dedicated Plan-Aware Trip Checklist & Notes Screen.
/// 
/// Displays day-by-day itinerary items, stay recommendations, and activities
/// originated solely from the user's latest finalized Trip Plan.
/// Respects Android system navigation bar insets and safe areas.
class TripChecklistScreen extends StatefulWidget {
  const TripChecklistScreen({super.key});

  @override
  State<TripChecklistScreen> createState() => _TripChecklistScreenState();
}

class _TripChecklistScreenState extends State<TripChecklistScreen> {
  TripPlan? _activePlan;
  List<TripChecklistItem> _items = [];
  bool _isLoading = true;

  StreamSubscription<List<TripChecklistItem>>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _loadPlanAndChecklist();
    _streamSubscription = TripChecklistService.checklistStream.listen((updatedItems) {
      if (mounted) {
        setState(() {
          _items = updatedItems;
        });
      }
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPlanAndChecklist() async {
    setState(() => _isLoading = true);
    final plan = await TripHistoryService.getLatestFinalizedPlan();
    final items = await TripChecklistService.getActiveChecklist();

    if (mounted) {
      setState(() {
        _activePlan = plan;
        _items = items;
        _isLoading = false;
      });
    }
  }

  String _cleanHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    final pendingCount = _items.where((i) => !i.isCompleted).length;
    final completedCount = _items.where((i) => i.isCompleted).length;
    final totalCount = _items.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip Checklist & Notes',
              style: TextStyle(
                color: onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (_activePlan != null)
              Text(
                '${_cleanHtml(_activePlan!.title)} (${_activePlan!.days} Days)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        actions: [
          if (_items.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: pendingCount > 0
                      ? AppTheme.primary.withValues(alpha: 0.16)
                      : Colors.green.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: pendingCount > 0
                        ? AppTheme.primary.withValues(alpha: 0.3)
                        : Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      pendingCount > 0
                          ? Icons.pending_actions_rounded
                          : Icons.check_circle_rounded,
                      size: 14,
                      color: pendingCount > 0 ? AppTheme.primary : Colors.green,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      pendingCount > 0 ? '$pendingCount Pending' : 'All Done! 🎉',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: pendingCount > 0 ? AppTheme.primary : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
            : _activePlan == null
                ? _buildNoPlanEmptyState(context, isDark, onSurface, onVar)
                : _buildChecklistContent(
                    context,
                    isDark,
                    surface,
                    onSurface,
                    onVar,
                    colorScheme,
                    progress,
                    completedCount,
                    totalCount,
                  ),
      ),
    );
  }

  Widget _buildNoPlanEmptyState(
    BuildContext context,
    bool isDark,
    Color onSurface,
    Color onVar,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.checklist_rounded,
                size: 46,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Trip Plan Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Create and finalize a trip plan first to automatically organize your activities, stays, and food recommendations by day.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: onVar,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AiTourPlanningScreen()),
                );
              },
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text(
                'Plan My Trip',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistContent(
    BuildContext context,
    bool isDark,
    Color surface,
    Color onSurface,
    Color onVar,
    ColorScheme colorScheme,
    double progress,
    int completedCount,
    int totalCount,
  ) {
    // Group items strictly by Day 1..N (No trip-wide section)
    final Map<int, List<TripChecklistItem>> grouped = {};

    if (_activePlan != null) {
      for (final day in _activePlan!.daysPlan) {
        grouped[day.dayNumber] = [];
      }
    }

    for (final item in _items) {
      final dayNum = item.dayNumber ?? 1;
      if (!grouped.containsKey(dayNum)) {
        grouped[dayNum] = [];
      }
      grouped[dayNum]!.add(item);
    }

    final dayKeys = grouped.keys.toList()..sort();

    return Column(
      children: [
        // Top Progress Header
        if (totalCount > 0)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            color: surface,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Trip Progress ($completedCount of $totalCount items)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: onVar,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),

        // Main List of Grouped Days
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            physics: const BouncingScrollPhysics(),
            children: [
              ...dayKeys.map((dayNum) {
                final dayItems = grouped[dayNum] ?? [];
                String dayTitle = 'Day $dayNum';
                String? routeSubtitle;

                if (_activePlan != null) {
                  final match = _activePlan!.daysPlan
                      .where((d) => d.dayNumber == dayNum)
                      .toList();
                  if (match.isNotEmpty) {
                    dayTitle = _cleanHtml(match.first.title.isNotEmpty ? match.first.title : 'Day $dayNum');
                    if (match.first.route.isNotEmpty) {
                      routeSubtitle = _cleanHtml(match.first.route);
                    }
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Day Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'DAY $dayNum',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dayTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: onSurface,
                                    ),
                                  ),
                                  if (routeSubtitle != null)
                                    Text(
                                      routeSubtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: onVar,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.05),
                      ),

                      // Item Tiles
                      if (dayItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No items added for this day.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              color: onVar.withValues(alpha: 0.7),
                            ),
                          ),
                        )
                      else
                        ...dayItems.map((item) => _buildChecklistItemTile(item, isDark, onSurface, onVar)),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 8),

              // Bottom Informational Rule
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This list will be valid until another plan is generated.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: onVar,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItemTile(
    TripChecklistItem item,
    bool isDark,
    Color onSurface,
    Color onVar,
  ) {
    final isDone = item.isCompleted;
    final cleanTitle = _cleanHtml(item.title);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.withValues(alpha: 0.8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => TripChecklistService.removeItem(item.id),
      child: InkWell(
        // Do not redirect to any other page on clicking any item - toggle completion
        onTap: () => TripChecklistService.toggleCompleted(item.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular Checkbox with Tickmark
              GestureDetector(
                onTap: () => TripChecklistService.toggleCompleted(item.id),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? const Color(0xFF2E7D32) : Colors.transparent,
                    border: Border.all(
                      color: isDone
                          ? const Color(0xFF2E7D32)
                          : (isDark ? Colors.white38 : Colors.black38),
                      width: 1.8,
                    ),
                  ),
                  child: isDone
                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Category / Content Tag Badge (Places to Visit, Hotel, Food, or chatbot tag)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: item.originColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.originIcon, size: 11.5, color: item.originColor),
                    const SizedBox(width: 4),
                    Text(
                      item.originTag,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: item.originColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Title Text (Content NOT cut through - clear and readable)
              Expanded(
                child: Text(
                  cleanTitle,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDone ? onSurface.withValues(alpha: 0.85) : onSurface,
                    decoration: null, // Just a tickmark; do not cut through the content!
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
