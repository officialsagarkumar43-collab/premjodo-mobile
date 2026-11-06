import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/utils/image_helper.dart';

class AppAvatar extends StatelessWidget {
  final String imageUrl;
  final String name;
  final double size;
  final bool isOnline;
  final bool showOnlineIndicator;

  const AppAvatar({
    super.key,
    required this.imageUrl,
    this.name = '',
    this.size = 52,
    this.isOnline = false,
    this.showOnlineIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (name.trim().isNotEmpty && name.trim() != 'Match')
        ? name.trim()[0].toUpperCase()
        : '?';

    final fallback = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.42,
        ),
      ),
    );

    final resolved = ImageHelper.resolveImageUrl(imageUrl);

    Widget avatarImage;
    if (resolved.trim().isEmpty) {
      avatarImage = fallback;
    } else if (!resolved.startsWith('http://') &&
        !resolved.startsWith('https://') &&
        !resolved.startsWith('data:') &&
        !resolved.startsWith('blob:')) {
      final file = File(resolved);
      if (file.existsSync()) {
        avatarImage = Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        );
      } else {
        avatarImage = fallback;
      }
    } else {
      avatarImage = CachedNetworkImage(
        imageUrl: resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: AppColors.darkSurface,
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => fallback,
      );
    }

    final circularAvatar = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: avatarImage,
      ),
    );

    if (!showOnlineIndicator) {
      return circularAvatar;
    }

    return Stack(
      children: [
        circularAvatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.onlineGreen : const Color(0xFF555566),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.darkBackground,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
