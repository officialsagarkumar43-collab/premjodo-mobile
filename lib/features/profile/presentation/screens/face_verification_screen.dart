import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:prem_jodo_mobile/core/constants/api_endpoints.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/network/api_client.dart';
import 'package:prem_jodo_mobile/core/widgets/custom_button.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:prem_jodo_mobile/features/navigation/screens/main_navigation_screen.dart';

class FaceVerificationScreen extends ConsumerStatefulWidget {
  final bool isMandatoryFlow;

  const FaceVerificationScreen({
    super.key,
    this.isMandatoryFlow = false,
  });

  @override
  ConsumerState<FaceVerificationScreen> createState() =>
      _FaceVerificationScreenState();
}

class _FaceVerificationScreenState
    extends ConsumerState<FaceVerificationScreen> {
  bool _isScanning = false;
  bool _isVerified = false;
  File? _selfieImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _captureSelfieAndVerify() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );

      if (photo == null) return;

      setState(() {
        _selfieImage = File(photo.path);
        _isScanning = true;
      });

      final apiClient = ApiClient();
      final fileName = photo.path.split(RegExp(r'[/\\]')).last;

      Response? response;
      try {
        final formData = FormData.fromMap({
          'image': await MultipartFile.fromFile(
            photo.path,
            filename: fileName.isNotEmpty ? fileName : 'face_verification.jpg',
          ),
          'photo': await MultipartFile.fromFile(
            photo.path,
            filename: fileName.isNotEmpty ? fileName : 'face_verification.jpg',
          ),
          'selfie': await MultipartFile.fromFile(
            photo.path,
            filename: fileName.isNotEmpty ? fileName : 'face_verification.jpg',
          ),
          'face': await MultipartFile.fromFile(
            photo.path,
            filename: fileName.isNotEmpty ? fileName : 'face_verification.jpg',
          ),
        });
        response = await apiClient.post(
          ApiEndpoints.verifyFace,
          data: formData,
        );
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 404) {
          // Fallback to /auth/face-verification if not mounted under /users
          final fallbackFormData = FormData.fromMap({
            'image': await MultipartFile.fromFile(
              photo.path,
              filename: fileName.isNotEmpty ? fileName : 'face_verification.jpg',
            ),
            'photo': await MultipartFile.fromFile(
              photo.path,
              filename: fileName.isNotEmpty ? fileName : 'face_verification.jpg',
            ),
            'selfie': await MultipartFile.fromFile(
              photo.path,
              filename: fileName.isNotEmpty ? fileName : 'face_verification.jpg',
            ),
          });
          response = await apiClient.post(
            '/auth/face-verification',
            data: fallbackFormData,
          );
        } else {
          rethrow;
        }
      }

      final int statusCode = response.statusCode ?? 0;
      final bool isSuccessStatus = statusCode >= 200 && statusCode < 300;

      final dynamic responseData = response.data;
      final bool isExplicitFailure = responseData is Map &&
          (responseData['success'] == false ||
              responseData['status'] == 'fail' ||
              responseData['status'] == 'error');

      if (isSuccessStatus && !isExplicitFailure) {
        try {
          await ref.read(authProvider.notifier).checkAuthStatus();
        } catch (e) {
          debugPrint('Silent checkAuthStatus error after face verification: $e');
        }
        if (mounted) {
          setState(() {
            _isScanning = false;
            _isVerified = true;
          });
        }
      } else {
        String msg = 'Face verification failed';
        if (responseData is Map && responseData['message'] != null) {
          msg = responseData['message'].toString();
        } else if (statusCode != 0) {
          msg = 'Verification upload failed with status $statusCode';
        }
        throw Exception(msg);
      }
    } catch (e) {
      debugPrint('Face verification error: $e');
      String errorMessage = 'Face verification failed. Please try again.';
      if (e is DioException) {
        if (e.response?.data is Map) {
          final data = e.response!.data as Map;
          if (data['message'] != null) {
            errorMessage = data['message'].toString();
          } else if (data['error'] != null) {
            errorMessage = data['error'].toString();
          }
        } else if (e.message != null && e.message!.isNotEmpty) {
          errorMessage = e.message!;
        }
      } else if (e is Exception) {
        errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
      }
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleNextStep() {
    final user = ref.read(authProvider).user;
    final isOnboarded = user?.isOnboarded ?? false;

    if (!isOnboarded) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    } else {
      if (Navigator.of(context).canPop() && !widget.isMandatoryFlow) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isOnboarded = user?.isOnboarded ?? false;
    final bool canGoBack = Navigator.of(context).canPop() &&
        !widget.isMandatoryFlow &&
        isOnboarded;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Face Verification',
            style: TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: canGoBack,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const Text(
                'Verify Your Real Identity 📸',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hold your phone at eye level. Our AI will verify your live face to give you the official blue checkmark badge.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
              ),
              const Spacer(),
              // Camera / Face Frame
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isVerified
                          ? AppColors.onlineGreen
                          : (_isScanning ? AppColors.primary : Colors.white24),
                      width: 4,
                    ),
                    color: AppColors.darkSurface,
                    boxShadow: [
                      BoxShadow(
                        color: (_isVerified
                                ? AppColors.onlineGreen
                                : AppColors.primary)
                            .withValues(alpha: 0.25),
                        blurRadius: 25,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _selfieImage != null
                        ? Image.file(_selfieImage!, fit: BoxFit.cover)
                        : Center(
                            child: _isVerified
                                ? const Icon(Icons.check_circle_rounded,
                                    size: 80, color: AppColors.onlineGreen)
                                : _isScanning
                                    ? const CircularProgressIndicator(
                                        color: AppColors.primary,
                                        strokeWidth: 3)
                                    : const Icon(
                                        Icons.face_retouching_natural_rounded,
                                        size: 100,
                                        color: Colors.white38),
                          ),
                  ),
                ),
              ),
              const Spacer(),
              if (_isVerified) ...[
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_rounded,
                        color: AppColors.onlineGreen, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Verified Successfully! 🎉',
                      style: TextStyle(
                          color: AppColors.onlineGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                CustomButton(
                  text: !isOnboarded
                      ? 'Continue to Profile Setup'
                      : 'Continue to App',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _handleNextStep,
                ),
              ] else ...[
                CustomButton(
                  text:
                      _isScanning ? 'Verifying with AI...' : 'Take Live Selfie',
                  isLoading: _isScanning,
                  icon: Icons.camera_alt_rounded,
                  onPressed: _isScanning ? null : _captureSelfieAndVerify,
                ),
                if (!isOnboarded || widget.isMandatoryFlow) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _handleNextStep,
                    child: const Text('Skip for now',
                        style: TextStyle(color: Colors.white54)),
                  ),
                ],
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
