import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prem_jodo_mobile/core/constants/api_endpoints.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/network/api_client.dart';
import 'package:prem_jodo_mobile/core/services/razorpay_service.dart';
import 'package:prem_jodo_mobile/core/widgets/custom_button.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:prem_jodo_mobile/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:prem_jodo_mobile/features/profile/data/models/addon_model.dart';
import 'package:prem_jodo_mobile/features/profile/presentation/screens/active_subscription_screen.dart';

class MembershipScreen extends ConsumerStatefulWidget {
  final String? initialTab; // 'plans' or 'addons'
  const MembershipScreen({super.key, this.initialTab});

  @override
  ConsumerState<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends ConsumerState<MembershipScreen> {
  final ApiClient _apiClient = ApiClient();
  final RazorpayService _razorpayService = RazorpayService();
  bool _isLoading = true;
  bool _isAnnual = false;
  bool _isProcessing = false;
  int _selectedTab = 0; // 0: Plans, 1: Add-ons
  List<dynamic> _plans = [];
  List<AddonModel> _addons = [];
  Map<String, dynamic>? _mySubscription;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab == 'addons') {
      _selectedTab = 1;
    }
    _fetchPlansAndSubscription();
  }

  bool get _hasActivePlan {
    if (_mySubscription == null) return false;
    final status = _mySubscription!['status']?.toString().toLowerCase();
    final plan = _mySubscription!['plan'];
    final planSlug = (plan is Map ? plan['slug'] : plan)?.toString().toLowerCase();
    final isVip = _mySubscription!['isVip'] == true ||
        _mySubscription!['perks']?['vipBadge'] == true;
    return status == 'active' && (isVip || (planSlug != null && planSlug != 'free'));
  }

  String get _activePlanName {
    if (_mySubscription == null) return 'VIP Plan';
    return _mySubscription!['planName'] ??
        (_mySubscription!['plan'] is Map ? _mySubscription!['plan']['name'] : _mySubscription!['plan']) ??
        'VIP Plan';
  }

  Future<void> _fetchPlansAndSubscription() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiClient.get(ApiEndpoints.getPlans),
        _apiClient.get(ApiEndpoints.getMySubscription),
        _apiClient.get(ApiEndpoints.getAddons),
      ]);

      final plansRes = results[0];
      final subRes = results[1];
      final addonsRes = results.length > 2 ? results[2] : null;

      // Parse plans & embedded addons
      if (plansRes.statusCode == 200 && plansRes.data != null) {
        final raw = plansRes.data;
        List<dynamic> planList = [];
        List<dynamic> embeddedAddons = [];
        if (raw is List) {
          planList = raw;
        } else if (raw is Map) {
          if (raw['data'] is List) {
            planList = raw['data'] as List<dynamic>;
          } else if (raw['data'] is Map) {
            if (raw['data']['plans'] is List) {
              planList = raw['data']['plans'] as List<dynamic>;
            }
            if (raw['data']['addons'] is List) {
              embeddedAddons = raw['data']['addons'] as List<dynamic>;
            }
          }
          if (raw['plans'] is List) {
            planList = raw['plans'] as List<dynamic>;
          }
          if (raw['addons'] is List) {
            embeddedAddons = raw['addons'] as List<dynamic>;
          }
        }
        _plans = planList;
        if (embeddedAddons.isNotEmpty) {
          _addons = embeddedAddons
              .map((a) => AddonModel.fromJson(a is Map<String, dynamic> ? a : Map<String, dynamic>.from(a as Map)))
              .toList();
        }
      }

      // Parse dedicated addons response
      if (addonsRes != null && addonsRes.statusCode == 200 && addonsRes.data != null) {
        final raw = addonsRes.data;
        List<dynamic> list = [];
        if (raw is List) {
          list = raw;
        } else if (raw is Map) {
          if (raw['data'] is List) {
            list = raw['data'] as List<dynamic>;
          } else if (raw['data'] is Map && raw['data']['addons'] is List) {
            list = raw['data']['addons'] as List<dynamic>;
          } else if (raw['addons'] is List) {
            list = raw['addons'] as List<dynamic>;
          }
        }
        if (list.isNotEmpty) {
          _addons = list
              .map((a) => AddonModel.fromJson(a is Map<String, dynamic> ? a : Map<String, dynamic>.from(a as Map)))
              .toList();
        }
      }

      // Parse subscription
      if (subRes.statusCode == 200 && subRes.data != null) {
        final raw = subRes.data;
        if (raw is Map) {
          final data = raw['data'] is Map ? raw['data'] as Map<String, dynamic> : raw as Map<String, dynamic>;
          if (data['subscription'] is Map) {
            _mySubscription = Map<String, dynamic>.from(data['subscription']);
            if (data['isVip'] == true) {
              _mySubscription!['isVip'] = true;
            }
          } else {
            _mySubscription = data;
          }
        }
      }

      // If user has an active membership plan and didn't explicitly request plans, default to Add-ons!
      if (_hasActivePlan && widget.initialTab != 'plans') {
        _selectedTab = 1;
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  String _getPlanPrice(Map<String, dynamic> plan, bool isAnnual) {
    final pricing = plan['pricing'];
    if (pricing is Map) {
      if (isAnnual && pricing['annual'] is Map) {
        final ann = pricing['annual'];
        final total = ann['totalAmount'] ?? ann['pricePerMonth'];
        if (total != null) return '₹$total/yr';
      } else if (!isAnnual && pricing['monthly'] is Map) {
        final mon = pricing['monthly'];
        final amount = mon['totalAmount'] ?? mon['pricePerMonth'];
        if (amount != null) return '₹$amount/mo';
      }
    }
    final raw = isAnnual ? (plan['annualPrice'] ?? plan['price']) : plan['price'];
    if (raw == null) return '';
    final str = raw.toString().trim();
    if (str.startsWith('₹') || str.startsWith('\$')) return str;
    return '₹$str';
  }

  List<String> _extractPerks(Map<String, dynamic> plan) {
    if (plan['features'] is List) {
      return (plan['features'] as List).map((e) => e.toString()).toList();
    }
    final perks = plan['perks'];
    if (perks is Map) {
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
    return [];
  }

  Future<void> _startPlanRazorpayCheckout(Map<String, dynamic> plan) async {
    final planSlug = plan['slug'] ?? plan['_id'] ?? plan['id'] ?? 'gold';
    final planName = plan['name']?.toString() ?? 'VIP Plan';
    final billingCycle = _isAnnual ? 'annual' : 'monthly';

    setState(() => _isProcessing = true);

    try {
      final orderData = await _razorpayService.createOrder(
        planSlugOrId: planSlug.toString(),
        billingCycle: billingCycle,
      );

      if (orderData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to initiate Razorpay order. Please try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      _razorpayService.openPaymentGateway(
        orderData: orderData,
        onSuccess: (paymentResponse) async {
          final orderId = paymentResponse['razorpay_order_id']?.toString() ?? orderData['orderId']?.toString() ?? '';
          final paymentId = paymentResponse['razorpay_payment_id']?.toString() ?? '';
          final signature = paymentResponse['razorpay_signature']?.toString() ?? '';

          final isVerified = await _razorpayService.verifyPayment(
            orderId: orderId,
            paymentId: paymentId,
            signature: signature,
            planSlugOrId: planSlug.toString(),
            billingCycle: billingCycle,
            type: 'subscription',
          );

          if (isVerified) {
            await _fetchPlansAndSubscription();
            ref.read(authProvider.notifier).checkAuthStatus();
            ref.read(discoveryProvider.notifier).refreshSwipeQuota();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Subscribed to $planName successfully! 🎉'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment verification failed. Please contact support.'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
        onFailure: (error) {
          final msg = error['message']?.toString() ?? 'Payment was cancelled';
          if (!msg.toLowerCase().contains('cancel')) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg), backgroundColor: AppColors.error),
              );
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _startAddonRazorpayCheckout(AddonModel addon) async {
    setState(() => _isProcessing = true);

    try {
      final orderData = await _razorpayService.createAddonOrder(
        addonSlugOrId: addon.slug.isNotEmpty ? addon.slug : addon.id,
      );

      if (orderData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to initiate Razorpay order for this add-on. Please try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      _razorpayService.openPaymentGateway(
        orderData: orderData,
        onSuccess: (paymentResponse) async {
          final orderId = paymentResponse['razorpay_order_id']?.toString() ?? orderData['orderId']?.toString() ?? '';
          final paymentId = paymentResponse['razorpay_payment_id']?.toString() ?? '';
          final signature = paymentResponse['razorpay_signature']?.toString() ?? '';

          final isVerified = await _razorpayService.verifyPayment(
            orderId: orderId,
            paymentId: paymentId,
            signature: signature,
            addonSlugOrId: addon.slug.isNotEmpty ? addon.slug : addon.id,
            type: 'addon',
          );

          if (isVerified) {
            await _fetchPlansAndSubscription();
            ref.read(authProvider.notifier).checkAuthStatus();
            ref.read(discoveryProvider.notifier).refreshSwipeQuota();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Purchased ${addon.name} successfully! Extra credits added 🎉'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment verification failed. Please contact support.'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
        onFailure: (error) {
          final msg = error['message']?.toString() ?? 'Payment was cancelled';
          if (!msg.toLowerCase().contains('cancel')) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg), backgroundColor: AppColors.error),
              );
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handlePlanSubscribe(Map<String, dynamic> plan) {
    // RULE: If user already has an active membership plan, they CANNOT upgrade or purchase another plan!
    if (_hasActivePlan) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1C2B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: AppColors.gold, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Plan Upgrade Not Allowed',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You already have an active membership plan ($_activePlanName). Plan upgrades or changing plans are not allowed while your current plan is active.',
                style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: AppColors.gold, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Want extra Super Likes or Profile Boosts? You can purchase Add-ons without affecting your plan!',
                        style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close', style: TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() => _selectedTab = 1);
                    },
                    child: const Text('Browse Add-ons', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      return;
    }

    final price = _getPlanPrice(plan, _isAnnual);
    final planName = plan['name']?.toString() ?? 'VIP Plan';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1C2B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Subscribe to $planName',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Billing Cycle', style: TextStyle(color: Colors.white60, fontSize: 13)),
                      Text(
                        _isAnnual ? 'Annual (Save 33%)' : 'Monthly',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount', style: TextStyle(color: Colors.white60, fontSize: 14)),
                      Text(
                        price,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Unlock unlimited swipes, direct DM messaging before matching, and VIP priority.',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _startPlanRazorpayCheckout(plan);
                  },
                  child: const Text('Confirm & Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleAddonPurchase(AddonModel addon) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1C2B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Row(
          children: [
            Icon(
              addon.isProfileBoost ? Icons.bolt_rounded : Icons.star_rounded,
              color: addon.isProfileBoost ? const Color(0xFFFF9500) : AppColors.gold,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Buy ${addon.name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Add-on Type', style: TextStyle(color: Colors.white60, fontSize: 13)),
                      Text(
                        addon.isProfileBoost ? 'Profile Boost' : 'Super Likes Pack',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Price (One-Time)', style: TextStyle(color: Colors.white60, fontSize: 14)),
                      Text(
                        '₹${addon.price}',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              addon.description.isNotEmpty
                  ? addon.description
                  : (addon.isProfileBoost
                      ? 'Be the top profile in your area for 24 hours.'
                      : 'Stand out 3x more and notify matches instantly.'),
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _startAddonRazorpayCheckout(addon);
                  },
                  child: const Text('Confirm & Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        title: const Text('Membership & Add-ons', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_mySubscription != null && _hasActivePlan)
            TextButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ActiveSubscriptionScreen()),
                );
                _fetchPlansAndSubscription();
              },
              icon: const Icon(Icons.stars_rounded, color: AppColors.gold, size: 18),
              label: const Text('My Plan', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Hero Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.workspace_premium_rounded, size: 48, color: Colors.white),
                            const SizedBox(height: 8),
                            const Text(
                              'Supercharge Your Matches',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Unlock unlimited swipes, instant DMs, profile boosts & super likes.',
                              style: TextStyle(fontSize: 13, color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            if (_hasActivePlan) ...[
                              const SizedBox(height: 14),
                              GestureDetector(
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const ActiveSubscriptionScreen()),
                                  );
                                  _fetchPlansAndSubscription();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.gold, width: 1.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.stars_rounded, color: AppColors.gold, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Active VIP: $_activePlanName',
                                        style: const TextStyle(
                                          color: AppColors.gold,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold, size: 12),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Category Selector (Membership Plans vs Add-ons)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedTab = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 0 ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.card_membership_rounded, color: Colors.white, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Membership Plans',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                                          color: Colors.white,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedTab = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 1 ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.bolt_rounded, color: AppColors.gold, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Add-ons & Power-ups',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                                          color: Colors.white,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // TAB 0: MEMBERSHIP PLANS
                      if (_selectedTab == 0) ...[
                        if (_hasActivePlan) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2838),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Active Membership: $_activePlanName',
                                        style: const TextStyle(
                                          color: AppColors.gold,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'You already have an active plan. Plan upgrades are not allowed while active. You can purchase Add-ons for extra Super Likes and Boosts anytime!',
                                        style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                                      ),
                                      const SizedBox(height: 10),
                                      GestureDetector(
                                        onTap: () => setState(() => _selectedTab = 1),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Go to Add-ons Catalog',
                                              style: TextStyle(
                                                color: AppColors.primaryLight,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            SizedBox(width: 4),
                                            Icon(Icons.arrow_forward_rounded, color: AppColors.primaryLight, size: 14),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Billing Toggle
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.darkSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _isAnnual = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !_isAnnual ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Monthly Billing',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: !_isAnnual ? FontWeight.bold : FontWeight.normal,
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _isAnnual = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _isAnnual ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Annual',
                                          style: TextStyle(
                                            fontWeight: _isAnnual ? FontWeight.bold : FontWeight.normal,
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.gold,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'SAVE 33%',
                                            style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Plans List
                        if (_plans.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            alignment: Alignment.center,
                            child: const Column(
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 48, color: Colors.white38),
                                SizedBox(height: 12),
                                Text(
                                  'No membership plans available at the moment',
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._plans.map((plan) {
                            final planMap = plan is Map<String, dynamic>
                                ? plan
                                : (plan is Map ? Map<String, dynamic>.from(plan) : <String, dynamic>{});
                            final isPopular = planMap['popular'] == true ||
                                planMap['slug'] == 'platinum' ||
                                (planMap['name']?.toString().toLowerCase().contains('platinum') ?? false);
                            final price = _getPlanPrice(planMap, _isAnnual);
                            final features = _extractPerks(planMap);

                            final activePlanSlug = (_mySubscription?['plan'] is String
                                    ? _mySubscription!['plan']
                                    : (_mySubscription?['plan'] is Map ? _mySubscription!['plan']['slug'] : null))
                                ?.toString()
                                .toLowerCase();
                            final isSubActive = _mySubscription?['status']?.toString().toLowerCase() == 'active';
                            final currentSlug = planMap['slug']?.toString().toLowerCase();
                            final currentId = planMap['_id']?.toString().toLowerCase();
                            final currentName = planMap['name']?.toString().toLowerCase() ?? '';

                            final isCurrentPlan = isSubActive &&
                                activePlanSlug != null &&
                                (activePlanSlug == currentSlug ||
                                    activePlanSlug == currentId ||
                                    currentName.contains(activePlanSlug));

                            return Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.darkCard,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isCurrentPlan
                                      ? AppColors.gold
                                      : (isPopular ? AppColors.primary : Colors.white12),
                                  width: (isCurrentPlan || isPopular) ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isCurrentPlan)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle_rounded, color: Colors.black, size: 14),
                                          SizedBox(width: 6),
                                          Text(
                                            'YOUR CURRENT ACTIVE PLAN',
                                            style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (isPopular)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'MOST POPULAR CHOICE',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        planMap['name']?.toString() ?? 'VIP Plan',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        price,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(color: Colors.white12),
                                  const SizedBox(height: 12),
                                  ...features.map((f) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded, color: AppColors.primaryLight, size: 18),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                f,
                                                style: const TextStyle(fontSize: 14, color: Colors.white70),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                  const SizedBox(height: 16),
                                  CustomButton(
                                    text: isCurrentPlan
                                        ? 'Active Plan ✓'
                                        : (_hasActivePlan ? 'Subscribed (Upgrade Disabled)' : 'Choose Plan'),
                                    isOutlined: !isPopular && !isCurrentPlan,
                                    onPressed: isCurrentPlan ? null : () => _handlePlanSubscribe(planMap),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],

                      // TAB 1: ADD-ONS & POWER-UPS
                      if (_selectedTab == 1) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF261828), Color(0xFF161524)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.bolt_rounded, color: AppColors.gold, size: 30),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Add-ons & Credits',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Buy extra Super Likes or Profile Boosts instantly without changing your subscription.',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_addons.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            alignment: Alignment.center,
                            child: const Column(
                              children: [
                                Icon(Icons.flash_off_rounded, size: 48, color: Colors.white38),
                                SizedBox(height: 12),
                                Text(
                                  'No add-ons available at the moment',
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._addons.map((addon) {
                            final isBoost = addon.isProfileBoost;
                            final icon = isBoost ? Icons.bolt_rounded : Icons.star_rounded;
                            final iconColor = isBoost ? const Color(0xFFFF9500) : AppColors.gold;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppColors.darkCard,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: addon.tag != null ? AppColors.primary : Colors.white12,
                                  width: addon.tag != null ? 1.8 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: iconColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(icon, color: iconColor, size: 26),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    addon.name,
                                                    style: const TextStyle(
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                if (addon.tag != null && addon.tag!.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      addon.tag!,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              addon.isProfileBoost
                                                  ? 'Top profile priority in your area'
                                                  : 'Notify partner & stand out 3x more',
                                              style: const TextStyle(fontSize: 12, color: Colors.white54),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (addon.description.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Text(
                                        addon.description,
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ),
                                  const Divider(color: Colors.white10),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                '₹${addon.price}',
                                                style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.gold,
                                                ),
                                              ),
                                              if (addon.originalPrice > addon.price) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  '₹${addon.originalPrice}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.white38,
                                                    decoration: TextDecoration.lineThrough,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (addon.discountPercent > 0)
                                            Text(
                                              '${addon.discountPercent}% Instant Savings',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.success,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                        ],
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        onPressed: () => _handleAddonPurchase(addon),
                                        child: const Text('Buy Add-on', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ],
                  ),
                ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Opening Secure Payment Gateway...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
