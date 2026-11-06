import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prem_jodo_mobile/features/auth/data/models/user_model.dart';
import 'package:prem_jodo_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';
import 'package:prem_jodo_mobile/core/network/socket_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final bool isInitialized;
  final bool isAuthenticated;
  final String? errorMessage;

  AuthState({
    this.user,
    this.isLoading = false,
    this.isInitialized = false,
    this.isAuthenticated = false,
    this.errorMessage,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    bool? isInitialized,
    bool? isAuthenticated,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState()) {
    checkAuthStatus(isInitialBoot: true);
  }

  Future<void> checkAuthStatus({bool isInitialBoot = false}) async {
    // Show splash screen for at least 1500ms on initial cold boot for smooth UX
    final Future<void>? splashMinTimer =
        isInitialBoot ? Future.delayed(const Duration(milliseconds: 1500)) : null;

    final token = StorageService.getToken();
    UserModel? cachedUser;

    final cachedDataStr = StorageService.getUserDataString();
    if (cachedDataStr != null && cachedDataStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedDataStr);
        if (decoded is Map<String, dynamic>) {
          cachedUser = UserModel.fromJson(decoded);
        }
      } catch (e) {
        debugPrint('Error parsing cached user data: $e');
      }
    }

    if (token != null && token.isNotEmpty) {
      // Decode JWT payload so user object is immediately available even if offline
      if (cachedUser == null) {
        final jwtPayload = StorageService.decodeJwt(token);
        final uid = jwtPayload?['_id'] ?? StorageService.getUserId() ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
        final email = jwtPayload?['email'];
        final savedName = StorageService.getUserName();
        final savedAvatar = StorageService.getUserAvatar();

        cachedUser = UserModel(
          id: uid.toString(),
          email: email?.toString(),
          name: (savedName != null && savedName.isNotEmpty) ? savedName : (email?.split('@').first ?? 'Prem Jodo Member'),
          photos: (savedAvatar != null && savedAvatar.isNotEmpty) ? [savedAvatar] : [],
          isOnboarded: true,
          isFaceVerification: true,
        );
        try {
          await StorageService.saveUserId(cachedUser.id);
          await StorageService.saveUserData(jsonEncode(cachedUser.toJson()));
        } catch (_) {}
      }

      // 1. Immediately mark user authenticated with cached/decoded model
      state = state.copyWith(
        user: cachedUser,
        isAuthenticated: true,
        isLoading: !isInitialBoot,
      );
      SocketService().connect(forceReconnect: true);
      SocketService().registerUser(cachedUser.id);

      // 2. Refresh live profile asynchronously
      try {
        final liveUser = await _repository.getProfile();
        if (liveUser != null) {
          await StorageService.saveUserId(liveUser.id);
          await StorageService.saveUserProfileInfo(
            name: liveUser.name,
            avatar: liveUser.photos.isNotEmpty ? liveUser.photos.first : '',
          );
          try {
            await StorageService.saveUserData(jsonEncode(liveUser.toJson()));
          } catch (_) {}

          SocketService().connect(forceReconnect: true);
          SocketService().registerUser(liveUser.id);

          state = state.copyWith(
            user: liveUser,
            isAuthenticated: true,
            isLoading: false,
          );
        }
      } catch (e) {
        debugPrint('checkAuthStatus live fetch background error: $e');
        // Do NOT log out user! Session remains preserved!
      }
    } else {
      state = state.copyWith(
        user: null,
        isAuthenticated: false,
        isLoading: false,
      );
    }

    // Wait for minimum splash animation time on cold boot
    if (splashMinTimer != null) {
      await splashMinTimer;
    }

    final hasToken = token != null && token.isNotEmpty;
    final finalUser = state.user ?? cachedUser;
    final isAuthed = hasToken && (finalUser != null);

    state = state.copyWith(
      isLoading: false,
      isInitialized: true,
      isAuthenticated: isAuthed,
      user: finalUser,
    );
  }

  Future<bool> sendOtp(String identifier) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _repository.sendOtp(identifier);
      if (result['success'] == true) {
        state = state.copyWith(isLoading: false, errorMessage: null);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: result['error'] ?? 'Failed to send OTP',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> verifyOtp(String identifier, String otp) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _repository.verifyOtp(identifier, otp);
      if (result['success'] == true) {
        final user = result['user'] as UserModel?;
        if (user != null) {
          await StorageService.saveUserId(user.id);
          await StorageService.saveUserProfileInfo(
            name: user.name,
            avatar: user.photos.isNotEmpty ? user.photos.first : '',
          );
          SocketService().connect(forceReconnect: true);
          SocketService().registerUser(user.id);
        }
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: user,
          errorMessage: null,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: result['error'] ?? 'Invalid OTP code',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> loginWithGoogle({String? idToken, String? email, String? name, String? photoUrl}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _repository.googleLogin(
        idToken: idToken,
        email: email,
        name: name,
        photoUrl: photoUrl,
      );
      if (result['success'] == true) {
        final user = result['user'] as UserModel?;
        if (user != null) {
          await StorageService.saveUserId(user.id);
          await StorageService.saveUserProfileInfo(
            name: user.name,
            avatar: user.photos.isNotEmpty ? user.photos.first : '',
          );
          SocketService().connect(forceReconnect: true);
          SocketService().registerUser(user.id);
        }
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: user,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: result['error'] ?? 'Google login failed',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    SocketService().disconnect();
    await _repository.logout();
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});

