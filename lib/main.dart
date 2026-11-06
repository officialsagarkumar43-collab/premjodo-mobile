import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/storage_service.dart';
import 'core/services/call_manager.dart';
import 'core/network/socket_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/splash_loading_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/onboarding_screen.dart';
import 'features/profile/presentation/screens/face_verification_screen.dart';
import 'features/navigation/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize storage
  await StorageService.init();

  runApp(
    const ProviderScope(
      child: PremJodoApp(),
    ),
  );

  // Initialize real-time socket and call manager asynchronously after first frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      SocketService().connect();
    } catch (_) {}
    try {
      CallManager().initialize();
    } catch (_) {}
  });
}

class PremJodoApp extends ConsumerWidget {
  const PremJodoApp({super.key});

  Widget _getRootScreen(AuthState authState) {
    if (!authState.isInitialized) {
      return const SplashLoadingScreen();
    }
    if (!authState.isAuthenticated || authState.user == null) {
      return const LoginScreen();
    }
    final user = authState.user!;
    if (!user.isFaceVerification) {
      return const FaceVerificationScreen(isMandatoryFlow: true);
    }
    if (!user.isOnboarded) {
      return const OnboardingScreen();
    }
    return const MainNavigationScreen();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      navigatorKey: CallManager().navigatorKey,
      title: 'Prem Jodo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: _getRootScreen(authState),
    );
  }
}
