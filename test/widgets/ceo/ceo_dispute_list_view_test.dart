import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/dispute_model.dart';
import 'package:ratebridge/views/ceo/ceo_dispute_list_view.dart';

import '../../mocks/mocks.dart';
import 'ceo_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerCeoWidgetFallbacks);

  late MockCeoViewModel ceo;
  late MockDisputeViewModel dispute;

  setUp(() {
    ceo = MockCeoViewModel();
    stubCeoViewModel(ceo);
    dispute = MockDisputeViewModel();
    stubDisputeViewModel(dispute);
  });

  testWidgets('shows a spinner when the company id is missing', (tester) async {
    when(() => ceo.company).thenReturn(null);
    final auth = MockAuthViewModel();
    stubAuthViewModel(auth, user: ceoUser().copyWith(companyId: ''));
    when(() => auth.companyId).thenReturn('');

    await pumpCeoScreen(
      tester,
      child: const CeoDisputeListView(),
      ceo: ceo,
      auth: auth,
      dispute: dispute,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows a spinner while disputes are loading', (tester) async {
    final controller = StreamController<List<DisputeModel>>();
    when(() => dispute.watchCompanyDisputes(any()))
        .thenAnswer((_) => controller.stream);

    await pumpCeoScreen(
      tester,
      child: const CeoDisputeListView(),
      ceo: ceo,
      dispute: dispute,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await controller.close();
  });

  testWidgets('shows error copy when the disputes stream fails', (tester) async {
    when(() => dispute.watchCompanyDisputes(any())).thenAnswer(
      (_) => Stream<List<DisputeModel>>.error('permission-denied'),
    );

    await pumpCeoScreen(
      tester,
      child: const CeoDisputeListView(),
      ceo: ceo,
      dispute: dispute,
    );
    await tester.pump();

    expect(find.textContaining('Could not load reported issues'), findsOneWidget);
  });

  testWidgets('shows empty copy when there are no disputes', (tester) async {
    await pumpCeoScreen(
      tester,
      child: const CeoDisputeListView(),
      ceo: ceo,
      dispute: dispute,
    );
    await tester.pump();

    expect(find.text('No active issues'), findsOneWidget);
  });

  testWidgets('renders a dispute card from the company stream', (tester) async {
    when(() => dispute.watchCompanyDisputes(any())).thenAnswer(
      (_) => Stream<List<DisputeModel>>.value([sampleDispute()]),
    );

    await pumpCeoScreen(
      tester,
      child: const CeoDisputeListView(),
      ceo: ceo,
      dispute: dispute,
    );
    await tester.pump();

    expect(find.text('Wrong Material'), findsOneWidget);
    expect(find.text('Bags arrived wet.'), findsOneWidget);
    expect(find.text('OPEN'), findsOneWidget);
  });

  testWidgets('tapping a dispute opens CEO dispute detail', (tester) async {
    when(() => dispute.watchCompanyDisputes(any())).thenAnswer(
      (_) => Stream<List<DisputeModel>>.value([sampleDispute()]),
    );

    await pumpCeoScreen(
      tester,
      child: const CeoDisputeListView(),
      ceo: ceo,
      dispute: dispute,
    );
    await tester.pump();

    await tester.tap(find.text('Wrong Material'));
    await tester.pumpAndSettle();

    expect(find.text('ceo-dispute-detail'), findsOneWidget);
  });

  testWidgets('company stream reflects resolved and rejected statuses',
      (tester) async {
    when(() => dispute.watchCompanyDisputes(any())).thenAnswer(
      (_) => Stream<List<DisputeModel>>.value([
        sampleDispute(id: 'd-res', status: 'resolved'),
        sampleDispute(id: 'd-rej', status: 'rejected'),
      ]),
    );

    await pumpCeoScreen(
      tester,
      child: const CeoDisputeListView(),
      ceo: ceo,
      dispute: dispute,
    );
    await tester.pump();

    expect(find.text('RESOLVED'), findsOneWidget);
    expect(find.text('REJECTED'), findsOneWidget);
  });
}
