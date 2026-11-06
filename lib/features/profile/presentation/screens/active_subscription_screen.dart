import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:prem_jodo_mobile/core/constants/api_endpoints.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/network/api_client.dart';
import 'package:prem_jodo_mobile/core/widgets/custom_button.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:prem_jodo_mobile/features/profile/presentation/screens/membership_screen.dart';

class ActiveSubscriptionScreen extends ConsumerStatefulWidget {
  const ActiveSubscriptionScreen({super.key});

  @override
  ConsumerState<ActiveSubscriptionScreen> createState() => _ActiveSubscriptionScreenState();
}

class _ActiveSubscriptionScreenState extends ConsumerState<ActiveSubscriptionScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  bool _isCancelling = false;
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _refundEligibility;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionDetails();
  }

  Future<void> _fetchSubscriptionDetails() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.get(ApiEndpoints.getMySubscription);
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data;
        if (raw is Map) {
          final data = raw['data'] is Map ? raw['data'] as Map<String, dynamic> : raw as Map<String, dynamic>;
          final sub = data['subscription'] is Map ? data['subscription'] as Map<String, dynamic> : data;
          setState(() {
            _subscription = sub;
            if (data['refundEligibility'] is Map) {
              _refundEligibility = Map<String, dynamic>.from(data['refundEligibility']);
            }
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr.toString());
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
    } catch (_) {
      return dateStr.toString();
    }
  }

  List<String> _extractPerks(Map<String, dynamic>? perks) {
    if (perks == null) return [];
    final List<String> list = [];
    if (perks['unlimitedSwipes'] == true) list.add('Unlimited Likes & Swipes');
    if (perks['seeWhoLikedYou'] == true) list.add('See Who Liked You Instantly');
    if (perks['messageBeforeMatch'] == true) list.add('Direct DM Before Matching');
    if (perks['priorityLikes'] == true) list.add('Priority Likes & Higher Visibility');
    if (perks['rewindAllowed'] == true) list.add('Rewind Unlimited Swipes');
    if (perks['passportLocation'] == true) list.add('Passport / Change Location');
    if (perks['vipBadge'] == true) list.add('Exclusive VIP Profile Badge');
    if (perks['superLikesPerWeek'] != null && perks['superLikesPerWeek'] > 0) {
      list.add('${perks['superLikesPerWeek']} Super Likes per week');
    }
    if (perks['profileBoostPerMonth'] != null && perks['profileBoostPerMonth'] > 0) {
      list.add('${perks['profileBoostPerMonth']} Profile Boosts per month');
    }
    perks.forEach((k, v) {
      if (![
        'unlimitedSwipes',
        'seeWhoLikedYou',
        'messageBeforeMatch',
        'priorityLikes',
        'rewindAllowed',
        'passportLocation',
        'vipBadge',
        'superLikesPerWeek',
        'profileBoostPerMonth',
      ].contains(k)) {
        if (v == true) {
          final title = k.toString().replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}').trim();
          list.add('${title[0].toUpperCase()}${title.substring(1)}');
        } else if (v is num && v > 0) {
          final title = k.toString().replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}').trim();
          list.add('$v $title');
        }
      }
    });
    return list;
  }

  Future<void> _handleCancelSubscription() async {
    final isEligible = _refundEligibility?['isEligible'] == true;
    final hoursLeft = _refundEligibility?['hoursRemaining'] ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1C2B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text(
          'Cancel Subscription?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEligible
                  ? 'You are within the 48-hour refund window ($hoursLeft hrs left). A full refund will be initiated to your original payment method and membership will end immediately.'
                  : 'Your membership perks will remain active until the end of your current billing cycle. Auto-renewal will be turned off.',
              style: const TextStyle(color: Colors.white70, height: 1.4, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Plan', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      final res = await _apiClient.post(
        ApiEndpoints.cancelMembership,
        data: {'reason': 'Cancelled via Mobile App'},
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription cancelled successfully.'),
              backgroundColor: AppColors.info,
            ),
          );
        }
        await _fetchSubscriptionDetails();
        ref.read(authProvider.notifier).checkAuthStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel subscription: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = _subscription;
    final planName = sub?['planName'] ?? (sub?['plan'] is Map ? sub!['plan']['name'] : sub?['plan']) ?? 'VIP Member';
    final status = sub?['status']?.toString().toUpperCase() ?? 'ACTIVE';
    final isActive = sub?['status']?.toString().toLowerCase() == 'active';
    final cycle = sub?['billingCycle']?.toString().toUpperCase() ?? 'MONTHLY';
    final amount = sub?['amount'] ?? 0;
    final currency = sub?['currency'] ?? 'INR';
    final startDate = sub?['startDate'];
    final endDate = sub?['endDate'];
    final autoRenew = sub?['autoRenew'] == true;
    final superLikesLeft = sub?['superLikesRemaining'] ?? sub?['perks']?['superLikesPerWeek'] ?? 0;
    final boostsLeft = sub?['boostsRemaining'] ?? sub?['perks']?['profileBoostPerMonth'] ?? 0;
    final perks = _extractPerks(sub?['perks'] is Map ? sub!['perks'] as Map<String, dynamic> : null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Membership Details', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchSubscriptionDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _fetchSubscriptionDetails,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero VIP Membership Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2C1625), Color(0xFF1B1423)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.6), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.workspace_premium_rounded, color: AppColors.primaryLight, size: 30),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: isActive ? AppColors.primaryGradient : null,
                                  color: isActive ? null : Colors.white24,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  isActive ? 'ACTIVE PLAN' : status,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            planName.toString(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isActive ? 'VIP Benefits & Perks Active' : 'Membership Status: $status',
                            style: TextStyle(
                              color: AppColors.primaryLight.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMiniInfo('BILLING', cycle),
                              _buildMiniInfo('PRICE', '₹$amount $currency'),
                              _buildMiniInfo('AUTO RENEW', autoRenew ? 'ON' : 'OFF'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quota Remaining Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuotaCard(
                            icon: Icons.star_rounded,
                            iconColor: const Color(0xFF4A90E2),
                            title: 'Super Likes',
                            value: '$superLikesLeft left',
                            subtitle: 'Refreshes weekly',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildQuotaCard(
                            icon: Icons.bolt_rounded,
                            iconColor: const Color(0xFFFF9500),
                            title: 'Profile Boosts',
                            value: '$boostsLeft left',
                            subtitle: 'Refreshes monthly',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Subscription Period & Timeline
                    const Text(
                      'Subscription Timeline',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.darkCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          _buildTimelineRow(
                            icon: Icons.play_circle_fill_rounded,
                            iconColor: AppColors.success,
                            title: 'Started On',
                            value: _formatDate(startDate),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(color: Colors.white10),
                          ),
                          _buildTimelineRow(
                            icon: Icons.event_available_rounded,
                            iconColor: AppColors.gold,
                            title: 'Expires / Renews On',
                            value: _formatDate(endDate),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Active Perks List
                    if (perks.isNotEmpty) ...[
                      const Text(
                        'Included Active Perks',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: perks.map((p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.primaryLight, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    p,
                                    style: const TextStyle(fontSize: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Refund Policy Banner if eligible
                    if (_refundEligibility?['isEligible'] == true) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2838),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF4A90E2).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFF4A90E2), size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '100% Refund Guarantee Active',
                                    style: TextStyle(color: Color(0xFF4A90E2), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'You have ${_refundEligibility!['hoursRemaining']} hours remaining to cancel and receive a full automatic refund.',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Action Buttons
                    CustomButton(
                      text: 'Purchase Add-ons (Super Likes & Boosts)',
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MembershipScreen(initialTab: 'addons'),
                          ),
                        );
                        _fetchSubscriptionDetails();
                        ref.read(authProvider.notifier).checkAuthStatus();
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MembershipScreen(initialTab: 'plans'),
                          ),
                        );
                        _fetchSubscriptionDetails();
                      },
                      child: const Text(
                        'View Membership Plans',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isActive)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _isCancelling ? null : _handleCancelSubscription,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isCancelling
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                                )
                              : const Text(
                                  'Cancel Subscription',
                                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMiniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildQuotaCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
