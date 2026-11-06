import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/network/socket_service.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';
import 'package:prem_jodo_mobile/core/services/sound_service.dart';
import 'package:prem_jodo_mobile/features/chat/presentation/screens/call_screen.dart';

class CallManager {
  static final CallManager _instance = CallManager._internal();
  factory CallManager() => _instance;
  CallManager._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool _isIncomingCallVisible = false;

  void initialize() {
    SocketService().onIncomingCall((data) {
      _handleIncomingCall(data);
    });

    SocketService().onCallEnded((data) {
      if (_isIncomingCallVisible) {
        _isIncomingCallVisible = false;
        SoundService().stopCallSounds();
        final nav = navigatorKey.currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        }
      }
    });
  }

  void _handleIncomingCall(dynamic data) {
    if (data == null || _isIncomingCallVisible) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    String callerName = 'Prem Jodo Member';
    String callerAvatar = '';
    String callerId = '';
    String channelName = '';
    bool isVideo = true;

    if (data is Map) {
      channelName = data['channelName']?.toString() ??
          data['channel']?.toString() ??
          data['roomId']?.toString() ??
          data['conversationId']?.toString() ??
          data['chatId']?.toString() ??
          data['channelId']?.toString() ??
          '';

      final callType = data['callType']?.toString() ??
          data['type']?.toString() ??
          data['mediaType']?.toString() ??
          (data['isVideo'] == true ? 'video' : 'audio');
      isVideo = callType.toLowerCase() == 'video' || data['isVideo'] == true;

      final caller = data['caller'] ?? data['user'] ?? data['fromUser'];
      if (caller is Map) {
        callerName = caller['name']?.toString() ??
            caller['fullName']?.toString() ??
            caller['userName']?.toString() ??
            callerName;
        callerAvatar = caller['avatar']?.toString() ??
            caller['photo']?.toString() ??
            caller['profilePic']?.toString() ??
            caller['userAvatar']?.toString() ??
            callerAvatar;
        callerId = caller['id']?.toString() ??
            caller['_id']?.toString() ??
            caller['userId']?.toString() ??
            callerId;
      }

      if (callerId.isEmpty) {
        callerId = data['callerId']?.toString() ??
            data['from']?.toString() ??
            data['senderId']?.toString() ??
            data['userId']?.toString() ??
            '';
      }
      if (callerName == 'Prem Jodo Member' && (data['callerName'] != null || data['name'] != null)) {
        callerName = (data['callerName'] ?? data['name']).toString();
      }
      if (callerAvatar.isEmpty && (data['callerAvatar'] != null || data['avatar'] != null)) {
        callerAvatar = (data['callerAvatar'] ?? data['avatar']).toString();
      }
    }

    // Ignore self-emitted incoming call notifications
    final currentUserId = StorageService.getUserId() ?? '';
    final cleanCaller = callerId.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '').trim();
    final cleanCurrent = currentUserId.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '').trim();
    if (cleanCurrent.isNotEmpty && cleanCaller == cleanCurrent) {
      return;
    }

    if (channelName.isEmpty) {
      if (callerId.isNotEmpty) {
        channelName = 'prem_jodo_call_${cleanCaller}_$cleanCurrent';
      } else {
        return;
      }
    }

    if (kDebugMode) {
      print('📲 [CallManager] Incoming call from $callerName ($callerId) on channel: $channelName (Video: $isVideo)');
    }

    _isIncomingCallVisible = true;
    SoundService().playIncomingRingtone();

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF161824),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Caller Avatar with pulsing glow
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: callerAvatar.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: callerAvatar,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _buildAvatarFallback(callerName),
                          )
                        : _buildAvatarFallback(callerName),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  callerName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Incoming ${isVideo ? 'Video' : 'Audio'} Call...',
                      style: const TextStyle(fontSize: 15, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // Action Buttons: Decline / Accept
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Decline
                    GestureDetector(
                      onTap: () {
                        _isIncomingCallVisible = false;
                        SoundService().stopCallSounds();
                        Navigator.of(modalCtx).pop();
                        SocketService().emitEndCall(to: callerId, channelName: channelName);
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: const BoxDecoration(
                              color: AppColors.nopeRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
                          ),
                          const SizedBox(height: 8),
                          const Text('Decline', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    // Accept
                    GestureDetector(
                      onTap: () {
                        _isIncomingCallVisible = false;
                        SoundService().stopCallSounds();
                        Navigator.of(modalCtx).pop();
                        SocketService().emitAnswerCall(to: callerId, channelName: channelName);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CallScreen(
                              channelName: channelName,
                              partnerId: callerId,
                              partnerName: callerName,
                              partnerAvatar: callerAvatar,
                              isVideo: isVideo,
                              isCaller: false,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: const BoxDecoration(
                              color: AppColors.onlineGreen,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isVideo ? 'Accept Video' : 'Accept',
                            style: const TextStyle(
                              color: AppColors.onlineGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _isIncomingCallVisible = false;
    });
  }

  Widget _buildAvatarFallback(String name) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
