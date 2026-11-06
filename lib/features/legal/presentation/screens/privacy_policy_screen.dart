import 'package:flutter/material.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  colors: [Color(0xFF1E2838), Color(0xFF141A24)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF4A90E2).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.privacy_tip_rounded, color: Color(0xFF4A90E2), size: 28),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Prem Jodo Privacy Policy',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your privacy and data security are our highest priorities. Learn how Prem Jodo collects, processes, and protects your personal data.',
                    style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Effective Date: September 2026 • Compliant with Indian DPDP Act',
                    style: TextStyle(fontSize: 11, color: Color(0xFF4A90E2), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              number: '1',
              title: 'Information We Collect',
              content:
                  'We collect information you provide directly to us when creating a profile (name, phone number, email, birth date, gender, bio, interests, and photos), as well as device identifiers, approximate location (with permission), and transaction logs for payment processing.',
            ),
            _buildSection(
              number: '2',
              title: 'How We Use Your Information',
              content:
                  'We use your information to facilitate matchmaking recommendations, verify genuine identities, process payments securely, provide customer support, and detect spam, fraudulent accounts, or community guideline violations.',
            ),
            _buildSection(
              number: '3',
              title: 'Data Sharing & Third-Party Services',
              content:
                  'Prem Jodo does not sell your personal data. We only share necessary data with trusted service providers: Razorpay (for PCI-DSS compliant payment processing), Agora (for secure peer-to-peer video/audio calls), and Cloudinary (for encrypted media hosting).',
            ),
            _buildSection(
              number: '4',
              title: 'AI Face & Selfie Verification',
              content:
                  'When you perform AI Face Verification, temporary biometric facial geometry points are processed exclusively to confirm photo authenticity and prevent catfishing. Biometric data is never shared with third parties or used for advertising.',
            ),
            _buildSection(
              number: '5',
              title: 'Your Privacy Controls & Rights',
              content:
                  'You have full control over your data. You can edit your profile details anytime, adjust discovery preferences, hide your active online presence, request a full copy of your data, or permanently delete your Prem Jodo account from the Settings menu.',
            ),
            _buildSection(
              number: '6',
              title: 'Data Security & Retention',
              content:
                  'We implement industry-standard 256-bit TLS/SSL encryption in transit and AES encryption at rest. Your account information is retained only as long as necessary to provide our matchmaking services or comply with statutory requirements.',
            ),

            // Contact & Privacy Inquiries Card
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
                      Icon(Icons.mark_email_read_rounded, color: Color(0xFF4A90E2), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Data Privacy Contact',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'For privacy inquiries, data deletion requests, or data protection officer inquiries:',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  SizedBox(height: 6),
                  Text('Email: officialsagarkumar43@gmail.com', style: TextStyle(fontSize: 13, color: Color(0xFF4A90E2), fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Address: New Delhi, India', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  number,
                  style: const TextStyle(color: Color(0xFF4A90E2), fontWeight: FontWeight.bold, fontSize: 12),
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
