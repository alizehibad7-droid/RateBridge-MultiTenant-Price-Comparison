import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/field_user/chat/field_chat_list_view.dart';
import 'package:ratebridge/views/field_user/widgets/field_async_states.dart';
import 'package:ratebridge/views/field_user/widgets/field_chat_list_skeleton.dart';
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

  testWidgets('shows a skeleton while conversations are loading',
      (tester) async {
    when(() => chat.isLoadingThreads).thenReturn(true);

    await pumpFieldScreen(
      tester,
      child: const FieldChatListView(),
      session: session,
      chat: chat,
    );
    await tester.pump();

    expect(find.byType(FieldChatListSkeleton), findsOneWidget);
    expect(find.byType(Shimmer), findsWidgets);
    expect(find.text('Messages'), findsOneWidget);
    verify(() => chat.watchConversations('co-1', 'field-1')).called(1);
  });

  testWidgets('shows an error and Retry starts watching again', (tester) async {
    when(() => chat.errorMessage).thenReturn('offline');

    await pumpFieldScreen(
      tester,
      child: const FieldChatListView(),
      session: session,
      chat: chat,
    );
    await tester.pump();

    expect(find.byType(FieldErrorState), findsOneWidget);
    expect(find.text('Could not load messages'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(() => chat.watchConversations('co-1', 'field-1'))
        .called(greaterThan(1));
  });

  testWidgets('shows empty copy when there are no conversations',
      (tester) async {
    await pumpFieldScreen(
      tester,
      child: const FieldChatListView(),
      session: session,
      chat: chat,
    );
    await tester.pump();

    expect(find.text('No conversations yet'), findsOneWidget);
  });

  testWidgets('renders conversation previews from the ViewModel',
      (tester) async {
    when(() => chat.threads).thenReturn([
      sampleThread(lastMessage: 'Need 50 more bags tomorrow.'),
    ]);

    await pumpFieldScreen(
      tester,
      child: const FieldChatListView(),
      session: session,
      chat: chat,
    );
    await tester.pump();

    expect(find.text('Skyline Materials'), findsOneWidget);
    expect(find.text('Need 50 more bags tomorrow.'), findsOneWidget);
  });
}
