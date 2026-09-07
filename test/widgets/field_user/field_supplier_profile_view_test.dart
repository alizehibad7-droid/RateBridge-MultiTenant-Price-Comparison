import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/field_user/suppliers/field_supplier_profile_view.dart';
import 'package:ratebridge/views/field_user/widgets/field_async_states.dart';

import '../../mocks/mocks.dart';
import 'field_user_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerFieldUserWidgetFallbacks);

  late MockFieldSessionViewModel session;
  late MockFieldSupplierProfileViewModel profile;

  setUp(() {
    session = MockFieldSessionViewModel();
    profile = MockFieldSupplierProfileViewModel();
    stubFieldSessionViewModel(session);
    stubFieldSupplierProfileViewModel(profile);
  });

  testWidgets('shows a spinner while the supplier is loading', (tester) async {
    final hang = Completer<void>();
    when(() => profile.isLoading).thenReturn(true);
    when(() => profile.load(any(), any())).thenAnswer((_) => hang.future);

    await pumpFieldScreen(
      tester,
      child: const FieldSupplierProfileView(supplierUid: 'sup-1'),
      session: session,
      supplierProfile: profile,
      pumpPostFrame: false,
    );
    await tester.pump();

    expect(find.byType(FieldLoadingState), findsOneWidget);
    expect(find.text('Loading supplier…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows an error and Retry reloads the supplier', (tester) async {
    when(() => profile.errorMessage).thenReturn('offline');

    await pumpFieldScreen(
      tester,
      child: const FieldSupplierProfileView(supplierUid: 'sup-1'),
      session: session,
      supplierProfile: profile,
    );
    await tester.pump();

    expect(find.byType(FieldErrorState), findsOneWidget);
    expect(find.text('Could not load supplier'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(() => profile.load('co-1', 'sup-1')).called(greaterThan(1));
  });

  testWidgets('renders supplier materials and reviews', (tester) async {
    when(() => profile.supplier).thenReturn(sampleSupplier());
    when(() => profile.materials).thenReturn([sampleMaterial()]);
    when(() => profile.recentRatings).thenReturn([sampleRating()]);
    when(() => profile.ratingCount).thenReturn(1);
    when(() => profile.averageRating).thenReturn(4.5);

    await pumpFieldScreen(
      tester,
      child: const FieldSupplierProfileView(supplierUid: 'sup-1'),
      session: session,
      supplierProfile: profile,
    );
    await tester.pump();

    expect(find.text('Skyline Materials'), findsWidgets);
    expect(find.text('Lucky Cement'), findsOneWidget);
    expect(find.text('Bags arrived in good condition.'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    verify(() => profile.load('co-1', 'sup-1')).called(1);
  });
}
