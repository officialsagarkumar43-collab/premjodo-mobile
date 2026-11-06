import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:prem_jodo_mobile/core/constants/api_endpoints.dart';
import 'package:prem_jodo_mobile/core/network/api_client.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';
import 'package:prem_jodo_mobile/core/models/option_item.dart';
import 'package:prem_jodo_mobile/features/auth/data/models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  String _extractErrorMessage(dynamic error, {String fallback = 'An error occurred'}) {
    if (error is DioException) {
      if (error.response?.data != null) {
        final data = error.response!.data;
        if (data is Map) {
          final msg = data['message'] ?? data['error'] ?? data['msg'];
          if (msg != null && msg.toString().trim().isNotEmpty) {
            return msg.toString().trim();
          }
          if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
            final first = data['errors'][0];
            if (first is Map) {
              final nestedMsg = first['msg'] ?? first['message'] ?? first['error'];
              if (nestedMsg != null && nestedMsg.toString().trim().isNotEmpty) {
                return nestedMsg.toString().trim();
              }
            }
            return first.toString();
          }
        } else if (data is String && data.trim().isNotEmpty) {
          return data.trim();
        }
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Connection timed out. Please check your internet connection.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Unable to connect to server. Please check your internet connection.';
      }
    }
    return fallback;
  }

  Future<Map<String, dynamic>> sendOtp(String identifier) async {
    final isEmail = identifier.contains('@');
    final payload = isEmail ? {'email': identifier} : {'phone': identifier};
    try {
      final response = await _apiClient.post(ApiEndpoints.sendOtp, data: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map && data['success'] == false) {
          return {
            'success': false,
            'error': data['message'] ?? data['error'] ?? 'Failed to send OTP',
          };
        }
        return {
          'success': true,
          'message': (data is Map) ? (data['message'] ?? 'OTP sent successfully') : 'OTP sent successfully',
        };
      }
      return {'success': false, 'error': 'Failed to send OTP'};
    } catch (e) {
      return {'success': false, 'error': _extractErrorMessage(e, fallback: 'Failed to send OTP')};
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String identifier, String otp) async {
    final isEmail = identifier.contains('@');
    final payload = isEmail
        ? {'email': identifier, 'otp': otp}
        : {'phone': identifier, 'otp': otp};
    try {
      final response = await _apiClient.post(
        ApiEndpoints.verifyOtp,
        data: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = response.data;
        if (resData is Map) {
          if (resData['success'] == false) {
            return {
              'success': false,
              'error': resData['message'] ?? resData['error'] ?? 'Invalid OTP code',
            };
          }
          final data = (resData['data'] is Map) ? resData['data'] as Map<String, dynamic> : Map<String, dynamic>.from(resData);
          final token = data['token'] ?? data['accessToken'] ?? resData['token'];

          if (token != null) {
            await StorageService.saveToken(token.toString());
          }

          final isFaceVer = data['isFaceVerification'] == true || data['isFaceVerified'] == true;
          final isOnboard = data['isOnboarded'] == true || data['isProfileCompleted'] == true;

          // Fetch full user profile with newly saved token
          var user = await getProfile();

          if (user != null) {
            user = UserModel(
              id: user.id,
              phone: user.phone,
              email: user.email ?? (isEmail ? identifier : null),
              name: user.name,
              age: user.age,
              gender: user.gender,
              bio: user.bio,
              occupation: user.occupation,
              city: user.city,
              photos: user.photos,
              isVerified: user.isVerified || isFaceVer,
              isFaceVerification: user.isFaceVerification || isFaceVer,
              isOnboarded: user.isOnboarded || isOnboard,
              isPremium: user.isPremium,
              isVip: user.isVip,
              planName: user.planName,
              subscriptionStatus: user.subscriptionStatus,
              subscription: user.subscription,
              coins: user.coins,
              interests: user.interests,
            );
          } else {
            final userJson = (data['user'] is Map) ? data['user'] as Map<String, dynamic> : data;
            user = UserModel.fromJson({
              ...userJson,
              'email': identifier,
              'isFaceVerification': isFaceVer,
              'isOnboarded': isOnboard,
            });
          }

          final jwtPayload = StorageService.decodeJwt(token.toString());
          final fallbackId = jwtPayload?['_id'] ?? StorageService.getUserId() ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
          final finalId = user.id.isNotEmpty ? user.id : fallbackId.toString();

          user = UserModel(
            id: finalId,
            phone: user.phone,
            email: user.email ?? (isEmail ? identifier : null),
            name: (user.name.isNotEmpty && user.name != 'Prem Jodo User')
                ? user.name
                : (identifier.split('@').first),
            age: user.age,
            gender: user.gender,
            bio: user.bio,
            occupation: user.occupation,
            city: user.city,
            photos: user.photos,
            isVerified: user.isVerified || isFaceVer,
            isFaceVerification: user.isFaceVerification || isFaceVer,
            isOnboarded: user.isOnboarded || isOnboard,
            isPremium: user.isPremium,
            isVip: user.isVip,
            planName: user.planName,
            subscriptionStatus: user.subscriptionStatus,
            subscription: user.subscription,
            coins: user.coins,
            interests: user.interests,
          );

          await StorageService.saveUserId(finalId);
          await StorageService.saveUserProfileInfo(
            name: user.name,
            avatar: user.photos.isNotEmpty ? user.photos.first : '',
          );
          try {
            await StorageService.saveUserData(jsonEncode(user.toJson()));
          } catch (_) {}

          return {
            'success': true,
            'user': user,
            'isNewUser': data['isNewUser'] ?? !isOnboard,
          };
        }
      }
      return {'success': false, 'error': 'Invalid OTP code'};
    } catch (e) {
      return {
        'success': false,
        'error': _extractErrorMessage(e, fallback: 'Invalid OTP code. Please enter the correct OTP.'),
      };
    }
  }

  Future<Map<String, dynamic>> googleLogin({
    String? idToken,
    String? email,
    String? name,
    String? photoUrl,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.googleLogin,
        data: {
          if (idToken != null) 'idToken': idToken,
          if (email != null) 'email': email,
          if (name != null) 'name': name,
          if (photoUrl != null) 'avatar': photoUrl,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = response.data;
        final data = (resData is Map && resData['data'] != null) ? resData['data'] : resData;
        final token = data['token'] ?? data['accessToken'] ?? resData['token'];

        if (token != null) {
          await StorageService.saveToken(token.toString());
        }

        var user = await getProfile();
        user ??= UserModel(
          id: StorageService.getUserId() ?? 'temp_user_id',
          email: email,
          name: (name != null && name.isNotEmpty) ? name : (email?.split('@').first ?? 'Prem Jodo User'),
          photos: (photoUrl != null && photoUrl.isNotEmpty) ? [photoUrl] : [],
        );

        if (user.id.isNotEmpty) {
          await StorageService.saveUserId(user.id);
          await StorageService.saveUserProfileInfo(
            name: user.name,
            avatar: user.photos.isNotEmpty ? user.photos.first : '',
          );
          try {
            await StorageService.saveUserData(jsonEncode(user.toJson()));
          } catch (_) {}
        }

        return {
          'success': true,
          'user': user,
          'isNewUser': data['isNewUser'] ?? (data['isOnboarded'] == false),
        };
      }
    } catch (e) {
      return {'success': false, 'error': _extractErrorMessage(e, fallback: 'Google authentication failed')};
    }
    return {'success': false, 'error': 'Google authentication failed'};
  }

  Future<UserModel?> getProfile() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.me);
      if (response.statusCode == 200) {
        final resData = response.data;
        final data = (resData is Map && resData['data'] != null) ? resData['data'] : resData;
        if (data is Map<String, dynamic>) {
          final userObj = data['user'] is Map ? data['user'] : data;
          final uid = userObj['_id'] ?? userObj['id'] ?? data['_id'];
          if (uid != null) {
            await StorageService.saveUserId(uid.toString());
          }

          UserModel userModel;

          // Fetch live subscription to ensure profile model has up-to-date VIP plan
          try {
            final subRes = await _apiClient.get(ApiEndpoints.getMySubscription);
            if (subRes.statusCode == 200 && subRes.data != null) {
              final subRaw = subRes.data;
              if (subRaw is Map) {
                final subData = subRaw['data'] is Map ? subRaw['data'] : subRaw;
                final subObj = subData['subscription'] is Map ? subData['subscription'] : subData;
                final enriched = Map<String, dynamic>.from(data);
                enriched['subscription'] = subObj;
                enriched['isVip'] = subData['isVip'] == true || subObj['status'] == 'active';
                userModel = UserModel.fromJson(enriched);
              } else {
                userModel = UserModel.fromJson(data);
              }
            } else {
              userModel = UserModel.fromJson(data);
            }
          } catch (_) {
            userModel = UserModel.fromJson(data);
          }

          try {
            await StorageService.saveUserData(jsonEncode(userModel.toJson()));
            await StorageService.saveUserProfileInfo(
              name: userModel.name,
              avatar: userModel.photos.isNotEmpty ? userModel.photos.first : '',
            );
          } catch (_) {}

          return userModel;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<OptionItem>> getInterestsOptions() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.getInterests);
      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data;
        final list = (resData is Map && resData['data'] != null)
            ? resData['data']
            : (resData is Map && resData['interests'] != null ? resData['interests'] : resData);
        if (list is List) {
          final result = <OptionItem>[];
          for (var item in list) {
            final opt = OptionItem.fromDynamic(item);
            if (opt.value.isNotEmpty && !result.any((r) => r.matches(opt.value))) {
              result.add(opt);
            }
          }
          return result;
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<String>> getInterests() async {
    final opts = await getInterestsOptions();
    return opts.map((e) => e.value).toList();
  }

  Future<List<OptionItem>> getLookingForOptionItems() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.getLookingForOptions);
      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data;
        final list = (resData is Map && resData['data'] != null)
            ? resData['data']
            : (resData is Map && resData['options'] != null ? resData['options'] : resData);
        if (list is List) {
          final result = <OptionItem>[];
          for (var item in list) {
            final opt = OptionItem.fromDynamic(item);
            if (opt.value.isNotEmpty && !result.any((r) => r.matches(opt.value))) {
              result.add(opt);
            }
          }
          return result;
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<String>> getLookingForOptions() async {
    final opts = await getLookingForOptionItems();
    return opts.map((e) => e.value).toList();
  }

  Future<void> logout() async {
    try {
      await _apiClient.post(ApiEndpoints.logout);
    } catch (_) {}
    await StorageService.clearAuth();
  }
}


