import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/widgets/custom_button.dart';
import 'package:prem_jodo_mobile/core/widgets/custom_text_field.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:prem_jodo_mobile/features/profile/presentation/screens/face_verification_screen.dart';
import 'package:prem_jodo_mobile/features/navigation/screens/main_navigation_screen.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  String? _localErrorMessage;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(() {
      if (_localErrorMessage != null && mounted) {
        setState(() {
          _localErrorMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      setState(() {
        _localErrorMessage = 'Please enter a valid 4 to 6-digit OTP code.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_localErrorMessage!),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _localErrorMessage = null;
    });

    await StorageService.saveLastEmail(widget.email);
    final success = await ref.read(authProvider.notifier).verifyOtp(widget.email, otp);
    if (!mounted) return;

    if (success) {
      final user = ref.read(authProvider).user;
      Widget nextScreen;
      if (user?.isFaceVerification != true) {
        nextScreen = const FaceVerificationScreen(isMandatoryFlow: true);
      } else if (user?.isOnboarded != true) {
        nextScreen = const OnboardingScreen();
      } else {
        nextScreen = const MainNavigationScreen();
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => nextScreen),
        (route) => false,
      );
    } else {
      final backendError = ref.read(authProvider).errorMessage ?? 'Invalid OTP code. Please try again.';
      setState(() {
        _localErrorMessage = backendError;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  backendError,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _resendOtp() async {
    if (_isResending) return;
    setState(() => _isResending = true);

    final success = await ref.read(authProvider.notifier).sendOtp(widget.email);
    if (!mounted) return;
    setState(() => _isResending = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('OTP resent successfully to your email!'),
            ],
          ),
          backgroundColor: AppColors.onlineGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      final errorMsg = ref.read(authProvider).errorMessage ?? 'Failed to resend OTP';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email OTP'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter Verification Code',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'We have sent a verification code to\n${widget.email}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondaryDark,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 32),
              CustomTextField(
                controller: _otpController,
                hintText: 'Enter 4 or 6 digit OTP',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.lock_outline_rounded,
              ),

              // Inline Error Message Banner
              if (_localErrorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _localErrorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              CustomButton(
                text: 'Verify & Continue',
                isLoading: authState.isLoading,
                onPressed: _verifyOtp,
              ),
              const SizedBox(height: 32),
              Center(
                child: TextButton(
                  onPressed: _isResending ? null : _resendOtp,
                  child: _isResending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                        )
                      : const Text(
                          'Resend OTP Code',
                          style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600),
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
