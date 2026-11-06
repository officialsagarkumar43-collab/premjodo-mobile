import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/widgets/custom_button.dart';
import 'package:prem_jodo_mobile/core/widgets/custom_text_field.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:prem_jodo_mobile/features/profile/presentation/screens/face_verification_screen.dart';
import 'package:prem_jodo_mobile/features/navigation/screens/main_navigation_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    final saved = StorageService.getLastEmail();
    if (saved != null && saved.isNotEmpty) {
      _emailController.text = saved;
    }
  }

  void _handleSendEmailOtp() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      await StorageService.saveLastEmail(email);
      final success = await ref.read(authProvider.notifier).sendOtp(email);
      if (!mounted) return;
      
      if (success) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(email: email),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(authProvider).errorMessage ?? 'Failed to send OTP to $email'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Clear any prior cached session to ensure the Google account selector opens fresh
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? account = await googleSignIn.signIn();

      if (account == null) {
        // User cancelled/dismissed the Google prompt
        if (mounted) setState(() => _isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final email = account.email;
      final name = (account.displayName != null && account.displayName!.isNotEmpty)
          ? account.displayName!
          : (email.contains('@') ? email.split('@').first : 'User');
      final photoUrl = account.photoUrl;
      final idToken = auth.idToken;

      final success = await ref.read(authProvider.notifier).loginWithGoogle(
        idToken: idToken,
        email: email,
        name: name,
        photoUrl: photoUrl,
      );

      if (!mounted) return;
      setState(() => _isGoogleLoading = false);

      if (success) {
        final user = ref.read(authProvider).user;
        Widget nextScreen;
        if (user != null && !user.isFaceVerification) {
          nextScreen = const FaceVerificationScreen(isMandatoryFlow: true);
        } else if (user != null && !user.isOnboarded) {
          nextScreen = const OnboardingScreen();
        } else {
          nextScreen = const MainNavigationScreen();
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => nextScreen),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(authProvider).errorMessage ?? 'Google login failed. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In: ${e.toString().replaceAll('Exception:', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF16091B), Color(0xFF0D0E15)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      // Brand Logo / Heart Icon
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 25,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'Prem Jodo',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Discover genuine connections & soulmates',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const Spacer(),
                      CustomTextField(
                        controller: _emailController,
                        labelText: 'Email Address',
                        hintText: 'yourname@example.com',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email address';
                          }
                          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      CustomButton(
                        text: 'Continue with Email OTP',
                        icon: Icons.mark_email_read_outlined,
                        isLoading: authState.isLoading && !_isGoogleLoading,
                        onPressed: _handleSendEmailOtp,
                      ),
                      const SizedBox(height: 20),
                      // Divider with "OR"
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Continue with Google Button
                      InkWell(
                        onTap: (_isGoogleLoading || authState.isLoading) ? null : _handleGoogleSignIn,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _isGoogleLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Google G Icon
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                      ),
                                      child: Image.network(
                                        'https://www.gstatic.com/images/branding/product/1x/gsa_512dp.png',
                                        width: 24,
                                        height: 24,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.g_mobiledata_rounded,
                                          color: Colors.black87,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        color: Color(0xFF1E1E1E),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          'By continuing you agree to our Terms & Privacy Policy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryDark.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
