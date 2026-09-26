import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/user_model.dart';
import 'package:ratebridge/views/ceo/ceo_field_users_view.dart';

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

  testWidgets('shows a spinner while field users are loading', (tester) async {
    final controller = StreamController<List<UserModel>>();
    when(() => ceo.watchFieldUsers(any(), any()))
        .thenAnswer((_) => controller.stream);

    await pumpCeoScreen(
      tester,
      child: const CeoFieldUsersView(),
      ceo: ceo,
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await controller.close();
  });

  testWidgets('shows empty copy when there are no pending field users',
      (tester) async {
    await pumpCeoScreen(
      tester,
      child: const CeoFieldUsersView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(find.text('No pending field users found'), findsOneWidget);
  });

  testWidgets('renders a pending user and Approve calls approveFieldUser',
      (tester) async {
    when(() => ceo.watchFieldUsers(any(), any())).thenAnswer((invocation) {
      final filter = invocation.positionalArguments[1] as String;
      if (filter == 'pending') {
        return Stream<List<UserModel>>.value([sampleFieldUser()]);
      }
      return Stream<List<UserModel>>.value(const []);
    });

    await pumpCeoScreen(
      tester,
      child: const CeoFieldUsersView(),
      ceo: ceo,
    );
    await tester.pump();

    expect(find.text('Hassan Field'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);

    await tapVisible(tester, find.text('Approve'));
    await tester.pump();

    verify(() => ceo.approveFieldUser('field-1')).called(1);
  });
}
