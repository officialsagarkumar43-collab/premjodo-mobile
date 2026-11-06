import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/widgets/custom_button.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:prem_jodo_mobile/features/legal/presentation/screens/terms_and_conditions_screen.dart';
import 'package:prem_jodo_mobile/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:prem_jodo_mobile/features/legal/presentation/screens/refund_policy_screen.dart';
import 'package:prem_jodo_mobile/features/legal/presentation/screens/contact_us_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushNotifications = true;
  bool _matchAlerts = true;
  bool _showActiveStatus = true;
  bool _globalMatches = false;

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to log out of Prem Jodo?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
        content: const Text(
          'This action is irreversible. All your photos, chats, coins, and matches will be permanently deleted.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.'), backgroundColor: AppColors.error),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Details
            _buildSectionHeader('Account Information'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _buildInfoTile('Name', user?.name ?? 'Prem Jodo User', Icons.person_outline),
                  const Divider(color: Colors.white10, height: 1),
                  _buildInfoTile('Email', user?.email ?? 'Not linked', Icons.email_outlined),
                  if (user?.phone != null && user!.phone!.isNotEmpty) ...[
                    const Divider(color: Colors.white10, height: 1),
                    _buildInfoTile('Phone', user.phone!, Icons.phone_outlined),
                  ],
                  const Divider(color: Colors.white10, height: 1),
                  _buildInfoTile('Account Status', user?.isVerified == true ? 'Verified 🌟' : 'Standard', Icons.verified_outlined),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Notification Preferences
            _buildSectionHeader('Notifications'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    activeThumbColor: AppColors.primary,
                    title: const Text('Push Notifications', style: TextStyle(color: Colors.white, fontSize: 15)),
                    subtitle: const Text('Receive real-time alerts for likes & messages', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: _pushNotifications,
                    onChanged: (val) => setState(() => _pushNotifications = val),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  SwitchListTile(
                    activeThumbColor: AppColors.primary,
                    title: const Text('New Match Alerts', style: TextStyle(color: Colors.white, fontSize: 15)),
                    subtitle: const Text('Instant notify when you find a match', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: _matchAlerts,
                    onChanged: (val) => setState(() => _matchAlerts = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Discovery Preferences
            _buildSectionHeader('Discovery & Privacy'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    activeThumbColor: AppColors.primary,
                    title: const Text('Show Active Status', style: TextStyle(color: Colors.white, fontSize: 15)),
                    subtitle: const Text('Let matches see when you are online', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: _showActiveStatus,
                    onChanged: (val) => setState(() => _showActiveStatus = val),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  SwitchListTile(
                    activeThumbColor: AppColors.primary,
                    title: const Text('Global Discovery', style: TextStyle(color: Colors.white, fontSize: 15)),
                    subtitle: const Text('Show profiles from other cities & states', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: _globalMatches,
                    onChanged: (val) => setState(() => _globalMatches = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Legal & Information
            _buildSectionHeader('Support & Legal'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _buildNavTile('Contact Us', Icons.mark_email_read_rounded, () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactUsScreen()));
                  }),
                  const Divider(color: Colors.white10, height: 1),
                  _buildNavTile('Privacy Policy', Icons.privacy_tip_rounded, () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
                  }),
                  const Divider(color: Colors.white10, height: 1),
                  _buildNavTile('Cancellation & Refund Policy', Icons.currency_exchange_rounded, () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RefundPolicyScreen()));
                  }),
                  const Divider(color: Colors.white10, height: 1),
                  _buildNavTile('Terms of Service', Icons.description_rounded, () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsAndConditionsScreen()));
                  }),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Log Out Button
            CustomButton(
              text: 'Log Out',
              icon: Icons.logout_rounded,
              isOutlined: true,
              onPressed: _handleLogout,
            ),
            const SizedBox(height: 16),

            // Delete Account Button
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 18),
                label: const Text(
                  'Delete My Account',
                  style: TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                onPressed: _handleDeleteAccount,
              ),
            ),
            const SizedBox(height: 16),

            // App Version
            const Center(
              child: Text(
                'Prem Jodo v1.0.0 • Made with ❤️ in India',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryLight, size: 22),
      title: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
      trailing: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }

  Widget _buildNavTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryLight, size: 22),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
      onTap: onTap,
    );
  }
}
