import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/rfq_bid_model.dart';
import 'package:ratebridge/models/rfq_model.dart';
import 'package:ratebridge/views/ceo/rfq/rfq_detail_view.dart';

import '../../mocks/mocks.dart';
import 'ceo_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerCeoWidgetFallbacks);

  late MockCeoViewModel ceo;
  late MockRfqViewModel rfq;

  setUp(() {
    ceo = MockCeoViewModel();
    stubCeoViewModel(ceo);
    rfq = MockRfqViewModel();
    stubRfqViewModel(rfq);
  });

  testWidgets('shows a spinner while the RFQ is loading', (tester) async {
    final controller = StreamController<RfqModel?>();
    when(() => rfq.watchRfq(any())).thenAnswer((_) => controller.stream);

    await pumpCeoScreen(
      tester,
      child: const RfqDetailView(rfqId: 'rfq-1'),
      ceo: ceo,
      rfq: rfq,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await controller.close();
  });

  testWidgets('shows not-found copy when the RFQ is missing', (tester) async {
    await pumpCeoScreen(
      tester,
      child: const RfqDetailView(rfqId: 'rfq-1'),
      ceo: ceo,
      rfq: rfq,
    );
    await tester.pump();

    expect(find.text('RFQ not found'), findsOneWidget);
  });

  testWidgets('shows empty bids copy when no suppliers have bid',
      (tester) async {
    when(() => rfq.watchRfq(any())).thenAnswer(
      (_) => Stream<RfqModel?>.value(sampleRfq()),
    );

    await pumpCeoScreen(
      tester,
      child: const RfqDetailView(rfqId: 'rfq-1'),
      ceo: ceo,
      rfq: rfq,
    );
    await tester.pump();

    expect(find.text('OPC 53, 500 bags'), findsOneWidget);
    expect(find.text('Waiting for bids...'), findsOneWidget);
  });

  testWidgets('renders a bid and AWARD calls awardRfq', (tester) async {
    final openRfq = sampleRfq();
    final bid = sampleBid();
    when(() => rfq.watchRfq(any()))
        .thenAnswer((_) => Stream<RfqModel?>.value(openRfq));
    when(() => rfq.watchRfqBids(any()))
        .thenAnswer((_) => Stream<List<RfqBidModel>>.value([bid]));

    await pumpCeoScreen(
      tester,
      child: const RfqDetailView(rfqId: 'rfq-1'),
      ceo: ceo,
      rfq: rfq,
    );
    await tester.pump();

    expect(find.text('Cement House'), findsOneWidget);

    await tapVisible(tester, find.text('AWARD CONTRACT'));
    await tester.pump();
    await tapVisible(tester, find.text('AWARD'));
    await tester.pump();

    verify(
      () => rfq.awardRfq(rfq: openRfq, bid: bid, ceoUid: 'ceo-1'),
    ).called(1);
  });
}
