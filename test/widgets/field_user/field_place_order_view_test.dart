import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/field_user/orders/field_place_order_view.dart';

import '../../mocks/mocks.dart';
import 'field_user_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerFieldUserWidgetFallbacks);

  late MockFieldSessionViewModel session;
  late MockFieldOrdersViewModel orders;

  setUp(() {
    session = MockFieldSessionViewModel();
    orders = MockFieldOrdersViewModel();
    stubFieldSessionViewModel(session);
    stubFieldOrdersViewModel(orders);
  });

  testWidgets('renders the listing and delivery form immediately',
      (tester) async {
    await pumpFieldScreen(
      tester,
      child: FieldPlaceOrderView(
        material: sampleListing(),
        initialAddress: 'Site A, Lahore',
        initialQuantity: 10,
      ),
      session: session,
      orders: orders,
    );

    expect(find.text('Place Order'), findsOneWidget);
    expect(find.text('Lucky Cement'), findsWidgets);
    expect(find.text('Enter full delivery address...'), findsOneWidget);
    expect(find.text('Select delivery date'), findsOneWidget);
  });

  testWidgets('Place Order calls placeOrderFromListing', (tester) async {
    await pumpFieldScreen(
      tester,
      child: FieldPlaceOrderView(
        material: sampleListing(),
        initialAddress: 'Site A, Lahore',
        initialQuantity: 10,
      ),
      session: session,
      orders: orders,
    );

    await tester.tap(find.text('Tap to choose a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Place Order —'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    verify(
      () => orders.placeOrderFromListing(
        companyId: 'co-1',
        fieldUserUid: 'field-1',
        fieldUserName: 'Hassan Field',
        fieldUserPhone: '03007654321',
        material: any(named: 'material'),
        quantity: 10,
        deliveryAddress: 'Site A, Lahore',
        requiredDate: any(named: 'requiredDate'),
        notes: any(named: 'notes'),
      ),
    ).called(1);
  });
}
