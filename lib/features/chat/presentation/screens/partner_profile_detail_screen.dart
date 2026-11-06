import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/utils/image_helper.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';
import 'package:prem_jodo_mobile/features/chat/presentation/screens/call_screen.dart';
import 'package:prem_jodo_mobile/features/discovery/data/models/profile_card_model.dart';

class PartnerProfileDetailScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  final String partnerAvatar;
  final String conversationId;
  final List<String> photos;
  final String bio;
  final List<String> interests;
  final String occupation;
  final String city;
  final int? age;
  final String? gender;
  final String? education;
  final String? lookingFor;
  final bool isVerified;

  const PartnerProfileDetailScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
    required this.partnerAvatar,
    required this.conversationId,
    this.photos = const [],
    this.bio = '',
    this.interests = const [],
    this.occupation = 'Member',
    this.city = 'India',
    this.age,
    this.gender,
    this.education,
    this.lookingFor,
    this.isVerified = false,
  });

  @override
  State<PartnerProfileDetailScreen> createState() => _PartnerProfileDetailScreenState();
}

class _PartnerProfileDetailScreenState extends State<PartnerProfileDetailScreen> {
  late final PageController _pageController;
  int _currentPhotoIndex = 0;

  List<String> get _displayPhotos {
    final list = <String>[];
    for (var p in widget.photos) {
      final res = ImageHelper.resolveImageUrl(p);
      if (res.isNotEmpty && !list.contains(res)) list.add(res);
    }
    if (widget.partnerAvatar.isNotEmpty) {
      final resAvatar = ImageHelper.resolveImageUrl(widget.partnerAvatar);
      if (resAvatar.isNotEmpty && !list.contains(resAvatar)) {
        list.insert(0, resAvatar);
      }
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPhoto() {
    final photos = _displayPhotos;
    if (_currentPhotoIndex < photos.length - 1) {
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

  String _formatLookingFor(String? value) {
    if (value == null || value.isEmpty) return 'Dating & Connection';
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map((e) => e.isNotEmpty ? '${e[0].toUpperCase()}${e.substring(1)}' : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final photos = _displayPhotos;
    final displayAge = widget.age ?? 24;
    final displayBio = widget.bio.isNotEmpty
        ? widget.bio
        : 'Looking for someone who loves spontaneous coffee dates and good conversations ✨';
    final displayInterests = widget.interests.isNotEmpty
        ? widget.interests
        : ['Coffee', 'Music', 'Travel', 'Photography', 'Design', 'Fitness'];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      body: CustomScrollView(
        slivers: [
          // 1. Full-Height Image Gallery with Story Tabs & Top Controls
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.62,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo PageView
                  if (photos.isNotEmpty)
                    PageView.builder(
                      controller: _pageController,
                      itemCount: photos.length,
                      onPageChanged: (idx) => setState(() => _currentPhotoIndex = idx),
                      itemBuilder: (context, index) {
                        final photoUrl = photos[index];
                        if (!photoUrl.startsWith('http://') &&
                            !photoUrl.startsWith('https://') &&
                            !photoUrl.startsWith('data:') &&
                            !photoUrl.startsWith('blob:')) {
                          try {
                            final file = File(photoUrl);
                            if (file.existsSync()) {
                              return Image.file(
                                file,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFF161824),
                                  child: const Icon(Icons.person, size: 80, color: Colors.white24),
                                ),
                              );
                            }
                          } catch (_) {}
                        }
                        return CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFF161824),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF161824),
                              child: const Icon(Icons.person, size: 80, color: Colors.white24),
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      color: const Color(0xFF161824),
                      child: const Icon(Icons.person, size: 80, color: Colors.white24),
                    ),

                  // Tap Left / Right Overlay for Photo Switch
                  if (photos.length > 1)
                    Row(
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
                            onTap: _nextPhoto,
                          ),
                        ),
                      ],
                    ),

                  // Top Gradient Overlay
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black87, Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Bottom Gradient Overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 140,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Color(0xFF0D0E15)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Photo Story Dash Indicator Bars
                  if (photos.length > 1)
                    Positioned(
                      top: 44,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: List.generate(photos.length, (idx) {
                          return Expanded(
                            child: Container(
                              height: 3.5,
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              decoration: BoxDecoration(
                                color: _currentPhotoIndex == idx
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                  // Top Action Controls (Back & Photo Count Badge)
                  Positioned(
                    top: 56,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back Button
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.5),
                            padding: const EdgeInsets.all(8),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),

                        // Photos Counter Badge
                        if (photos.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              '${_currentPhotoIndex + 1}/${photos.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Name & Details Floating on Bottom of Photo
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${widget.partnerName}, $displayAge',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                              ),
                            ),
                            if (widget.isVerified) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.verified_rounded, color: Color(0xFF1E88E5), size: 24),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              widget.city,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (widget.occupation.isNotEmpty && widget.occupation != 'Member') ...[
                              const SizedBox(width: 12),
                              const Icon(Icons.work_outline_rounded, color: Colors.white60, size: 15),
                              const SizedBox(width: 4),
                              Text(
                                widget.occupation,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Profile Details Content Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // About Me Section
                  _buildSectionCard(
                    title: 'About Me',
                    icon: Icons.format_quote_rounded,
                    child: Text(
                      displayBio,
                      style: const TextStyle(
                        color: Color(0xFFD4D6E0),
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Interests / Passions Section
                  _buildSectionCard(
                    title: 'Interests & Passions',
                    icon: Icons.local_fire_department_rounded,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: displayInterests.map((interest) {
                        final formatted = ProfileCardModel.formatInterest(interest);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.18),
                                const Color(0xFF9C27B0).withValues(alpha: 0.18),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            formatted,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Basics & Lifestyle Details Card
                  _buildSectionCard(
                    title: 'Basics & Lifestyle',
                    icon: Icons.info_outline_rounded,
                    child: Column(
                      children: [
                        _buildInfoRow(
                          icon: Icons.favorite_border_rounded,
                          label: 'Looking For',
                          value: _formatLookingFor(widget.lookingFor),
                        ),
                        if (widget.education != null && widget.education!.isNotEmpty)
                          _buildInfoRow(
                            icon: Icons.school_outlined,
                            label: 'Education',
                            value: widget.education!,
                          ),
                        if (widget.gender != null && widget.gender!.isNotEmpty)
                          _buildInfoRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Gender',
                            value: widget.gender!.toUpperCase(),
                          ),
                        _buildInfoRow(
                          icon: Icons.verified_user_outlined,
                          label: 'Profile Status',
                          value: widget.isVerified ? 'Photo & Face Verified' : 'Standard Member',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 110), // Padding for bottom floating actions
                ],
              ),
            ),
          ),
        ],
      ),

      // 3. Floating Bottom Call & Chat Action Buttons
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF141520),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Audio Call Action
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkSurface,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.white12),
                  ),
                ),
                icon: const Icon(Icons.call_rounded, color: AppColors.onlineGreen, size: 20),
                label: const Text('Audio Call', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                onPressed: () {
                  final currentName = StorageService.getUserName() ?? 'Prem Jodo Member';
                  final currentAvatar = StorageService.getUserAvatar() ?? '';

                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CallScreen(
                        channelName: widget.conversationId,
                        partnerId: widget.partnerId,
                        partnerName: widget.partnerName,
                        partnerAvatar: widget.partnerAvatar,
                        callerName: currentName,
                        callerAvatar: currentAvatar,
                        isVideo: false,
                        isCaller: true,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: 12),

            // Video Call Action
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                ),
                icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
                label: const Text('Video Call', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                onPressed: () {
                  final currentName = StorageService.getUserName() ?? 'Prem Jodo Member';
                  final currentAvatar = StorageService.getUserAvatar() ?? '';

                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CallScreen(
                        channelName: widget.conversationId,
                        partnerId: widget.partnerId,
                        partnerName: widget.partnerName,
                        partnerAvatar: widget.partnerAvatar,
                        callerName: currentName,
                        callerAvatar: currentAvatar,
                        isVideo: true,
                        isCaller: true,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161824),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
