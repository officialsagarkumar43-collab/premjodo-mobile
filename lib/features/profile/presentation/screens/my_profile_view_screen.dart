import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/utils/image_helper.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';
import 'package:prem_jodo_mobile/core/widgets/app_avatar.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:prem_jodo_mobile/features/discovery/data/models/profile_card_model.dart';
import 'package:prem_jodo_mobile/features/profile/presentation/screens/edit_profile_screen.dart';

class MyProfileViewScreen extends ConsumerStatefulWidget {
  const MyProfileViewScreen({super.key});

  @override
  ConsumerState<MyProfileViewScreen> createState() => _MyProfileViewScreenState();
}

class _MyProfileViewScreenState extends ConsumerState<MyProfileViewScreen> {
  final PageController _pageController = PageController();
  int _currentPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).checkAuthStatus();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToEdit(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    ref.read(authProvider.notifier).checkAuthStatus();
  }

  void _nextPhoto(int total) {
    if (_currentPhotoIndex < total - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPhoto() {
    if (_currentPhotoIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildGalleryImage(String photoUrl, {double? width, double? height}) {
    final resolved = ImageHelper.resolveImageUrl(photoUrl);
    if (resolved.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFF161824),
        child: Center(
          child: Icon(Icons.person_rounded, size: (width != null && width < 100) ? 36 : 80, color: Colors.white24),
        ),
      );
    }

    final isNetwork = resolved.startsWith('http://') ||
        resolved.startsWith('https://') ||
        resolved.startsWith('data:') ||
        resolved.startsWith('blob:');

    if (!isNetwork) {
      final file = File(resolved);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: width ?? double.infinity,
          height: height ?? double.infinity,
          errorBuilder: (_, __, ___) => Container(
            width: width,
            height: height,
            color: const Color(0xFF161824),
            child: Center(
              child: Icon(Icons.person_rounded, size: (width != null && width < 100) ? 36 : 80, color: Colors.white24),
            ),
          ),
        );
      }
    }

    return CachedNetworkImage(
      imageUrl: resolved,
      fit: BoxFit.cover,
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: const Color(0xFF161824),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        width: width,
        height: height,
        color: const Color(0xFF161824),
        child: Center(
          child: Icon(Icons.person_rounded, size: (width != null && width < 100) ? 36 : 80, color: Colors.white24),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    final photos = <String>[];
    if (user?.photos != null && user!.photos.isNotEmpty) {
      for (final p in user.photos) {
        final resolved = ImageHelper.resolveImageUrl(p);
        if (resolved.isNotEmpty && !photos.contains(resolved)) {
          photos.add(resolved);
        }
      }
    }
    if (photos.isEmpty && user?.photoObjects != null && user!.photoObjects.isNotEmpty) {
      for (final po in user.photoObjects) {
        final raw = po.url.isNotEmpty ? po.url : po.rawUrl;
        final resolved = ImageHelper.resolveImageUrl(raw);
        if (resolved.isNotEmpty && !photos.contains(resolved)) {
          photos.add(resolved);
        }
      }
    }
    if (photos.isEmpty) {
      final cachedAvatar = StorageService.getUserAvatar();
      if (cachedAvatar != null && cachedAvatar.trim().isNotEmpty) {
        final resolved = ImageHelper.resolveImageUrl(cachedAvatar);
        if (resolved.isNotEmpty && !photos.contains(resolved)) {
          photos.add(resolved);
        }
      }
    }
    final name = user?.name.isNotEmpty == true ? user!.name : 'Prem Jodo User';
    final age = user?.age;
    final occupation = user?.occupation?.isNotEmpty == true ? user!.occupation! : 'Member';
    final city = user?.city?.isNotEmpty == true ? user!.city! : 'India';
    final bio = user?.bio?.isNotEmpty == true ? user!.bio! : 'No bio added yet. Tap edit to express yourself ✨';
    final interests = user?.interests ?? [];
    final gender = (user?.gender?.isNotEmpty == true)
        ? (user!.gender![0].toUpperCase() + user.gender!.substring(1))
        : 'Not specified';
    final isVerified = user?.isVerified == true;
    final isVip = user?.isVip == true;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Photo Gallery Header
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.52,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Photo PageView (Swipeable)
                      if (photos.isNotEmpty)
                        PageView.builder(
                          controller: _pageController,
                          physics: const BouncingScrollPhysics(),
                          itemCount: photos.length,
                          onPageChanged: (idx) => setState(() => _currentPhotoIndex = idx),
                          itemBuilder: (context, index) {
                            return _buildGalleryImage(photos[index]);
                          },
                        )
                      else
                        Container(
                          color: const Color(0xFF181A26),
                          child: Center(
                            child: AppAvatar(
                              imageUrl: photos.isNotEmpty ? photos.first : (StorageService.getUserAvatar() ?? ''),
                              name: name,
                              size: 140,
                            ),
                          ),
                        ),

                      // 2. Tap Left / Right Overlay for Story-style fast photo browsing
                      if (photos.length > 1)
                        Positioned.fill(
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: _prevPhoto,
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: () => _nextPhoto(photos.length),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 3. Top & Bottom Gradient Overlays (Ignored so gestures pass through)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0x99000000),
                                  Colors.transparent,
                                  Color(0x800D0E15),
                                  Color(0xFF0D0E15),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.0, 0.25, 0.75, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 4. Top Story Dots Indicator (Ignored so touches don't get blocked)
                      if (photos.length > 1)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 12,
                          left: 16,
                          right: 16,
                          child: IgnorePointer(
                            child: Row(
                              children: List.generate(
                                photos.length,
                                (idx) => Expanded(
                                  child: Container(
                                    height: 3.5,
                                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                    decoration: BoxDecoration(
                                      color: _currentPhotoIndex == idx
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 5. Back Button & Edit Button in Top Bar
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 20,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _navigateToEdit(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'Edit',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Profile Details
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    24 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name, Age & Badges
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              age != null ? '$name, $age' : name,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.verified_rounded, color: AppColors.info, size: 24),
                          ],
                          if (isVip) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Occupation & City
                      Row(
                        children: [
                          const Icon(Icons.work_outline_rounded, color: Colors.white60, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '$occupation • $city',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // About Me / Bio Card
                      _buildSectionHeader('About Me', Icons.person_rounded),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          bio,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Basic Details Grid
                      _buildSectionHeader('Basic Details', Icons.info_outline_rounded),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildDetailBadge(Icons.wc_rounded, 'Gender', gender),
                          _buildDetailBadge(Icons.location_on_rounded, 'City', city),
                          _buildDetailBadge(Icons.work_rounded, 'Work', occupation),
                          if (user?.email?.isNotEmpty == true)
                            _buildDetailBadge(Icons.email_rounded, 'Email', user!.email!),
                          if (user?.phone?.isNotEmpty == true)
                            _buildDetailBadge(Icons.phone_rounded, 'Phone', user!.phone!),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Interests Section
                      if (interests.isNotEmpty) ...[
                        _buildSectionHeader('Interests & Passions', Icons.local_fire_department_rounded),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: interests.map((interest) {
                            final formatted = ProfileCardModel.formatInterest(interest);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.darkSurface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                formatted,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Photos Gallery Preview (if more than 1 photo)
                      if (photos.length > 1) ...[
                        _buildSectionHeader('My Photos (${photos.length})', Icons.photo_library_rounded),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final isSelected = _currentPhotoIndex == index;
                              return GestureDetector(
                                onTap: () {
                                  _pageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : Colors.white12,
                                      width: isSelected ? 2.5 : 1.0,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: _buildGalleryImage(
                                      photos[index],
                                      width: 90,
                                      height: 110,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryLight, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailBadge(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryLight),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
