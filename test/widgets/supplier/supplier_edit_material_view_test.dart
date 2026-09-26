import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/views/supplier/supplier_edit_material_view.dart';

import '../../mocks/mocks.dart';
import 'supplier_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerSupplierWidgetFallbacks);

  late MockSupplierViewModel supplier;
  late MockMaterialViewModel materialVm;

  setUp(() {
    supplier = MockSupplierViewModel();
    stubSupplierViewModel(supplier);
    materialVm = MockMaterialViewModel();
    stubMaterialViewModel(materialVm);
  });

  testWidgets('shows a spinner while categories are loading', (tester) async {
    final completer = Completer<void>();
    when(() => materialVm.isLoading).thenReturn(true);
    when(() => materialVm.loadCategories()).thenAnswer((_) => completer.future);

    await pumpSupplierScreen(
      tester,
      child: SupplierEditMaterialView(material: sampleMaterial()),
      supplier: supplier,
      material: materialVm,
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows a ViewModel error on the form', (tester) async {
    when(() => materialVm.error).thenReturn('Image upload failed');
    when(() => materialVm.categories).thenReturn([sampleCategory()]);
    when(() => materialVm.selectedCategory).thenReturn(sampleCategory());

    await pumpSupplierScreen(
      tester,
      child: SupplierEditMaterialView(material: sampleMaterial()),
      supplier: supplier,
      material: materialVm,
    );
    await tester.pump();

    expect(find.text('Image upload failed'), findsOneWidget);
    expect(find.text('Lucky Cement'), findsOneWidget);
  });

  testWidgets('UPDATE MATERIAL calls updateMaterial', (tester) async {
    when(() => materialVm.categories).thenReturn([sampleCategory()]);
    when(() => materialVm.selectedCategory).thenReturn(sampleCategory());

    await pumpSupplierScreen(
      tester,
      child: SupplierEditMaterialView(material: sampleMaterial()),
      supplier: supplier,
      material: materialVm,
    );
    await tester.pump();

    expect(find.text('Lucky Cement'), findsOneWidget);

    await tapVisible(tester, find.text('UPDATE MATERIAL'));
    await tester.pump();

    verify(
      () => materialVm.updateMaterial(
        'mat-1',
        any(),
        any(),
        'co-1',
        'sup-1',
      ),
    ).called(1);
  });
}
