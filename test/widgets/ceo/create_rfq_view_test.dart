import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/ceo/rfq/create_rfq_view.dart';

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
      child: const CreateRfqView(),
      ceo: ceo,
      auth: auth,
      rfq: rfq,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows premium-required copy on a free plan', (tester) async {
    final fake = FakeFirebaseFirestore();
    await fake.collection('companies').doc('co-1').set({
      'name': 'Acme Builders',
      'plan': 'free',
      'status': 'active',
    });

    await pumpCeoScreen(
      tester,
      child: CreateRfqView(debugFirestore: fake),
      ceo: ceo,
      rfq: rfq,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Premium plan required'), findsOneWidget);
    expect(find.text('VIEW PLANS'), findsOneWidget);
  });

  testWidgets('PUBLISH REQUEST calls RfqViewModel.createRfq', (tester) async {
    final fake = FakeFirebaseFirestore();
    await fake.collection('companies').doc('co-1').set({
      'name': 'Acme Builders',
      'plan': 'premium',
      'status': 'active',
    });

    await pumpCeoScreen(
      tester,
      child: CreateRfqView(debugFirestore: fake),
      ceo: ceo,
      rfq: rfq,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('PUBLISH REQUEST'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Cement').last);
    await tester.pump();

    await tester.enterText(
      textFieldByHint('e.g. 500 bags of OPC Lucky Cement'),
      'OPC Lucky Cement',
    );
    await tester.enterText(find.byType(TextFormField).at(1), '100');
    await tester.enterText(textFieldByHint('Bags/Tons'), 'bag');

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Lahore').last);
    await tester.pump();

    await tapVisible(tester, find.widgetWithText(ListTile, 'Required By Date'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('OK'));
    await tester.pump();

    await tapVisible(tester, find.text('PUBLISH REQUEST'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    verify(
      () => rfq.createRfq(
        uid: 'ceo-1',
        companyId: 'co-1',
        companyName: 'Acme Builders',
        category: 'Cement',
        materialDescription: 'OPC Lucky Cement',
        quantity: 100.0,
        unit: 'bag',
        city: 'Lahore',
        requiredByDate: any(named: 'requiredByDate'),
      ),
    ).called(1);
  });
}
