import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';

/// Data model representing a featured escape destination.
class FeaturedEscapeItem {
  final String title;
  final String location;
  final String tag;
  final IconData icon;
  final String videoAsset;
  final Color tagColor;
  final String fallbackImageUrl;

  const FeaturedEscapeItem({
    required this.title,
    required this.location,
    required this.tag,
    required this.icon,
    required this.videoAsset,
    required this.tagColor,
    required this.fallbackImageUrl,
  });
}

/// Auto-advancing video carousel for "Featured Escapes".
///
/// Automatically plays the active card's video and moves left to the next card
/// when the video completes (Fairy Meadows -> Lahore Heritage -> Attabad Lake -> loop).
class FeaturedEscapesCarousel extends StatefulWidget {
  final void Function(String title)? onCardTap;

  const FeaturedEscapesCarousel({
    super.key,
    this.onCardTap,
  });

  @override
  State<FeaturedEscapesCarousel> createState() => _FeaturedEscapesCarouselState();
}

class _FeaturedEscapesCarouselState extends State<FeaturedEscapesCarousel> {
  static const List<FeaturedEscapeItem> _escapes = [
    FeaturedEscapeItem(
      title: 'Fairy Meadows',
      location: 'Gilgit-Baltistan',
      tag: 'Adventure',
      icon: Icons.landscape_rounded,
      videoAsset: 'assets/videos/fairymedows.mp4',
      tagColor: Color(0xFF8CCBB2),
      fallbackImageUrl:
          'https://images.unsplash.com/photo-1590076215668-97019effa016',
    ),
    FeaturedEscapeItem(
      title: 'Lahore Heritage',
      location: 'Punjab',
      tag: 'Culture',
      icon: Icons.account_balance_rounded,
      videoAsset: 'assets/videos/lahore_heritage.mp4',
      tagColor: Color(0xFFE89A58),
      fallbackImageUrl:
          'https://images.unsplash.com/photo-1584809837053-1f1f2eae0b1d',
    ),
    FeaturedEscapeItem(
      title: 'Attabad Lake',
      location: 'Hunza Valley',
      tag: 'Nature',
      icon: Icons.water_rounded,
      videoAsset: 'assets/videos/attabad.mp4',
      tagColor: Color(0xFFA8E7CD),
      fallbackImageUrl:
          'https://images.unsplash.com/photo-1609766857041-ed402ea8069a',
    ),
  ];

  late PageController _pageController;
  final List<VideoPlayerController?> _controllers = [null, null, null];
  final List<bool> _initialized = [false, false, false];

