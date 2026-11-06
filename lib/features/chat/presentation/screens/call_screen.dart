import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:prem_jodo_mobile/core/constants/api_endpoints.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/network/api_client.dart';
import 'package:prem_jodo_mobile/core/network/socket_service.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';
import 'package:prem_jodo_mobile/core/services/sound_service.dart';
import 'package:prem_jodo_mobile/core/widgets/web_camera_view.dart';
import 'package:prem_jodo_mobile/features/navigation/screens/main_navigation_screen.dart';

enum CallStatus {
  connecting,
  ringing,
  connected,
  ended,
}

class CallScreen extends StatefulWidget {
  final String channelName;
  final String partnerId;
  final String partnerName;
  final String partnerAvatar;
  final String? callerName;
  final String? callerAvatar;
  final bool isVideo;
  final bool isCaller;

  const CallScreen({
    super.key,
    required this.channelName,
    this.partnerId = '',
    required this.partnerName,
    required this.partnerAvatar,
    this.callerName,
    this.callerAvatar,
    this.isVideo = false,
    this.isCaller = true,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  RtcEngine? _engine;
  VideoViewController? _localVideoController;
  VideoViewController? _remoteVideoController;
  int? _remoteUid;
  bool _hasRemoteVideo = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  final bool _isVideoDisabled = false;
  bool _isFrontCamera = true;
  bool _isEnding = false;
  CallStatus _status = CallStatus.ringing;

  Timer? _callDurationTimer;
  int _durationSeconds = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _status = widget.isCaller ? CallStatus.ringing : CallStatus.connecting;
    if (widget.isCaller) {
      SoundService().playOutgoingCallTone();
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initAgora();
    _initSocketSignaling();
  }

  String get _effectiveChannelName {
    final raw = widget.channelName.trim();
    if (raw.isEmpty) return 'prem_jodo_${DateTime.now().millisecondsSinceEpoch}';
    if (raw.startsWith('prem_jodo_')) return raw;
    final clean = raw.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_|call_)'), '').trim();
    return 'prem_jodo_$clean';
  }

  Future<String> _fetchAgoraToken(String channelName) async {
    final candidateEndpoints = [
      '/call/rtc-token',
      '/chat/agora-token',
      '/chat/agora/token',
      '/chat/agora/rtc-token',
      '/call/agora-token',
    ];

    for (final ep in candidateEndpoints) {
      try {
        final response = await ApiClient().get(
          ep,
          queryParameters: {
            'channelName': channelName,
            'channel': channelName,
            'callType': widget.isVideo ? 'video' : 'audio',
            'uid': 0,
            'role': 'publisher',
          },
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data['data'] ?? response.data;
          if (data is Map) {
            final token = data['token'] ?? data['rtcToken'] ?? data['agoraToken'] ?? data['key'];
            if (token != null && token.toString().isNotEmpty) {
              final tokenStr = token.toString();
              debugPrint('🔑 [Agora RTC] Successfully obtained token from $ep: ${tokenStr.substring(0, tokenStr.length > 15 ? 15 : tokenStr.length)}...');
              return tokenStr;
            }
          } else if (data is String && data.isNotEmpty) {
            debugPrint('🔑 [Agora RTC] Successfully obtained raw string token from $ep');
            return data;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [Agora RTC] Token fetch note ($ep): $e');
      }
    }
    return '';
  }

  Future<void> _initAgora() async {
    if (kIsWeb) {
      return;
    }

    try {
      await [
        Permission.microphone,
        if (widget.isVideo) Permission.camera,
      ].request();
    } catch (_) {}

    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        const RtcEngineContext(
          appId: ApiEndpoints.agoraAppId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('✅ [Agora RTC] Local user joined channel: ${connection.channelId} (uid: ${connection.localUid})');
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('ℹ️ [Agora RTC] Remote user joined room: $remoteUid (waiting for active media frames...)');
          },
          onUserMuteVideo: (RtcConnection connection, int remoteUid, bool muted) {
            debugPrint('📹 [Agora RTC] Remote user mute video: $remoteUid -> $muted');
            if (mounted) {
              setState(() => _hasRemoteVideo = !muted);
            }
          },
          onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid, RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
            debugPrint('📹 [Agora RTC] Remote video state: $remoteUid -> $state (reason: $reason)');
            if (state == RemoteVideoState.remoteVideoStateDecoding) {
              _setupRemoteVideo(remoteUid, connection);
            } else if (state == RemoteVideoState.remoteVideoStateStopped || state == RemoteVideoState.remoteVideoStateFailed) {
              if (mounted) setState(() => _hasRemoteVideo = false);
            }
          },
          onRemoteAudioStateChanged: (RtcConnection connection, int remoteUid, RemoteAudioState state, RemoteAudioStateReason reason, int elapsed) {
            debugPrint('🔊 [Agora RTC] Remote audio state: $remoteUid -> $state');
            if (state == RemoteAudioState.remoteAudioStateDecoding) {
              _setupRemoteVideo(remoteUid, connection);
            }
          },
          onFirstRemoteVideoDecoded: (RtcConnection connection, int remoteUid, int width, int height, int elapsed) {
            debugPrint('📹 [Agora RTC] First remote video decoded: $remoteUid ($width x $height)');
            _setupRemoteVideo(remoteUid, connection);
          },
          onFirstRemoteAudioFrame: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('🔊 [Agora RTC] First remote audio frame: $remoteUid');
            _setupRemoteVideo(remoteUid, connection);
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint('👋 [Agora RTC] Remote user offline: $remoteUid');
            _endCall(shouldNotifyPartner: false);
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('⚠️ [Agora RTC] Error: $err -> $msg');
          },
        ),
      );

