class RazorpayHelper {
  static void openCheckout({
    required String keyId,
    required num amountInPaise,
    required String currency,
    required String name,
    required String description,
    required String orderId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required void Function(Map<String, dynamic> response) onSuccess,
    required void Function(Map<String, dynamic> error) onFailure,
  }) {
    // Non-web platform stub
    onFailure({'message': 'Razorpay SDK is configured for web / mobile checkout.'});
  }
}
