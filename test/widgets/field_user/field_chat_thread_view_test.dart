import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/field_user/chat/field_chat_thread_view.dart';
import 'package:ratebridge/views/field_user/widgets/field_async_states.dart';
import 'package:shimmer/shimmer.dart';

import '../../mocks/mocks.dart';
import 'field_user_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerFieldUserWidgetFallbacks);

  late MockFieldSessionViewModel session;
  late MockFieldChatViewModel chat;

  setUp(() {
    session = MockFieldSessionViewModel();
    chat = MockFieldChatViewModel();
    stubFieldSessionViewModel(session);
    stubFieldChatViewModel(chat);
  });

  testWidgets('shows a skeleton while messages are loading', (tester) async {
    final hang = Completer<void>();
    when(() => chat.isLoadingMessages).thenReturn(true);
    when(
      () => chat.openThread(
        companyId: any(named: 'companyId'),
        fieldUserId: any(named: 'fieldUserId'),
        fieldUserName: any(named: 'fieldUserName'),
        supplierId: any(named: 'supplierId'),
        supplierName: any(named: 'supplierName'),
      ),
    ).thenAnswer((_) => hang.future);

    await pumpFieldScreen(
      tester,
      child: const FieldChatThreadView(
        supplierUid: 'sup-1',
        supplierName: 'Skyline Materials',
      ),
      session: session,
      chat: chat,
    );
    await tester.pump();

    expect(find.byType(FieldChatThreadSkeleton), findsOneWidget);
    expect(find.byType(Shimmer), findsWidgets);
    expect(find.text('Skyline Materials'), findsOneWidget);
    verify(
      () => chat.openThread(
        companyId: 'co-1',
        fieldUserId: 'field-1',
        fieldUserName: 'Hassan Field',
        supplierId: 'sup-1',
        supplierName: 'Skyline Materials',
      ),
    ).called(1);
  });

  testWidgets('shows an error and Retry opens the thread again',
      (tester) async {
    when(() => chat.errorMessage).thenReturn('offline');

    await pumpFieldScreen(
      tester,
      child: const FieldChatThreadView(
        supplierUid: 'sup-1',
        supplierName: 'Skyline Materials',
      ),
      session: session,
      chat: chat,
    );
    await tester.pump();

    expect(find.byType(FieldErrorState), findsOneWidget);
    expect(find.text('Could not load messages'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(
      () => chat.openThread(
        companyId: 'co-1',
        fieldUserId: 'field-1',
        fieldUserName: 'Hassan Field',
        supplierId: 'sup-1',
        supplierName: 'Skyline Materials',
      ),
    ).called(greaterThan(1));
  });

  testWidgets('shows empty copy when the thread has no messages',
      (tester) async {
    await pumpFieldScreen(
      tester,
      child: const FieldChatThreadView(
        supplierUid: 'sup-1',
        supplierName: 'Skyline Materials',
      ),
      session: session,
      chat: chat,
    );
    await tester.pump();

    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.text('Type a message…'), findsOneWidget);
  });

  testWidgets('renders messages and send calls sendMessage', (tester) async {
    when(() => chat.messages).thenReturn([
      sampleMessage(content: 'Need 50 more bags tomorrow.'),
    ]);

    await pumpFieldScreen(
      tester,
      child: const FieldChatThreadView(
        supplierUid: 'sup-1',
        supplierName: 'Skyline Materials',
      ),
      session: session,
      chat: chat,
    );
    await tester.pump();

    expect(find.text('Need 50 more bags tomorrow.'), findsOneWidget);

    await tester.enterText(
      textFieldByHint('Type a message…'),
      'On the way.',
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    verify(
      () => chat.sendMessage(
        companyId: 'co-1',
        fieldUserId: 'field-1',
        fieldUserName: 'Hassan Field',
        supplierId: 'sup-1',
        supplierName: 'Skyline Materials',
        content: 'On the way.',
        attachmentUrl: any(named: 'attachmentUrl'),
      ),
    ).called(1);
  });

  testWidgets('keeps the composer on the scaffold bottom bar while scrolling',
      (tester) async {
    when(() => chat.messages).thenReturn([
      sampleMessage(content: 'Need 50 more bags tomorrow.'),
    ]);

    await pumpFieldScreen(
      tester,
      surfaceSize: const Size(400, 800),
      child: const FieldChatThreadView(
        supplierUid: 'sup-1',
        supplierName: 'Skyline Materials',
      ),
      session: session,
      chat: chat,
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(scaffold.resizeToAvoidBottomInset, isTrue);
    expect(scaffold.bottomNavigationBar, isNotNull);

    final before = tester.getRect(textFieldByHint('Type a message…'));
    await tester.drag(find.byType(ListView), const Offset(0, 80));
    await tester.pump();
    expect(
      tester.getRect(textFieldByHint('Type a message…')).bottom,
      closeTo(before.bottom, 0.5),
    );
    expect(find.text('Need 50 more bags tomorrow.'), findsOneWidget);
  });
}
