import 'package:flutter/material.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.bold)),
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
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.gavel_rounded, color: AppColors.primaryLight, size: 28),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Prem Jodo Terms of Service',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Please review these terms carefully. By using Prem Jodo, you agree to these legal obligations, billing guidelines, and community safety policies.',
                    style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Last Updated: September 2026 • Platform: Prem Jodo',
                    style: TextStyle(fontSize: 11, color: AppColors.gold, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              number: '1',
              title: 'Eligibility & Acceptance',
              content:
                  'You must be at least 18 years of age to create an account and use Prem Jodo. By accessing or using our services, you represent and warrant that you have the right, authority, and capacity to enter into this Agreement and abide by all terms and conditions.',
            ),
            _buildSection(
              number: '2',
              title: 'Account Registration & Security',
              content:
                  'You are responsible for maintaining the confidentiality of your login credentials (OTP/Google sign-in) and for all activities that occur under your account. You agree to provide accurate, current, and complete profile information and promptly update it as needed.',
            ),
            _buildSection(
              number: '3',
              title: 'Community Guidelines & Safety',
              content:
                  'Prem Jodo strictly prohibits harassment, hate speech, explicit or non-consensual content, impersonation, commercial spam, and unlawful activities. Accounts violating our community safety standards are subject to immediate termination without refund.',
            ),
            _buildSection(
              number: '4',
              title: 'VIP Memberships & Billing Cycles',
              content:
                  'Prem Jodo offers optional premium subscription tiers (e.g., Gold, Platinum, Diamond) with recurring billing options (Monthly and Annual). Subscription fees are charged upfront at the beginning of each billing period through authorized payment gateways (Razorpay).',
            ),
            _buildSection(
              number: '5',
              title: 'Cancellation & Refund Rights',
              content:
                  'You may cancel auto-renewal at any time. Purchases made on Prem Jodo are covered by our 48-Hour Full Refund Guarantee for new subscriptions. After 48 hours, active memberships remain valid until the end of the current billing cycle without prorated refunds.',
            ),
            _buildSection(
              number: '6',
              title: 'Virtual Coins & In-App Purchases',
              content:
                  'Virtual coins and in-app gifts purchased within Prem Jodo constitute a limited, non-transferable license. Coins have no real-world monetary value and cannot be redeemed for fiat currency outside the platform.',
            ),
            _buildSection(
              number: '7',
              title: 'Limitation of Liability',
              content:
                  'To the maximum extent permitted by applicable Indian law, Prem Jodo, its founders, and affiliates shall not be liable for any indirect, incidental, special, or consequential damages resulting from your use of the platform or conduct of any other users.',
            ),
            _buildSection(
              number: '8',
              title: 'Governing Law & Dispute Jurisdiction',
              content:
                  'These Terms shall be governed by and construed in accordance with the laws of India. Any disputes arising under these Terms shall be subject to the exclusive jurisdiction of the competent courts located in New Delhi, India.',
            ),

            // Statutory Grievance Card
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
                      Icon(Icons.shield_rounded, color: AppColors.gold, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Statutory Grievance Redressal',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'In compliance with Information Technology Act, 2000 and SPDI Rules:',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  SizedBox(height: 6),
                  Text('Email: officialsagarkumar43@gmail.com', style: TextStyle(fontSize: 13, color: AppColors.primaryLight, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Contact: +91 7087362399 | Helpline: +91 9625477336', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  SizedBox(height: 4),
                  Text('Resolution SLA: Acknowledgment within 24h, resolution within 15 days.', style: TextStyle(fontSize: 11, color: Colors.white54)),
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
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  number,
                  style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 12),
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
