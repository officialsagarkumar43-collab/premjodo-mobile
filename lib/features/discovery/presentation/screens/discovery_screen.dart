import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';
import 'package:prem_jodo_mobile/core/utils/image_helper.dart';
import 'package:prem_jodo_mobile/core/widgets/app_avatar.dart';
import 'package:prem_jodo_mobile/core/widgets/custom_button.dart';
import 'package:prem_jodo_mobile/core/widgets/glass_container.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:prem_jodo_mobile/features/discovery/data/models/profile_card_model.dart';
import 'package:prem_jodo_mobile/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:prem_jodo_mobile/features/discovery/presentation/screens/match_modal_screen.dart';
import 'package:prem_jodo_mobile/features/discovery/presentation/widgets/discovery_filter_modal.dart';
import 'package:prem_jodo_mobile/features/profile/presentation/screens/membership_screen.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen>
    with TickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  double _dragAngle = 0.0;
  bool _isAnimating = false;
  int _activePhotoIndex = 0;

  late final AnimationController _swipeAnimController;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _angleAnimation;

  late final AnimationController _rewindAnimController;
  late Animation<Offset> _rewindOffsetAnimation;
  late Animation<double> _rewindScaleAnimation;
  late Animation<double> _rewindAngleAnimation;

  late final AnimationController _radarAnimController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (ref.read(authProvider).user == null) {
          ref.read(authProvider.notifier).checkAuthStatus();
        }
        final discoveryState = ref.read(discoveryProvider);
        if (discoveryState.profiles.isEmpty && !discoveryState.isLoading) {
          ref.read(discoveryProvider.notifier).loadRecommendations();
        }
      }
    });

    _swipeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _rewindAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _radarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _rewindOffsetAnimation = Tween<Offset>(
      begin: const Offset(-320, 20),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _rewindAnimController,
      curve: Curves.easeOutCubic,
    ));

    _rewindScaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rewindAnimController,
      curve: Curves.easeOutCubic,
    ));

    _rewindAngleAnimation = Tween<double>(
      begin: -0.12,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _rewindAnimController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _swipeAnimController.dispose();
    _rewindAnimController.dispose();
    _radarAnimController.dispose();
    super.dispose();
  }

  void _openFilterModal(BuildContext context) {
    final state = ref.read(discoveryProvider);
    final notifier = ref.read(discoveryProvider.notifier);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DiscoveryFilterModal(
        currentFilter: state.filter,
        onApply: (newFilter) {
          notifier.updateFilter(newFilter);
        },
      ),
    );
  }

  void _showSwipeLimitReachedDialog(BuildContext context, String? message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1C2B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Daily Swipe Limit Reached!',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message ??
                    'Free accounts receive 50 swipes daily. Upgrade your membership for unlimited swipes or explore Add-ons for instant power-ups!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 22),
              CustomButton(
                text: 'Upgrade to VIP (Unlimited Swipes)',
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MembershipScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MembershipScreen(initialTab: 'addons'),
                    ),
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt_rounded, color: AppColors.gold, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Get Add-ons (Super Likes & Boosts)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Maybe Tomorrow', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      ref.read(discoveryProvider.notifier).clearSwipeLimit();
    });
  }

  void _animateSwipeOut({
    required Offset targetOffset,
    required double targetAngle,
    required String action,
  }) {
    if (_isAnimating) return;
    _isAnimating = true;

    final startOffset = _dragOffset;
    final startAngle = _dragAngle;

    _offsetAnimation = Tween<Offset>(
      begin: startOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: _swipeAnimController,
      curve: Curves.easeOutCubic,
    ));

    _angleAnimation = Tween<double>(
      begin: startAngle,
      end: targetAngle,
    ).animate(CurvedAnimation(
      parent: _swipeAnimController,
      curve: Curves.easeOutCubic,
    ));

    _swipeAnimController.forward(from: 0.0).then((_) {
      ref.read(discoveryProvider.notifier).swipe(action: action);
      if (mounted) {
        setState(() {
          _dragOffset = Offset.zero;
          _dragAngle = 0.0;
          _activePhotoIndex = 0;
          _isAnimating = false;
        });
      }
    });
  }

  void _animateSnapBack() {
    if (_isAnimating) return;
    _isAnimating = true;

    _offsetAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _swipeAnimController,
      curve: Curves.easeOutBack,
    ));

    _angleAnimation = Tween<double>(
      begin: _dragAngle,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _swipeAnimController,
      curve: Curves.easeOutBack,
    ));

    _swipeAnimController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _dragOffset = Offset.zero;
          _dragAngle = 0.0;
          _isAnimating = false;
        });
      }
    });
  }

  void _triggerButtonSwipe(String action) {
    if (_isAnimating) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    Offset target;
    double targetAngle;

    if (action == 'like') {
      target = Offset(screenWidth * 1.4, 30);
      targetAngle = 0.25;
    } else if (action == 'pass') {
      target = Offset(-screenWidth * 1.4, 30);
      targetAngle = -0.25;
    } else {
      target = Offset(0, -screenHeight * 1.1);
      targetAngle = 0.0;
    }

    _animateSwipeOut(
      targetOffset: target,
      targetAngle: targetAngle,
      action: action,
    );
  }

  void _triggerRewind() {
    if (_isAnimating) return;
    final state = ref.read(discoveryProvider);
    if (!state.canRewind) return;

    _isAnimating = true;
    ref.read(discoveryProvider.notifier).rewind();
    setState(() {
      _activePhotoIndex = 0;
      _dragOffset = Offset.zero;
      _dragAngle = 0.0;
    });
    _rewindAnimController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _isAnimating = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryProvider);
    final notifier = ref.read(discoveryProvider.notifier);

    // Listen for match events to pop up match dialog
    ref.listen<DiscoveryState>(discoveryProvider, (prev, next) {
      if (next.matchedUser != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => MatchModalScreen(
            matchedUser: next.matchedUser!,
            conversationId: next.matchedConversationId,
            onClose: () => notifier.clearMatch(),
          ),
        );
      }
      if (next.isSwipeLimitReached && (prev == null || !prev.isSwipeLimitReached)) {
        _showSwipeLimitReachedDialog(context, next.swipeLimitMessage);
      }
    });

    // Pre-cache nearby profile photos in memory to prevent blinking
    if (state.profiles.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _precacheNearbyProfiles(state);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: state.isLoading
          ? _buildRadarPreloader(context)
          : state.currentProfile == null
              ? SafeArea(child: _buildEmptyState(context, notifier))
              : SafeArea(child: _buildCardStack(context, state)),
    );
  }

  Widget _buildRadarPreloader(BuildContext context) {
    final user = ref.watch(authProvider).user;

    final String rawAvatar = (user != null &&
            user.photos.isNotEmpty &&
            user.photos.first.trim().isNotEmpty)
        ? user.photos.first
        : (user != null &&
                user.photoObjects.isNotEmpty &&
                user.photoObjects.first.url.trim().isNotEmpty
            ? user.photoObjects.first.url
            : (StorageService.getUserAvatar() ?? ''));

    final String avatarUrl = ImageHelper.resolveImageUrl(rawAvatar);

    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      body: Stack(
        children: [
          // Ambient glow in center
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.9,
                  colors: [
                    Color(0xFF281E23),
                    Color(0xFF101014),
                  ],
                ),
              ),
            ),
          ),

          // Pulsating Radar Ripples & Center User Avatar
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 300,
                  height: 300,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated Radar Waves
                      AnimatedBuilder(
                        animation: _radarAnimController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: List.generate(4, (index) {
                              final waveOffset = index * 0.25;
                              final progress =
                                  (_radarAnimController.value + waveOffset) %
                                      1.0;
                              final size = 96.0 + (progress * 190.0);
                              final opacity = (1.0 - progress) * 0.50;

                              return Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFE94057)
                                        .withValues(alpha: opacity),
                                    width: 1.6,
                                  ),
                                  color: const Color(0xFFE94057)
                                      .withValues(alpha: opacity * 0.10),
                                ),
                              );
                            }),
                          );
                        },
                      ),

                      // Center User Avatar with glowing halo
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF4E6A),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFFFF4E6A).withValues(alpha: 0.45),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: AppAvatar(
                            imageUrl: avatarUrl,
                            name: user?.name ?? 'User',
                            size: 96,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                AnimatedBuilder(
                  animation: _radarAnimController,
                  builder: (context, child) {
                    final alpha = 0.65 +
                        (0.35 *
                            math.sin(_radarAnimController.value * 2 * math.pi)
                                .abs());
                    return Text(
                      'Finding people near you ...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: alpha),
                        letterSpacing: 0.4,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, DiscoveryNotifier notifier) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.darkSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.style_rounded,
                size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text(
            'No More Profiles Nearby',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Expand your distance filter to discover more people',
            style: TextStyle(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => notifier.loadRecommendations(),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStack(BuildContext context, DiscoveryState state) {
    final currentProfile = state.currentProfile!;
    final nextIndex = state.currentIndex + 1;
    final nextProfile =
        nextIndex < state.profiles.length ? state.profiles[nextIndex] : null;

    final screenWidth = MediaQuery.of(context).size.width;
    final swipeThreshold = screenWidth * 0.33;

    // Calculate drag progress (0.0 to 1.0) for background card animation
    final dragProgress =
        math.min(1.0, _dragOffset.distance / (swipeThreshold * 1.2));

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          // 1. Background Card (Next Profile)
          if (nextProfile != null)
            Transform.scale(
              scale: 0.95 + (0.05 * dragProgress),
              child: Transform.translate(
                offset: Offset(0, 10 * (1.0 - dragProgress)),
                child: _buildProfileCard(
                  profile: nextProfile,
                  isTopCard: false,
                  photoIndex: 0,
                ),
              ),
            ),

          // 2. Foreground Top Card (Full Screen Tinder Style)
          AnimatedBuilder(
            animation:
                Listenable.merge([_swipeAnimController, _rewindAnimController]),
            builder: (context, child) {
              Offset currentOffset = _dragOffset;
              double currentAngle = _dragAngle;
              double currentScale = 1.0;

              if (_swipeAnimController.isAnimating) {
                currentOffset = _offsetAnimation.value;
                currentAngle = _angleAnimation.value;
              } else if (_rewindAnimController.isAnimating) {
                currentOffset = _rewindOffsetAnimation.value;
                currentScale = _rewindScaleAnimation.value;
                currentAngle = _rewindAngleAnimation.value;
              }

              return Transform.translate(
                offset: currentOffset,
                child: Transform.rotate(
                  angle: currentAngle,
                  child: Transform.scale(
                    scale: currentScale,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        if (_isAnimating) return;
                        if (_dragOffset.distance > 10) return;
                        final count = currentProfile.photos.length;
                        if (count <= 1) return;
                        final cardWidth = screenWidth - 16;
                        final tapX = details.localPosition.dx;
                        final isNext = tapX > (cardWidth * 0.40);
                        setState(() {
                          if (isNext) {
                            _activePhotoIndex = (_activePhotoIndex + 1) % count;
                          } else {
                            _activePhotoIndex =
                                (_activePhotoIndex - 1 + count) % count;
                          }
                        });
                      },
                      onPanStart: (details) {
                        if (_isAnimating) return;
                      },
                      onPanUpdate: (details) {
                        if (_isAnimating) return;
                        setState(() {
                          _dragOffset += details.delta;
                          _dragAngle = (_dragOffset.dx / screenWidth) * 0.45;
                        });
                      },
                      onPanEnd: (details) {
                        if (_isAnimating) return;
                        final velocity = details.velocity.pixelsPerSecond;

                        if (_dragOffset.dx > swipeThreshold ||
                            velocity.dx > 650) {
                          _animateSwipeOut(
                            targetOffset:
                                Offset(screenWidth * 1.4, _dragOffset.dy),
                            targetAngle: 0.3,
                            action: 'like',
                          );
                        } else if (_dragOffset.dx < -swipeThreshold ||
                            velocity.dx < -650) {
                          _animateSwipeOut(
                            targetOffset:
                                Offset(-screenWidth * 1.4, _dragOffset.dy),
                            targetAngle: -0.3,
                            action: 'pass',
                          );
                        } else if (_dragOffset.dy < -110 &&
                            _dragOffset.dx.abs() < 70) {
                          _animateSwipeOut(
                            targetOffset: Offset(_dragOffset.dx,
                                -MediaQuery.of(context).size.height * 1.1),
                            targetAngle: 0.0,
                            action: 'superlike',
                          );
                        } else {
                          _animateSnapBack();
                        }
                      },
                      child: _buildProfileCard(
                        profile: currentProfile,
                        isTopCard: true,
                        photoIndex: _activePhotoIndex,
                        onPhotoTap: (isNext) {
                          final count = currentProfile.photos.length;
                          if (count <= 1) return;
                          setState(() {
                            if (isNext) {
                              _activePhotoIndex =
                                  (_activePhotoIndex + 1) % count;
                            } else {
                              _activePhotoIndex =
                                  (_activePhotoIndex - 1 + count) % count;
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // 3b. Floating Swipe Quota Badge (Top Left over card)
          Positioned(
            top: 22,
            left: 14,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MembershipScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: state.isUnlimitedSwipes
                        ? AppColors.gold.withValues(alpha: 0.7)
                        : (state.swipesRemainingToday != null && state.swipesRemainingToday! <= 10
                            ? AppColors.error.withValues(alpha: 0.7)
                            : Colors.white24),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      state.isUnlimitedSwipes ? Icons.workspace_premium_rounded : Icons.flash_on_rounded,
                      color: state.isUnlimitedSwipes
                          ? AppColors.gold
                          : (state.swipesRemainingToday != null && state.swipesRemainingToday! <= 10
                              ? AppColors.error
                              : AppColors.primaryLight),
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.isUnlimitedSwipes
                          ? 'VIP Unlimited'
                          : '${state.swipesRemainingToday ?? state.dailySwipeLimit}/${state.dailySwipeLimit} Swipes',
                      style: TextStyle(
                        color: state.isUnlimitedSwipes ? AppColors.gold : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Floating Filter Button (Top Right over card)
          Positioned(
            top: 22,
            right: 14,
            child: GestureDetector(
              onTap: () => _openFilterModal(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),

          // 4. Floating Action Buttons (Tinder Style at bottom over the card)
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.replay_rounded,
                  color: AppColors.gold,
                  size: 48,
                  iconSize: 24,
                  disabled: !state.canRewind || _isAnimating,
                  onTap: _triggerRewind,
                ),
                _buildActionButton(
                  icon: Icons.close_rounded,
                  color: AppColors.nopeRed,
                  size: 58,
                  iconSize: 32,
                  disabled: _isAnimating,
                  onTap: () => _triggerButtonSwipe('pass'),
                ),
                _buildActionButton(
                  icon: Icons.star_rounded,
                  color: AppColors.superLikeBlue,
                  size: 50,
                  iconSize: 26,
                  disabled: _isAnimating,
                  onTap: () => _triggerButtonSwipe('superlike'),
                ),
                _buildActionButton(
                  icon: Icons.favorite_rounded,
                  color: AppColors.likeGreen,
                  size: 58,
                  iconSize: 32,
                  disabled: _isAnimating,
                  onTap: () => _triggerButtonSwipe('like'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard({
    required ProfileCardModel profile,
    required bool isTopCard,
    required int photoIndex,
    void Function(bool isNext)? onPhotoTap,
  }) {
    final photos = profile.photos;
    final safeIndex =
        (photos.isNotEmpty && photoIndex < photos.length) ? photoIndex : 0;

    // Stamp Opacity Calculations
    double likeOpacity = 0.0;
    double nopeOpacity = 0.0;
    double superLikeOpacity = 0.0;

    if (isTopCard) {
      if (_dragOffset.dx > 15) {
        likeOpacity = math.min(1.0, (_dragOffset.dx - 15) / 90);
      } else if (_dragOffset.dx < -15) {
        nopeOpacity = math.min(1.0, (-_dragOffset.dx - 15) / 90);
      }
      if (_dragOffset.dy < -20 && _dragOffset.dx.abs() < 55) {
        superLikeOpacity = math.min(1.0, (-_dragOffset.dy - 20) / 90);
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Photo Image (Instant Blink-Free IndexedStack)
            if (photos.isNotEmpty)
              IndexedStack(
                index: safeIndex,
                children: photos
                    .map((p) => _buildCardImage(p, profile.name))
                    .toList(),
              )
            else
              _buildFallbackImage(profile.name),

            // 2. Multi-photo Tap Triggers (Left 35% / Right 35%)
            if (isTopCard && photos.length > 1)
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => onPhotoTap?.call(false),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  const Expanded(flex: 1, child: SizedBox.expand()),
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => onPhotoTap?.call(true),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),

            // 3. Dark Vignette Bottom Gradient for Text Readability
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 380,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.35, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // 4. Story-style Segmented Photo Bar Indicators
            if (photos.length > 1)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: List.generate(photos.length, (idx) {
                    return Expanded(
                      child: Container(
                        height: 4.0,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          color: idx == safeIndex
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 4,
                            )
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),

            // 5. Distance Badge (Top-left)
            Positioned(
              top: photos.length > 1 ? 24 : 14,
              left: 14,
              child: GlassContainer(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  children: [
                    const Icon(Icons.near_me_rounded,
                        color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      profile.formattedDistance ?? 'Nearby',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // 6. Visual Stamp Badges (LIKE, NOPE, SUPER LIKE)
          if (isTopCard) ...[
            // LIKE Stamp
            if (likeOpacity > 0.01)
              Positioned(
                top: 50,
                left: 24,
                child: Transform.rotate(
                  angle: -0.25,
                  child: Opacity(
                    opacity: likeOpacity,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: AppColors.likeGreen, width: 3.5),
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.likeGreen.withValues(alpha: 0.25),
                      ),
                      child: const Text(
                        'LIKE',
                        style: TextStyle(
                          color: AppColors.likeGreen,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // NOPE Stamp
            if (nopeOpacity > 0.01)
              Positioned(
                top: 50,
                right: 24,
                child: Transform.rotate(
                  angle: 0.25,
                  child: Opacity(
                    opacity: nopeOpacity,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: AppColors.nopeRed, width: 3.5),
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.nopeRed.withValues(alpha: 0.25),
                      ),
                      child: const Text(
                        'NOPE',
                        style: TextStyle(
                          color: AppColors.nopeRed,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // SUPER LIKE Stamp
            if (superLikeOpacity > 0.01)
              Positioned(
                bottom: 200,
                left: 0,
                right: 0,
                child: Center(
                  child: Transform.rotate(
                    angle: -0.08,
                    child: Opacity(
                      opacity: superLikeOpacity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppColors.superLikeBlue, width: 3.5),
                          borderRadius: BorderRadius.circular(14),
                          color: AppColors.superLikeBlue.withValues(alpha: 0.3),
                        ),
                        child: const Text(
                          'SUPER LIKE',
                          style: TextStyle(
                            color: AppColors.superLikeBlue,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],

          // 7. Profile Information Bottom Details (Above Action Buttons)
          Positioned(
            bottom: 92,
            left: 18,
            right: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name, Age & Verified Badge
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${profile.name}, ${profile.age}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (profile.isVerified) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.verified_rounded,
                          color: AppColors.info, size: 24),
                    ],
                  ],
                ),
                const SizedBox(height: 4),

                // Occupation & City
                Row(
                  children: [
                    if (profile.occupation.isNotEmpty &&
                        profile.occupation != 'Member') ...[
                      const Icon(Icons.work_outline_rounded,
                          size: 14, color: Colors.white70),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          profile.occupation,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('•',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 13)),
                      const SizedBox(width: 8),
                    ],
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        profile.city.isNotEmpty ? profile.city : 'Nearby',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (profile.bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    profile.bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      height: 1.3,
                    ),
                  ),
                ],
                if (profile.formattedInterests.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        profile.formattedInterests.take(4).map((interest) {
                      return GlassContainer(
                        borderRadius: 12,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        child: Text(
                          interest,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
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

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required double size,
    required double iconSize,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.35 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF161722).withValues(alpha: 0.92),
            shape: BoxShape.circle,
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ],
            border: Border.all(
              color: disabled
                  ? Colors.white.withValues(alpha: 0.1)
                  : color.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
          child: Icon(icon,
              color: disabled ? Colors.white38 : color, size: iconSize),
        ),
      ),
    );
  }

  Widget _buildCardImage(String rawUrl, String userName) {
    final resolved = ImageHelper.resolveImageUrl(rawUrl);
    if (resolved.isEmpty) {
      return _buildFallbackImage(userName);
    }

    // If it's a local filesystem path
    if (!resolved.startsWith('http://') &&
        !resolved.startsWith('https://') &&
        !resolved.startsWith('data:') &&
        !resolved.startsWith('blob:')) {
      try {
        final file = File(resolved);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => _buildFallbackImage(userName),
          );
        }
      } catch (_) {}
    }

    // Network Image
    return CachedNetworkImage(
      imageUrl: resolved,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) => Container(
        color: const Color(0xFF141418),
      ),
      errorWidget: (context, url, error) {
        return Image.network(
          resolved,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _buildFallbackImage(userName),
        );
      },
    );
  }

  void _precacheNearbyProfiles(DiscoveryState state) {
    final curIdx = state.currentIndex;
    final total = state.profiles.length;
    for (int i = curIdx; i < curIdx + 3 && i < total; i++) {
      final profile = state.profiles[i];
      for (final p in profile.photos) {
        final res = ImageHelper.resolveImageUrl(p);
        if (res.startsWith('http://') || res.startsWith('https://')) {
          precacheImage(CachedNetworkImageProvider(res), context);
        }
      }
    }
  }

  Widget _buildFallbackImage(String userName) {
    final initial =
        (userName.trim().isNotEmpty && userName.trim() != 'Prem Jodo User')
            ? userName.trim()[0].toUpperCase()
            : '?';

    return Container(
      color: const Color(0xFF141418),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 44,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            userName,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
