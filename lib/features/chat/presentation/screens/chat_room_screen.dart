import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/network/socket_service.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';
import 'package:prem_jodo_mobile/core/widgets/app_avatar.dart';
import 'package:prem_jodo_mobile/core/widgets/whatsapp_emoji_picker.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:prem_jodo_mobile/features/chat/presentation/providers/chat_provider.dart';
import 'package:prem_jodo_mobile/features/chat/presentation/screens/call_screen.dart';
import 'package:prem_jodo_mobile/features/chat/presentation/screens/partner_profile_detail_screen.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? partnerId;
  final String partnerName;
  final String partnerAvatar;
  final List<String> photos;
  final String bio;
  final List<String> interests;
  final String occupation;
  final String city;
  final int? age;
  final String? gender;
  final String? education;
  final String? lookingFor;
  final bool isVerified;
  final String? initialMessage;

  const ChatRoomScreen({
    super.key,
    required this.conversationId,
    this.partnerId,
    required this.partnerName,
    required this.partnerAvatar,
    this.photos = const [],
    this.bio = '',
    this.interests = const [],
    this.occupation = 'Member',
    this.city = 'India',
    this.age,
    this.gender,
    this.education,
    this.lookingFor,
    this.isVerified = false,
    this.initialMessage,
  });

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _showEmojiPicker = false;
  Timer? _typingTimer;

  String get _effectivePartnerId =>
      (widget.partnerId != null && widget.partnerId!.isNotEmpty)
          ? widget.partnerId!
          : widget.conversationId;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    if (widget.initialMessage != null && widget.initialMessage!.trim().isNotEmpty) {
      final msg = widget.initialMessage!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(messagesProviderFamily(widget.conversationId).notifier).send(msg, _effectivePartnerId);
      });
    }
  }

  void _onEmojiSelected(String emoji) {
    final text = _textController.text;
    final selection = _textController.selection;
    if (selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, emoji);
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + emoji.length),
      );
    } else {
      _textController.text += emoji;
      _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
    }
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      _focusNode.requestFocus();
      setState(() => _showEmojiPicker = false);
    } else {
      _focusNode.unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  void _onTextChanged() {
    final text = _textController.text;
    if (text.isNotEmpty) {
      SocketService().emitTyping(
        conversationId: widget.conversationId,
        receiverId: _effectivePartnerId,
      );
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        SocketService().emitStopTyping(
          conversationId: widget.conversationId,
          receiverId: _effectivePartnerId,
        );
      });
    } else {
      _typingTimer?.cancel();
      SocketService().emitStopTyping(
        conversationId: widget.conversationId,
        receiverId: _effectivePartnerId,
      );
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _typingTimer?.cancel();
    SocketService().emitStopTyping(
      conversationId: widget.conversationId,
      receiverId: _effectivePartnerId,
    );

    ref
        .read(messagesProviderFamily(widget.conversationId).notifier)
        .send(text, _effectivePartnerId);
    _textController.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    SocketService().emitStopTyping(
      conversationId: widget.conversationId,
      receiverId: _effectivePartnerId,
    );
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openPartnerProfile() {
    final convos = ref.read(conversationsProvider).conversations;
    final matchedConvo = convos.where((c) =>
        c.id == widget.conversationId ||
        (widget.partnerId != null && c.partnerId == widget.partnerId)).firstOrNull;

    final effectivePhotos = widget.photos.isNotEmpty
        ? widget.photos
        : (matchedConvo?.partnerPhotos.isNotEmpty == true
            ? matchedConvo!.partnerPhotos
            : (widget.partnerAvatar.isNotEmpty ? [widget.partnerAvatar] : <String>[]));

    final effectiveBio = widget.bio.isNotEmpty
        ? widget.bio
        : (matchedConvo?.partnerBio ?? '');

    final effectiveInterests = widget.interests.isNotEmpty
        ? widget.interests
        : (matchedConvo?.partnerInterests ?? <String>[]);

    final effectiveOccupation = widget.occupation.isNotEmpty && widget.occupation != 'Member'
        ? widget.occupation
        : (matchedConvo?.partnerOccupation ?? 'Member');

    final effectiveCity = widget.city.isNotEmpty && widget.city != 'India'
        ? widget.city
        : (matchedConvo?.partnerCity ?? 'India');

    final effectiveAge = widget.age ?? matchedConvo?.partnerAge;
    final effectiveGender = widget.gender ?? matchedConvo?.partnerGender;
    final effectiveEducation = widget.education ?? matchedConvo?.partnerEducation;
    final effectiveLookingFor = widget.lookingFor ?? matchedConvo?.partnerLookingFor;
    final effectiveIsVerified = widget.isVerified || (matchedConvo?.isVerified ?? false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PartnerProfileDetailScreen(
          partnerId: _effectivePartnerId,
          partnerName: widget.partnerName,
          partnerAvatar: widget.partnerAvatar,
          conversationId: widget.conversationId,
          photos: effectivePhotos,
          bio: effectiveBio,
          interests: effectiveInterests,
          occupation: effectiveOccupation,
          city: effectiveCity,
          age: effectiveAge,
          gender: effectiveGender,
          education: effectiveEducation,
          lookingFor: effectiveLookingFor,
          isVerified: effectiveIsVerified,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagesProviderFamily(widget.conversationId));
    final onlineUsers = ref.watch(onlineUsersProvider);

    final partnerClean = _effectivePartnerId
        .replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '')
        .trim();
    final isOnline = _effectivePartnerId.isNotEmpty &&
        (onlineUsers.contains(_effectivePartnerId) ||
            onlineUsers.contains(partnerClean) ||
            SocketService().isUserOnline(_effectivePartnerId));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _openPartnerProfile,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              children: [
                AppAvatar(
                  imageUrl: widget.partnerAvatar,
                  name: widget.partnerName,
                  size: 38,
                  isOnline: isOnline,
                  showOnlineIndicator: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.partnerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (widget.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, size: 15, color: AppColors.primaryLight),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      if (state.isPartnerTyping)
                        const Text(
                          'typing...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.primary,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else if (isOnline)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6.5,
                              height: 6.5,
                              decoration: const BoxDecoration(
                                color: AppColors.onlineGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Active now',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.onlineGreen,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6.5,
                              height: 6.5,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Offline',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded, color: Colors.white),
            onPressed: () {
              final authUser = ref.read(authProvider).user;
              final currentName = (authUser != null && authUser.name.isNotEmpty)
                  ? authUser.name
                  : (StorageService.getUserName() ?? 'Prem Jodo Member');
              final currentAvatar = (authUser != null && authUser.photos.isNotEmpty)
                  ? authUser.photos.first
                  : (StorageService.getUserAvatar() ?? '');

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    channelName: widget.conversationId,
                    partnerId: _effectivePartnerId,
                    partnerName: widget.partnerName,
                    partnerAvatar: widget.partnerAvatar,
                    callerName: currentName,
                    callerAvatar: currentAvatar,
                    isVideo: false,
                    isCaller: true,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: Colors.white),
            onPressed: () {
              final authUser = ref.read(authProvider).user;
              final currentName = (authUser != null && authUser.name.isNotEmpty)
                  ? authUser.name
                  : (StorageService.getUserName() ?? 'Prem Jodo Member');
              final currentAvatar = (authUser != null && authUser.photos.isNotEmpty)
                  ? authUser.photos.first
                  : (StorageService.getUserAvatar() ?? '');

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    channelName: widget.conversationId,
                    partnerId: _effectivePartnerId,
                    partnerName: widget.partnerName,
                    partnerAvatar: widget.partnerAvatar,
                    callerName: currentName,
                    callerAvatar: currentAvatar,
                    isVideo: true,
                    isCaller: true,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: state.messages.length,
              itemBuilder: (context, index) {
                final msg = state.messages[index];
                final currentUserId = StorageService.getUserId()?.trim() ?? '';
                final sId = msg.senderId.trim();
                final pId = _effectivePartnerId.trim();
                final partnerClean = pId.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '').trim();
                final sIdClean = sId.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '').trim();
                final currentClean = currentUserId.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '').trim();

                final isPartnerSender = pId.isNotEmpty && (sId == pId || sIdClean == partnerClean);
                final isMe = sId == 'me' ||
                    (currentClean.isNotEmpty && (sId == currentUserId || sIdClean == currentClean)) ||
                    (msg.receiverId.isNotEmpty && (msg.receiverId == pId || msg.receiverId.replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '').trim() == partnerClean)) ||
                    (!isPartnerSender && sId.isNotEmpty);

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      gradient: isMe ? AppColors.primaryGradient : null,
                      color: isMe ? null : AppColors.darkSurface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.message,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat.jm().format(msg.timestamp.toLocal()),
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : Colors.white.withValues(alpha: 0.45),
                                fontSize: 10,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                msg.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildInputBar(),
          if (_showEmojiPicker)
            WhatsAppEmojiPicker(
              onEmojiSelected: _onEmojiSelected,
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final systemBottomPadding = MediaQuery.of(context).padding.bottom;
    final double effectiveBottomPadding = bottomInset > 0
        ? 8.0
        : (_showEmojiPicker
            ? 8.0
            : (systemBottomPadding > 0 ? systemBottomPadding + 10.0 : 16.0));

    return Container(
      padding: EdgeInsets.fromLTRB(10, 8, 10, effectiveBottomPadding),
      color: const Color(0xFF0D0E15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // WhatsApp-style rounded pill container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E202C),
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Emoji button inside input on the left
                  IconButton(
                    icon: Icon(
                      _showEmojiPicker
                          ? Icons.keyboard_rounded
                          : Icons.sentiment_satisfied_alt_rounded,
                      color: _showEmojiPicker ? AppColors.primaryLight : Colors.white70,
                      size: 24,
                    ),
                    onPressed: _toggleEmojiPicker,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                        isDense: true,
                      ),
                      onTap: () {
                        if (_showEmojiPicker) {
                          setState(() => _showEmojiPicker = false);
                        }
                      },
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Circular gradient send button
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