      // 1. Broadcaster Role & Audio Profile
      try {
        await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      } catch (e) {
        debugPrint('⚠️ [Agora setClientRole] $e');
      }

      // 2. Video setup (Enabled before audio for immediate camera binding)
      if (widget.isVideo) {
        try {
          await _engine!.enableVideo();
          await _engine!.enableLocalVideo(true);
          await _engine!.startPreview();

          _localVideoController = VideoViewController(
            rtcEngine: _engine!,
            canvas: const VideoCanvas(
              uid: 0,
              renderMode: RenderModeType.renderModeHidden,
            ),
          );
          if (mounted) setState(() {});
        } catch (e) {
          debugPrint('⚠️ [Agora Video Setup] $e');
        }
      }

      // 3. High-Fidelity HD Audio Setup & Noise Cancellation
      try {
        await _engine!.enableAudio();
        await _engine!.enableLocalAudio(true);
        await _engine!.muteLocalAudioStream(false);
        // MusicStandard (48kHz fullband, high bitrate) with GameStreaming scenario for HD full-duplex voice with AEC & ANS
        await _engine!.setAudioProfile(
          profile: AudioProfileType.audioProfileMusicStandard,
          scenario: AudioScenarioType.audioScenarioGameStreaming,
        );
        // Set standard unity volume (100) to eliminate clipping, buzzing, and echo feedback
        await _engine!.adjustRecordingSignalVolume(100);
        await _engine!.adjustPlaybackSignalVolume(100);
        await _engine!.setDefaultAudioRouteToSpeakerphone(_isSpeakerOn);
        await _engine!.enableAudioVolumeIndication(interval: 200, smooth: 3, reportVad: true);
      } catch (e) {
        debugPrint('⚠️ [Agora Audio Setup] $e');
      }

      // 4. Obtain token and Join channel
      final token = await _fetchAgoraToken(_effectiveChannelName);
      debugPrint('🚀 [Agora RTC] Joining channel: $_effectiveChannelName with token: ${token.isNotEmpty ? "YES (${token.length} chars)" : "NONE"}');

