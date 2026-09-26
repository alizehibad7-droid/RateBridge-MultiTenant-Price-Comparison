import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/viewmodels/field_user/field_rating_viewmodel.dart';
import 'package:ratebridge/views/field_user/orders/field_rate_supplier_view.dart';
import 'package:ratebridge/views/field_user/widgets/field_async_states.dart';

import '../../mocks/mocks.dart';
import 'field_user_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerFieldUserWidgetFallbacks);

  late MockFieldSessionViewModel session;
  late MockFieldRatingViewModel rating;

  setUp(() {
    session = MockFieldSessionViewModel();
    rating = MockFieldRatingViewModel();
    stubFieldSessionViewModel(session);
    stubFieldRatingViewModel(rating);
  });

  testWidgets('shows a spinner while checking an existing rating',
      (tester) async {
    final hang = Completer<bool>();
    when(() => rating.hasUserRatedOrder(any(), any()))
        .thenAnswer((_) => hang.future);

    await pumpFieldScreen(
      tester,
      child: FieldRateSupplierView(order: sampleOrder(status: 'confirmed')),
      session: session,
      rating: rating,
      pumpPostFrame: false,
    );
    await tester.pump();

    expect(find.byType(FieldLoadingState), findsOneWidget);
    expect(find.text('Loading rating…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('blocks rating until delivery is confirmed', (tester) async {
    await pumpFieldScreen(
      tester,
      child: FieldRateSupplierView(order: sampleOrder(status: 'pending')),
      session: session,
      rating: rating,
    );
    await tester.pump();

    expect(
      find.text('You can rate the supplier after delivery has been confirmed.'),
      findsOneWidget,
    );
  });

  testWidgets('shows already-rated copy when the order was rated',
      (tester) async {
    when(() => rating.hasUserRatedOrder(any(), any()))
        .thenAnswer((_) async => true);

    await pumpFieldScreen(
      tester,
      child: FieldRateSupplierView(order: sampleOrder(status: 'confirmed')),
      session: session,
      rating: rating,
    );
    await tester.pump();

    expect(find.text("You've already rated this order"), findsOneWidget);
  });

  testWidgets('Submit rating calls submitRating on the ViewModel',
      (tester) async {
    await pumpFieldScreen(
      tester,
      child: FieldRateSupplierView(order: sampleOrder(status: 'confirmed')),
      session: session,
      rating: rating,
    );
    await tester.pump();

    expect(find.text('Skyline Materials'), findsOneWidget);
    expect(find.text('Lucky Cement'), findsWidgets);
    expect(find.text('Overall experience'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.star_outline_rounded).first);
    await tester.pump();
    await tester.tap(find.text('Submit rating'));
    await tester.pump();

    verify(
      () => rating.submitRating(
        orderId: 'order-001',
        companyId: 'co-1',
        rating: any(named: 'rating'),
      ),
    ).called(1);
  });
}
