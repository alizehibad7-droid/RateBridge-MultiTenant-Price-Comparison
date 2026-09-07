import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/ceo/ceo_subscription_view.dart';

import '../../mocks/mocks.dart';
import 'ceo_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerCeoWidgetFallbacks);

  late MockCeoViewModel ceo;
  late MockSubscriptionViewModel subscription;

  setUp(() {
    ceo = MockCeoViewModel();
    stubCeoViewModel(ceo);
    subscription = MockSubscriptionViewModel();
    stubSubscriptionViewModel(subscription);
  });

  testWidgets('shows a spinner while the subscription is loading',
      (tester) async {
    when(() => subscription.isLoading).thenReturn(true);
    when(() => subscription.currentSubscription).thenReturn(null);

    await pumpCeoScreen(
      tester,
      child: const CeoSubscriptionView(),
      ceo: ceo,
      subscription: subscription,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verify(() => subscription.loadSubscription('co-1')).called(1);
  });

  testWidgets('shows error copy when the subscription fails to load',
      (tester) async {
    when(() => subscription.error).thenReturn('Could not reach billing.');

    await pumpCeoScreen(
      tester,
      child: const CeoSubscriptionView(),
      ceo: ceo,
      subscription: subscription,
    );
    await tester.pump();

    expect(find.text('Could not reach billing.'), findsOneWidget);
    expect(find.text('No billing history found.'), findsOneWidget);
  });

  testWidgets('renders the current plan and cancels via the ViewModel',
      (tester) async {
    when(() => subscription.currentSubscription)
        .thenReturn(sampleSubscription());

    await pumpCeoScreen(
      tester,
      child: const CeoSubscriptionView(),
      ceo: ceo,
      subscription: subscription,
    );
    await tester.pump();

    expect(find.text('BASIC'), findsOneWidget);
    expect(find.text('CANCEL SUBSCRIPTION'), findsOneWidget);

    await tapVisible(tester, find.text('CANCEL SUBSCRIPTION'));
    await tester.pump();
    await tapVisible(tester, find.text('CANCEL PLAN'));
    await tester.pump();

    verify(() => subscription.cancelSubscription('co-1')).called(1);
  });
}
