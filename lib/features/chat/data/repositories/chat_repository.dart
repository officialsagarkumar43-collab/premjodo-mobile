import 'package:prem_jodo_mobile/core/constants/api_endpoints.dart';
import 'package:prem_jodo_mobile/core/network/api_client.dart';
import 'package:prem_jodo_mobile/features/chat/data/models/conversation_model.dart';
import 'package:prem_jodo_mobile/features/chat/data/models/chat_message_model.dart';

class ConversationsResponse {
  final List<ConversationModel> conversations;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasMore;
  final bool isSuccess;

  ConversationsResponse({
    required this.conversations,
    this.page = 1,
    this.limit = 10,
    this.total = 0,
    this.totalPages = 1,
    this.hasMore = false,
    this.isSuccess = true,
  });
}

class ChatRepository {
  final ApiClient _apiClient = ApiClient();
  final Map<String, List<ChatMessageModel>> _messageCache = {};

  void clearCache() {
    _messageCache.clear();
  }

  List<ChatMessageModel>? getCachedMessages(String conversationId) {
    final cleanId = conversationId.replaceAll('conv_', '').trim();
    return _messageCache[cleanId] ?? _messageCache[conversationId];
  }

  void cacheMessages(String conversationId, List<ChatMessageModel> messages) {
    final cleanId = conversationId.replaceAll('conv_', '').trim();
    _messageCache[cleanId] = List<ChatMessageModel>.from(messages);
    _messageCache[conversationId] = List<ChatMessageModel>.from(messages);
  }

  Future<ConversationsResponse> getConversations({int page = 1, int limit = 10}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.getConversations,
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data;
        final list = (raw is List)
            ? raw
            : (raw is Map && raw['data'] is Map && raw['data']['conversations'] is List)
                ? raw['data']['conversations'] as List<dynamic>
                : (raw is Map && raw['data'] is List)
                    ? raw['data'] as List<dynamic>
                    : (raw is Map && raw['conversations'] is List)
                        ? raw['conversations'] as List<dynamic>
                        : null;

        int resPage = page;
        int resLimit = limit;
        int resTotal = 0;
        int resTotalPages = 1;
        bool resHasMore = false;

        final paginationMap = (raw is Map && raw['data'] is Map && raw['data']['pagination'] is Map)
            ? raw['data']['pagination'] as Map
            : (raw is Map && raw['pagination'] is Map)
                ? raw['pagination'] as Map
                : null;

        if (paginationMap != null) {
          resPage = paginationMap['page'] is int
              ? paginationMap['page']
              : int.tryParse(paginationMap['page']?.toString() ?? '$page') ?? page;
          resLimit = paginationMap['limit'] is int
              ? paginationMap['limit']
              : int.tryParse(paginationMap['limit']?.toString() ?? '$limit') ?? limit;
          resTotal = paginationMap['total'] is int
              ? paginationMap['total']
              : (paginationMap['totalConversations'] is int
                  ? paginationMap['totalConversations']
                  : int.tryParse(paginationMap['total']?.toString() ?? '0') ?? 0);
          resTotalPages = paginationMap['totalPages'] is int
              ? paginationMap['totalPages']
              : int.tryParse(paginationMap['totalPages']?.toString() ?? '1') ?? 1;
          resHasMore = paginationMap['hasMore'] == true ||
              paginationMap['hasNextPage'] == true ||
              (resPage < resTotalPages);
        } else if (list != null) {
          resHasMore = list.length >= limit;
        }

        if (list != null) {
          final convos = list
              .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
              .toList();

          // Populate cache with messages returned directly by the conversation API
          for (var convo in convos) {
            if (convo.messages.isNotEmpty) {
              cacheMessages(convo.id, convo.messages);
            }
          }

          return ConversationsResponse(
            conversations: convos,
            page: resPage,
            limit: resLimit,
            total: resTotal,
            totalPages: resTotalPages,
            hasMore: resHasMore,
            isSuccess: true,
          );
        }
      }
    } catch (_) {
      return ConversationsResponse(conversations: [], isSuccess: false);
    }
    return ConversationsResponse(conversations: [], isSuccess: false);
  }

  Future<List<ChatMessageModel>> getMessages(String conversationId) async {
    // Return cached messages parsed from conversation API without hitting separate message endpoint
    return getCachedMessages(conversationId) ?? [];
  }

  Future<ChatMessageModel?> sendMessage({
    required String conversationId,
    required String receiverId,
    required String message,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.getConversationMessages(conversationId),
        data: {
          'content': message,
          'message': message,
          'receiverId': receiverId,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = response.data;
        final data = raw['data'] ?? raw['message'] ?? raw;
        if (data is Map<String, dynamic>) {
          return ChatMessageModel.fromJson(data);
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final cleanId = conversationId.replaceAll('conv_', '').trim();
    try {
      await _apiClient.patch(ApiEndpoints.markConversationRead(cleanId));
    } catch (_) {}
  }

  Future<void> clearConversationMessages(String conversationId) async {
    final cleanId = conversationId.replaceAll('conv_', '').trim();
    try {
      await _apiClient.post(ApiEndpoints.clearConversationMessages(cleanId));
    } catch (_) {}
  }
}
