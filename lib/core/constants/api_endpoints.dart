class ApiEndpoints {
  ApiEndpoints._();

  // Base URLs (Prem Jodo Production & Live Staging)
  static const String baseUrl = 'https://prem-jodo-backend.onrender.com/api/v1';
  static const String socketUrl = 'https://prem-jodo-backend.onrender.com';
  static const String agoraAppId = '831b93c6b07d400886fc6707ffb5c0db';
  static const String imageBaseUrl = 'https://res.cloudinary.com';

  // Auth & Session
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String googleLogin = '/auth/google';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String onboarding = '/auth/onboarding';

  // User & Profile
  static const String updateProfile = '/users/profile';
  static const String uploadPhotos = '/users/photos';
  static const String deletePhoto = '/users/photos';
  static const String verifyFace = '/users/face-verification';
  static const String getInterests = '/users/interests';
  static const String getLookingForOptions = '/users/looking-for-options';
  static String getUserProfile(String userId) => '/users/profile/$userId';
  static String getUserById(String userId) => '/users/$userId';

  // Discovery & Matches
  static const String getDiscoveryFeed = '/matches/feed';
  static const String swipeAction = '/matches/swipe';
  static const String getMatches = '/matches/list';
  static const String getLikesReceived = '/matches/likes-received';

  // Chat & Messaging
  static const String getConversations = '/chat/conversations';
  static String getConversationMessages(String conversationId) =>
      '/chat/conversations/$conversationId/messages';
  static String markConversationRead(String conversationId) =>
      '/chat/conversations/$conversationId/read';
  static String clearConversationMessages(String conversationId) =>
      '/chat/conversations/$conversationId/clear';
  static const String initiateCall = '/call/initiate';
  static const String getAgoraRtcToken = '/call/rtc-token';

  // Membership & Wallet
  static const String getPlans = '/membership/plans';
  static const String getAddons = '/membership/addons';
  static const String getMySubscription = '/membership/my-subscription';
  static const String createMembershipOrder = '/membership/create-order';
  static const String verifyMembershipPayment = '/membership/verify-payment';
  static const String cancelMembership = '/membership/cancel';
  static const String getWallet = '/wallet';
  static const String purchaseCoins = '/wallet/purchase-coins';

  // Events
  static const String getEvents = '/events';
  static String rsvpEvent(String eventId) => '/events/$eventId/rsvp';

  // Support Tickets
  static const String tickets = '/tickets';
  static const String ticketCategories = '/tickets/categories';
  static const String myTickets = '/tickets/my-tickets';
  static String ticketDetail(String id) => '/tickets/$id';
  static String ticketReply(String id) => '/tickets/$id/reply';
}
