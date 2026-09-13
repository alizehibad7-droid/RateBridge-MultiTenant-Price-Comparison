import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/material_model.dart';
import 'package:ratebridge/views/supplier/supplier_material_detail_view.dart';

import '../../mocks/mocks.dart';
import 'supplier_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerSupplierWidgetFallbacks);

  late MockSupplierViewModel supplier;

  setUp(() {
    supplier = MockSupplierViewModel();
    stubSupplierViewModel(supplier);
  });

  testWidgets('shows a spinner while the material is fetched', (tester) async {
    final completer = Completer<MaterialModel?>();
    when(() => supplier.materialById('mat-1')).thenReturn(null);
    when(() => supplier.fetchMaterialById('mat-1'))
        .thenAnswer((_) => completer.future);

    await pumpSupplierScreen(
      tester,
      child: const SupplierMaterialDetailView(materialId: 'mat-1'),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(null);
  });

  testWidgets('shows empty copy when the material cannot be found',
      (tester) async {
    when(() => supplier.materialById('missing')).thenReturn(null);
    when(() => supplier.fetchMaterialById('missing'))
        .thenAnswer((_) async => null);

    await pumpSupplierScreen(
      tester,
      child: const SupplierMaterialDetailView(materialId: 'missing'),
      supplier: supplier,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Material not found'), findsWidgets);
  });

  testWidgets('renders the material when it is already in the ViewModel',
      (tester) async {
    final material = sampleMaterial();
    when(() => supplier.materialById('mat-1')).thenReturn(material);

    await pumpSupplierScreen(
      tester,
      child: const SupplierMaterialDetailView(materialId: 'mat-1'),
      supplier: supplier,
    );
    await tester.pump();

    expect(find.text('Lucky Cement'), findsOneWidget);
    expect(find.text('Edit Material'), findsOneWidget);
    verifyNever(() => supplier.fetchMaterialById(any()));
  });
}
