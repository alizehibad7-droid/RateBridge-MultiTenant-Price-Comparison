import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/views/auth/role_selection_view.dart';

import '../../mocks/mocks.dart';
import 'auth_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAuthWidgetFallbacks);

  late MockAuthViewModel auth;

  setUp(() {
    auth = MockAuthViewModel();
    stubAuthViewModel(auth);
  });

  testWidgets('renders the three role options', (tester) async {
    await pumpAuthScreen(
      tester,
      child: const RoleSelectionView(),
      auth: auth,
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to RateBridge'), findsOneWidget);
    expect(find.text('Material Supplier'), findsOneWidget);
    expect(find.text('Company / CEO'), findsOneWidget);
    expect(find.text('Field Employee'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('tapping Material Supplier opens supplier registration',
      (tester) async {
    await pumpAuthScreen(
      tester,
      child: const RoleSelectionView(),
      auth: auth,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Material Supplier'));
    await tester.pumpAndSettle();

    expect(find.text('supplier-reg'), findsOneWidget);
  });

  testWidgets('tapping Company / CEO opens CEO registration', (tester) async {
    await pumpAuthScreen(
      tester,
      child: const RoleSelectionView(),
      auth: auth,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Company / CEO'));
    await tester.pumpAndSettle();

    expect(find.text('ceo-reg'), findsOneWidget);
  });

  testWidgets('tapping Field Employee opens field-user registration',
      (tester) async {
    await pumpAuthScreen(
      tester,
      child: const RoleSelectionView(),
      auth: auth,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Field Employee'));
    await tester.pumpAndSettle();

    expect(find.text('field-reg'), findsOneWidget);
  });

  testWidgets('tapping Sign In opens the login screen', (tester) async {
    await pumpAuthScreen(
      tester,
      child: const RoleSelectionView(),
      auth: auth,
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('login-screen'), findsOneWidget);
  });
}
