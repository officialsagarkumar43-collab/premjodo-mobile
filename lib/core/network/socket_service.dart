import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_endpoints.dart';
import '../services/storage_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  io.Socket? _socket;
  String? _registeredUserId;
  final Set<String> _onlineUsers = {};
  final List<Function(Set<String>)> _onlineListeners = [];

  // Persistent callback registries across socket re-connections
  final List<Function(dynamic)> _incomingCallListeners = [];
  final List<Function(dynamic)> _callAcceptedListeners = [];
  final List<Function(dynamic)> _callEndedListeners = [];
  final List<Function(dynamic)> _messageListeners = [];
  final List<Function(dynamic)> _newMatchListeners = [];
  final List<Function(dynamic)> _typingListeners = [];
  final List<Function(dynamic)> _stopTypingListeners = [];

  SocketService._internal();

  io.Socket? get socket => _socket;
  bool get isConnected => _socket?.connected ?? false;
  Set<String> get onlineUsers => Set.unmodifiable(_onlineUsers);

  bool isUserOnline(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    final cleanId = userId.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '').trim();
    return _onlineUsers.contains(userId) || _onlineUsers.contains(cleanId);
  }

  void onOnlineUsersChange(Function(Set<String>) callback) {
    _onlineListeners.add(callback);
    callback(Set.unmodifiable(_onlineUsers));
  }

  void removeOnlineUsersListener(Function(Set<String>) callback) {
    _onlineListeners.remove(callback);
  }

  void _notifyOnlineListeners() {
    for (final listener in List.from(_onlineListeners)) {
      try {
        listener(Set.unmodifiable(_onlineUsers));
      } catch (_) {}
    }
  }

  void connect({bool forceReconnect = false}) {
    if (forceReconnect) {
      disconnect();
    } else if (_socket != null && _socket!.connected) {
      final currentUserId = StorageService.getUserId();
      if (currentUserId != null && currentUserId.isNotEmpty) {
        registerUser(currentUserId);
      }
      return;
    }

    final token = StorageService.getToken();
    final cleanToken = token?.replaceAll(RegExp(r'^Bearer\s+', caseSensitive: false), '').trim();
    final currentUserId = StorageService.getUserId();

    _socket = io.io(
      ApiEndpoints.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setAuth({
            'token': cleanToken,
            'userId': currentUserId,
            'id': currentUserId,
            if (cleanToken != null) 'Authorization': 'Bearer $cleanToken',
          })
          .setQuery({
            'token': cleanToken,
            'userId': currentUserId,
          })
          .setExtraHeaders(cleanToken != null ? {'Authorization': 'Bearer $cleanToken'} : {})
          .build(),
    );

    _socket?.onConnect((_) {
      if (kDebugMode) print('🔌 [SocketService] Connected to real-time server');
      final uid = StorageService.getUserId();
      if (uid != null && uid.isNotEmpty) {
        registerUser(uid);
      }
      _socket?.emit('get_online_users');
      _socket?.emit('getOnlineUsers');
      _socket?.emit('request_online_users');
    });

    _setupSocketListeners();

    _socket?.onDisconnect((_) {
      if (kDebugMode) print('🔌 [SocketService] Disconnected');
    });

    _socket?.onConnectError((err) {
      if (kDebugMode) print('🔌 [SocketService] Connect Error: $err');
    });
  }

  void _setupSocketListeners() {
    if (_socket == null) return;

    // Online/offline presence tracking
    void handleOnlineUsersList(dynamic data) {
      if (data is List) {
        _onlineUsers.clear();
        for (final u in data) {
          if (u != null) {
            final str = u is Map ? (u['userId'] ?? u['_id'] ?? u['id'])?.toString() : u.toString();
            if (str != null && str.isNotEmpty) {
              _onlineUsers.add(str.trim());
              _onlineUsers.add(str.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '').trim());
            }
          }
        }
        _notifyOnlineListeners();
      }
    }

    for (final ev in ['online_users', 'onlineUsers', 'users:online', 'online-users']) {
      _socket?.on(ev, handleOnlineUsersList);
    }

    void handleUserOnline(dynamic data) {
      String? uid;
      if (data is String) {
        uid = data;
      } else if (data is Map) {
        uid = data['userId']?.toString() ??
            data['user']?['_id']?.toString() ??
            data['_id']?.toString() ??
            data['id']?.toString();
      }
      if (uid != null && uid.isNotEmpty) {
        final clean = uid.trim();
        _onlineUsers.add(clean);
        _onlineUsers.add(clean.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '').trim());
        _notifyOnlineListeners();
      }
    }

    for (final ev in ['user_online', 'user:online', 'user_connected', 'userConnected']) {
      _socket?.on(ev, handleUserOnline);
    }

    void handleUserOffline(dynamic data) {
      String? uid;
      if (data is String) {
        uid = data;
      } else if (data is Map) {
        uid = data['userId']?.toString() ??
            data['user']?['_id']?.toString() ??
            data['_id']?.toString() ??
            data['id']?.toString();
      }
      if (uid != null && uid.isNotEmpty) {
        final clean = uid.trim();
        _onlineUsers.remove(clean);
        final cleanId = clean.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '').trim();
        _onlineUsers.remove(cleanId);
        _notifyOnlineListeners();
      }
    }

    for (final ev in ['user_offline', 'user:offline', 'user_disconnected', 'userDisconnected']) {
      _socket?.on(ev, handleUserOffline);
    }

    // Call signaling dispatchers
    final incomingCallEvents = [
      'incoming_call',
      'incomingCall',
      'call_user',
      'callUser',
      'call_incoming',
      'callIncoming',
      'call_request',
      'callRequest',
      'call:incoming',
      'call:received',
      'call:initiate',
      'initiate_call',
      'initiateCall',
      'call:start',
      'call-incoming',
      'call:ring',
      'ringing',
    ];
    for (final ev in incomingCallEvents) {
      _socket?.on(ev, (data) {
        if (kDebugMode) print('📞 [SocketService] Received Incoming Call Event: $ev -> $data');
        for (final listener in List.from(_incomingCallListeners)) {
          try {
            listener(data);
          } catch (e) {
            if (kDebugMode) print('⚠️ [SocketService] Error in incomingCallListener: $e');
          }
        }
      });
    }

    final callAcceptedEvents = [
      'call_accepted',
      'callAccepted',
      'call:accepted',
      'answer_call',
      'answerCall',
      'call:answer',
      'call_answer',
    ];
    for (final ev in callAcceptedEvents) {
      _socket?.on(ev, (data) {
        if (kDebugMode) print('✅ [SocketService] Received Call Accepted Event: $ev -> $data');
        for (final listener in List.from(_callAcceptedListeners)) {
          try {
            listener(data);
          } catch (e) {
            if (kDebugMode) print('⚠️ [SocketService] Error in callAcceptedListener: $e');
          }
        }
      });
    }

    final callEndedEvents = [
      'call_ended',
      'callEnded',
      'end_call',
      'endCall',
      'reject_call',
      'call_rejected',
      'callRejected',
      'call_declined',
      'call:declined',
      'call:ended',
      'call:rejected',
      'call:end',
      'leave_call',
      'leaveCall',
      'call:leave',
    ];
    for (final ev in callEndedEvents) {
      _socket?.on(ev, (data) {
        if (kDebugMode) print('🛑 [SocketService] Received Call Ended Event: $ev -> $data');
        for (final listener in List.from(_callEndedListeners)) {
          try {
            listener(data);
          } catch (e) {
            if (kDebugMode) print('⚠️ [SocketService] Error in callEndedListener: $e');
          }
        }
      });
    }

    // Messages
    final msgEvents = ['receive_message', 'message', 'new_message', 'chat:message', 'message_received'];
    for (final ev in msgEvents) {
      _socket?.on(ev, (data) {
        for (final listener in List.from(_messageListeners)) {
          try {
            listener(data);
          } catch (_) {}
        }
      });
    }

    // Matches
    final matchEvents = ['new_match', 'match_created', 'match_notification', 'recent_matches_updated'];
    for (final ev in matchEvents) {
      _socket?.on(ev, (data) {
        for (final listener in List.from(_newMatchListeners)) {
          try {
            listener(data);
          } catch (_) {}
        }
      });
    }

    // Typing
    final typingEvents = ['typing', 'user_typing', 'typing:start'];
    for (final ev in typingEvents) {
      _socket?.on(ev, (data) {
        for (final listener in List.from(_typingListeners)) {
          try {
            listener(data);
          } catch (_) {}
        }
      });
    }

    final stopTypingEvents = ['stop_typing', 'user_stopped_typing', 'typing:stop'];
    for (final ev in stopTypingEvents) {
      _socket?.on(ev, (data) {
        for (final listener in List.from(_stopTypingListeners)) {
          try {
            listener(data);
          } catch (_) {}
        }
      });
    }
  }

  void registerUser(String userId) {
    if (userId.isEmpty) return;
    _registeredUserId = userId;
    final cleanId = userId.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '');
    final token = StorageService.getToken()?.replaceAll(RegExp(r'^Bearer\s+', caseSensitive: false), '').trim();

    // Standard Chat app events
    _socket?.emit('setup', userId);
    _socket?.emit('setup', {'_id': userId, 'id': userId, 'userId': userId});
    _socket?.emit('setup', {'_id': cleanId, 'id': cleanId, 'userId': cleanId});
    _socket?.emit('addUser', userId);
    _socket?.emit('addUser', cleanId);
    _socket?.emit('add_user', userId);
    _socket?.emit('add_user', cleanId);
    _socket?.emit('register', userId);
    _socket?.emit('register', cleanId);
    _socket?.emit('register', {'userId': userId, 'token': token});
    _socket?.emit('register', {'userId': cleanId, 'token': token});
    _socket?.emit('register_user', userId);
    _socket?.emit('register_user', cleanId);
    _socket?.emit('user_connected', userId);
    _socket?.emit('user_connected', cleanId);
    _socket?.emit('user_connected', {'userId': userId});
    _socket?.emit('online', userId);
    _socket?.emit('online', cleanId);
    _socket?.emit('online', {'userId': userId});
    _socket?.emit('user:online', userId);
    _socket?.emit('user:online', cleanId);
    _socket?.emit('join', userId);
    _socket?.emit('join', cleanId);
    _socket?.emit('join_user', userId);
    _socket?.emit('join_user', cleanId);
    _socket?.emit('identify', {'userId': userId, 'token': token});
  }

  void joinChat(String conversationId) {
    if (conversationId.isEmpty) return;
    final rawId = conversationId.trim();
    final cleanId = rawId.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '');
    _socket?.emit('join_chat', rawId);
    _socket?.emit('join_chat', cleanId);
    _socket?.emit('join_room', rawId);
    _socket?.emit('join_room', cleanId);
    _socket?.emit('join_conversation', rawId);
    _socket?.emit('join_conversation', cleanId);
  }

  void leaveChat(String conversationId) {
    if (conversationId.isEmpty) return;
    final rawId = conversationId.trim();
    final cleanId = rawId.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '');
    _socket?.emit('leave_chat', rawId);
    _socket?.emit('leave_chat', cleanId);
    _socket?.emit('leave_room', rawId);
    _socket?.emit('leave_room', cleanId);
  }

  void emitSendMessage(Map<String, dynamic> payload) {
    if (!isConnected) {
      connect();
    }
    _socket?.emit('send_message', payload);
  }

  void emitTyping({required String conversationId, required String receiverId}) {
    final cleanConv = conversationId.replaceAll('conv_', '');
    final payload = {
      'conversationId': cleanConv,
      'chatId': cleanConv,
      'receiverId': receiverId,
      'senderId': _registeredUserId ?? StorageService.getUserId() ?? '',
    };
    _socket?.emit('typing', payload);
    _socket?.emit('typing:start', payload);
    _socket?.emit('user_typing', payload);
  }

  void emitStopTyping({required String conversationId, required String receiverId}) {
    final cleanConv = conversationId.replaceAll('conv_', '');
    final payload = {
      'conversationId': cleanConv,
      'chatId': cleanConv,
      'receiverId': receiverId,
      'senderId': _registeredUserId ?? StorageService.getUserId() ?? '',
    };
    _socket?.emit('stop_typing', payload);
    _socket?.emit('typing:stop', payload);
    _socket?.emit('user_stopped_typing', payload);
  }

  void emitMarkRead(String conversationId) {
    final cleanConv = conversationId.replaceAll('conv_', '');
    final payload = {
      'conversationId': cleanConv,
      'readerId': _registeredUserId ?? StorageService.getUserId() ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    };
    _socket?.emit('mark_read', payload);
    _socket?.emit('messages_read', payload);
    _socket?.emit('read_receipt', payload);
  }

  void emitInitiateCall({
    required String to,
    required String channelName,
    required String callType,
    required String callerName,
    required String callerAvatar,
    String? token,
    String? callerId,
    String? conversationId,
  }) {
    final uid = callerId ?? _registeredUserId ?? StorageService.getUserId() ?? '';
    final cleanTo = to.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '').trim();
    final cleanChannel = channelName.trim();
    final cleanConv = (conversationId ?? channelName).replaceAll(RegExp(r'^(conv_)'), '').trim();

    // Join channel room on socket so call:connected from backend reaches caller
    joinChat(cleanChannel);
    if (cleanConv.isNotEmpty && cleanConv != cleanChannel) {
      joinChat(cleanConv);
    }

    final payload = {
      'from': uid,
      'callerId': uid,
      'senderId': uid,
      'userId': uid,
      'to': cleanTo,
      'receiverId': cleanTo,
      'targetUserId': cleanTo,
      'userToCall': cleanTo,
      'channelName': cleanChannel,
      'channel': cleanChannel,
      'callType': callType,
      'type': callType,
      'mediaType': callType,
      'isVideo': callType.toLowerCase() == 'video',
      'conversationId': cleanConv,
      'chatId': cleanConv,
      'roomId': cleanConv.isNotEmpty ? cleanConv : cleanChannel,
      'caller': {
        'id': uid,
        '_id': uid,
        'userId': uid,
        'name': callerName,
        'avatar': callerAvatar,
      },
      'callerName': callerName,
      'name': callerName,
      'callerAvatar': callerAvatar,
      'avatar': callerAvatar,
      'token': token ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (!isConnected) {
      connect();
    }

    _socket?.emit('call:initiate', payload);
    _socket?.emit('initiate_call', payload);
    _socket?.emit('initiateCall', payload);
    _socket?.emit('call_user', payload);
    _socket?.emit('callUser', payload);
    _socket?.emit('call:start', payload);
    _socket?.emit('call:ring', payload);
  }

  void emitAnswerCall({
    required String to,
    required String channelName,
    String? conversationId,
  }) {
    final uid = _registeredUserId ?? StorageService.getUserId() ?? '';
    final cleanTo = to.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '').trim();
    final cleanChannel = channelName.trim();
    final cleanConv = (conversationId ?? channelName).replaceAll(RegExp(r'^(conv_)'), '').trim();

    // Join channel room
    joinChat(cleanChannel);

    final payload = {
      'from': uid,
      'to': cleanTo,
      'callerId': cleanTo,
      'receiverId': uid,
      'targetUserId': cleanTo,
      'userToCall': cleanTo,
      'channelName': cleanChannel,
      'channel': cleanChannel,
      'conversationId': cleanConv,
      'chatId': cleanConv,
      'roomId': cleanConv.isNotEmpty ? cleanConv : cleanChannel,
      'callType': 'video',
      'acceptedAt': DateTime.now().toIso8601String(),
    };

    if (!isConnected) {
      connect();
    }

    _socket?.emit('call:accept', payload);
    _socket?.emit('call_accepted', payload);
    _socket?.emit('callAccepted', payload);
    _socket?.emit('answer_call', payload);
    _socket?.emit('answerCall', payload);
    _socket?.emit('call:answer', payload);
    _socket?.emit('call_answer', payload);
    _socket?.emit('call:connected', payload);
  }

  void emitEndCall({
    required String to,
    required String channelName,
    String? conversationId,
  }) {
    final uid = _registeredUserId ?? StorageService.getUserId() ?? '';
    final cleanTo = to.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '').trim();
    final cleanChannel = channelName.trim();
    final cleanConv = (conversationId ?? channelName).replaceAll(RegExp(r'^(conv_)'), '').trim();

    final payload = {
      'from': uid,
      'to': cleanTo,
      'callerId': cleanTo,
      'receiverId': uid,
      'partnerId': cleanTo,
      'targetUserId': cleanTo,
      'channelName': cleanChannel,
      'channel': cleanChannel,
      'conversationId': cleanConv,
      'chatId': cleanConv,
      'roomId': cleanConv.isNotEmpty ? cleanConv : cleanChannel,
      'reason': 'ended',
      'endedAt': DateTime.now().toIso8601String(),
    };

    if (!isConnected) {
      connect();
    }

    _socket?.emit('call:end', payload);
    _socket?.emit('call_ended', payload);
    _socket?.emit('callEnded', payload);
    _socket?.emit('end_call', payload);
    _socket?.emit('endCall', payload);
    _socket?.emit('call:reject', payload);
    _socket?.emit('call_rejected', payload);
    _socket?.emit('callRejected', payload);
    _socket?.emit('call_declined', payload);
    _socket?.emit('call:declined', payload);
    _socket?.emit('leave_call', payload);
    _socket?.emit('call:leave', payload);
  }

  void onMessageReceived(Function(dynamic) handler) {
    if (!_messageListeners.contains(handler)) {
      _messageListeners.add(handler);
    }
  }

  void offMessageReceived(Function(dynamic) handler) {
    _messageListeners.remove(handler);
  }

  void onNewMatch(Function(dynamic) handler) {
    if (!_newMatchListeners.contains(handler)) {
      _newMatchListeners.add(handler);
    }
  }

  void offNewMatch(Function(dynamic) handler) {
    _newMatchListeners.remove(handler);
  }

  void onTyping(Function(dynamic) handler) {
    if (!_typingListeners.contains(handler)) {
      _typingListeners.add(handler);
    }
  }

  void offTyping(Function(dynamic) handler) {
    _typingListeners.remove(handler);
  }

  void onStopTyping(Function(dynamic) handler) {
    if (!_stopTypingListeners.contains(handler)) {
      _stopTypingListeners.add(handler);
    }
  }

  void offStopTyping(Function(dynamic) handler) {
    _stopTypingListeners.remove(handler);
  }

  void onIncomingCall(Function(dynamic) handler) {
    if (!_incomingCallListeners.contains(handler)) {
      _incomingCallListeners.add(handler);
    }
  }

  void offIncomingCall(Function(dynamic) handler) {
    _incomingCallListeners.remove(handler);
  }

  void onCallAccepted(Function(dynamic) handler) {
    if (!_callAcceptedListeners.contains(handler)) {
      _callAcceptedListeners.add(handler);
    }
  }

  void offCallAccepted(Function(dynamic) handler) {
    _callAcceptedListeners.remove(handler);
  }

  void onCallEnded(Function(dynamic) handler) {
    if (!_callEndedListeners.contains(handler)) {
      _callEndedListeners.add(handler);
    }
  }

  void offCallEnded(Function(dynamic) handler) {
    _callEndedListeners.remove(handler);
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _registeredUserId = null;
    _onlineUsers.clear();
    _notifyOnlineListeners();
  }
}
