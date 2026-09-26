import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/rfq_model.dart';
import 'package:ratebridge/views/ceo/rfq/ceo_rfq_list_view.dart';

import '../../mocks/mocks.dart';
import 'ceo_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerCeoWidgetFallbacks);

  late MockCeoViewModel ceo;
  late MockRfqViewModel rfq;

  setUp(() {
    ceo = MockCeoViewModel();
    stubCeoViewModel(ceo);
    rfq = MockRfqViewModel();
    stubRfqViewModel(rfq);
  });

  testWidgets('shows a spinner when the company id is missing', (tester) async {
    when(() => ceo.company).thenReturn(null);
    final auth = MockAuthViewModel();
    stubAuthViewModel(auth, user: ceoUser().copyWith(companyId: ''));

    await pumpCeoScreen(
      tester,
      child: const CeoRfqListView(),
      ceo: ceo,
      auth: auth,
      rfq: rfq,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows a spinner while RFQs are loading', (tester) async {
    final controller = StreamController<List<RfqModel>>();
    when(() => rfq.watchCompanyRfqs(any())).thenAnswer((_) => controller.stream);

    await pumpCeoScreen(
      tester,
      child: const CeoRfqListView(),
      ceo: ceo,
      rfq: rfq,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await controller.close();
  });

  testWidgets('shows empty copy when there are no RFQs', (tester) async {
    await pumpCeoScreen(
      tester,
      child: const CeoRfqListView(),
      ceo: ceo,
      rfq: rfq,
    );
    await tester.pump();

    expect(find.text('No active RFQs'), findsOneWidget);
  });

  testWidgets('renders RFQ tiles from RfqViewModel', (tester) async {
    when(() => rfq.watchCompanyRfqs(any())).thenAnswer(
      (_) => Stream<List<RfqModel>>.value([sampleRfq()]),
    );

    await pumpCeoScreen(
      tester,
      child: const CeoRfqListView(),
      ceo: ceo,
      rfq: rfq,
    );
    await tester.pump();

    expect(find.text('Cement'), findsOneWidget);
    expect(find.text('OPC 53, 500 bags'), findsOneWidget);
    expect(find.text('OPEN'), findsOneWidget);
  });

  testWidgets('CREATE RFQ on a free plan shows the premium dialog',
      (tester) async {
    final fake = FakeFirebaseFirestore();
    await fake.collection('companies').doc('co-1').set({
      'name': 'Acme Builders',
      'plan': 'free',
      'status': 'active',
    });

    await pumpCeoScreen(
      tester,
      child: CeoRfqListView(debugFirestore: fake),
      ceo: ceo,
      rfq: rfq,
    );
    await tester.pump();

    await tapVisible(tester, find.text('CREATE RFQ'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Premium Access'), findsOneWidget);
  });
}
