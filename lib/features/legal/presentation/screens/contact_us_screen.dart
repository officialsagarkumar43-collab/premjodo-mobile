import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:prem_jodo_mobile/core/constants/api_endpoints.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/network/api_client.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';
import 'package:prem_jodo_mobile/core/widgets/custom_button.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/providers/auth_provider.dart';

class ContactUsScreen extends ConsumerStatefulWidget {
  const ContactUsScreen({super.key});

  @override
  ConsumerState<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends ConsumerState<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  String _selectedCategory = 'general_support';
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  String? _submittedTicketId;

  final List<Map<String, String>> _categories = [
    {
      'value': 'general_support',
      'label': 'General Support & Feedback',
      'desc': 'Account, features & app feedback'
    },
    {
      'value': 'subscriptions_payments',
      'label': 'Subscriptions & Payments',
      'desc': 'Plus, Gold, Platinum billing & refunds'
    },
    {
      'value': 'safety_reporting',
      'label': 'Safety & Reporting an Account',
      'desc': 'Harassment, fake profiles & safety issues'
    },
    {
      'value': 'selfie_verification',
      'label': 'Selfie Verification Issue',
      'desc': 'Blue badge & face scan assistance'
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillUserData();
    });
  }

  void _prefillUserData() {
    try {
      final user = ref.read(authProvider).user;
      if (user != null) {
        if (_nameController.text.isEmpty && user.name.isNotEmpty) {
          _nameController.text = user.name;
        }
        if (_emailController.text.isEmpty && (user.email?.isNotEmpty ?? false)) {
          _emailController.text = user.email!;
        }
        if (_phoneController.text.isEmpty && (user.phone?.isNotEmpty ?? false)) {
          _phoneController.text = user.phone!;
        }
      } else {
        final cachedName = StorageService.getUserName();
        if (cachedName != null && cachedName.isNotEmpty && _nameController.text.isEmpty) {
          _nameController.text = cachedName;
        }
        final cachedEmail = StorageService.getLastEmail();
        if (cachedEmail != null && cachedEmail.isNotEmpty && _emailController.text.isEmpty) {
          _emailController.text = cachedEmail;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final fullDescription = _subjectController.text.trim().isNotEmpty
          ? '[Subject: ${_subjectController.text.trim()}]\n\n${_messageController.text.trim()}'
          : _messageController.text.trim();

      final payload = {
        'category': _selectedCategory,
        'description': fullDescription,
        'fullName': _nameController.text.trim(),
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        if (_phoneController.text.trim().isNotEmpty) ...{
          'phoneNumber': _phoneController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
      };

      final response = await ApiClient().dio.post(
        ApiEndpoints.tickets,
        data: payload,
      );

      final data = response.data;
      String? generatedTicketId;
      if (data is Map<String, dynamic>) {
        final ticketData = data['data'];
        if (ticketData is Map<String, dynamic>) {
          generatedTicketId = ticketData['ticketId']?.toString() ??
              ticketData['ticket']?['ticketId']?.toString();
        }
      }

      if (mounted) {
        setState(() {
          _submittedTicketId = generatedTicketId ??
              'TCK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
          _isSubmitting = false;
          _isSubmitted = true;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final errorMsg = e.response?.data?['message']?.toString() ??
            'Failed to submit ticket. Please check your network and try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      _isSubmitted = false;
      _submittedTicketId = null;
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _subjectController.clear();
      _messageController.clear();
      _selectedCategory = 'general_support';
    });
    _prefillUserData();
  }

  void _showMyTicketsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MyTicketsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(authProvider).user != null || StorageService.getToken() != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0D14),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Contact & Support',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          if (isLoggedIn)
            TextButton.icon(
              onPressed: _showMyTicketsModal,
              icon: const Icon(Icons.history_rounded, color: Color(0xFFFB7185), size: 18),
              label: const Text(
                'My Tickets',
                style: TextStyle(
                  color: Color(0xFFFB7185),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE11D48),
                    Color(0xFFF43F5E),
                    Color(0xFFFB7185),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF43F5E).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.mark_email_unread_rounded,
                      size: 32, color: Colors.white),
                  const SizedBox(height: 12),
                  const Text(
                    'Get in Touch with Us',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Have an issue with verification, subscription, or safety? Submit an official support ticket. Our team responds within 24 hours.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),
                  if (isLoggedIn) ...[
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _showMyTicketsModal,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.confirmation_number_outlined, size: 16, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Track My Open Tickets',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),

            // 2. Official Contact Channels Grid
            const Text(
              'OFFICIAL CHANNELS',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),

            _buildContactChannelCard(
              icon: Icons.email_rounded,
              iconColor: const Color(0xFFF43F5E),
              bgColor: const Color(0xFF26121D),
              title: 'Customer Support Desk',
              value: 'support@premjodo.com',
              subtitle: 'Response in 15 mins (24/7)',
            ),
            const SizedBox(height: 10),

            _buildContactChannelCard(
              icon: Icons.shield_rounded,
              iconColor: const Color(0xFF38BDF8),
              bgColor: const Color(0xFF0F2230),
              title: 'Grievance & Safety Officer',
              value: 'grievance@premjodo.com',
              subtitle: 'Designated Officer as per IT Rules 2021',
            ),
            const SizedBox(height: 10),

            _buildContactChannelCard(
              icon: Icons.phone_in_talk_rounded,
              iconColor: const Color(0xFF10B981),
              bgColor: const Color(0xFF0D251C),
              title: 'Helpline & WhatsApp Support',
              value: '+91 98765 43210',
              subtitle: 'Mon – Sat • 10:00 AM – 7:00 PM IST',
            ),
            const SizedBox(height: 10),

            _buildContactChannelCard(
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFFF59E0B),
              bgColor: const Color(0xFF291D0E),
              title: 'Registered Headquarters',
              value: 'Prem Jodo Tech Pvt. Ltd.',
              subtitle: 'Connaught Place, New Delhi, India - 110001',
            ),

            const SizedBox(height: 32),

            // 3. Create Ticket / Send Us A Message Form
            const Text(
              'SUBMIT A SUPPORT TICKET',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),

            _isSubmitted ? _buildSuccessCard() : _buildContactForm(),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildContactChannelCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151825),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
          width: 1.1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151825),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.1,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full Name
            _buildFieldLabel('Full Name *'),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration('Enter your full name', Icons.person_outline),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Please enter your name' : null,
            ),
            const SizedBox(height: 16),

            // Email Address
            _buildFieldLabel('Email Address *'),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration('name@example.com', Icons.email_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!v.contains('@') || !v.contains('.')) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone Number
            _buildFieldLabel('Phone Number (Optional)'),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration('+91 98765 43210', Icons.phone_outlined),
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            _buildFieldLabel('Ticket Category / Department *'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F101A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: const Color(0xFF1B1D2C),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  items: _categories.map((c) {
                    return DropdownMenuItem<String>(
                      value: c['value'],
                      child: Text(c['label']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCategory = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Subject
            _buildFieldLabel('Subject *'),
            TextFormField(
              controller: _subjectController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration('Brief summary of your inquiry', Icons.subject_rounded),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Please enter a subject' : null,
            ),
            const SizedBox(height: 16),

            // Message / Description
            _buildFieldLabel('Message / Description * (min 10 characters)'),
            TextFormField(
              controller: _messageController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration(
                'Please describe your query or issue in detail...',
                Icons.chat_bubble_outline_rounded,
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  v == null || v.trim().length < 10 ? 'Message must be at least 10 characters' : null,
            ),
            const SizedBox(height: 24),

            // Submit Button
            CustomButton(
              text: 'Submit Support Ticket',
              isLoading: _isSubmitting,
              icon: Icons.send_rounded,
              onPressed: _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard() {
    final ticketId = _submittedTicketId ??
        'TCK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF151825),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ticket Submitted Successfully!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFB7185).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFB7185).withValues(alpha: 0.3)),
            ),
            child: Text(
              'Ticket ID: $ticketId',
              style: const TextStyle(
                color: Color(0xFFFB7185),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Thank you for contacting Prem Jodo support. Your ticket has been registered in our support desk. Our team will review and reply directly to your email within 24 hours.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Track Tickets',
                  icon: Icons.history_rounded,
                  onPressed: _showMyTicketsModal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  text: 'New Ticket',
                  isOutlined: true,
                  onPressed: _resetForm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon,
      {bool alignLabelWithHint = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.primaryLight, size: 20),
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: const Color(0xFF0F101A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFF43F5E), width: 1.4),
      ),
    );
  }
}

class _MyTicketsSheet extends StatefulWidget {
  @override
  State<_MyTicketsSheet> createState() => _MyTicketsSheetState();
}

class _MyTicketsSheetState extends State<_MyTicketsSheet> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _tickets = [];

  @override
  void initState() {
    super.initState();
    _fetchMyTickets();
  }

  Future<void> _fetchMyTickets() async {
    try {
      final response = await ApiClient().dio.get(ApiEndpoints.myTickets);
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] != null) {
        final ticketList = data['data']['tickets'];
        if (ticketList is List) {
          setState(() {
            _tickets = ticketList;
            _isLoading = false;
          });
          return;
        }
      }
      setState(() {
        _tickets = [];
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message']?.toString() ?? 'Failed to load tickets';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'resolved':
      case 'closed':
        return const Color(0xFF10B981);
      case 'in_progress':
        return const Color(0xFF38BDF8);
      case 'open':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF12141F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Support Tickets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFB7185)))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline, color: Colors.amber, size: 40),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isLoading = true;
                                    _error = null;
                                  });
                                  _fetchMyTickets();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF43F5E),
                                ),
                                child: const Text('Retry', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _tickets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                                const SizedBox(height: 12),
                                const Text(
                                  'No support tickets submitted yet',
                                  style: TextStyle(color: Colors.white60, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _tickets.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, index) {
                              final t = _tickets[index] as Map<String, dynamic>;
                              final ticketId = t['ticketId'] ?? 'TCK';
                              final status = (t['status'] ?? 'open').toString();
                              final category = (t['category'] ?? 'General').toString().replaceAll('_', ' ').toUpperCase();
                              final desc = t['description']?.toString() ?? '';
                              final createdAt = t['createdAt']?.toString().split('T').first ?? '';

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B1D2C),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          ticketId,
                                          style: const TextStyle(
                                            color: Color(0xFFFB7185),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(status).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: _getStatusColor(status).withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              color: _getStatusColor(status),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      category,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      desc,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                    if (createdAt.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        'Created on: $createdAt',
                                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
