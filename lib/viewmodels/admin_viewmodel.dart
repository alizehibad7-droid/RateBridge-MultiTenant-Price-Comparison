// MVVM: ViewModel
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/company_model.dart';
import '../models/user_model.dart';
import '../models/category_model.dart';
import '../models/subscription_model.dart';
import '../utils/invite_code_generator.dart';
import 'auth_viewmodel.dart';

class PlatformTransaction {
  final String id;
  final String type; // 'subscription' | 'commission'
  final String companyName; 
  final String? supplierName;
  final double amount;
  final String status; // 'pending' | 'confirmed' | 'failed' | 'rejected'
  final DateTime? date;
  final String? screenshotUrl;
  final String? rejectionReason;
  final String payerRole;

  PlatformTransaction({
    required this.id,
    required this.type,
    required this.companyName,
    this.supplierName,
    required this.amount,
    required this.status,
    this.date,
    this.screenshotUrl,
    this.rejectionReason,
    required this.payerRole,
  });
}

class AdminViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription? _transactionsSub;

  String? _uid;
  String? _adminName;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<CompanyModel> _companies = [];
  List<CompanyModel> get companiesList => _companies;

  List<PlatformTransaction> _transactions = [];
  List<PlatformTransaction> get transactions => _transactions;

  List<Map<String, dynamic>> _ceosList = [];
  List<Map<String, dynamic>> get ceosList => _ceosList;

  List<Map<String, dynamic>> _suppliersList = [];
  List<Map<String, dynamic>> get suppliersList => _suppliersList;

  AdminViewModel();

  @override
  void dispose() {
    _transactionsSub?.cancel();
    super.dispose();
  }

  void updateAuth(AuthViewModel auth) {
    if (auth.user != null && (auth.user!.role.toLowerCase() == 'admin' || auth.user!.role.toLowerCase() == 'administrator')) {
      if (_uid != auth.user!.uid) {
        _uid = auth.user!.uid;
        _adminName = auth.user!.name;
        loadDashboardData();
        _startListeningTransactions();
      }
    } else {
      _uid = null;
      _adminName = null;
      _transactionsSub?.cancel();
      _transactions = [];
    }
  }

  void _startListeningTransactions() {
    _transactionsSub?.cancel();
    _transactionsSub = _db.collection('payment_proofs')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      _transactions = snap.docs.map((d) {
        final data = d.data();
        return PlatformTransaction(
          id: d.id,
          type: data['type'] as String? ?? 'subscription',
          companyName: data['payerName'] as String? ?? 'Unknown Payer',
          amount: (data['amountExpected'] as num? ?? 0).toDouble(),
          status: data['status'] as String? ?? 'pending',
          date: (data['createdAt'] as Timestamp?)?.toDate(),
          screenshotUrl: data['screenshotUrl'] as String?,
          rejectionReason: data['adminNotes'] as String?,
          payerRole: data['payerRole'] as String? ?? '',
        );
      }).toList();
      notifyListeners();
    }, onError: (e) {
      developer.log("Transactions stream error: $e");
    });
  }

  Future<void> _logAction({
    required String actionType,
    required String targetType,
    required String targetId,
    required String description,
    String? reason,
  }) async {
    final actorId = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (actorId == null) return;
    try {
      await _db.collection('audit_logs').add({
        'actorId': actorId,
        'actorName': _adminName ?? 'Admin',
        'actionType': actionType,
        'targetType': targetType,
        'targetId': targetId,
        'description': description,
        if (reason != null) 'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      developer.log("Audit log error: $e");
    }
  }

  Future<void> loadDashboardData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final companySnap = await _db.collection('companies').get();
      _companies = companySnap.docs.map((doc) => CompanyModel.fromMap(doc.data())).toList();
    } catch (e) {
      developer.log("Load companies error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markTransaction(String transactionId, String status, {String? reason}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final proofDoc = await _db.collection('payment_proofs').doc(transactionId).get();
      if (!proofDoc.exists) return;

      final data = proofDoc.data()!;
      final batch = _db.batch();

      batch.update(_db.collection('payment_proofs').doc(transactionId), {
        'status': status,
        if (status == 'confirmed') 'approvedAt': FieldValue.serverTimestamp(),
        if (reason != null) 'adminNotes': reason,
      });

      if (status == 'confirmed') {
        final type = data['type'];
        final payerId = data['payerId']; // This is usually the CEO UID
        final planKey = data['planKey'] ?? 'free';
        
        if (type == 'subscription') {
          // Find the plan definition to get duration and features
          final planDef = kPlans.firstWhere(
            (p) => p.planKey == planKey,
            orElse: () => kPlans.first,
          );

          final now = DateTime.now();
          final expiry = planDef.durationDays > 0
              ? now.add(Duration(days: planDef.durationDays))
              : null;

          // 1. Update Subscriptions tracking record
          batch.set(_db.collection('subscriptions').doc(payerId), {
            'plan': planKey,
            'status': 'active',
            'startedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'expiresAt': expiry != null ? Timestamp.fromDate(expiry) : null,
            'adminGranted': false,
            'history': FieldValue.arrayUnion([
              {
                'plan': planKey,
                'action': 'purchased',
                'date': Timestamp.now(),
                'amountPaid': (data['amountExpected'] as num? ?? 0).toInt(),
                'note': 'Payment confirmed by admin ($transactionId)',
              }
            ]),
          }, SetOptions(merge: true));

          // 2. Identify the company associated with the CEO
          String? companyId = data['companyId'];
          if (companyId == null || companyId.isEmpty) {
            final userDoc = await _db.collection('users').doc(payerId).get();
            if (userDoc.exists) {
              companyId = userDoc.data()?['companyId'];
            }
          }

          if (companyId != null && companyId.isNotEmpty) {
            // 3. Update Company document so all field users inherit the plan
            batch.update(_db.collection('companies').doc(companyId), {
              'plan': planKey,
              'status': 'active',
              'aiEnabled': planDef.aiUnlocked,
              'planExpiry': expiry != null ? Timestamp.fromDate(expiry) : null,
            });
            
            // 4. Ensure CEO user account is active
            batch.update(_db.collection('users').doc(payerId), {
              'status': 'active',
              'approved': true,
              'approvedAt': FieldValue.serverTimestamp(),
            });
          }
        } else if (type == 'commission') {
          final List<String> txIds = data['relatedTransactions'] != null 
              ? List<String>.from(data['relatedTransactions']) : [];
          for (var id in txIds) {
            batch.update(_db.collection('transactions').doc(id), {
              'status': 'settled',
              'settledAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      await batch.commit();
      await _logAction(
        actionType: 'verify_payment',
        targetType: 'payment_proof',
        targetId: transactionId,
        description: 'Payment from ${data['payerName']} marked as $status',
        reason: reason,
      );
    } catch (e) {
      developer.log("Verify error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // CEO Management
  Future<void> loadCEOs() async {
    _isLoading = true;
    notifyListeners();
    try {
      final userSnap = await _db.collection('users').where('role', isEqualTo: 'CEO').get();
      _ceosList = [];
      for (var doc in userSnap.docs) {
        final ceo = UserModel.fromMap(doc.data());
        final companySnap = await _db.collection('companies').doc(ceo.companyId).get();
        _ceosList.add({
          'ceo': ceo,
          'company': companySnap.exists ? CompanyModel.fromMap(companySnap.data()!) : null,
        });
      }
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
        String code = InviteCodeGenerator.generate();
        batch.update(_db.collection('companies').doc(companyId), {
          'status': 'active',
          'inviteCode': code,
          'inviteCodeGeneratedAt': FieldValue.serverTimestamp(),
        });
      }
      batch.update(_db.collection('users').doc(ceoUid), {
        'status': 'active', 
        'approved': true,
        'approvedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      
      await _logAction(
        actionType: 'approve_ceo',
        targetType: 'ceo',
        targetId: ceoUid,
        description: 'Approved CEO registration',
      );
      
      await loadCEOs();
    } catch (e) {
      developer.log("Accept CEO error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> approveCEO(String? companyId, String ceoUid) => acceptCEO(companyId, ceoUid);

  Future<void> suspendCEO(String? companyId, String ceoUid) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _db.collection('users').doc(ceoUid).update({'status': 'suspended'});
      if (companyId != null && companyId.isNotEmpty) {
        await _db.collection('companies').doc(companyId).update({'status': 'suspended'});
      }
      
      await _logAction(
        actionType: 'suspend_ceo',
        targetType: 'ceo',
        targetId: ceoUid,
        description: 'Suspended CEO account',
      );
      
      await loadCEOs();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> activateCEO(String? companyId, String ceoUid) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _db.collection('users').doc(ceoUid).update({'status': 'active'});
      if (companyId != null && companyId.isNotEmpty) {
        await _db.collection('companies').doc(companyId).update({'status': 'active'});
      }
      
      await _logAction(
        actionType: 'activate_ceo',
        targetType: 'ceo',
        targetId: ceoUid,
        description: 'Reactivated CEO account',
      );
      
      await loadCEOs();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectCEO(String? companyId, String ceoUid, String reason) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _db.collection('users').doc(ceoUid).update({
        'status': 'rejected', 
        'rejectionReason': reason
      });
      if (companyId != null && companyId.isNotEmpty) {
        await _db.collection('companies').doc(companyId).update({'status': 'rejected'});
      }
      
      await _logAction(
        actionType: 'reject_ceo',
        targetType: 'ceo',
        targetId: ceoUid,
        description: 'Rejected CEO application',
        reason: reason,
      );
      
      await loadCEOs();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Supplier Management
  Future<void> loadSuppliers() async {
    final snap = await _db.collection('users').where('role', isEqualTo: 'Supplier').get();
    _suppliersList = snap.docs.map((d) => {'user': UserModel.fromMap(d.data())}).toList();
    notifyListeners();
  }

  Future<void> approveSupplier(String uid) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _db.collection('users').doc(uid).update({
        'status': 'active', 
        'approved': true,
        'approvedAt': FieldValue.serverTimestamp(),
      });
      await _db.collection('suppliers').doc(uid).update({
        'status': 'Active', 
        'isVerified': true
      });
      
      await _logAction(
        actionType: 'approve_supplier',
        targetType: 'supplier',
        targetId: uid,
        description: 'Approved supplier registration',
      );
      
      await loadSuppliers();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> suspendSupplier(String uid) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _db.collection('users').doc(uid).update({'status': 'suspended'});
      await _db.collection('suppliers').doc(uid).update({'status': 'Suspended'});
      
      await _logAction(
        actionType: 'suspend_supplier',
        targetType: 'supplier',
        targetId: uid,
        description: 'Suspended supplier account',
      );
      
      await loadSuppliers();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reactivateSupplier(String uid) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _db.collection('users').doc(uid).update({
        'status': 'active',
        'approved': true,
      });
      await _db.collection('suppliers').doc(uid).update({
        'status': 'Active',
        'isVerified': true,
      });
      
      await _logAction(
        actionType: 'reactivate_supplier',
        targetType: 'supplier',
        targetId: uid,
        description: 'Reactivated supplier account',
      );
      
      await loadSuppliers();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectSupplier(String uid, String reason) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _db.collection('users').doc(uid).update({
        'status': 'rejected', 
        'rejectionReason': reason
      });
      await _db.collection('suppliers').doc(uid).update({'status': 'Rejected'});
      
      await _logAction(
        actionType: 'reject_supplier',
        targetType: 'supplier',
        targetId: uid,
        description: 'Rejected supplier application',
        reason: reason,
      );
      
      await loadSuppliers();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteSupplierPermanently(String uid) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _db.collection('users').doc(uid).delete();
      await _db.collection('suppliers').doc(uid).delete();
      
      await _logAction(
        actionType: 'delete_supplier',
        targetType: 'supplier',
        targetId: uid,
        description: 'Permanently deleted supplier account',
      );
      
      await loadSuppliers();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Category & Taxonomy
  Future<void> addCategory(String name, String unit, List<String> brands, List<String> grades, {String iconKey = 'construction_outlined'}) async {
    try {
      final docRef = await _db.collection('categories').add({
        'name': name,
        'unit': unit,
        'brands': brands,
        'grades': grades,
        'icon': iconKey,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      await _logAction(
        actionType: 'add_category',
        targetType: 'category',
        targetId: docRef.id,
        description: 'Added category: $name',
      );
    } catch (e) {
      developer.log("Add category error: $e");
    }
  }

  Future<void> editCategory(String id, String name, String unit, List<String> brands, List<String> grades, {bool? isActive}) async {
    try {
      final updates = <String, dynamic>{'name': name, 'unit': unit, 'brands': brands, 'grades': grades};
      if (isActive != null) updates['active'] = isActive;
      await _db.collection('categories').doc(id).update(updates);
      
      await _logAction(
        actionType: 'edit_category',
        targetType: 'category',
        targetId: id,
        description: 'Edited category: $name',
      );
    } catch (e) {
      developer.log("Edit category error: $e");
    }
  }

  Future<void> setCategoryActive(String id, bool active) async {
    try {
      await _db.collection('categories').doc(id).update({'active': active});
      
      await _logAction(
        actionType: active ? 'activate_category' : 'deactivate_category',
        targetType: 'category',
        targetId: id,
        description: '${active ? "Activated" : "Deactivated"} category',
      );
    } catch (e) {
      developer.log("Set active error: $e");
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _db.collection('categories').doc(id).delete();
      
      await _logAction(
        actionType: 'delete_category',
        targetType: 'category',
        targetId: id,
        description: 'Deleted category',
      );
    } catch (e) {
      developer.log("Delete category error: $e");
    }
  }

  // Commission Settle
  Future<void> settleSupplierCommissions({required String supplierUid, required String supplierName, required double unsettledAmount, required int orderCount}) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final snap = await _db.collection('transactions')
          .where('supplierUid', isEqualTo: supplierUid)
          .where('status', isEqualTo: 'unsettled')
          .get();

      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'status': 'settled', 'settledAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
      
      await _logAction(
        actionType: 'settle_commission', 
        targetType: 'supplier', 
        targetId: supplierUid, 
        description: 'Settled Rs ${unsettledAmount.toStringAsFixed(0)} for $supplierName'
      );
    } catch (e) {
      developer.log("Settle commission error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Dashboard Stats
  Stream<int> watchActiveUsersCount() => _db.collection('users').where('status', isEqualTo: 'active').snapshots().map((s) => s.docs.length);
  Stream<int> watchSuspendedUsersCount() => _db.collection('users').where('status', isEqualTo: 'suspended').snapshots().map((s) => s.docs.length);
  Stream<int> watchPendingUsersCount() => _db.collection('users').where('status', isEqualTo: 'pending').snapshots().map((s) => s.docs.length);
  
  Stream<List<CategoryModel>> watchCategories() => _db.collection('categories').snapshots().map((s) => s.docs.map((d) => CategoryModel.fromDoc(d.id, d.data())).toList());
}
