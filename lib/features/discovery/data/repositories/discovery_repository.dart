import 'package:dio/dio.dart';
import 'package:prem_jodo_mobile/core/constants/api_endpoints.dart';
import 'package:prem_jodo_mobile/core/network/api_client.dart';
import 'package:prem_jodo_mobile/features/discovery/data/models/profile_card_model.dart';

class DiscoveryRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<ProfileCardModel>> getRecommendations({
    double? maxDistance,
    int? minAge,
    int? maxAge,
    String? gender,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (maxDistance != null) queryParams['distance'] = maxDistance.round();
      if (minAge != null) queryParams['minAge'] = minAge;
      if (maxAge != null) queryParams['maxAge'] = maxAge;
      if (gender != null &&
          gender.isNotEmpty &&
          gender.toLowerCase() != 'everyone' &&
          gender.toLowerCase() != 'all') {
        queryParams['gender'] = gender.toLowerCase();
      }

      final response = await _apiClient.get(
        ApiEndpoints.getDiscoveryFeed,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data;
        final list = (raw is List)
            ? raw
            : (raw['data'] is List)
                ? raw['data'] as List<dynamic>
                : (raw['feed'] is List)
                    ? raw['feed'] as List<dynamic>
                    : null;

        if (list != null) {
          return list
              .map((e) => ProfileCardModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      // Return empty list on network/auth error - no dummy data
      return [];
    }
    return [];
  }

  Future<Map<String, dynamic>?> getSubscriptionQuota() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.getMySubscription);
      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data;
        if (raw is Map) {
          final data = raw['data'] is Map ? raw['data'] as Map<String, dynamic> : raw as Map<String, dynamic>;
          return data;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> swipeUser({
    required String targetUserId,
    required String action,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.swipeAction,
        data: {
          'receiverId': targetUserId,
          'action': action,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final rawData = response.data is Map ? response.data as Map<String, dynamic> : <String, dynamic>{};
        final innerData = rawData['data'] is Map ? rawData['data'] as Map<String, dynamic> : rawData;
        final isMutual = innerData['isMutualMatch'] == true || rawData['isMutualMatch'] == true;
        final convId = innerData['conversation']?['_id'] ??
            rawData['conversation']?['_id'] ??
            innerData['match']?['_id'] ??
            rawData['match']?['_id'] ??
            targetUserId;

        return {
          'success': true,
          'isMutualMatch': isMutual,
          'conversationId': convId?.toString(),
          'conversation': innerData['conversation'] ?? rawData['conversation'],
          'swipesRemainingToday': innerData['swipesRemainingToday'],
          'dailySwipeLimit': innerData['dailySwipeLimit'],
          'unlimitedSwipes': innerData['unlimitedSwipes'] == true,
          'swipesUsedToday': innerData['swipesUsedToday'],
          'data': innerData,
        };
      }
    } on DioException catch (dioErr) {
      final respData = dioErr.response?.data;
      String message = 'Daily swipe limit reached';
      if (respData is Map) {
        message = respData['message']?.toString() ?? respData['error']?.toString() ?? message;
      }
      final statusCode = dioErr.response?.statusCode;
      final isLimit = statusCode == 429 || message.toLowerCase().contains('swipe limit') || message.toLowerCase().contains('50');
      return {
        'success': false,
        'isLimitReached': isLimit,
        'message': message,
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
    return {'success': false};
  }
}
