import 'package:cloud_functions/cloud_functions.dart';
import '../utils/app_exception.dart';

class CloudFunctionService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<dynamic> callFunction(String name, Map<String, dynamic> data) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable(name);
      final result = await callable.call(data);
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      throw AppException(e.message ?? 'Cloud function error', e.code);
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
