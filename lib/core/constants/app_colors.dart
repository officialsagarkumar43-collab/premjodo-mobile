import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Brand Colors (Vibrant Romantic Rose & Sunset Gradient)
  static const Color primary = Color(0xFFFF2D55);
  static const Color primaryLight = Color(0xFFFF6480);
  static const Color primaryDark = Color(0xFFD81B60);
  static const Color accent = Color(0xFFFF5E3A);
  static const Color secondary = Color(0xFF8A2BE2);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF2D55), Color(0xFFFF5E3A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumGoldGradient = LinearGradient(
    colors: [Color(0xFFFF2D55), Color(0xFFFF758C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardOverlayGradient = LinearGradient(
    colors: [Colors.transparent, Color(0x99000000), Color(0xEE0B0C10)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkSurfaceGradient = LinearGradient(
    colors: [Color(0xFF1E1F28), Color(0xFF14151B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Background & Surfaces
  static const Color darkBackground = Color(0xFF0D0E15);
  static const Color darkCard = Color(0xFF181924);
  static const Color darkSurface = Color(0xFF222433);
  static const Color lightBackground = Color(0xFFF8F9FD);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF0F2F8);

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF11142D);
  static const Color textSecondaryLight = Color(0xFF70768C);
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFF9E9EA7);

  // Status & Utility Colors
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFAB00);
  static const Color error = Color(0xFFFF3D71);
  static const Color info = Color(0xFF0095FF);
  static const Color onlineGreen = Color(0xFF10B981);
  static const Color gold = Color(0xFFFF758C);

  // Swipe & Action Buttons
  static const Color nopeRed = Color(0xFFFF4B4B);
  static const Color likeGreen = Color(0xFF24D087);
  static const Color superLikeBlue = Color(0xFF00A3FF);
  static const Color boostPurple = Color(0xFFA855F7);
}
