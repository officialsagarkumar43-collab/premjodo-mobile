import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayHelper {
  static Razorpay? _razorpay;

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
    try {
      _razorpay?.clear();
      _razorpay = Razorpay();

      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
        onSuccess({
          'razorpay_payment_id': response.paymentId ?? '',
          'razorpay_order_id': response.orderId ?? orderId,
          'razorpay_signature': response.signature ?? '',
        });
        _razorpay?.clear();
      });

      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
        onFailure({
          'code': response.code,
          'message': response.message ?? 'Payment failed or cancelled',
        });
        _razorpay?.clear();
      });

      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
        // Handle external wallet if needed
      });

      final Map<String, dynamic> options = {
        'key': keyId,
        'amount': amountInPaise,
        'name': name,
        'description': description,
        if (orderId.isNotEmpty) 'order_id': orderId,
        'currency': currency,
        'prefill': {
          if (customerPhone.isNotEmpty) 'contact': customerPhone,
          if (customerEmail.isNotEmpty) 'email': customerEmail,
          if (customerName.isNotEmpty) 'name': customerName,
        },
        'theme': {
          'color': '#FE2C55',
        },
      };

      _razorpay!.open(options);
    } catch (e) {
      onFailure({'message': e.toString()});
    }
  }
}
