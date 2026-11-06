import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:prem_jodo_mobile/features/discovery/data/models/profile_card_model.dart';
import 'package:prem_jodo_mobile/features/discovery/data/models/discovery_filter_model.dart';
import 'package:prem_jodo_mobile/features/discovery/data/repositories/discovery_repository.dart';

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) => DiscoveryRepository());

class DiscoveryState {
  final List<ProfileCardModel> profiles;
  final int currentIndex;
  final bool isLoading;
  final String? errorMessage;
  final ProfileCardModel? matchedUser;
  final String? matchedConversationId;
  final DiscoveryFilterModel filter;
  final int? swipesRemainingToday;
  final int dailySwipeLimit;
  final bool isUnlimitedSwipes;
  final bool isSwipeLimitReached;
  final String? swipeLimitMessage;

  DiscoveryState({
    this.profiles = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.errorMessage,
    this.matchedUser,
    this.matchedConversationId,
    DiscoveryFilterModel? filter,
    this.swipesRemainingToday,
    this.dailySwipeLimit = 50,
    this.isUnlimitedSwipes = false,
    this.isSwipeLimitReached = false,
    this.swipeLimitMessage,
  }) : filter = filter ?? _getInitialFilter();

  static DiscoveryFilterModel _getInitialFilter() {
    try {
      final saved = StorageService.getDiscoveryFilter();
      if (saved != null) {
        return DiscoveryFilterModel.fromJson(saved);
      }
    } catch (_) {}
    return const DiscoveryFilterModel();
  }

  ProfileCardModel? get currentProfile =>
      currentIndex < profiles.length ? profiles[currentIndex] : null;

  bool get canRewind => currentIndex > 0;

  DiscoveryState copyWith({
    List<ProfileCardModel>? profiles,
    int? currentIndex,
    bool? isLoading,
    String? errorMessage,
    ProfileCardModel? matchedUser,
    String? matchedConversationId,
    DiscoveryFilterModel? filter,
    int? swipesRemainingToday,
    int? dailySwipeLimit,
    bool? isUnlimitedSwipes,
    bool? isSwipeLimitReached,
    String? swipeLimitMessage,
  }) {
    return DiscoveryState(
      profiles: profiles ?? this.profiles,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      matchedUser: matchedUser,
      matchedConversationId: matchedConversationId,
      filter: filter ?? this.filter,
      swipesRemainingToday: swipesRemainingToday ?? this.swipesRemainingToday,
      dailySwipeLimit: dailySwipeLimit ?? this.dailySwipeLimit,
      isUnlimitedSwipes: isUnlimitedSwipes ?? this.isUnlimitedSwipes,
      isSwipeLimitReached: isSwipeLimitReached ?? this.isSwipeLimitReached,
      swipeLimitMessage: swipeLimitMessage ?? this.swipeLimitMessage,
    );
  }
}

