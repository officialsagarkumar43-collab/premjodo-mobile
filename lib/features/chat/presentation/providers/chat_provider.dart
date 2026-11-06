import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:prem_jodo_mobile/features/chat/data/models/conversation_model.dart';
import 'package:prem_jodo_mobile/features/chat/data/models/chat_message_model.dart';
import 'package:prem_jodo_mobile/features/chat/data/repositories/chat_repository.dart';
import 'package:prem_jodo_mobile/core/network/socket_service.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';
import 'package:prem_jodo_mobile/core/services/sound_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  // Recreate repository and clear cache whenever the authenticated user changes
  ref.watch(authProvider.select((s) => s.user?.id));
  final repo = ChatRepository();
  ref.onDispose(() {
    repo.clearCache();
  });
  return repo;
});

class OnlineUsersNotifier extends StateNotifier<Set<String>> {
  late final Function(Set<String>) _listener;

  OnlineUsersNotifier() : super(SocketService().onlineUsers) {
    _listener = (users) {
      if (mounted) {
        state = Set<String>.from(users);
      }
    };
    SocketService().onOnlineUsersChange(_listener);
  }

  @override
  void dispose() {
    SocketService().removeOnlineUsersListener(_listener);
    super.dispose();
  }
}

final onlineUsersProvider = StateNotifierProvider<OnlineUsersNotifier, Set<String>>((ref) {
  return OnlineUsersNotifier();
});

class ConversationsState {
  final List<ConversationModel> conversations;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;

  ConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 1,
  });

  ConversationsState copyWith({
    List<ConversationModel>? conversations,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class ConversationsNotifier extends StateNotifier<ConversationsState> {
  final ChatRepository _repository;
  final String? userId;

  late final Function(dynamic) _messageHandler;
  late final Function(dynamic) _newMatchHandler;

  ConversationsNotifier(this._repository, {this.userId}) : super(ConversationsState()) {
    final effectiveUid = userId ?? StorageService.getUserId();
    if (effectiveUid != null && effectiveUid.isNotEmpty) {
      loadConversations();
    }
    _listenSocket();
  }

  void _listenSocket() {
    _messageHandler = (data) {
      loadConversations(silent: true);
    };
    _newMatchHandler = (data) {
      loadConversations(silent: true);
    };
    SocketService().onMessageReceived(_messageHandler);
    SocketService().onNewMatch(_newMatchHandler);
  }

  @override
  void dispose() {
    SocketService().offMessageReceived(_messageHandler);
    SocketService().offNewMatch(_newMatchHandler);
    super.dispose();
  }

  void clear() {
    state = ConversationsState();
  }

  Future<void> loadConversations({bool silent = false}) async {
    final effectiveUid = userId ?? StorageService.getUserId();
    if (effectiveUid == null || effectiveUid.isEmpty) {
      state = ConversationsState();
      return;
    }

    if (!silent && state.conversations.isEmpty) {
      state = state.copyWith(isLoading: true);
    }
    final response = await _repository.getConversations(page: 1, limit: 10);
    if (!response.isSuccess) {
      state = state.copyWith(isLoading: false);
      return;
    }

    final list = response.conversations;
    if (list.isEmpty) {
      state = state.copyWith(
        conversations: [],
        isLoading: false,
        hasMore: false,
        currentPage: 1,
      );
      return;
    }

    final existingMap = {for (var c in state.conversations) c.id: c};
    final mergedList = list.map((newConvo) {
      final oldConvo = existingMap[newConvo.id];
      if (oldConvo != null) {
        final mergedPhotos = newConvo.partnerPhotos.isNotEmpty
            ? newConvo.partnerPhotos
            : oldConvo.partnerPhotos;
        final mergedAvatar = newConvo.partnerAvatar.isNotEmpty
            ? newConvo.partnerAvatar
            : (oldConvo.partnerAvatar.isNotEmpty
                ? oldConvo.partnerAvatar
                : (mergedPhotos.isNotEmpty ? mergedPhotos.first : ''));

        return newConvo.copyWith(
          partnerAvatar: mergedAvatar,
          partnerPhotos: mergedPhotos,
          partnerName: newConvo.partnerName.isNotEmpty && newConvo.partnerName != 'Match'
              ? newConvo.partnerName
              : oldConvo.partnerName,
          partnerBio: newConvo.partnerBio.isNotEmpty
              ? newConvo.partnerBio
              : oldConvo.partnerBio,
          partnerInterests: newConvo.partnerInterests.isNotEmpty
              ? newConvo.partnerInterests
              : oldConvo.partnerInterests,
          partnerOccupation: newConvo.partnerOccupation.isNotEmpty && newConvo.partnerOccupation != 'Member'
              ? newConvo.partnerOccupation
              : oldConvo.partnerOccupation,
          partnerCity: newConvo.partnerCity.isNotEmpty && newConvo.partnerCity != 'India'
              ? newConvo.partnerCity
              : oldConvo.partnerCity,
          partnerAge: newConvo.partnerAge ?? oldConvo.partnerAge,
          partnerGender: newConvo.partnerGender ?? oldConvo.partnerGender,
          partnerEducation: newConvo.partnerEducation ?? oldConvo.partnerEducation,
          partnerLookingFor: newConvo.partnerLookingFor ?? oldConvo.partnerLookingFor,
          isVerified: newConvo.isVerified || oldConvo.isVerified,
          messages: newConvo.messages.isNotEmpty ? newConvo.messages : oldConvo.messages,
        );
      }
      return newConvo;
    }).toList();

    state = state.copyWith(
      conversations: mergedList,
      isLoading: false,
      hasMore: response.hasMore,
      currentPage: 1,
    );
  }

  Future<void> loadMoreConversations() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.currentPage + 1;
    final response = await _repository.getConversations(page: nextPage, limit: 10);
    final newItems = response.conversations;

    if (newItems.isEmpty) {
      state = state.copyWith(isLoadingMore: false, hasMore: false);
      return;
    }

    final existingIds = state.conversations.map((c) => c.id).toSet();
    final uniqueNewItems = newItems.where((c) => !existingIds.contains(c.id)).toList();
    final combined = [...state.conversations, ...uniqueNewItems];

    state = state.copyWith(
      conversations: combined,
      isLoadingMore: false,
      hasMore: response.hasMore && uniqueNewItems.isNotEmpty,
      currentPage: nextPage,
    );
  }

  void markAsRead(String conversationId) {
    final cleanId = conversationId.replaceAll('conv_', '').trim();
    final updatedList = state.conversations.map((c) {
      if (c.id == conversationId || c.id.replaceAll('conv_', '').trim() == cleanId) {
        return c.copyWith(unreadCount: 0);
      }
      return c;
    }).toList();
    state = state.copyWith(conversations: updatedList);
    _repository.markConversationAsRead(conversationId);
    SocketService().emitMarkRead(conversationId);
  }
}

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, ConversationsState>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  final userId = ref.watch(authProvider.select((s) => s.user?.id));
  return ConversationsNotifier(repo, userId: userId);
});

// Messages Provider for Active Chat Room
class MessagesState {
  final List<ChatMessageModel> messages;
  final bool isLoading;
  final bool isPartnerTyping;

  MessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isPartnerTyping = false,
  });

  MessagesState copyWith({
    List<ChatMessageModel>? messages,
    bool? isLoading,
    bool? isPartnerTyping,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isPartnerTyping: isPartnerTyping ?? this.isPartnerTyping,
    );
  }
}

class MessagesNotifier extends StateNotifier<MessagesState> {
  final ChatRepository _repository;
  final String conversationId;

  late final Function(dynamic) _messageHandler;
  late final Function(dynamic) _typingHandler;
  late final Function(dynamic) _stopTypingHandler;

  MessagesNotifier(this._repository, this.conversationId)
      : super(MessagesState(
          messages: _repository.getCachedMessages(conversationId) ?? [],
          isLoading: false,
        )) {
    loadMessages();
    _initSocket();
  }

