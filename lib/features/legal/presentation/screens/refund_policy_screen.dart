import 'package:flutter/material.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';

class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cancellation & Refund Policy', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E1C44), Color(0xFF1B1426)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.currency_exchange_rounded, color: AppColors.gold, size: 28),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Cancellation & Refund Policy',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Clear, fair, and transparent guidelines on subscription cancellations, payment reversals, and refund timelines.',
                    style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Standard Settlement: 5 - 7 Working Days • Platform: Prem Jodo',
                    style: TextStyle(fontSize: 11, color: AppColors.gold, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              number: '1',
              title: '48-Hour Full Refund Guarantee',
              content:
                  'We offer a 100% full refund guarantee for new membership subscriptions if requested within 48 hours of purchase. If you cancel within 48 hours, a complete reversal is automatically processed to your original payment method with zero cancellation charges.',
            ),
            _buildSection(
              number: '2',
              title: 'Subscription Auto-Renewal Cancellation',
              content:
                  'You can cancel your subscription auto-renewal at any time through the Active Membership screen. After cancellation, you will retain access to all VIP perks and features until the conclusion of your current monthly or annual billing cycle.',
            ),
            _buildSection(
              number: '3',
              title: 'Virtual Coins & Coin Top-ups',
              content:
                  'Prem Coins purchased for in-app virtual gifts or profile boosts are digital consumables. Once credited to your wallet, coin purchases are non-refundable, except in verified cases of technical failure or duplicate billing deductions.',
            ),
            _buildSection(
              number: '4',
              title: 'Duplicate Deductions & Technical Errors',
              content:
                  'In the rare event of duplicate charges or payment gateway errors where amount was debited but features/coins were not activated, our billing team verifies the Razorpay payment ID and initiates an immediate refund within 24 hours.',
            ),
            _buildSection(
              number: '5',
              title: 'Refund Processing & Settlement SLA',
              content:
                  'Once approved, refund amounts are credited directly back to the original payment source (UPI, Credit/Debit Card, Net Banking, or Wallet) within 5 to 7 working days, subject to your bank or card issuer processing timelines.',
            ),
            _buildSection(
              number: '6',
              title: 'How to Submit a Refund Claim',
              content:
                  'To file a refund request, email our billing desk at officialsagarkumar43@gmail.com with your Registered Phone/Email, Razorpay Order ID / Payment ID, and transaction screenshot. Our team acknowledges within 24 hours and resolves within 48-72 hours.',
            ),

            // Direct Billing Helpline Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.headset_mic_rounded, color: AppColors.gold, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Direct Billing Support Desk',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Need urgent assistance with a recent transaction or billing discrepancy?',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  SizedBox(height: 6),
                  Text('Billing Email: officialsagarkumar43@gmail.com', style: TextStyle(fontSize: 13, color: AppColors.gold, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Helpline: +91 9625477336 | Phone: +91 7087362399', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  SizedBox(height: 4),
                  Text('Operating Hours: Mon - Sat, 9:00 AM - 7:00 PM IST', style: TextStyle(fontSize: 11, color: Colors.white54)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String number,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  number,
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }
}
