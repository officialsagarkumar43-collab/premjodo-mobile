import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/widgets/app_avatar.dart';
import 'package:prem_jodo_mobile/core/network/socket_service.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';
import 'package:prem_jodo_mobile/features/discovery/data/models/profile_card_model.dart';
import 'package:prem_jodo_mobile/features/chat/presentation/screens/chat_room_screen.dart';

class MatchModalScreen extends StatefulWidget {
  final ProfileCardModel matchedUser;
  final String? conversationId;
  final VoidCallback onClose;

  const MatchModalScreen({
    super.key,
    required this.matchedUser,
    this.conversationId,
    required this.onClose,
  });

  @override
  State<MatchModalScreen> createState() => _MatchModalScreenState();
}

class _MatchModalScreenState extends State<MatchModalScreen> {
  late final TextEditingController _textController;

  static const List<String> _predefinedIcebreakers = [
    "Hey! It's a match 👋",
    "Coffee or chai? ☕",
    "Loved your profile vibe! ✨",
    "Hey there! How's your day? 😊",
    "Hey! Nice to connect with you! 💫",
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _predefinedIcebreakers.first);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _selectIcebreaker(String text) {
    HapticFeedback.lightImpact();
    setState(() {
      _textController.text = text;
      _textController.selection = TextSelection.collapsed(offset: text.length);
    });
  }

  void _sendMessageAndChat() {
    final rawText = _textController.text.trim();
    final textToSend = rawText.isNotEmpty
        ? rawText
        : "Hey! It's a match 👋 Nice to connect with you!";

    final convId = widget.conversationId ?? widget.matchedUser.id;
    final partnerId = widget.matchedUser.id;
    final currentUserId = StorageService.getUserId() ?? '';

    // Emit socket message for real-time delivery
    if (convId.isNotEmpty && textToSend.isNotEmpty) {
      SocketService().emitSendMessage({
        'conversationId': convId.replaceAll('conv_', ''),
        'chatId': convId.replaceAll('conv_', ''),
        'roomId': convId.replaceAll('conv_', ''),
        'sender': currentUserId,
        'senderId': currentUserId,
        'receiver': partnerId,
        'receiverId': partnerId,
        'recipientId': partnerId,
        'content': textToSend,
        'text': textToSend,
        'message': textToSend,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    Navigator.of(context).pop();
    widget.onClose();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          conversationId: convId,
          partnerId: widget.matchedUser.id,
          partnerName: widget.matchedUser.name,
          partnerAvatar: widget.matchedUser.photos.isNotEmpty ? widget.matchedUser.photos.first : '',
          photos: widget.matchedUser.photos,
          bio: widget.matchedUser.bio,
          interests: widget.matchedUser.interests,
          occupation: widget.matchedUser.occupation,
          city: widget.matchedUser.city,
          age: widget.matchedUser.age,
          gender: widget.matchedUser.gender,
          education: widget.matchedUser.education,
          lookingFor: widget.matchedUser.lookingFor,
          isVerified: widget.matchedUser.isVerified,
          initialMessage: textToSend,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partnerPhoto = widget.matchedUser.photos.isNotEmpty
        ? widget.matchedUser.photos.first
        : '';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF14121F),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Close Button
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onClose();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ),
              ),

              // Animated Heart Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),

              // Match Title
              ShaderMask(
                shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                child: const Text(
                  "It's a Match! 🎉",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle
              Text.rich(
                TextSpan(
                  text: 'You and ',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  children: [
                    TextSpan(
                      text: widget.matchedUser.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' liked each other.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              // Matched Avatar with Glow Ring
              Container(
                width: 84,
                height: 84,
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AppAvatar(
                  imageUrl: partnerPhoto,
                  name: widget.matchedUser.name,
                  size: 77,
                ),
              ),
              const SizedBox(height: 20),

              // Icebreaker Box (Web-Matched)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0A14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.gold,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'SEND AN ICEBREAKER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Text Field
                    TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Say something charming...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 13,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        filled: true,
                        fillColor: const Color(0xFF1E1A2D),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        suffixIcon: _textController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.white54),
                                onPressed: () => setState(() => _textController.clear()),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quick Suggestion Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _predefinedIcebreakers.map((chip) {
                        final isSelected = _textController.text.trim() == chip;
                        return GestureDetector(
                          onTap: () => _selectIcebreaker(chip),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.6)
                                    : Colors.white.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              chip,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.white70,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Action Button: Send Message & Chat
              GestureDetector(
                onTap: _sendMessageAndChat,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Send Message & Chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Keep Swiping Button
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onClose();
                },
                child: const Text(
                  'Keep Swiping',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
