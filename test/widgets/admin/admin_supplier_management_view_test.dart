import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/admin/admin_supplier_management_view.dart';

import '../../mocks/mocks.dart';
import 'admin_widget_harness.dart';

Future<FakeFirebaseFirestore> _seedPendingSupplier() async {
  final fake = FakeFirebaseFirestore();
  await fake.collection('users').doc('sup-1').set({
    'uid': 'sup-1',
    'email': 'sales@skyline.test',
    'name': 'Skyline Materials',
    'role': 'Supplier',
    'companyId': '',
    'phone': '03007654321',
    'city': 'Karachi',
    'status': 'pending',
    'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
  });
  await fake.collection('suppliers').doc('sup-1').set({
    'uid': 'sup-1',
    'name': 'Skyline Materials',
    'city': 'Karachi',
    'businessType': 'Sole Proprietorship',
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

  testWidgets('shows empty copy when no pending suppliers exist',
      (tester) async {
    await pumpAdminScreen(
      tester,
      child: AdminSupplierManagementView(debugFirestore: FakeFirebaseFirestore()),
      admin: admin,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Supplier Management'), findsOneWidget);
    expect(find.text('No pending suppliers found.'), findsOneWidget);
  });

  testWidgets('renders a pending supplier card from Firestore', (tester) async {
    final fake = await _seedPendingSupplier();

    await pumpAdminScreen(
      tester,
      child: AdminSupplierManagementView(debugFirestore: fake),
      admin: admin,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Skyline Materials'), findsWidgets);
    expect(find.text('sales@skyline.test'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
  });

  testWidgets('Approve confirms and calls approveSupplier', (tester) async {
    final fake = await _seedPendingSupplier();

    await pumpAdminScreen(
      tester,
      child: AdminSupplierManagementView(debugFirestore: fake),
      admin: admin,
    );
    await tester.pump();
    await tester.pump();

    await tapVisible(tester, find.text('Approve'));
    await tester.pump();
    await tapVisible(tester, find.text('CONFIRM'));
    await tester.pump();

    verify(() => admin.approveSupplier('sup-1')).called(1);
  });
}
