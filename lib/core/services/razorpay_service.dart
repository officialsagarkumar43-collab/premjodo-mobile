import 'package:prem_jodo_mobile/core/constants/api_endpoints.dart';
import 'package:prem_jodo_mobile/core/network/api_client.dart';
import 'razorpay_mobile.dart' if (dart.library.js_interop) 'razorpay_web.dart';

class RazorpayService {
  final ApiClient _apiClient = ApiClient();

  /// Create Razorpay order via backend: POST /membership/create-order
  Future<Map<String, dynamic>?> createOrder({
    required String planSlugOrId,
    required String billingCycle,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.createMembershipOrder,
      data: {
        'plan': planSlugOrId,
        'billingCycle': billingCycle,
        'paymentMethod': 'Razorpay',
        if (customerName != null && customerName.isNotEmpty) 'customerName': customerName,
        if (customerEmail != null && customerEmail.isNotEmpty) 'customerEmail': customerEmail,
        if (customerPhone != null && customerPhone.isNotEmpty) 'customerPhone': customerPhone,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = response.data;
      if (raw is Map) {
        return (raw['data'] is Map ? Map<String, dynamic>.from(raw['data']) : Map<String, dynamic>.from(raw));
      }
    }
    return null;
  }

  /// Create Razorpay order for Addon via backend: POST /membership/create-order
  Future<Map<String, dynamic>?> createAddonOrder({
    required String addonSlugOrId,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.createMembershipOrder,
      data: {
        'type': 'addon',
        'addon': addonSlugOrId,
        'paymentMethod': 'Razorpay',
        if (customerName != null && customerName.isNotEmpty) 'customerName': customerName,
        if (customerEmail != null && customerEmail.isNotEmpty) 'customerEmail': customerEmail,
        if (customerPhone != null && customerPhone.isNotEmpty) 'customerPhone': customerPhone,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = response.data;
      if (raw is Map) {
        return (raw['data'] is Map ? Map<String, dynamic>.from(raw['data']) : Map<String, dynamic>.from(raw));
      }
    }
    return null;
  }

  /// Verify Razorpay payment via backend: POST /membership/verify-payment
  Future<bool> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    String? planSlugOrId,
    String? billingCycle,
    String? addonSlugOrId,
    String type = 'subscription',
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.verifyMembershipPayment,
      data: {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
        'orderId': orderId,
        'paymentId': paymentId,
        'signature': signature,
        if (planSlugOrId != null) 'plan': planSlugOrId,
        if (billingCycle != null) 'billingCycle': billingCycle,
        if (addonSlugOrId != null) 'addon': addonSlugOrId,
        'type': type,
      },
    );

    return (response.statusCode == 200 || response.statusCode == 201);
  }

  /// Open Razorpay payment gateway
  void openPaymentGateway({
    required Map<String, dynamic> orderData,
    required void Function(Map<String, dynamic> response) onSuccess,
    required void Function(Map<String, dynamic> error) onFailure,
  }) {
    final keyId = orderData['keyId']?.toString() ?? '';
    final amountPaise = orderData['amountInPaise'] ?? ((orderData['amount'] as num? ?? 0) * 100);
    final currency = orderData['currency']?.toString() ?? 'INR';
    const name = 'Prem Jodo';
    final isAddon = orderData['type'] == 'addon' || orderData['addon'] != null;
    final description = isAddon
        ? '${orderData['addonName'] ?? 'Power-up'} Add-on'
        : '${orderData['planName'] ?? 'VIP'} Membership';
    final orderId = orderData['orderId']?.toString() ?? orderData['razorpayOrderId']?.toString() ?? '';

    final userData = orderData['user'] is Map ? orderData['user'] as Map : {};
    final customerName = userData['name']?.toString() ?? '';
    final customerEmail = userData['email']?.toString() ?? '';
    final customerPhone = userData['contact']?.toString() ?? '';

    RazorpayHelper.openCheckout(
      keyId: keyId,
      amountInPaise: amountPaise,
      currency: currency,
      name: name,
      description: description,
      orderId: orderId,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }
}