  void _initSocket() {
    SocketService().joinChat(conversationId);

    _messageHandler = (data) {
      if (data is Map<String, dynamic>) {
        final conv = data['conversationId'] ?? data['chatId'] ?? data['roomId'];
        if (conv == null ||
            conv.toString() == conversationId ||
            conv.toString() == conversationId.replaceAll('conv_', '')) {
          final newMsg = ChatMessageModel.fromJson(data);
          if (newMsg.message.trim().isEmpty) return;

          final currentUserId = StorageService.getUserId() ?? 'me';
          final sIdClean = newMsg.senderId.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '').trim();
          final currentClean = currentUserId.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '').trim();
          final isSenderMe = newMsg.senderId == 'me' ||
              newMsg.senderId == currentUserId ||
              (currentClean.isNotEmpty && sIdClean == currentClean);

          final existingIndex = state.messages.indexWhere((m) {
            if (newMsg.id.isNotEmpty && m.id == newMsg.id) return true;
            if (m.message.trim() == newMsg.message.trim() &&
                (m.senderId == 'me' || m.senderId == currentUserId || m.senderId == newMsg.senderId || isSenderMe) &&
                DateTime.now().difference(m.timestamp).inSeconds.abs() < 20) {
              return true;
            }
            return false;
          });

          List<ChatMessageModel> updatedList;
          if (existingIndex != -1) {
            updatedList = List<ChatMessageModel>.from(state.messages);
            updatedList[existingIndex] = newMsg;
          } else {
            updatedList = [...state.messages, newMsg];
            if (!isSenderMe) {
              SoundService().playMessageReceived();
            }
          }
          _repository.cacheMessages(conversationId, updatedList);
          state = state.copyWith(messages: updatedList);
        }
      }
    };

    _typingHandler = (data) {
      state = state.copyWith(isPartnerTyping: true);
    };

    _stopTypingHandler = (data) {
      state = state.copyWith(isPartnerTyping: false);
    };

    SocketService().onMessageReceived(_messageHandler);
    SocketService().onTyping(_typingHandler);
    SocketService().onStopTyping(_stopTypingHandler);
  }

  Future<void> loadMessages() async {
    final cached = _repository.getCachedMessages(conversationId);
    if (cached != null && cached.isNotEmpty) {
      state = state.copyWith(messages: cached, isLoading: false);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> send(String text, String receiverId) async {
    SoundService().playMessageSent();
    final currentUserId = StorageService.getUserId() ?? 'me';
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final localMsg = ChatMessageModel(
      id: tempId,
      senderId: currentUserId,
      receiverId: receiverId,
      message: text,
      timestamp: DateTime.now(),
    );

    final optimisticList = [...state.messages, localMsg];
    _repository.cacheMessages(conversationId, optimisticList);
    state = state.copyWith(messages: optimisticList);

    // Persist and broadcast through backend HTTP API
    final serverMsg = await _repository.sendMessage(
      conversationId: conversationId,
      receiverId: receiverId,
      message: text,
    );

    if (serverMsg != null) {
      final idx = state.messages.indexWhere(
        (m) => m.id == tempId || (serverMsg.id.isNotEmpty && m.id == serverMsg.id),
      );
      if (idx != -1) {
        final updated = List<ChatMessageModel>.from(state.messages);
        updated[idx] = serverMsg;
        _repository.cacheMessages(conversationId, updated);
        state = state.copyWith(messages: updated);
      }
    }
  }

  @override
  void dispose() {
    SocketService().offMessageReceived(_messageHandler);
    SocketService().offTyping(_typingHandler);
    SocketService().offStopTyping(_stopTypingHandler);
    SocketService().leaveChat(conversationId);
    super.dispose();
  }
}

final messagesProviderFamily =
    StateNotifierProvider.family<MessagesNotifier, MessagesState, String>((ref, conversationId) {
  final repo = ref.watch(chatRepositoryProvider);
  return MessagesNotifier(repo, conversationId);
});

