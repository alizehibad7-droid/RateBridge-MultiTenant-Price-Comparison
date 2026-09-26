import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/admin/admin_dashboard_view.dart';

import '../../mocks/mocks.dart';
import 'admin_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAdminWidgetFallbacks);

  late MockAdminViewModel admin;
  late FakeFirebaseFirestore fake;

  setUp(() {
    admin = MockAdminViewModel();
    stubAdminViewModel(admin);
    fake = FakeFirebaseFirestore();
  });

  testWidgets('shows a loading bar when AdminViewModel is loading',
      (tester) async {
    when(() => admin.isLoading).thenReturn(true);

    await pumpAdminScreen(
      tester,
      child: AdminDashboardView(debugFirestore: fake),
      admin: admin,
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('renders zero counts while user streams have no data',
      (tester) async {
    await pumpAdminScreen(
      tester,
      child: AdminDashboardView(debugFirestore: fake),
      admin: admin,
    );
    await tester.pump();

    expect(find.text('Pending'), findsWidgets);
    expect(find.text('0'), findsWidgets);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Revenue'), findsOneWidget);
  });

  testWidgets('renders live user counts from AdminViewModel streams',
      (tester) async {
    when(() => admin.watchPendingUsersCount())
        .thenAnswer((_) => Stream<int>.value(4));
    when(() => admin.watchActiveUsersCount())
        .thenAnswer((_) => Stream<int>.value(12));
    when(() => admin.watchSuspendedUsersCount())
        .thenAnswer((_) => Stream<int>.value(2));

    await pumpAdminScreen(
      tester,
      child: AdminDashboardView(debugFirestore: fake),
      admin: admin,
    );
    await tester.pump();

    expect(find.text('4'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('Review CEOs switches to the CEOs tab', (tester) async {
    await pumpAdminScreen(
      tester,
      child: AdminDashboardView(debugFirestore: fake),
      admin: admin,
    );
    await tester.pump();

    await tapVisible(tester, find.text('Review CEOs'));
    await tester.pump();

    expect(find.text('Pending'), findsWidgets);
    expect(find.text('No pending CEOs found.'), findsOneWidget);
  });

  testWidgets('Sign Out confirms and calls AuthViewModel.signOut',
      (tester) async {
    final auth = MockAuthViewModel();
    stubAuthViewModel(auth);

    await pumpAdminScreen(
      tester,
      child: AdminDashboardView(debugFirestore: fake),
      admin: admin,
      auth: auth,
    );
    await tester.pump();

    await tapVisible(tester, find.text('Profile'));
    await tester.pump();

    expect(find.text('Language'), findsNothing);
    expect(find.text('My Profile'), findsWidgets);
    expect(find.text('Account Settings'), findsOneWidget);

    await tapVisible(tester, find.text('Sign Out'));
    await tester.pump();
    await tapVisible(tester, find.text('Sign out'));
    await tester.pump();

    verify(() => auth.signOut()).called(1);
  });
}
