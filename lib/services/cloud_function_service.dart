import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_exception.dart';

String _messageForFunctionsException(FirebaseFunctionsException e) {
  final code = (e.code).trim().toLowerCase();
  final message = (e.message ?? '').trim();
  final details = e.details;
  if (details is String && details.trim().isNotEmpty) {
    return details.trim();
  }
  if (details is Map && details['message'] is String) {
    final nested = (details['message'] as String).trim();
    if (nested.isNotEmpty) return nested;
  }
  if (message.isNotEmpty && message.toLowerCase() != code) {
    return message;
  }
  switch (code) {
    case 'unknown':
    case 'unavailable':
    case 'internal':
      return message.isNotEmpty && message.toLowerCase() != code
          ? message
          : 'Something went wrong on the server. Please try again, or contact support if it continues.';
    case 'unauthenticated':
      return 'Please sign in again and retry.';
    case 'permission-denied':
      return 'You do not have permission to do that.';
    case 'failed-precondition':
      return 'This action is not available on the current plan or account state.';
    case 'invalid-argument':
      return 'Please check the form and try again.';
    case 'not-found':
      return 'The requested record was not found.';
    default:
      return message.isNotEmpty
          ? message
          : 'Something went wrong. Please try again.';
  }
}

class CloudFunctionService {
  final FirebaseFunctions _functions;

  CloudFunctionService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  Future<dynamic> callFunction(String name, Map<String, dynamic> data) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable(name);
      final result = await callable.call(data);
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'Cloud function $name failed: code=${e.code} message=${e.message} details=${e.details}',
      );
      throw AppException(_messageForFunctionsException(e), e.code);
    } catch (e) {
      throw AppException('An unexpected error occurred in Cloud Functions: $e');
    }
  }

  // Helper methods for specific features
  Future<void> sendOrderNotification({
    required String toUid,
    required String orderId,
    required String type,
    required String title,
    required String body,
  }) async {
    await callFunction('sendOrderNotification', {
      'toUid': toUid,
      'orderId': orderId,
      'type': type,
      'title': title,
      'body': body,
    });
  }

  Future<void> sendJoinRequestNotification(String companyId, String supplierName, String reqId) async {
    await callFunction('sendJoinRequestNotification', {
      'companyId': companyId,
      'supplierName': supplierName,
      'reqId': reqId,
    });
  }
}
