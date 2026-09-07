import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/supplier/supplier_chat_thread_view.dart';

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

  testWidgets('shows a spinner while messages are loading', (tester) async {
    when(() => chat.isLoadingMessages).thenReturn(true);

    await pumpSupplierScreen(
      tester,
      child: SupplierChatThreadView(thread: sampleThread()),
      supplier: supplier,
      chat: chat,
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verify(
      () => chat.startListening('chat-1', currentUserId: 'sup-1'),
    ).called(1);
  });

  testWidgets('shows empty copy when the thread has no messages',
      (tester) async {
    await pumpSupplierScreen(
      tester,
      child: SupplierChatThreadView(thread: sampleThread()),
      supplier: supplier,
      chat: chat,
    );
    await tester.pump();

    expect(find.text('No messages yet. Say hello!'), findsOneWidget);
    expect(find.text('Hassan Field'), findsOneWidget);
  });

  testWidgets('renders messages and send calls sendMessage', (tester) async {
    when(() => chat.messages).thenReturn([
      sampleMessage(content: 'Need 50 more bags tomorrow.'),
    ]);

    await pumpSupplierScreen(
      tester,
      child: SupplierChatThreadView(thread: sampleThread()),
      supplier: supplier,
      chat: chat,
    );
    await tester.pump();

    expect(find.text('Need 50 more bags tomorrow.'), findsOneWidget);

    await tester.enterText(
      textFieldByHint('Type a message...'),
      'On the way.',
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    verify(
      () => chat.sendMessage(
        'chat-1',
        'On the way.',
        'sup-1',
        'Skyline Materials',
        'field-1',
        'co-1',
        any(),
      ),
    ).called(1);
  });

  testWidgets('keeps the composer on the scaffold bottom bar while scrolling',
      (tester) async {
    when(() => chat.messages).thenReturn([
      sampleMessage(content: 'Need 50 more bags tomorrow.'),
    ]);

    await pumpSupplierScreen(
      tester,
      surfaceSize: const Size(400, 800),
      child: SupplierChatThreadView(thread: sampleThread()),
      supplier: supplier,
      chat: chat,
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(scaffold.resizeToAvoidBottomInset, isTrue);
    expect(scaffold.bottomNavigationBar, isNotNull);

    final before = tester.getRect(textFieldByHint('Type a message...'));
    await tester.drag(find.byType(ListView), const Offset(0, 80));
    await tester.pump();
    expect(
      tester.getRect(textFieldByHint('Type a message...')).bottom,
      closeTo(before.bottom, 0.5),
    );
    expect(find.text('Need 50 more bags tomorrow.'), findsOneWidget);
  });
}
