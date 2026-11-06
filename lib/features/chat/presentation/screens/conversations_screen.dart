import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/network/socket_service.dart';
import 'package:prem_jodo_mobile/core/widgets/app_avatar.dart';
import 'package:prem_jodo_mobile/core/widgets/app_logo.dart';
import 'package:prem_jodo_mobile/features/chat/presentation/providers/chat_provider.dart';
import 'package:prem_jodo_mobile/features/chat/presentation/screens/chat_room_screen.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(conversationsProvider.notifier).loadConversations(silent: true);
      }
    });
  }

  void _onScroll() {
    if (_isSearching) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(conversationsProvider.notifier).loadMoreConversations();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  String _formatConversationTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(local.year, local.month, local.day);

    if (messageDate == today) {
      return DateFormat.jm().format(local);
    } else if (today.difference(messageDate).inDays == 1) {
      return 'Yesterday';
    } else if (now.year == local.year) {
      return DateFormat('dd MMM').format(local);
    } else {
      return DateFormat('dd/MM/yy').format(local);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(conversationsProvider);
    final onlineUsers = ref.watch(onlineUsersProvider);

    // Filter conversations based on query
    final filteredConversations = chatState.conversations.where((convo) {
      if (_searchQuery.trim().isEmpty) return true;
      final query = _searchQuery.trim().toLowerCase();
      final nameMatches = convo.partnerName.toLowerCase().contains(query);
      final msgMatches = convo.lastMessage.toLowerCase().contains(query);
      return nameMatches || msgMatches;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: 'Search chats or names...',
                  hintStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 15),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white70, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const AppLogo(
                fontSize: 21,
                iconSize: 32,
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              if (_isSearching) {
                _stopSearch();
              } else {
                _startSearch();
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: chatState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : chatState.conversations.isEmpty
              ? _buildEmptyState()
              : _searchQuery.isNotEmpty && filteredConversations.isEmpty
                  ? _buildEmptySearchResultState()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.darkCard,
                      onRefresh: () async {
                        await ref.read(conversationsProvider.notifier).loadConversations();
                      },
                      child: ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filteredConversations.length +
                            (chatState.isLoadingMore && !_isSearching ? 1 : 0),
                        separatorBuilder: (_, __) => Divider(
                          color: Colors.white.withValues(alpha: 0.06),
                          indent: 80,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          if (index >= filteredConversations.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            );
                          }
                          final convo = filteredConversations[index];
                          final partnerClean = convo.partnerId
                              .replaceAll(RegExp(r'^(usr_|conv_|chat_|match_)'), '')
                              .trim();
                          final isPartnerOnline = convo.partnerId.isNotEmpty &&
                              (onlineUsers.contains(convo.partnerId) ||
                                  onlineUsers.contains(partnerClean) ||
                                  SocketService().isUserOnline(convo.partnerId));

                          return ListTile(
                            onTap: () async {
                              ref.read(conversationsProvider.notifier).markAsRead(convo.id);
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatRoomScreen(
                                    conversationId: convo.id,
                                    partnerId: convo.partnerId,
                                    partnerName: convo.partnerName,
                                    partnerAvatar: convo.partnerAvatar,
                                    photos: convo.partnerPhotos,
                                    bio: convo.partnerBio,
                                    interests: convo.partnerInterests,
                                    occupation: convo.partnerOccupation,
                                    city: convo.partnerCity,
                                    age: convo.partnerAge,
                                    gender: convo.partnerGender,
                                    education: convo.partnerEducation,
                                    lookingFor: convo.partnerLookingFor,
                                    isVerified: convo.isVerified,
                                  ),
                                ),
                              );
                            },
                            leading: AppAvatar(
                              imageUrl: convo.partnerAvatar,
                              name: convo.partnerName,
                              size: 52,
                              isOnline: isPartnerOnline,
                              showOnlineIndicator: true,
                            ),
                            title: Text(
                              convo.partnerName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              convo.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: convo.unreadCount > 0 ? Colors.white : AppColors.textSecondaryDark,
                                fontWeight: convo.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatConversationTime(convo.lastMessageTime),
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                                ),
                                if (convo.unreadCount > 0) ...[
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${convo.unreadCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmptySearchResultState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.darkSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 48, color: Colors.white38),
            ),
            const SizedBox(height: 16),
            Text(
              'No matches for "$_searchQuery"',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Try searching with a different name or message text.',
              style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.darkSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.primaryLight),
          ),
          const SizedBox(height: 16),
          const Text('No messages yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Match with someone and start a conversation!', style: TextStyle(color: AppColors.textSecondaryDark)),
        ],
      ),
    );
  }
}
