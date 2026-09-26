import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/supplier/supplier_chat_view.dart';

import '../../mocks/mocks.dart';
import 'supplier_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerSupplierWidgetFallbacks);

  late MockSupplierViewModel supplier;
  late MockChatViewModel chat;

  setUp(() {
    supplier = MockSupplierViewModel();
    stubSupplierViewModel(supplier);
    chat = MockChatViewModel();
    stubChatViewModel(chat);
  });

  testWidgets('shows a spinner while threads are loading', (tester) async {
    when(() => chat.isLoading).thenReturn(true);
    when(() => chat.threads).thenReturn(const []);

    await pumpSupplierScreen(
      tester,
      child: const SupplierChatView(),
      supplier: supplier,
      chat: chat,
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verify(() => chat.watchSupplierThreads('sup-1')).called(greaterThanOrEqualTo(1));
  });

  testWidgets('shows error copy and Retry reloads threads', (tester) async {
    when(() => chat.errorMessage).thenReturn('offline');
    when(() => chat.threads).thenReturn(const []);

    await pumpSupplierScreen(
      tester,
      child: const SupplierChatView(),
      supplier: supplier,
      chat: chat,
    );
    await tester.pump();

    expect(find.text('offline'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(() => chat.watchSupplierThreads('sup-1')).called(greaterThanOrEqualTo(2));
  });

  testWidgets('shows empty copy when there are no threads', (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierChatView(),
      supplier: supplier,
      chat: chat,
    );
    await tester.pump();

    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('renders thread previews from ChatViewModel', (tester) async {
    when(() => chat.threads).thenReturn([
      sampleThread(lastMessage: 'Need 50 more bags tomorrow.'),
    ]);

    await pumpSupplierScreen(
      tester,
      child: const SupplierChatView(),
      supplier: supplier,
      chat: chat,
    );
    await tester.pump();

    expect(find.text('Hassan Field'), findsOneWidget);
    expect(find.text('Need 50 more bags tomorrow.'), findsOneWidget);
  });
}
