// MVVM: ViewModel
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company_model.dart';
import '../models/user_model.dart';
import '../models/category_model.dart';
import '../utils/invite_code_generator.dart';
import 'auth_viewmodel.dart';

// New Admin Models
class PlatformTransaction {
  final String id;
  final String type; // 'subscription' | 'order_payment'
  final String companyName;
  final String? supplierName;
  final double amount;
  final String status; // 'pending' | 'confirmed' | 'failed'
  final DateTime? date;

  PlatformTransaction({
    required this.id,
    required this.type,
    required this.companyName,
    this.supplierName,
    required this.amount,
    required this.status,
    this.date,
  });
}

class AdminViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _uid;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _suppliersList = [];
  List<Map<String, dynamic>> get suppliersList => _suppliersList;

  List<Map<String, dynamic>> _ceosList = [];
  List<Map<String, dynamic>> get ceosList => _ceosList;

  List<CompanyModel> _companies = [];
  List<CompanyModel> get companiesList => _companies;

  List<PlatformTransaction> _transactions = [];
  List<PlatformTransaction> get transactions => _transactions;

  AdminViewModel();

  void updateAuth(AuthViewModel auth) {
    if (auth.user != null && (auth.user!.role.toLowerCase() == 'admin' || auth.user!.role.toLowerCase() == 'administrator')) {
      if (_uid != auth.user!.uid) {
        _uid = auth.user!.uid;
        loadDashboardData();
      }
    }
  }

  Future<void> loadDashboardData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final companySnap = await _db.collection('companies').get();
      _companies = companySnap.docs.map((doc) => CompanyModel.fromMap(doc.data())).toList();

      final txSnap = await _db.collection('transactions').limit(50).get();
      _transactions = txSnap.docs.map((d) {
        final data = d.data();
        return PlatformTransaction(
          id: d.id,
          type: data['type'] as String? ?? 'order_payment',
          companyName: data['companyName'] as String? ?? '',
          supplierName: data['supplierName'] as String?,
          amount: (data['amount'] as num? ?? 0).toDouble(),
          status: data['status'] as String? ?? 'pending',
          date: (data['date'] as Timestamp?)?.toDate(),
        );
      }).toList();
    } catch (e) {
      developer.log("AdminViewModel Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Approvals ---

  Future<void> loadCEOs() async {
    _isLoading = true;
    notifyListeners();
    try {
      final userSnap = await _db.collection('users').where('role', isEqualTo: 'CEO').get();
      List<Map<String, dynamic>> temp = [];
      for (var doc in userSnap.docs) {
        final ceo = UserModel.fromMap(doc.data());
        final companySnap = await _db.collection('companies').doc(ceo.companyId).get();
        temp.add({
          'ceo': ceo,
          'company': companySnap.exists ? CompanyModel.fromMap(companySnap.data()!) : null,
        });
      }
      _ceosList = temp;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptCEO(String? companyId, String ceoUid) async {
    _isLoading = true;
    notifyListeners();
    try {
      final batch = _db.batch();
      if (companyId != null && companyId.isNotEmpty) {
        String inviteCode = await _generateUniqueInviteCode();
        batch.update(_db.collection('companies').doc(companyId), {
          'status': 'active',
          'inviteCode': inviteCode,
          'inviteCodeGeneratedAt': FieldValue.serverTimestamp(),
        });
      }
      batch.update(_db.collection('users').doc(ceoUid), {'status': 'active', 'approved': true});
      await batch.commit();
      loadCEOs();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Alias for backward compatibility if any
  Future<void> approveCEO(String? companyId, String ceoUid) => acceptCEO(companyId, ceoUid);

  Future<void> suspendCEO(String? companyId, String ceoUid) async {
    await _db.collection('users').doc(ceoUid).update({'status': 'suspended'});
    if (companyId != null && companyId.isNotEmpty) {
      await _db.collection('companies').doc(companyId).update({'status': 'suspended'});
    }
    loadCEOs();
  }

  Future<void> activateCEO(String? companyId, String ceoUid) async {
    await _db.collection('users').doc(ceoUid).update({'status': 'active'});
    if (companyId != null && companyId.isNotEmpty) {
      await _db.collection('companies').doc(companyId).update({'status': 'active'});
    }
    loadCEOs();
  }

  Future<void> rejectCEO(String? companyId, String ceoUid, String reason) async {
    await _db.collection('users').doc(ceoUid).update({
      'status': 'rejected',
      'rejectionReason': reason,
    });
    if (companyId != null && companyId.isNotEmpty) {
      await _db.collection('companies').doc(companyId).update({
        'status': 'rejected',
        'rejectionReason': reason,
      });
    }
    loadCEOs();
  }

  Future<void> approveSupplier(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _db.collection('users').doc(uid).update({'status': 'active', 'approved': true});
      await _db.collection('suppliers').doc(uid).update({'status': 'Active', 'isVerified': true});
      loadSuppliers();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> suspendSupplier(String uid) async {
    await _db.collection('users').doc(uid).update({'status': 'suspended'});
    await _db.collection('suppliers').doc(uid).update({'status': 'Suspended'});
    loadSuppliers();
  }

  Future<void> rejectSupplier(String uid, String reason) async {
    await _db.collection('users').doc(uid).update({
      'status': 'rejected',
      'rejectionReason': reason,
    });
    await _db.collection('suppliers').doc(uid).update({'status': 'Rejected'});
    loadSuppliers();
  }

  Future<void> deleteSupplierPermanently(String uid) async {
    // In a real app, this might involve more cleanup
    await _db.collection('users').doc(uid).delete();
    await _db.collection('suppliers').doc(uid).delete();
    loadSuppliers();
  }

  // --- Category & Transaction Management ---

  Future<void> addCategory(
    String name,
    String unit,
    List<String> brands,
    List<String> grades, {
    String iconKey = 'construction_outlined',
  }) async {
    await _db.collection('categories').add({
      'name': name,
      'unit': unit,
      'brands': brands,
      'grades': grades,
      'icon': iconKey,
      'active': true,
      'activeMaterialsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> editCategory(
    String id,
    String name,
    String unit,
    List<String> brands,
    List<String> grades, {
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{
      'name': name,
      'unit': unit,
      'brands': brands,
      'grades': grades,
    };
    if (isActive != null) {
      updates['active'] = isActive;
    }
    await _db.collection('categories').doc(id).update(updates);
  }

  Future<void> setCategoryActive(String id, bool active) async {
    await _db.collection('categories').doc(id).update({'active': active});
  }

  Future<void> deleteCategory(String id) async {
    await _db.collection('categories').doc(id).delete();
  }

  Future<void> markTransaction(String transactionId, String status) async {
    await _db.collection('transactions').doc(transactionId).update({
      'status': status,
      'reconciledAt': FieldValue.serverTimestamp(),
    });
    loadDashboardData();
  }

  Future<void> loadSuppliers() async {
    final snap = await _db.collection('users').where('role', isEqualTo: 'Supplier').get();
    _suppliersList = snap.docs.map((d) => {'user': UserModel.fromMap(d.data())}).toList();
    notifyListeners();
  }

  Future<String> _generateUniqueInviteCode() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final candidate = InviteCodeGenerator.generate();
      final existing = await _db.collection('companies').where('inviteCode', isEqualTo: candidate).limit(1).get();
      if (existing.docs.isEmpty) return candidate;
    }
    return InviteCodeGenerator.generate(length: 8);
  }

  // Dashboard Statistics
  Stream<int> watchActiveUsersCount() => _db.collection('users').where('status', isEqualTo: 'active').snapshots().map((s) => s.docs.length);
  Stream<int> watchSuspendedUsersCount() => _db.collection('users').where('status', isEqualTo: 'suspended').snapshots().map((s) => s.docs.length);
  Stream<int> watchPendingUsersCount() => _db.collection('users').where('status', isEqualTo: 'pending').snapshots().map((s) => s.docs.length);
  
  Stream<List<CategoryModel>> watchCategories() => _db
      .collection('categories')
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => CategoryModel.fromDoc(d.id, d.data()))
            .where((c) => c.name.isNotEmpty)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
      );
}
