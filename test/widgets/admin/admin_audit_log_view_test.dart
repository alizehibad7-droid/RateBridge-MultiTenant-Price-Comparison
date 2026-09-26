import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/audit_log_model.dart';
import 'package:ratebridge/views/admin/admin_audit_log_view.dart';

import '../../mocks/mocks.dart';
import 'admin_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAdminWidgetFallbacks);

  late MockAdminViewModel admin;
  late MockFirestoreService firestore;

  setUp(() {
    admin = MockAdminViewModel();
    stubAdminViewModel(admin);
    firestore = MockFirestoreService();
    when(() => firestore.streamAuditLogs())
        .thenAnswer((_) => Stream<List<AuditLogModel>>.value(const []));
    when(
      () => firestore.getSupplierStats(
        any(),
        companyId: any(named: 'companyId'),
      ),
    ).thenAnswer((_) async => {'totalFulfilled': 0, 'onTimeRate': 0.0});
    when(
      () => firestore.getSupplierDisputeCount(
        any(),
        companyId: any(named: 'companyId'),
      ),
    ).thenAnswer((_) async => 0);
  });

  testWidgets('shows a spinner while the activity log is loading',
      (tester) async {
    final controller = StreamController<List<AuditLogModel>>();
    when(() => firestore.streamAuditLogs())
        .thenAnswer((_) => controller.stream);

    await pumpAdminScreen(
      tester,
      child: const AdminAuditLogView(),
      admin: admin,
      firestore: firestore,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await controller.close();
  });

  testWidgets('shows error copy when the activity log stream fails',
      (tester) async {
    when(() => firestore.streamAuditLogs()).thenAnswer(
      (_) => Stream<List<AuditLogModel>>.error('unavailable'),
    );

    await pumpAdminScreen(
      tester,
      child: const AdminAuditLogView(),
      admin: admin,
      firestore: firestore,
    );
    await tester.pump();

    expect(find.textContaining('Could not load activity log'), findsOneWidget);
  });

  testWidgets('shows empty copy when there is no activity', (tester) async {
    await pumpAdminScreen(
      tester,
      child: const AdminAuditLogView(),
      admin: admin,
      firestore: firestore,
    );
    await tester.pump();

    expect(find.text('No activity recorded yet'), findsOneWidget);
  });

  testWidgets('renders audit log entries', (tester) async {
    when(() => firestore.streamAuditLogs()).thenAnswer(
      (_) => Stream<List<AuditLogModel>>.value([sampleAuditLog()]),
    );

    await pumpAdminScreen(
      tester,
      child: const AdminAuditLogView(),
      admin: admin,
      firestore: firestore,
    );
    await tester.pump();

    expect(find.text('Approved CEO Ali Khan'), findsOneWidget);
    expect(find.text('By Platform Admin'), findsOneWidget);
  });
}
