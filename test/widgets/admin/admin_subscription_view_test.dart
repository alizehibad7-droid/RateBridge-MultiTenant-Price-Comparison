import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/subscription_model.dart';
import 'package:ratebridge/views/admin/admin_subscription_view.dart';

import '../../mocks/mocks.dart';
import 'admin_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAdminWidgetFallbacks);

  late MockAdminViewModel admin;
  late MockSubscriptionViewModel subscription;

  setUp(() {
    admin = MockAdminViewModel();
    stubAdminViewModel(admin);
    subscription = MockSubscriptionViewModel();
    stubSubscriptionViewModel(subscription);
  });

  testWidgets('shows a spinner while companies are loading', (tester) async {
    final fake = FakeFirebaseFirestore();
    final gate = Completer<void>();
    await pumpAdminScreen(
      tester,
      child: AdminSubscriptionView(
        debugFirestore: fake,
        debugLoadGate: gate.future,
      ),
      admin: admin,
      subscription: subscription,
    );

    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete();
    await tester.pump();
  });

  testWidgets('shows empty copy when there are no active companies',
      (tester) async {
    final fake = FakeFirebaseFirestore();

    await pumpAdminScreen(
      tester,
      child: AdminSubscriptionView(debugFirestore: fake),
      admin: admin,
      subscription: subscription,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No companies found'), findsOneWidget);
  });

  testWidgets('renders an active company and grants a plan', (tester) async {
    final fake = FakeFirebaseFirestore();
    await fake.collection('companies').doc('co-1').set({
      'name': 'Acme Builders',
      'status': 'active',
    });

    await pumpAdminScreen(
      tester,
      child: AdminSubscriptionView(debugFirestore: fake),
      admin: admin,
      subscription: subscription,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Acme Builders'), findsOneWidget);
    expect(find.text('Basic'), findsWidgets);

    await tapVisible(tester, find.text('Basic').last);
    await tester.pump();

    await tapVisible(tester, find.text('GRANT BASIC'));
    await tester.pump();

    verify(
      () => subscription.adminGrantPlan(
        companyId: 'co-1',
        plan: kPlans[1],
        note: '',
      ),
    ).called(1);
  });
}
