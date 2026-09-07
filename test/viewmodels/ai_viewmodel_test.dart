import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/price_history_model.dart';
import 'package:ratebridge/models/supplier_compare_model.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/viewmodels/ai_viewmodel.dart';

import '../mocks/mocks.dart';

SupplierCompareModel _supplier({
  String uid = 'sup-1',
  String name = 'Cement House',
  double price = 1250,
  double rating = 4.6,
}) {
  return SupplierCompareModel(
    supplierUid: uid,
    businessName: name,
    price: price,
    rating: rating,
    city: 'Lahore',
    isVerified: true,
    isAnomalyFlagged: false,
  );
}

PriceHistoryModel _history({
  String id = 'hist-1',
  double price = 1200,
  DateTime? timestamp,
}) {
  return PriceHistoryModel(
    histId: id,
    materialId: 'mat-1',
    supplierUid: 'sup-1',
    companyId: 'co-1',
    price: price,
    timestamp: timestamp ?? DateTime.utc(2026, 4, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(<String, dynamic>{});
  });

  late MockFirestoreService firestore;
  late MockFirebaseAuth auth;
  late MockFirebaseUser firebaseUser;
  late AiViewModel viewModel;

  void stubAi({String text = 'Buy Lucky OPC this week.'}) {
    when(
      () => firestore.generateAiText(
        uid: any(named: 'uid'),
        prompt: any(named: 'prompt'),
      ),
    ).thenAnswer((_) async => text);
  }

  void stubAiError(Object error) {
    when(
      () => firestore.generateAiText(
        uid: any(named: 'uid'),
        prompt: any(named: 'prompt'),
      ),
    ).thenThrow(error);
  }

  setUp(() {
    firestore = MockFirestoreService();
    auth = MockFirebaseAuth();
    firebaseUser = MockFirebaseUser();
    when(() => auth.currentUser).thenReturn(firebaseUser);
    when(() => firebaseUser.uid).thenReturn('user-1');
    stubAi();
    viewModel = AiViewModel(firestore, auth: auth);
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('AiViewModel getters', () {
    test('statusFeedback is ready before any analysis', () {
      expect(viewModel.result, isNull);
      expect(viewModel.error, isNull);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isAnalyzing, isFalse);
      expect(viewModel.statusFeedback, 'AI Engine ready for analysis.');
    });

    test('isAnalyzing tracks isLoading', () async {
      final gate = Completer<String>();
      when(
        () => firestore.generateAiText(
          uid: any(named: 'uid'),
          prompt: any(named: 'prompt'),
        ),
      ).thenAnswer((_) => gate.future);

      final pending = viewModel.runMarketAnalysis('cement shortage');
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isLoading, isTrue);
      expect(viewModel.isAnalyzing, isTrue);
      expect(viewModel.result, isNull);
      expect(viewModel.error, isNull);
      expect(viewModel.statusFeedback, 'AI Engine ready for analysis.');

      gate.complete('Prices will rise.');
      await pending;

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isAnalyzing, isFalse);
      expect(viewModel.statusFeedback, 'Prices will rise.');
    });
  });

  group('AiViewModel.askAssistant', () {
    test('success returns the AI text without mutating analysis state',
        () async {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      final answer = await viewModel.askAssistant(
        question: 'How do I compare prices?',
        screenName: 'Marketplace',
        screenData: const {'city': 'Lahore'},
      );

      expect(answer, 'Buy Lucky OPC this week.');
      expect(notifies, 0);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.result, isNull);
      expect(viewModel.error, isNull);

      final captured = verify(
        () => firestore.generateAiText(
          uid: captureAny(named: 'uid'),
          prompt: captureAny(named: 'prompt'),
        ),
      ).captured;
      expect(captured[0], 'user-1');
      expect(captured[1], contains('Current screen: Marketplace'));
      expect(captured[1], contains('How do I compare prices?'));
      expect(captured[1], contains('Lahore'));
    });

    test('unauthenticated users fail before the AI service is called',
        () async {
      when(() => auth.currentUser).thenReturn(null);

      await expectLater(
        viewModel.askAssistant(
          question: 'Hello',
          screenName: 'Home',
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            'Please sign in again and retry.',
          ),
        ),
      );
      verifyNever(
        () => firestore.generateAiText(
          uid: any(named: 'uid'),
          prompt: any(named: 'prompt'),
        ),
      );
    });

    test('empty uid is treated as unauthenticated', () async {
      when(() => firebaseUser.uid).thenReturn('');

      await expectLater(
        viewModel.askAssistant(question: 'Hello', screenName: 'Home'),
        throwsA(isA<AppException>()),
      );
      verifyNever(
        () => firestore.generateAiText(
          uid: any(named: 'uid'),
          prompt: any(named: 'prompt'),
        ),
      );
    });

    test('AI service failure propagates to the caller', () async {
      stubAiError(AppException('The assistant returned an empty response.'));

      await expectLater(
        viewModel.askAssistant(question: 'Hello', screenName: 'Home'),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            'The assistant returned an empty response.',
          ),
        ),
      );
    });
  });

  group('AiViewModel.runMarketAnalysis', () {
    test('success stores the forecast and toggles loading', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      String? errorOnFirst;
      String? resultOnFirst;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) {
          loadingOnFirst = viewModel.isLoading;
          errorOnFirst = viewModel.error;
          resultOnFirst = viewModel.result;
        }
      });

      await viewModel.runMarketAnalysis('steel shortage in Karachi');

      expect(loadingOnFirst, isTrue);
      expect(errorOnFirst, isNull);
      expect(resultOnFirst, isNull);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.result, 'Buy Lucky OPC this week.');
      expect(viewModel.error, isNull);
      expect(viewModel.statusFeedback, 'Buy Lucky OPC this week.');
      expect(notifies, 2);

      final prompt = verify(
        () => firestore.generateAiText(
          uid: 'user-1',
          prompt: captureAny(named: 'prompt'),
        ),
      ).captured.single as String;
      expect(prompt, contains('steel shortage in Karachi'));
      expect(prompt, contains('forecast'));
    });

    test('unavailable AppException is shown as error', () async {
      stubAiError(
        AppException(
          'AI recommendations temporarily unavailable. Please try again in a moment.',
          'unavailable',
        ),
      );

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.runMarketAnalysis('cement');

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.result, isNull);
      expect(
        viewModel.error,
        'AI recommendations temporarily unavailable. Please try again in a moment.',
      );
      expect(
        viewModel.statusFeedback,
        'AI recommendations temporarily unavailable. Please try again in a moment.',
      );
      expect(notifies, 2);
    });

    test('generic failures stringify onto error', () async {
      stubAiError(Exception('socket hang up'));

      await viewModel.runMarketAnalysis('cement');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, 'Exception: socket hang up');
      expect(viewModel.result, isNull);
    });
  });

  group('AiViewModel.runDetailedBidAnalysis', () {
    test('success includes city, materials, and bid price in the prompt',
        () async {
      await viewModel.runDetailedBidAnalysis(
        city: 'Lahore',
        materialsNeeded: const ['OPC Cement', 'Steel bar'],
        bidPrice: const {'total': 540000, 'unit': 'PKR'},
      );

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.result, 'Buy Lucky OPC this week.');
      expect(viewModel.error, isNull);

      final prompt = verify(
        () => firestore.generateAiText(
          uid: 'user-1',
          prompt: captureAny(named: 'prompt'),
        ),
      ).captured.single as String;
      expect(prompt, contains('Lahore'));
      expect(prompt, contains('OPC Cement, Steel bar'));
      expect(prompt, contains('total'));
      expect(prompt, contains('540000'));
    });

    test('timeout AppException is stored as error', () async {
      stubAiError(
        AppException(
          'The assistant timed out. Please try again.',
          'deadline-exceeded',
        ),
      );

      await viewModel.runDetailedBidAnalysis(
        city: 'Lahore',
        materialsNeeded: const ['Cement'],
        bidPrice: const {'total': 1},
      );

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, 'The assistant timed out. Please try again.');
      expect(viewModel.result, isNull);
    });
  });

  group('AiViewModel.getSupplierRecommendation', () {
    test('success serializes suppliers into the prompt', () async {
      await viewModel.getSupplierRecommendation(
        [
          _supplier(),
          _supplier(uid: 'sup-2', name: 'Steel Co', price: 980, rating: 4.1),
        ],
        'cheapest verified cement',
        'en',
      );

      expect(viewModel.result, 'Buy Lucky OPC this week.');
      expect(viewModel.isLoading, isFalse);

      final prompt = verify(
        () => firestore.generateAiText(
          uid: 'user-1',
          prompt: captureAny(named: 'prompt'),
        ),
      ).captured.single as String;
      expect(prompt, contains('Cement House (Rating: 4.6, Price: 1250.0)'));
      expect(prompt, contains('Steel Co (Rating: 4.1, Price: 980.0)'));
      expect(prompt, contains('cheapest verified cement'));
      expect(prompt, contains('Language: en'));
    });

    test('empty assistant response is treated as failure', () async {
      stubAiError(AppException('The assistant returned an empty response.'));

      await viewModel.getSupplierRecommendation(
        [_supplier()],
        'best value',
        'en',
      );

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, 'The assistant returned an empty response.');
      expect(viewModel.result, isNull);
    });
  });

  group('AiViewModel.getPriceTrendInsight', () {
    test('success includes material name and history points', () async {
      await viewModel.getPriceTrendInsight(
        [
          _history(price: 1100),
          _history(id: 'hist-2', price: 1180, timestamp: DateTime.utc(2026, 4, 15)),
        ],
        'OPC Cement',
        'ur',
      );

      expect(viewModel.result, 'Buy Lucky OPC this week.');
      expect(viewModel.isLoading, isFalse);

      final prompt = verify(
        () => firestore.generateAiText(
          uid: 'user-1',
          prompt: captureAny(named: 'prompt'),
        ),
      ).captured.single as String;
      expect(prompt, contains('OPC Cement'));
      expect(prompt, contains('1100.0'));
      expect(prompt, contains('1180.0'));
      expect(prompt, contains('Language: ur'));
    });

    test('service unavailable clears loading and exposes the message', () async {
      stubAiError(
        AppException(
          'The assistant could not complete that request.',
          'unavailable',
        ),
      );

      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoading;
      });

      await viewModel.getPriceTrendInsight([], 'Steel', 'en');

      expect(loadingOnFirst, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isAnalyzing, isFalse);
      expect(viewModel.error, 'The assistant could not complete that request.');
      expect(viewModel.result, isNull);
      expect(notifies, 2);
    });
  });

  group('AiViewModel.clearResult', () {
    test('clears result and error and notifies listeners', () async {
      await viewModel.runMarketAnalysis('cement');
      expect(viewModel.result, isNotNull);

      var notifies = 0;
      viewModel.addListener(() => notifies++);

      viewModel.clearResult();

      expect(viewModel.result, isNull);
      expect(viewModel.error, isNull);
      expect(viewModel.statusFeedback, 'AI Engine ready for analysis.');
      expect(notifies, 1);
    });

    test('also clears a previous error', () async {
      stubAiError(AppException('unavailable'));
      await viewModel.runMarketAnalysis('cement');
      expect(viewModel.error, isNotNull);

      viewModel.clearResult();

      expect(viewModel.error, isNull);
      expect(viewModel.statusFeedback, 'AI Engine ready for analysis.');
    });
  });
}
