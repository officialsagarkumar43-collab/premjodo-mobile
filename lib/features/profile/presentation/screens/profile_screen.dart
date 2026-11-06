import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';
import 'package:prem_jodo_mobile/core/widgets/app_avatar.dart';
import 'package:prem_jodo_mobile/core/widgets/app_logo.dart';
import 'package:prem_jodo_mobile/core/widgets/custom_button.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:prem_jodo_mobile/features/profile/presentation/screens/my_profile_view_screen.dart';
import 'package:prem_jodo_mobile/features/profile/presentation/screens/membership_screen.dart';
import 'package:prem_jodo_mobile/features/profile/presentation/screens/active_subscription_screen.dart';
import 'package:prem_jodo_mobile/features/legal/presentation/screens/terms_and_conditions_screen.dart';
import 'package:prem_jodo_mobile/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:prem_jodo_mobile/features/legal/presentation/screens/refund_policy_screen.dart';
import 'package:prem_jodo_mobile/features/legal/presentation/screens/contact_us_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).checkAuthStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final sub = user?.subscription;
    final isVip = user?.isVip == true ||
        user?.subscriptionStatus == 'active' ||
        sub?['status'] == 'active';
    final planName = user?.planName ??
        (sub?['planName'] ?? (sub?['plan'] is Map ? sub!['plan']['name'] : sub?['plan'])) ??
        (isVip ? 'Membership Active' : null);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const AppLogo(
          fontSize: 21,
          iconSize: 32,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // Profile Photo & Verification Badge
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 3,
                      ),
                      boxShadow: isVip
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: AppAvatar(
                      imageUrl: (user != null && user.photos.isNotEmpty)
                          ? user.photos.first
                          : (user?.photoObjects.isNotEmpty == true
                              ? user!.photoObjects.first.url
                              : (StorageService.getUserAvatar() ?? '')),
                      name: user?.name ?? '',
                      size: 104,
                    ),
                  ),
                  if (user?.isVerified == true)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.info,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  if (isVip)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    user?.name ?? 'User Profile',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isVip) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stars_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'VIP',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              user?.occupation ?? user?.email ?? 'Member on Prem Jodo',
              style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // VIP Membership Card
            GestureDetector(
              onTap: () async {
                if (isVip) {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ActiveSubscriptionScreen()),
                  );
                } else {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MembershipScreen()),
                  );
                }
                ref.read(authProvider.notifier).checkAuthStatus();
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: isVip
                      ? const LinearGradient(
                          colors: [Color(0xFF2C1625), Color(0xFF1B1423)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isVip ? AppColors.primaryLight.withValues(alpha: 0.6) : Colors.white24,
                    width: isVip ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isVip
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: isVip ? AppColors.primaryLight : Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isVip ? (planName ?? 'Membership Active') : 'Upgrade Membership',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isVip
                                ? 'Active Perks: Unlimited Swipes, DMs & Boosts'
                                : 'Unlock unlimited swipes, instant DMs & profile badges',
                            style: TextStyle(
                              color: isVip ? AppColors.primaryLight.withValues(alpha: 0.9) : Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: isVip ? AppColors.primaryGradient : null,
                        color: isVip ? null : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isVip ? 'ACTIVE' : 'UPGRADE',
                        style: TextStyle(
                          color: isVip ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),


            // Menu Items List
            _buildMenuItem(
              Icons.person_rounded,
              'My Profile',
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyProfileViewScreen()),
                );
              },
            ),
            _buildMenuItem(
              Icons.card_membership_rounded,
              'Membership Plans',
              () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MembershipScreen()),
                );
                ref.read(authProvider.notifier).checkAuthStatus();
              },
            ),

            _buildMenuItem(
              Icons.mark_email_read_rounded,
              'Contact Us',
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                );
              },
            ),
            _buildMenuItem(
              Icons.currency_exchange_rounded,
              'Cancellation & Refund Policy',
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RefundPolicyScreen()),
                );
              },
            ),
            _buildMenuItem(
              Icons.privacy_tip_rounded,
              'Privacy Policy',
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                );
              },
            ),
            _buildMenuItem(
              Icons.description_rounded,
              'Terms of Service',
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsAndConditionsScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Log Out',
              isOutlined: true,
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white38),
      onTap: onTap,
    );
  }
}
