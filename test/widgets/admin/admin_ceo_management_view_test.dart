import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/admin/admin_ceo_management_view.dart';

import '../../mocks/mocks.dart';
import 'admin_widget_harness.dart';

Future<FakeFirebaseFirestore> _seedPendingCeo() async {
  final fake = FakeFirebaseFirestore();
  await fake.collection('users').doc('ceo-1').set({
    'uid': 'ceo-1',
    'email': 'ceo@acme.test',
    'name': 'Ali CEO',
    'role': 'CEO',
    'companyId': 'co-1',
    'phone': '03001234567',
    'city': 'Lahore',
    'status': 'pending',
    'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
  });
  await fake.collection('companies').doc('co-1').set({
    'id': 'co-1',
    'name': 'Acme Builders',
    'registrationNumber': 'NTN-1',
    'address': 'Lahore',
    'status': 'pending',
    'ceoUid': 'ceo-1',
    'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
  });
  return fake;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAdminWidgetFallbacks);

  late MockAdminViewModel admin;

  setUp(() {
    admin = MockAdminViewModel();
    stubAdminViewModel(admin);
  });

  testWidgets('shows empty copy when no pending CEOs exist', (tester) async {
    await pumpAdminScreen(
      tester,
      child: AdminCeoManagementView(debugFirestore: FakeFirebaseFirestore()),
      admin: admin,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('CEO Management'), findsOneWidget);
    expect(find.text('No pending CEOs found.'), findsOneWidget);
  });

  testWidgets('renders a pending CEO card from Firestore', (tester) async {
    final fake = await _seedPendingCeo();

    await pumpAdminScreen(
      tester,
      child: AdminCeoManagementView(debugFirestore: fake),
      admin: admin,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Ali CEO'), findsWidgets);
    expect(find.text('ceo@acme.test'), findsOneWidget);
    expect(find.text('Acme Builders'), findsWidgets);
    expect(find.text('Approve'), findsOneWidget);
  });

  testWidgets('Approve confirms and calls acceptCEO', (tester) async {
    final fake = await _seedPendingCeo();

    await pumpAdminScreen(
      tester,
      child: AdminCeoManagementView(debugFirestore: fake),
      admin: admin,
    );
    await tester.pump();
    await tester.pump();

    await tapVisible(tester, find.text('Approve'));
    await tester.pump();
    await tapVisible(tester, find.text('CONFIRM'));
    await tester.pump();

    verify(() => admin.acceptCEO('co-1', 'ceo-1')).called(1);
  });
}
