import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/supplier/supplier_appeal_view.dart';

import '../../mocks/mocks.dart';
import 'supplier_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerSupplierWidgetFallbacks);

  late MockSupplierViewModel supplier;

  setUp(() {
    supplier = MockSupplierViewModel();
    stubSupplierViewModel(supplier);
  });

  testWidgets('renders the appeal form', (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierAppealView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('Submit Appeal'), findsOneWidget);
    expect(find.text('SUBMIT APPEAL'), findsOneWidget);
  });

  testWidgets('shows success copy after an appeal is submitted', (tester) async {
    when(() => supplier.appealSubmitted).thenReturn(true);

    await pumpSupplierScreen(
      tester,
      child: const SupplierAppealView(),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('Appeal Submitted'), findsOneWidget);
    expect(find.text('BACK TO STATUS'), findsOneWidget);
  });

  testWidgets('SUBMIT APPEAL calls submitAppeal with the typed message',
      (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierAppealView(),
      supplier: supplier,
    );
    await tester.pump();

    const message =
        'Please reconsider this account. We have valid NTN papers, a warehouse, and years of supply history.';
    await tester.enterText(
      textFieldByHint('Describe why your account should be reconsidered...'),
      message,
    );
    await tester.pump();

    await tapVisible(tester, find.text('SUBMIT APPEAL'));
    await tester.pump();

    verify(() => supplier.submitAppeal(message, any(), any())).called(1);
  });
}
