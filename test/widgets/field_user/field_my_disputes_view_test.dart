import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/dispute_model.dart';
import 'package:ratebridge/views/field_user/orders/field_my_disputes_view.dart';
import 'package:ratebridge/views/field_user/profile/field_profile_view.dart';
import 'package:ratebridge/views/shared/dispute_record_detail_view.dart';

import '../../mocks/mocks.dart';
import 'field_user_widget_harness.dart';

DisputeModel _mine({
  String id = 'd-1',
  String status = 'open',
  String? notes,
  String? materialName,
}) {
  return DisputeModel(
    id: id,
    orderId: 'order-19818236',
    supplierId: 'sup-1',
    companyId: 'co-1',
    raisedByUid: 'field-1',
    raisedByRole: 'field_user',
    type: DisputeType.wrongMaterial,
    description:
        'A-grade red clay bricks were substituted with a lower grade lot.',
    status: status,
    resolutionNotes: notes,
    materialName: materialName,
    createdAt: DateTime.utc(2026, 4, 1),
    updatedAt: DateTime.utc(2026, 4, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerFieldUserWidgetFallbacks);

  late MockDisputeViewModel dispute;

  setUp(() {
    dispute = MockDisputeViewModel();
    when(() => dispute.isLoading).thenReturn(false);
    when(() => dispute.error).thenReturn(null);
    when(() => dispute.watchMyDisputes(any()))
        .thenAnswer((_) => Stream<List<DisputeModel>>.value(const []));
    when(() => dispute.watchDispute(any()))
        .thenAnswer((_) => Stream<DisputeModel?>.value(null));
  });

  testWidgets('profile lists a My Disputes shortcut', (tester) async {
    await pumpFieldScreen(
      tester,
      child: const FieldProfileView(),
      dispute: dispute,
    );
    await tester.pump();

    expect(find.text('My Disputes'), findsOneWidget);
  });

  testWidgets('shows empty copy when the user has no disputes', (tester) async {
    await pumpFieldScreen(
      tester,
      child: const FieldMyDisputesView(),
      dispute: dispute,
    );
    await tester.pump();

    expect(find.text('My Disputes'), findsWidgets);
    expect(find.text('No disputes yet'), findsOneWidget);
    verify(() => dispute.watchMyDisputes('field-1')).called(1);
  });

  testWidgets('renders type, excerpt, status, order, and date', (tester) async {
    when(() => dispute.watchMyDisputes(any())).thenAnswer(
      (_) => Stream<List<DisputeModel>>.value([_mine()]),
    );

    await pumpFieldScreen(
      tester,
      child: const FieldMyDisputesView(),
      dispute: dispute,
    );
    await tester.pump();

    expect(find.text('Wrong Material'), findsOneWidget);
    expect(
      find.textContaining('A-grade red clay bricks'),
      findsOneWidget,
    );
    expect(find.text('Open'), findsWidgets);
    expect(find.textContaining('Order #'), findsOneWidget);
    expect(find.text('Apr 01, 2026'), findsOneWidget);
  });

  testWidgets('tapping a dispute opens its detail route', (tester) async {
    when(() => dispute.watchMyDisputes(any())).thenAnswer(
      (_) => Stream<List<DisputeModel>>.value([_mine()]),
    );

    await pumpFieldScreen(
      tester,
      child: const FieldMyDisputesView(),
      dispute: dispute,
    );
    await tester.pump();

    await tester.tap(find.text('Wrong Material'));
    await tester.pumpAndSettle();

    expect(find.text('field-dispute-detail'), findsOneWidget);
  });

  testWidgets('resolved cards show resolution notes', (tester) async {
    when(() => dispute.watchMyDisputes(any())).thenAnswer(
      (_) => Stream<List<DisputeModel>>.value([
        _mine(status: 'resolved', notes: 'Replacement batch approved.'),
      ]),
    );

    await pumpFieldScreen(
      tester,
      child: const FieldMyDisputesView(),
      dispute: dispute,
    );
    await tester.pump();

    expect(find.text('Resolved'), findsWidgets);
    expect(find.text('Replacement batch approved.'), findsOneWidget);
  });

  testWidgets('Open tab hides resolved disputes', (tester) async {
    when(() => dispute.watchMyDisputes(any())).thenAnswer(
      (_) => Stream<List<DisputeModel>>.value([
        _mine(id: 'open-1'),
        _mine(id: 'res-1', status: 'resolved', notes: 'Closed'),
      ]),
    );

    await pumpFieldScreen(
      tester,
      child: const FieldMyDisputesView(),
      dispute: dispute,
    );
    await tester.pump();

    expect(find.text('Wrong Material'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Open'));
    await tester.pump();

    expect(find.text('Wrong Material'), findsOneWidget);
    expect(find.text('Closed'), findsNothing);
  });

  testWidgets('live stream updates replace the list', (tester) async {
    final controller = StreamController<List<DisputeModel>>();
    when(() => dispute.watchMyDisputes(any()))
        .thenAnswer((_) => controller.stream);

    await pumpFieldScreen(
      tester,
      child: const FieldMyDisputesView(),
      dispute: dispute,
    );

    controller.add([_mine()]);
    await tester.pump();
    expect(find.text('Open'), findsWidgets);

    controller.add([
      _mine(status: 'resolved', notes: 'Refund issued.'),
    ]);
    await tester.pump();
    expect(find.text('Resolved'), findsWidgets);
    expect(find.text('Refund issued.'), findsOneWidget);

    await controller.close();
  });

  testWidgets('dispute detail shows material, type, status, and notes',
      (tester) async {
    when(() => dispute.watchDispute(any())).thenAnswer(
      (_) => Stream<DisputeModel?>.value(
        _mine(
          status: 'resolved',
          notes: 'Replacement batch approved.',
          materialName: 'A-grade Red Clay Bricks',
        ),
      ),
    );

    await pumpFieldScreen(
      tester,
      child: const DisputeRecordDetailView(
        disputeId: 'd-1',
        audience: DisputeDetailAudience.field,
      ),
      dispute: dispute,
    );
    await tester.pump();

    expect(find.text('Wrong Material'), findsWidgets);
    expect(find.textContaining('A-grade Red Clay Bricks'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.textContaining('A-grade red clay bricks'), findsOneWidget);
    expect(find.text('Replacement batch approved.'), findsOneWidget);
  });
}
