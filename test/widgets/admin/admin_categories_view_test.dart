import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/category_model.dart';
import 'package:ratebridge/views/admin/admin_categories_view.dart';

import '../../mocks/mocks.dart';
import 'admin_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAdminWidgetFallbacks);

  late MockAdminViewModel admin;

  setUp(() {
    admin = MockAdminViewModel();
    stubAdminViewModel(admin);
  });

  testWidgets('shows a spinner while categories are loading', (tester) async {
    final controller = StreamController<List<CategoryModel>>();
    when(() => admin.watchCategories()).thenAnswer((_) => controller.stream);

    await pumpAdminScreen(
      tester,
      child: const AdminCategoriesView(),
      admin: admin,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await controller.close();
  });

  testWidgets('shows empty copy when there are no categories', (tester) async {
    await pumpAdminScreen(
      tester,
      child: const AdminCategoriesView(),
      admin: admin,
    );
    await tester.pump();

    expect(find.text('No categories found'), findsOneWidget);
    expect(find.text('Add First Category'), findsOneWidget);
  });

  testWidgets('renders category rows and toggles visibility', (tester) async {
    when(() => admin.watchCategories()).thenAnswer(
      (_) => Stream<List<CategoryModel>>.value([sampleCategory()]),
    );

    await pumpAdminScreen(
      tester,
      child: const AdminCategoriesView(),
      admin: admin,
    );
    await tester.pump();

    expect(find.text('Cement'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    verify(() => admin.setCategoryActive('cement', false)).called(1);
  });

  testWidgets('ADD CUSTOM CATEGORY submits addCategory', (tester) async {
    when(() => admin.watchCategories()).thenAnswer(
      (_) => Stream<List<CategoryModel>>.value([sampleCategory()]),
    );

    await pumpAdminScreen(
      tester,
      child: const AdminCategoriesView(),
      admin: admin,
    );
    await tester.pump();

    await tapVisible(tester, find.text('ADD CUSTOM CATEGORY'));
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Bricks');
    await tester.enterText(fields.at(1), 'piece');
    await tapVisible(tester, find.text('CREATE'));
    await tester.pump();
    await tester.pump();

    verify(() => admin.addCategory('Bricks', 'piece', <String>[], <String>[]))
        .called(1);
  });

  testWidgets('edit specifications submits editCategory', (tester) async {
    when(() => admin.watchCategories()).thenAnswer(
      (_) => Stream<List<CategoryModel>>.value([sampleCategory()]),
    );

    await pumpAdminScreen(
      tester,
      child: const AdminCategoriesView(),
      admin: admin,
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Edit Specifications'));
    await tester.pump();

    expect(find.text('Edit Category'), findsOneWidget);
    expect(find.text('Cement'), findsWidgets);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'ton');
    await tester.enterText(fields.at(1), 'Lucky, Bestway');
    await tapVisible(tester, find.text('SAVE CHANGES'));
    await tester.pump();
    await tester.pump();

    verify(
      () => admin.editCategory(
        'cement',
        'Cement',
        'ton',
        ['Lucky', 'Bestway'],
        ['OPC'],
      ),
    ).called(1);
  });
}
