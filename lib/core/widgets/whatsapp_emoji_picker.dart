import 'package:flutter/material.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';

class WhatsAppEmojiPicker extends StatefulWidget {
  final Function(String emoji) onEmojiSelected;
  final VoidCallback? onBackspace;

  const WhatsAppEmojiPicker({
    super.key,
    required this.onEmojiSelected,
    this.onBackspace,
  });

  @override
  State<WhatsAppEmojiPicker> createState() => _WhatsAppEmojiPickerState();
}

class _WhatsAppEmojiPickerState extends State<WhatsAppEmojiPicker>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<Map<String, dynamic>> _categories = [
    {
      'icon': Icons.sentiment_satisfied_alt_rounded,
      'name': 'Smileys',
      'emojis': [
        '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
        '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰',
        '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜',
        '🤪', '🤨', '🧐', '🤓', '😎', '🥸', '🤩', '🥳',
        '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '😣',
        '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠',
        '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨',
        '😰', '😥', '😓', '🤗', '🤔', '🤭', '🤫', '🤥',
        '😶', '😐', '😑', '😬', '🙄', '😯', '😦', '😧',
        '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '🤐',
      ],
    },
    {
      'icon': Icons.favorite_rounded,
      'name': 'Love & Hearts',
      'emojis': [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
        '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖',
        '💘', '💝', '💟', '💌', '💋', '👩‍❤️‍👨', '👨‍❤️‍👨', '👩‍❤️‍👩',
        '💑', '👩‍❤️‍💋‍👨', '👨‍❤️‍💋‍👨', '👩‍❤️‍💋‍👩', '💏', '🌹', '💐', '🌺',
        '🌸', '🌷', '🌻', '🥀', '💍', '💎', '🎁', '🍫',
      ],
    },
    {
      'icon': Icons.thumb_up_alt_rounded,
      'name': 'Gestures',
      'emojis': [
        '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙',
        '👈', '👉', '👆', '🖕', '👇', '☝️', '👋', '🤚',
        '🖐️', '✋', '🖖', '👏', '🙌', '👐', '🤲', '🤝',
        '🙏', '✍️', '💅', '🤳', '💪', '🦾', '🦿', '🦵',
        '🦶', '👂', '🦻', '👃', '🧠', '🫀', '🫁', '👀',
      ],
    },
    {
      'icon': Icons.celebration_rounded,
      'name': 'Party & Fun',
      'emojis': [
        '🎉', '🎊', '🎈', '🎂', '🍰', '🧁', '🥂', '🍻',
        '🍺', '🍷', '🍸', '🍹', '🍾', '🎆', '🎇', '✨',
        '🌟', '⭐', '💫', '🔥', '💥', '🍿', '🎵', '🎶',
        '🎤', '🎧', '🎸', '🎹', '🎺', '🎻', '🥁', '🎭',
        '🎨', '🎬', '🎪', '🎟️', '🎫', '🏆', '🥇', '🥈',
      ],
    },
    {
      'icon': Icons.fastfood_rounded,
      'name': 'Food & Drinks',
      'emojis': [
        '🍕', '🍔', '🍟', '🌭', '🥪', '🌮', '🌯', '🥙',
        '🥗', '🍝', '🍜', '🍲', '🍣', '🍱', '🍛', '🍙',
        '🍚', '🥞', '🧇', '🧀', '🍗', '🥩', '🥓', '🍳',
        '☕', '🍵', '🧃', '🥤', '🧋', '🍦', '🍧', '🍨',
        '🍩', '🍪', '🍫', '🍬', '🍭', '🍮', '🍯', '🍎',
      ],
    },
    {
      'icon': Icons.emoji_nature_rounded,
      'name': 'Nature & Animals',
      'emojis': [
        '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼',
        '🐨', '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🐔',
        '🐧', '🐦', '🐤', '🦆', '🦅', '🦉', '🦇', '🐺',
        '🦄', '🐝', '🐛', '🦋', '🐌', '🐞', '🐜', '🦟',
        '🐢', '🐍', '🦎', '🐙', '🦑', '🦐', '🦞', '🦀',
      ],
    },
    {
      'icon': Icons.lightbulb_rounded,
      'name': 'Objects',
      'emojis': [
        '💡', '🔦', '🕯️', '📱', '💻', '⌚', '📷', '📹',
        '📺', '📻', '⏰', '🔋', '🔌', '💰', '💵', '💳',
        '💎', '🔑', '🗝️', '🚪', '🛋️', '🛏️', '📦', '✉️',
        '📮', '📝', '📄', '📅', '📌', '📍', '📎', '🔒',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 270,
      decoration: const BoxDecoration(
        color: Color(0xFF13141E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Category Tab Bar
          Container(
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1B28),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primaryLight,
              unselectedLabelColor: Colors.white38,
              tabs: _categories.map((cat) {
                return Tab(
                  icon: Icon(cat['icon'] as IconData, size: 20),
                );
              }).toList(),
            ),
          ),

          // Emoji Grid Pages
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((cat) {
                final List<String> emojis = cat['emojis'] as List<String>;
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: emojis.length,
                  itemBuilder: (context, index) {
                    final emoji = emojis[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => widget.onEmojiSelected(emoji),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