class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  final DiscoveryRepository _repository;
  final String? userId;

  DiscoveryNotifier(this._repository, {this.userId}) : super(DiscoveryState()) {
    final effectiveUid = userId ?? StorageService.getUserId();
    if (effectiveUid != null && effectiveUid.isNotEmpty) {
      loadRecommendations();
      refreshSwipeQuota();
    }
  }

  void clear() {
    state = DiscoveryState();
  }

  void clearSwipeLimit() {
    state = state.copyWith(isSwipeLimitReached: false, swipeLimitMessage: null);
  }

  Future<void> refreshSwipeQuota() async {
    try {
      final quota = await _repository.getSubscriptionQuota();
      if (quota != null) {
        int? rem;
        final rawRem = quota['swipesRemainingToday'];
        if (rawRem is int) {
          rem = rawRem;
        } else if (rawRem != null && rawRem != 'unlimited') {
          rem = int.tryParse(rawRem.toString());
        }
        final isUnlim = quota['unlimitedSwipes'] == true || rawRem == 'unlimited';
        final limit = quota['dailySwipeLimit'] is int ? quota['dailySwipeLimit'] as int : state.dailySwipeLimit;

        state = state.copyWith(
          swipesRemainingToday: rem,
          dailySwipeLimit: limit,
          isUnlimitedSwipes: isUnlim,
          isSwipeLimitReached: !isUnlim && rem != null && rem <= 0,
        );
      }
    } catch (_) {}
  }

  Future<void> loadRecommendations([DiscoveryFilterModel? customFilter]) async {
    final activeFilter = customFilter ?? state.filter;
    StorageService.saveDiscoveryFilter(activeFilter.toJson());
    state = state.copyWith(
      isLoading: true,
      filter: activeFilter,
      errorMessage: null,
    );
    try {
      var list = await _repository.getRecommendations(
        maxDistance: activeFilter.maxDistance,
        minAge: activeFilter.minAge,
        maxAge: activeFilter.maxAge,
        gender: activeFilter.gender,
      );

      // Client-side fallback filtering if needed
      if (activeFilter.verifiedOnly) {
        list = list.where((p) => p.isVerified).toList();
      }

      state = state.copyWith(
        profiles: list,
        isLoading: false,
        currentIndex: 0,
      );
      refreshSwipeQuota();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void updateFilter(DiscoveryFilterModel newFilter) {
    loadRecommendations(newFilter);
  }

  Future<void> swipe({required String action}) async {
    final current = state.currentProfile;
    if (current == null) return;

    // Check if free daily limit of 50 swipes is already exhausted
    if (!state.isUnlimitedSwipes && state.swipesRemainingToday != null && state.swipesRemainingToday! <= 0) {
      state = state.copyWith(
        isSwipeLimitReached: true,
        swipeLimitMessage:
            'Daily swipe limit of ${state.dailySwipeLimit} reached. Upgrade your plan for unlimited swipes or check back tomorrow!',
      );
      return;
    }

    final nextIndex = state.currentIndex + 1;
    // 1. Optimistically advance currentIndex instantly so UI transition is immediate
    state = state.copyWith(
      currentIndex: nextIndex,
      isSwipeLimitReached: false,
      swipeLimitMessage: null,
    );

    // 2. Perform network request asynchronously in background
    try {
      final result = await _repository.swipeUser(targetUserId: current.id, action: action);

      if (result['isLimitReached'] == true) {
        // Rewind card position if backend rejected swipe due to limit reached
        state = state.copyWith(
          currentIndex: (state.currentIndex > 0) ? state.currentIndex - 1 : 0,
          isSwipeLimitReached: true,
          swipeLimitMessage: result['message']?.toString() ??
              'Daily swipe limit of ${state.dailySwipeLimit} reached. Upgrade to VIP for unlimited swipes or check back tomorrow!',
          swipesRemainingToday: 0,
        );
        return;
      }

      if (result['success'] == true) {
        int? rem;
        final rawRem = result['swipesRemainingToday'];
        if (rawRem is int) {
          rem = rawRem;
        } else if (rawRem != null && rawRem != 'unlimited') {
          rem = int.tryParse(rawRem.toString());
        }
        final isUnlim = result['unlimitedSwipes'] == true || rawRem == 'unlimited';
        final limit = result['dailySwipeLimit'] is int ? result['dailySwipeLimit'] as int : state.dailySwipeLimit;

        state = state.copyWith(
          matchedUser: result['isMutualMatch'] == true ? current : null,
          matchedConversationId: result['conversationId']?.toString(),
          swipesRemainingToday: rem,
          isUnlimitedSwipes: isUnlim,
          dailySwipeLimit: limit,
        );
      }
    } catch (_) {}
  }

  void rewind() {
    if (state.currentIndex > 0) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    }
  }

  void clearMatch() {
    state = state.copyWith(matchedUser: null, matchedConversationId: null);
  }
}

final discoveryProvider = StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
  final repo = ref.watch(discoveryRepositoryProvider);
  final userId = ref.watch(authProvider.select((s) => s.user?.id));
  return DiscoveryNotifier(repo, userId: userId);
});
