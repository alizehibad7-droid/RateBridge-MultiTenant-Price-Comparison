import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/field_user/profile/field_profile_view.dart';
import 'package:ratebridge/views/field_user/widgets/field_async_states.dart';

import '../../mocks/mocks.dart';
import 'field_user_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerFieldUserWidgetFallbacks);

  late MockFieldSessionViewModel session;
  late MockAuthViewModel auth;
  late MockFieldOrdersViewModel orders;

  setUp(() {
    session = MockFieldSessionViewModel();
    auth = MockAuthViewModel();
    orders = MockFieldOrdersViewModel();
    stubFieldSessionViewModel(session);
    stubAuthViewModel(auth, user: fieldUser());
    stubFieldOrdersViewModel(orders);
  });

  testWidgets('shows a spinner when the profile user is not ready',
      (tester) async {
    when(() => session.user).thenReturn(null);

    await pumpFieldScreen(
      tester,
      child: const FieldProfileView(),
      session: session,
      auth: auth,
      orders: orders,
    );

    expect(find.byType(FieldLoadingState), findsOneWidget);
    expect(find.text('Loading profile…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verify(() => session.refreshProfile()).called(1);
  });

  testWidgets('renders the signed-in field user', (tester) async {
    await pumpFieldScreen(
      tester,
      child: const FieldProfileView(),
      session: session,
      auth: auth,
      orders: orders,
    );
    await tester.pump();

    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Hassan Field'), findsWidgets);
    expect(find.text('Acme Builders'), findsWidgets);
    expect(find.text('Sign Out'), findsOneWidget);
  });

  testWidgets('Save calls updateProfile on the session ViewModel',
      (tester) async {
    await pumpFieldScreen(
      tester,
      child: const FieldProfileView(),
      session: session,
      auth: auth,
      orders: orders,
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();

    verify(
      () => session.updateProfile(
        name: 'Hassan Field',
        phone: '03007654321',
      ),
    ).called(1);
  });

  testWidgets('Sign Out confirms and calls auth.signOut', (tester) async {
    await pumpFieldScreen(
      tester,
      child: const FieldProfileView(),
      session: session,
      auth: auth,
      orders: orders,
    );
    await tester.pump();

    await tapVisible(tester, find.text('Sign Out'));
    await tester.pump();
    await tester.tap(find.text('Sign out'));
    await tester.pump();

    verify(() => auth.signOut()).called(1);
  });
}
