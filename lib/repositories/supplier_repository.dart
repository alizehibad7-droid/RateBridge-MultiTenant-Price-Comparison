import '../models/supplier_model.dart';
import '../services/firestore_service.dart';

class SupplierRepository {
  final FirestoreService _firestoreService;

  SupplierRepository(this._firestoreService);

  Stream<List<SupplierModel>> getSuppliers() {
    return _firestoreService.streamSuppliers();
  }

  Future<void> registerSupplier(SupplierModel supplier) async {
    await _firestoreService.saveSupplier(supplier);
  }
}
