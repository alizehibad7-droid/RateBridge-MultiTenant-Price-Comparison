import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../utils/app_exception.dart';

class StripeService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> payWithStripe({
    required String type, // "subscription" or "commission"
    String? plan,
    int? amountPKR,
    List<String>? transactionIds,
  }) async {
    try {
      final callableName = type == "subscription"
          ? 'createSubscriptionPaymentIntent'
          : 'createCommissionPaymentIntent';

      final callable = _functions.httpsCallable(callableName);

      final payload = <String, dynamic>{};
      if (plan != null) payload['plan'] = plan;
      if (amountPKR != null) payload['amountPKR'] = amountPKR;
      if (transactionIds != null) payload['transactionIds'] = transactionIds;

      final result = await callable.call(payload);
      final clientSecret = result.data['clientSecret'];

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'RateBridge',
        ),
      );

      await Stripe.instance.presentPaymentSheet();
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Stripe init failed: code=${e.code} message=${e.message}');
      throw AppException(e.message ?? 'Payment initialization failed', e.code);
    } on StripeException catch (e) {
      debugPrint('Stripe error: ${e.error.localizedMessage}');
      throw AppException(e.error.localizedMessage ?? 'Payment failed');
    } catch (e) {
      debugPrint('Unexpected payment error: $e');
      throw AppException('An unexpected error occurred during payment.');
    }
  }
}