      await _engine!.joinChannel(
        token: token,
        channelId: _effectiveChannelName,
        uid: 0,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishCameraTrack: widget.isVideo,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: widget.isVideo,
          enableAudioRecordingOrPlayout: true,
        ),
      );

      // 5. Route to speakerphone after joining
      try {
        await _engine!.setEnableSpeakerphone(_isSpeakerOn);
      } catch (_) {}
    } catch (e) {
      debugPrint('⚠️ [Agora Init Exception] $e');
    }
  }

  void _setupRemoteVideo(int uid, [RtcConnection? connection]) {
    if (!mounted || uid == 0) return;
    debugPrint('🎥 [Agora RTC] Setup remote video & audio for UID: $uid');

    SoundService().stopCallSounds();
    _startCallTimer();

    try {
      _engine?.muteRemoteAudioStream(uid: uid, mute: false);
      _engine?.adjustPlaybackSignalVolume(100);
      _engine?.adjustUserPlaybackSignalVolume(uid: uid, volume: 100);
      _engine?.setEnableSpeakerphone(_isSpeakerOn);
    } catch (_) {}

    if (_remoteUid != uid || _remoteVideoController == null) {
      _remoteUid = uid;
      _remoteVideoController?.dispose();
      if (_engine != null && widget.isVideo) {
        _remoteVideoController = VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(
            uid: uid,
            renderMode: RenderModeType.renderModeHidden,
          ),
          connection: connection ?? RtcConnection(channelId: _effectiveChannelName),
        );
      }
    }

    setState(() {
      _status = CallStatus.connected;
      _hasRemoteVideo = true;
    });
  }

  void _initSocketSignaling() {
    final socketService = SocketService();

    if (widget.isCaller && widget.partnerId.isNotEmpty) {
      final currentUserId = StorageService.getUserId() ?? '';
      final currentUserName = (widget.callerName != null && widget.callerName!.isNotEmpty)
          ? widget.callerName!
          : (StorageService.getUserName() ?? 'Prem Jodo Member');
      final currentUserAvatar = (widget.callerAvatar != null && widget.callerAvatar!.isNotEmpty)
          ? widget.callerAvatar!
          : (StorageService.getUserAvatar() ?? '');

      socketService.emitInitiateCall(
        to: widget.partnerId,
        channelName: _effectiveChannelName,
        callType: widget.isVideo ? 'video' : 'audio',
        callerName: currentUserName,
        callerAvatar: currentUserAvatar,
        callerId: currentUserId,
        conversationId: _effectiveChannelName,
      );
    }

    socketService.onCallAccepted((data) {
      if (!mounted) return;
      debugPrint('📞 [CallScreen] Call accepted via socket event: $data');
      SoundService().stopCallSounds();
      setState(() {
        _status = CallStatus.connected;
      });
      _startCallTimer();
    });

    socketService.onCallEnded((data) {
      if (!mounted) return;
      debugPrint('📞 [CallScreen] Call ended via socket event: $data');
      _endCall(shouldNotifyPartner: false);
    });
  }

  void _startCallTimer() {
    if (_callDurationTimer != null && _callDurationTimer!.isActive) return;
    _callDurationTimer?.cancel();
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _durationSeconds++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Future<void> _toggleMute() async {
    final newMute = !_isMuted;
    if (!kIsWeb && _engine != null) {
      await _engine?.muteLocalAudioStream(newMute);
    }
    setState(() => _isMuted = newMute);
  }

  Future<void> _toggleSpeaker() async {
    final nextState = !_isSpeakerOn;
    if (!kIsWeb && _engine != null) {
      try {
        await _engine?.setEnableSpeakerphone(nextState);
        await _engine?.setDefaultAudioRouteToSpeakerphone(nextState);
      } catch (e) {
        debugPrint('⚠️ [Agora RTC] Error toggling speakerphone: $e');
      }
    }
    if (mounted) {
      setState(() => _isSpeakerOn = nextState);
    }
  }

  Future<void> _switchCamera() async {
    if (!kIsWeb && _engine != null) {
      await _engine?.switchCamera();
    }
    setState(() => _isFrontCamera = !_isFrontCamera);
  }

  void _endCall({bool shouldNotifyPartner = true}) {
    if (_isEnding) return;
    _isEnding = true;

    SoundService().stopCallSounds();
    _callDurationTimer?.cancel();

    if (shouldNotifyPartner && widget.partnerId.isNotEmpty) {
      try {
        SocketService().emitEndCall(
          to: widget.partnerId,
          channelName: _effectiveChannelName,
        );
      } catch (_) {}
    }

    WebCameraView.stopCamera();

    _localVideoController?.dispose();
    _localVideoController = null;
    _remoteVideoController?.dispose();
    _remoteVideoController = null;

    if (!kIsWeb && _engine != null) {
      final engine = _engine;
      _engine = null;
      try {
        engine?.leaveChannel().catchError((_) {});
        engine?.release().catchError((_) {});
      } catch (_) {}
    }

    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    SoundService().stopCallSounds();
    _callDurationTimer?.cancel();
    _pulseController.dispose();
    WebCameraView.stopCamera();
    _localVideoController?.dispose();
    _localVideoController = null;
    _remoteVideoController?.dispose();
    _remoteVideoController = null;
    if (!kIsWeb && _engine != null) {
      try {
        _engine?.leaveChannel();
        _engine?.release();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRemoteActiveVideo = widget.isVideo && !_isVideoDisabled && _remoteVideoController != null && _hasRemoteVideo && _status == CallStatus.connected;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1016),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background (Blurred Avatar Backdrop or Remote Video Fullscreen)
          if (hasRemoteActiveVideo)
            AgoraVideoView(
              key: ValueKey('remote_$_remoteUid'),
              controller: _remoteVideoController!,
            )
          else
            _buildBackdropLayout(),

          // 2. Dark Vignette Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // 3. Center Partner Profile (Visible when no active remote video stream is filling screen)
          if (!hasRemoteActiveVideo)
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: _buildCenterPartnerCard(),
                ),
              ),
            ),

          // 4. Top Header Bar (Encrypted Badge)
          Positioned(
            top: 14,
            left: 18,
            right: 18,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, color: AppColors.primary, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Prem Jodo Encrypted',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Local Camera PiP Preview (Top Right with "You" Badge)
          if (widget.isVideo && !_isVideoDisabled)
            Positioned(
              top: 70,
              right: 18,
              width: 105,
              height: 145,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.7), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_localVideoController != null)
                        AgoraVideoView(
                          key: const ValueKey('local_pip_preview'),
                          controller: _localVideoController!,
                        )
                      else if (kIsWeb)
                        WebCameraView(isFrontCamera: _isFrontCamera)
                      else
                        Container(color: const Color(0xFF1B1D28)),
                      Positioned(
                        bottom: 6,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. Bottom Action Controls Bar
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: _buildBottomControls(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdropLayout() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.partnerAvatar.isNotEmpty)
          CachedNetworkImage(
            imageUrl: widget.partnerAvatar,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(color: const Color(0xFF14151E)),
          )
        else
          Container(color: const Color(0xFF14151E)),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
          child: Container(color: Colors.black.withValues(alpha: 0.45)),
        ),
      ],
    );
  }

  Widget _buildCenterPartnerCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing glowing circular avatar
        ScaleTransition(
          scale: _status == CallStatus.connected ? const AlwaysStoppedAnimation(1.0) : _pulseAnimation,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFF43F5E), Color(0xFFEC4899), Color(0xFFFBBF24)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF43F5E).withValues(alpha: 0.45),
                  blurRadius: 30,
                  spreadRadius: 6,
                ),
              ],
            ),
            padding: const EdgeInsets.all(3.5),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF14151E),
              ),
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: widget.partnerAvatar.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.partnerAvatar,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildAvatarFallback(),
                      )
                    : _buildAvatarFallback(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        // Partner Name
        Text(
          widget.partnerName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        // Connected / Calling Status Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _status == CallStatus.connected
                ? const Color(0xFF064E3B).withValues(alpha: 0.7)
                : const Color(0xFF881337).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _status == CallStatus.connected
                  ? const Color(0xFF059669).withValues(alpha: 0.5)
                  : const Color(0xFFE11D48).withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _status == CallStatus.connected ? AppColors.onlineGreen : AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getStatusLabel(),
                style: TextStyle(
                  color: _status == CallStatus.connected ? const Color(0xFF6EE7B7) : const Color(0xFFFDA4AF),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusLabel() {
    switch (_status) {
      case CallStatus.ringing:
        return widget.isVideo ? 'Video Calling...' : 'Ringing...';
      case CallStatus.connecting:
        return 'Connecting...';
      case CallStatus.connected:
        return 'Connected • ${_formatDuration(_durationSeconds)}';
      case CallStatus.ended:
        return 'Call Ended';
    }
  }

  Widget _buildAvatarFallback() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.25),
      child: Center(
        child: Text(
          widget.partnerName.isNotEmpty ? widget.partnerName[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Speaker Toggle Button (Loudspeaker vs Earpiece)
          _buildControlButton(
            icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
            label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
            isActive: _isSpeakerOn,
            onTap: _toggleSpeaker,
          ),

          // 2. Camera Switch (Only for Video Calls)
          if (widget.isVideo)
            _buildControlButton(
              icon: Icons.cameraswitch_rounded,
              label: 'Flip',
              isActive: false,
              onTap: _switchCamera,
            ),

          // 3. Mic Mute / Unmute Toggle Button
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _isMuted ? 'Muted' : 'Mic On',
            isActive: !_isMuted,
            isWarning: _isMuted,
            onTap: _toggleMute,
          ),

          // 4. End Call Button
          _buildEndCallButton(),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    bool isWarning = false,
    required VoidCallback onTap,
  }) {
    final bgColor = isWarning
        ? const Color(0xFFEF4444).withValues(alpha: 0.25)
        : isActive
            ? Colors.white
            : const Color(0xFF232634).withValues(alpha: 0.85);
    final iconColor = isWarning
        ? const Color(0xFFEF4444)
        : isActive
            ? const Color(0xFF111827)
            : Colors.white70;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isWarning
                    ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                    : isActive
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isActive ? Colors.white : Colors.black).withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isWarning
                  ? const Color(0xFFFDA4AF)
                  : isActive
                      ? Colors.white
                      : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndCallButton() {
    return GestureDetector(
      onTap: () => _endCall(shouldNotifyPartner: true),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935).withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'End',
            style: TextStyle(
              color: Color(0xFFFDA4AF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
