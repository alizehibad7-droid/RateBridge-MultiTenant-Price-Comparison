import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/services/cloud_function_service.dart';
import 'package:ratebridge/utils/app_exception.dart';

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(<String, dynamic>{});
  });

  late MockFirebaseFunctions functions;
  late MockHttpsCallable callable;
  late MockHttpsCallableResult result;
  late CloudFunctionService service;

  setUp(() {
    functions = MockFirebaseFunctions();
    callable = MockHttpsCallable();
    result = MockHttpsCallableResult();
    when(() => functions.httpsCallable(any())).thenReturn(callable);
    when(() => callable.call(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'ok': true});
    service = CloudFunctionService(functions: functions);
  });

  group('CloudFunctionService.callFunction', () {
    test('returns the callable result data', () async {
      when(() => result.data).thenReturn({'orderId': 'order-1'});

      final data = await service.callFunction('placeOrder', {
        'companyId': 'co-1',
      });

      expect(data, {'orderId': 'order-1'});
      verify(() => functions.httpsCallable('placeOrder')).called(1);
      verify(() => callable.call({'companyId': 'co-1'})).called(1);
    });

    test('maps FirebaseFunctionsException details string to AppException',
        () async {
      when(() => callable.call(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'failed-precondition',
          details: 'Upgrade to Basic to use AI.',
        ),
      );

      await expectLater(
        service.callFunction('generateAiText', {}),
        throwsA(
          isA<AppException>()
              .having((e) => e.message, 'message', 'Upgrade to Basic to use AI.')
              .having((e) => e.code, 'code', 'failed-precondition'),
        ),
      );
    });

    test('maps nested details.message when present', () async {
      when(() => callable.call(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'invalid-argument',
          details: {'message': 'Missing companyId'},
        ),
      );

      await expectLater(
        service.callFunction('sendOrderNotification', {}),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            'Missing companyId',
          ),
        ),
      );
    });

    test('maps known codes when the SDK message equals the code', () async {
      when(() => callable.call(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'unauthenticated',
        ),
      );

      await expectLater(
        service.callFunction('secureOp', {}),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            'Please sign in again and retry.',
          ),
        ),
      );
    });

    test('maps permission-denied, not-found, and unknown codes', () async {
      Future<String> messageFor(String code) async {
        when(() => callable.call(any())).thenThrow(
          FirebaseFunctionsException(code: code, message: code),
        );
        try {
          await service.callFunction('op', {});
        } on AppException catch (e) {
          return e.message;
        }
        fail('expected AppException');
      }

      expect(
        await messageFor('permission-denied'),
        'You do not have permission to do that.',
      );
      expect(
        await messageFor('not-found'),
        'The requested record was not found.',
      );
      expect(
        await messageFor('unknown'),
        contains('Something went wrong on the server'),
      );
      expect(
        await messageFor('invalid-argument'),
        'Please check the form and try again.',
      );
    });

    test('uses the SDK message when it is distinct from the code', () async {
      when(() => callable.call(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'internal',
          message: 'Quota exceeded for this project',
        ),
      );

      await expectLater(
        service.callFunction('op', {}),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            'Quota exceeded for this project',
          ),
        ),
      );
    });

    test('wraps unexpected errors in AppException', () async {
      when(() => callable.call(any())).thenThrow(Exception('socket reset'));

      await expectLater(
        service.callFunction('op', {}),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('unexpected error occurred in Cloud Functions'),
          ),
        ),
      );
    });
  });

  group('CloudFunctionService helpers', () {
    test('sendOrderNotification forwards the payload', () async {
      await service.sendOrderNotification(
        toUid: 'ceo-1',
        orderId: 'order-1',
        type: 'placed',
        title: 'New order',
        body: 'Ali placed an order',
      );

      verify(() => functions.httpsCallable('sendOrderNotification')).called(1);
      verify(
        () => callable.call({
          'toUid': 'ceo-1',
          'orderId': 'order-1',
          'type': 'placed',
          'title': 'New order',
          'body': 'Ali placed an order',
        }),
      ).called(1);
    });

    test('sendJoinRequestNotification forwards the payload', () async {
      await service.sendJoinRequestNotification(
        'co-1',
        'Cement House',
        'req-1',
      );

      verify(() => functions.httpsCallable('sendJoinRequestNotification'))
          .called(1);
      verify(
        () => callable.call({
          'companyId': 'co-1',
          'supplierName': 'Cement House',
          'reqId': 'req-1',
        }),
      ).called(1);
    });

    test('sendOrderNotification surfaces callable failures', () async {
      when(() => callable.call(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'unavailable',
          message: 'unavailable',
        ),
      );

      await expectLater(
        service.sendOrderNotification(
          toUid: 'ceo-1',
          orderId: 'order-1',
          type: 'placed',
          title: 'New order',
          body: 'Hi',
        ),
        throwsA(isA<AppException>()),
      );
    });
  });
}
