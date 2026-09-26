import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/supplier/supplier_add_material_view.dart';

import '../../mocks/mocks.dart';
import 'supplier_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerSupplierWidgetFallbacks);

  late MockSupplierViewModel supplier;
  late MockMaterialViewModel material;

  setUp(() {
    supplier = MockSupplierViewModel();
    stubSupplierViewModel(supplier);
    material = MockMaterialViewModel();
    stubMaterialViewModel(material);
  });

  testWidgets('shows loading copy while categories are fetched',
      (tester) async {
    final completer = Completer<void>();
    when(() => material.isLoadingCategories).thenReturn(true);
    when(() => material.loadCategories()).thenAnswer((_) => completer.future);

    await pumpSupplierScreen(
      tester,
      child: const SupplierAddMaterialView(),
      supplier: supplier,
      material: material,
    );
    await tester.pump();

    expect(find.text('Loading categories…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('shows empty copy when there are no categories', (tester) async {
    await pumpSupplierScreen(
      tester,
      child: const SupplierAddMaterialView(),
      supplier: supplier,
      material: material,
    );
    await tester.pump();

    expect(find.text('No categories available'), findsOneWidget);
    verify(() => material.loadCategories()).called(1);
  });

  testWidgets('renders categories and selecting one calls onCategorySelected',
      (tester) async {
    final category = sampleCategory();
    when(() => material.categories).thenReturn([category]);
    when(() => material.selectedCategory).thenReturn(category);

    await pumpSupplierScreen(
      tester,
      child: const SupplierAddMaterialView(),
      supplier: supplier,
      material: material,
    );
    await tester.pump();

    expect(find.text('Select a category'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cement').last);
    await tester.pump();

    verify(() => material.onCategorySelected('cat-cement')).called(1);
  });
}
