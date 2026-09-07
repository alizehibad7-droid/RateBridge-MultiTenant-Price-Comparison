import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/dispute_model.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/views/admin/admin_dispute_list_view.dart';

import '../../mocks/mocks.dart';
import 'admin_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAdminWidgetFallbacks);

  late MockAdminViewModel admin;
  late MockDisputeViewModel dispute;

  setUp(() {
    admin = MockAdminViewModel();
    stubAdminViewModel(admin);
    dispute = MockDisputeViewModel();
    stubDisputeViewModel(dispute);
  });

  testWidgets('shows a spinner while disputes are loading', (tester) async {
    final controller = StreamController<List<DisputeModel>>();
    when(() => dispute.watchAllDisputes(status: any(named: 'status')))
        .thenAnswer((_) => controller.stream);

    await pumpAdminScreen(
      tester,
      child: const AdminDisputeListView(),
      admin: admin,
      dispute: dispute,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await controller.close();
  });

  testWidgets('shows error copy when the disputes stream fails', (tester) async {
    when(() => dispute.watchAllDisputes(status: any(named: 'status')))
        .thenAnswer((_) => Stream<List<DisputeModel>>.error('permission-denied'));

    await pumpAdminScreen(
      tester,
      child: const AdminDisputeListView(),
      admin: admin,
      dispute: dispute,
    );
    await tester.pump();

    expect(find.textContaining('Could not load disputes'), findsOneWidget);
  });

  testWidgets('shows empty copy when there are no disputes', (tester) async {
    await pumpAdminScreen(
      tester,
      child: const AdminDisputeListView(),
      admin: admin,
      dispute: dispute,
    );
    await tester.pump();

    expect(find.text('No disputes found'), findsOneWidget);
  });

  testWidgets('renders a dispute tile and SAVE RESOLUTION calls resolveDispute',
      (tester) async {
    when(() => dispute.watchAllDisputes(status: any(named: 'status')))
        .thenAnswer(
      (_) => Stream<List<DisputeModel>>.value([sampleDispute()]),
    );

    await pumpAdminScreen(
      tester,
      child: const AdminDisputeListView(),
      admin: admin,
      dispute: dispute,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Wrong Material'), findsOneWidget);
    expect(find.text('OPEN'), findsOneWidget);

    await tapVisible(tester, find.text('Wrong Material'));
    await tester.pump();

    expect(find.text('Review Dispute'), findsOneWidget);
    await tapVisible(tester, find.text('SAVE RESOLUTION'));
    await tester.pump();

    verify(
      () => dispute.resolveDispute(
        'd-1',
        'under_review',
        '',
        adminUid: 'admin-1',
        raisedByUid: 'field-1',
        raisedByRole: 'field_user',
        orderId: 'order-001',
        companyId: 'co-1',
      ),
    ).called(1);
  });

  testWidgets('failed resolve shows the backend error and keeps the dialog',
      (tester) async {
    when(() => dispute.watchAllDisputes(status: any(named: 'status')))
        .thenAnswer(
      (_) => Stream<List<DisputeModel>>.value([sampleDispute()]),
    );
    when(
      () => dispute.resolveDispute(
        any(),
        any(),
        any(),
        adminUid: any(named: 'adminUid'),
        raisedByUid: any(named: 'raisedByUid'),
        raisedByRole: any(named: 'raisedByRole'),
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
      ),
    ).thenThrow(AppException('Dispute not found.'));

    await pumpAdminScreen(
      tester,
      child: const AdminDisputeListView(),
      admin: admin,
      dispute: dispute,
    );
    await tester.pump();
    await tester.pump();

    await tapVisible(tester, find.text('Wrong Material'));
    await tester.pump();
    await tapVisible(tester, find.text('SAVE RESOLUTION'));
    await tester.pump();

    expect(find.text('Review Dispute'), findsOneWidget);
    expect(find.text('Error: Dispute not found.'), findsOneWidget);
    expect(find.text('SAVE RESOLUTION'), findsOneWidget);
  });
}
