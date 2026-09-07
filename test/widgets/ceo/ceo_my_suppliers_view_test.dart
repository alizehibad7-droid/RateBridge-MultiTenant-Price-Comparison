import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/ceo/ceo_my_suppliers_view.dart';

import '../../mocks/mocks.dart';
import 'ceo_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerCeoWidgetFallbacks);

  late MockCeoViewModel ceo;

  setUp(() {
    ceo = MockCeoViewModel();
    stubCeoViewModel(ceo);
  });

  testWidgets('shows a spinner while linked suppliers are loading',
      (tester) async {
    final controller = StreamController<List<Map<String, dynamic>>>();
    when(() => ceo.watchMySuppliers(any())).thenAnswer((_) => controller.stream);

    await pumpCeoScreen(
      tester,
      child: const CeoMySuppliersView(),
      ceo: ceo,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await controller.close();
  });

  testWidgets('shows empty copy when there are no linked partners',
      (tester) async {
    await pumpCeoScreen(
      tester,
      child: const CeoMySuppliersView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(find.text('No partners linked yet'), findsOneWidget);
  });

  testWidgets('renders a partner and Remove calls removeSupplier',
      (tester) async {
    when(() => ceo.watchMySuppliers(any())).thenAnswer(
      (_) => Stream<List<Map<String, dynamic>>>.value([sampleLinkedSupplier()]),
    );

    await pumpCeoScreen(
      tester,
      child: const CeoMySuppliersView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(find.text('Skyline Materials'), findsOneWidget);

    await tapVisible(tester, find.text('Remove'));
    await tester.pump();
    await tapVisible(tester, find.text('REMOVE PERMANENTLY'));
    await tester.pump();

    verify(() => ceo.removeSupplier('sup-1')).called(1);
  });
}
