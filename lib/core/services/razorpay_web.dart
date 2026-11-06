// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

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
    try {
      final options = JSObject();
      options['key'] = keyId.toJS;
      options['amount'] = amountInPaise.toJS;
      options['currency'] = currency.toJS;
      options['name'] = name.toJS;
      options['description'] = description.toJS;
      options['order_id'] = orderId.toJS;

      final prefill = JSObject();
      prefill['name'] = customerName.toJS;
      prefill['email'] = customerEmail.toJS;
      prefill['contact'] = customerPhone.toJS;
      options['prefill'] = prefill;

      final theme = JSObject();
      theme['color'] = '#FE2C55'.toJS;
      options['theme'] = theme;

      options['handler'] = ((JSObject response) {
        final paymentId = (response['razorpay_payment_id'] as JSString?)?.toDart ?? '';
        final resOrderId = (response['razorpay_order_id'] as JSString?)?.toDart ?? orderId;
        final signature = (response['razorpay_signature'] as JSString?)?.toDart ?? '';
        onSuccess({
          'razorpay_payment_id': paymentId,
          'razorpay_order_id': resOrderId,
          'razorpay_signature': signature,
        });
      }).toJS;

      final modal = JSObject();
      modal['ondismiss'] = (() {
        onFailure({'message': 'Payment cancelled'});
      }).toJS;
      options['modal'] = modal;

      final rzpConstructor = globalContext['Razorpay'] as JSFunction?;
      if (rzpConstructor != null) {
        final rzpInstance = rzpConstructor.callAsConstructor<JSObject>(options);
        rzpInstance.callMethod('open'.toJS);
      } else {
        onFailure({'message': 'Razorpay SDK script not loaded'});
      }
    } catch (e) {
      onFailure({'message': e.toString()});
    }
  }
}