  int _currentIndex = 0;
  bool _isAutoAdvancing = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.85,
      initialPage: 0,
    );

    _initializeAllVideos();
  }

  Future<void> _initializeAllVideos() async {
    for (int i = 0; i < _escapes.length; i++) {
      try {
        final controller = VideoPlayerController.asset(_escapes[i].videoAsset);
        _controllers[i] = controller;

        await controller.initialize();
        await controller.setVolume(_isMuted ? 0.0 : 1.0);
        await controller.setLooping(false);

        controller.addListener(() => _handleVideoListener(i));

        if (mounted) {
          setState(() {
            _initialized[i] = true;
          });

          // Automatically play the first video if this is card 0
          if (i == 0 && _currentIndex == 0) {
            controller.play();
          }
        }
      } catch (e) {
        debugPrint('[FeaturedEscapes] Error initializing video $i: $e');
      }
    }
  }

  void _handleVideoListener(int index) {
    if (!mounted) return;
    if (index != _currentIndex || _isAutoAdvancing) return;

    final controller = _controllers[index];
    if (controller == null || !controller.value.isInitialized) return;

    final position = controller.value.position;
    final duration = controller.value.duration;

    // Trigger advance when video reaches completion
    if (duration > Duration.zero && position >= duration && !controller.value.isPlaying) {
      _advanceToNextCard();
    }
  }

  void _advanceToNextCard() {
    if (_isAutoAdvancing || !mounted) return;
    _isAutoAdvancing = true;

    final nextIndex = (_currentIndex + 1) % _escapes.length;
    _pageController
        .animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    )
        .then((_) {
      _isAutoAdvancing = false;
    });
  }

  void _onPageChanged(int newIndex) {
    if (!mounted) return;

    setState(() {
      _currentIndex = newIndex;
    });

    // Pause and rewind other videos, and play current
    for (int i = 0; i < _controllers.length; i++) {
      final controller = _controllers[i];
      if (controller != null && controller.value.isInitialized) {
        if (i == newIndex) {
          controller.seekTo(Duration.zero).then((_) {
            if (mounted) controller.play();
          });
        } else {
          controller.pause();
          controller.seekTo(Duration.zero);
        }
      }
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });

    for (final controller in _controllers) {
      if (controller != null && controller.value.isInitialized) {
        controller.setVolume(_isMuted ? 0.0 : 1.0);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _controllers) {
      controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        SizedBox(
          height: 360,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: _escapes.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final item = _escapes[index];
              final isFocused = index == _currentIndex;
              final controller = _controllers[index];
              final isReady = _initialized[index] && controller != null;

              return AnimatedPadding(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: isFocused ? 0 : 8,
                ),
                child: GestureDetector(
                  onTap: () {
                    if (index != _currentIndex) {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                      );
                    } else if (isReady && controller.value.isInitialized) {
                      if (controller.value.isPlaying) {
                        controller.pause();
                      } else {
                        controller.play();
                      }
                    }
                    widget.onCardTap?.call(item.title);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: isFocused
                              ? AppTheme.primary.withValues(alpha: 0.22)
                              : Colors.black.withValues(alpha: 0.15),
                          blurRadius: isFocused ? 28 : 14,
                          offset: const Offset(0, 10),
                          spreadRadius: isFocused ? 2 : 0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. Video or Fallback Image Background
                          if (isReady && controller.value.isInitialized)
                            FittedBox(
                              fit: BoxFit.cover,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: controller.value.size.width,
                                height: controller.value.size.height,
                                child: VideoPlayer(controller),
                              ),
                            )
                          else
                            Image.network(
                              item.fallbackImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  item.icon,
                                  size: 64,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),

                          // 2. Cinematic Gradient Overlay
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x33000000),
                                  Colors.transparent,
                                  Color(0x77000000),
                                  Color(0xF0020305),
                                ],
                                stops: [0.0, 0.3, 0.65, 1.0],
                              ),
                            ),
                          ),

                          // 3. Thin Video Progress Indicator at Top
                          if (isReady && isFocused)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: ValueListenableBuilder<VideoPlayerValue>(
                                valueListenable: controller,
                                builder: (context, value, _) {
                                  final total = value.duration.inMilliseconds;
                                  final pos = value.position.inMilliseconds;
                                  final progress = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;

                                  return LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                                    minHeight: 3.5,
                                  );
                                },
                              ),
                            ),

                          // 4. Mute / Unmute Button (Top Left)
                          Positioned(
                            top: 14,
                            left: 14,
                            child: GestureDetector(
                              onTap: _toggleMute,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Icon(
                                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          // 5. Category Tag (Top Right)
                          Positioned(
                            top: 14,
                            right: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: item.tagColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 13,
                                    color: Colors.black87,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.tag,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 6. Title and Location Info (Bottom)
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 22,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppTheme.primary.withValues(alpha: 0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.play_circle_fill_rounded,
                                            color: AppTheme.primary,
                                            size: 12,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'LIVE PREVIEW',
                                            style: TextStyle(
                                              color: AppTheme.primary,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      size: 15,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.location,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 14),

        // Animated Page Indicators (Dots)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_escapes.length, (i) {
            final isSelected = i == _currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: isSelected ? 22 : 6,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }
}
