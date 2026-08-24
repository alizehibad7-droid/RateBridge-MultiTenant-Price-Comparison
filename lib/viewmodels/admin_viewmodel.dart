// MVVM: ViewModel
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/company_model.dart';
import '../models/user_model.dart';
import '../models/category_model.dart';
import '../models/commission_settings_model.dart';
import '../constants/firestore_paths.dart';
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
  String? _adminName;
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
        _adminName = auth.user!.name;
        loadDashboardData();
      }
    }
  }

  Future<void> _logAction({
    required String actionType,
    required String targetType,
    required String targetId,
    required String description,
    String? reason,
  }) async {
    final actorId = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (actorId == null || actorId.isEmpty) {
      developer.log('Skipping audit log for $actionType: no admin actor id');
      return;
    }
    final actorName = (_adminName != null && _adminName!.trim().isNotEmpty)
        ? _adminName!.trim()
        : (FirebaseAuth.instance.currentUser?.displayName?.trim().isNotEmpty == true
            ? FirebaseAuth.instance.currentUser!.displayName!.trim()
            : 'Admin');
    try {
      await _db.collection('audit_logs').add({
        'actorId': actorId,
        'actorName': _clip(actorName, 200),
        'actionType': _clip(actionType, 80),
        'targetType': _clip(targetType, 40),
        'targetId': _clip(targetId, 200),
        'description': _clip(description, 1000),
        if (reason != null && reason.trim().isNotEmpty)
          'reason': _clip(reason.trim(), 4000),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      developer.log("Error saving audit log: $e");
    }
  }

  String _clip(String value, int max) {
    final trimmed = value.trim();
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max - 3)}...';
  }

  Future<String> _userName(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final name = (doc.data()?['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    } catch (e) {
      developer.log('Failed to load user name for $uid: $e');
    }
    return uid;
  }

  Future<String> _companyName(String? companyId) async {
    if (companyId == null || companyId.isEmpty) return 'unknown company';
    try {
      final doc = await _db.collection('companies').doc(companyId).get();
      final name =
          (doc.data()?['name'] ?? doc.data()?['companyName'] ?? '')
              .toString()
              .trim();
      if (name.isNotEmpty) return name;
    } catch (e) {
      developer.log('Failed to load company name for $companyId: $e');
    }
    return companyId;
  }

  Future<String> _supplierName(String uid) async {
    try {
      final supplierDoc = await _db.collection('suppliers').doc(uid).get();
      final business =
          (supplierDoc.data()?['businessName'] ??
                  supplierDoc.data()?['name'] ??
                  '')
              .toString()
              .trim();
      if (business.isNotEmpty) return business;
    } catch (e) {
      developer.log('Failed to load supplier profile for $uid: $e');
    }
    return _userName(uid);
  }

  Future<String> _resolvedCompanyId(String ceoUid, String? companyId) async {
    if (companyId != null && companyId.isNotEmpty) return companyId;
    try {
      final user = await _db.collection('users').doc(ceoUid).get();
      return (user.data()?['companyId'] ?? '').toString();
    } catch (_) {
      return '';
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

      final ceoName = await _userName(ceoUid);
      final resolvedCompanyId = await _resolvedCompanyId(ceoUid, companyId);
      final companyName = await _companyName(resolvedCompanyId);
      await _logAction(
        actionType: 'approve_ceo',
        targetType: 'ceo',
        targetId: ceoUid,
        description: 'Approved CEO $ceoName for company $companyName',
      );

      loadCEOs();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Alias for backward compatibility if any
  Future<void> approveCEO(String? companyId, String ceoUid) => acceptCEO(companyId, ceoUid);

  Future<void> suspendCEO(String? companyId, String ceoUid) async {
    final resolvedCompanyId = await _resolvedCompanyId(ceoUid, companyId);
    final ceoName = await _userName(ceoUid);
    final companyName = await _companyName(resolvedCompanyId);

    await _db.collection('users').doc(ceoUid).update({'status': 'suspended'});
    if (resolvedCompanyId.isNotEmpty) {
      await _db.collection('companies').doc(resolvedCompanyId).update({'status': 'suspended'});
    }

    await _logAction(
      actionType: 'ban_company',
      targetType: 'company',
      targetId: resolvedCompanyId.isNotEmpty ? resolvedCompanyId : ceoUid,
      description: 'Banned company $companyName (CEO: $ceoName)',
    );

    loadCEOs();
  }

  Future<void> activateCEO(String? companyId, String ceoUid) async {
    final resolvedCompanyId = await _resolvedCompanyId(ceoUid, companyId);
    final ceoName = await _userName(ceoUid);
    final companyName = await _companyName(resolvedCompanyId);

    await _db.collection('users').doc(ceoUid).update({'status': 'active'});
    if (resolvedCompanyId.isNotEmpty) {
      await _db.collection('companies').doc(resolvedCompanyId).update({'status': 'active'});
    }

    await _logAction(
      actionType: 'reactivate_company',
      targetType: 'company',
      targetId: resolvedCompanyId.isNotEmpty ? resolvedCompanyId : ceoUid,
      description: 'Reactivated company $companyName (CEO: $ceoName)',
    );

    loadCEOs();
  }

  Future<void> rejectCEO(String? companyId, String ceoUid, String reason) async {
    final resolvedCompanyId = await _resolvedCompanyId(ceoUid, companyId);
    final ceoName = await _userName(ceoUid);
    final companyName = await _companyName(resolvedCompanyId);

    await _db.collection('users').doc(ceoUid).update({
      'status': 'rejected',
      'rejectionReason': reason,
    });
    if (resolvedCompanyId.isNotEmpty) {
      await _db.collection('companies').doc(resolvedCompanyId).update({
        'status': 'rejected',
        'rejectionReason': reason,
      });
    }

    await _logAction(
      actionType: 'reject_ceo',
      targetType: 'ceo',
      targetId: ceoUid,
      description: 'Rejected CEO application for $ceoName ($companyName)',
      reason: reason,
    );

    loadCEOs();
  }

  Future<void> approveSupplier(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _db.collection('users').doc(uid).update({'status': 'active', 'approved': true});
      await _db.collection('suppliers').doc(uid).update({'status': 'Active', 'isVerified': true});

      final supplierName = await _supplierName(uid);
      await _logAction(
        actionType: 'approve_supplier',
        targetType: 'supplier',
        targetId: uid,
        description: 'Approved supplier $supplierName',
      );

      loadSuppliers();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> suspendSupplier(String uid) async {
    final supplierName = await _supplierName(uid);
    await _db.collection('users').doc(uid).update({'status': 'suspended'});
    await _db.collection('suppliers').doc(uid).update({'status': 'Suspended'});

    await _logAction(
      actionType: 'ban_supplier',
      targetType: 'supplier',
      targetId: uid,
      description: 'Banned supplier $supplierName',
    );

    loadSuppliers();
  }

  Future<void> reactivateSupplier(String uid) async {
    final supplierName = await _supplierName(uid);
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
      description: 'Reactivated supplier $supplierName',
    );

    loadSuppliers();
  }

  Future<void> rejectSupplier(String uid, String reason) async {
    final supplierName = await _supplierName(uid);
    await _db.collection('users').doc(uid).update({
      'status': 'rejected',
      'rejectionReason': reason,
    });
    await _db.collection('suppliers').doc(uid).update({'status': 'Rejected'});

    await _logAction(
      actionType: 'reject_supplier',
      targetType: 'supplier',
      targetId: uid,
      description: 'Rejected supplier application for $supplierName',
      reason: reason,
    );

    loadSuppliers();
  }

  Future<void> deleteSupplierPermanently(String uid) async {
    // In a real app, this might involve more cleanup
    await _db.collection('users').doc(uid).delete();
    await _db.collection('suppliers').doc(uid).delete();

    await _logAction(
      actionType: 'delete_supplier',
      targetType: 'supplier',
      targetId: uid,
      description: 'Permanently deleted supplier account and data',
    );

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
    final docRef = await _db.collection('categories').add({
      'name': name,
      'unit': unit,
      'brands': brands,
      'grades': grades,
      'icon': iconKey,
      'active': true,
      'activeMaterialsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _logAction(
      actionType: 'add_category',
      targetType: 'category',
      targetId: docRef.id,
      description: 'Added new material category: $name',
    );
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

    await _logAction(
      actionType: 'edit_category',
      targetType: 'category',
      targetId: id,
      description: 'Updated category details for $name',
    );
  }

  Future<void> setCategoryActive(String id, bool active) async {
    await _db.collection('categories').doc(id).update({'active': active});

    await _logAction(
      actionType: active ? 'activate_category' : 'deactivate_category',
      targetType: 'category',
      targetId: id,
      description: '${active ? "Activated" : "Deactivated"} category',
    );
  }

  Future<void> deleteCategory(String id) async {
    await _db.collection('categories').doc(id).delete();

    await _logAction(
      actionType: 'delete_category',
      targetType: 'category',
      targetId: id,
      description: 'Deleted category',
    );
  }

  Future<void> markTransaction(String transactionId, String status) async {
    await _db.collection('transactions').doc(transactionId).update({
      'status': status,
      'reconciledAt': FieldValue.serverTimestamp(),
    });

    await _logAction(
      actionType: 'mark_transaction',
      targetType: 'transaction',
      targetId: transactionId,
      description: 'Marked payment-queue transaction $transactionId as $status',
    );

    loadDashboardData();
  }

  Future<void> settleSupplierCommissions({
    required String supplierUid,
    required String supplierName,
    required double unsettledAmount,
    required int orderCount,
  }) async {
    final snap = await _db
        .collection('transactions')
        .where('supplierUid', isEqualTo: supplierUid)
        .where('status', isEqualTo: 'unsettled')
        .get();

    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'status': 'settled',
        'settledAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    final ids = snap.docs.map((d) => d.id).join(', ');
    final amountLabel = unsettledAmount.toStringAsFixed(0);
    await _logAction(
      actionType: 'settle_commission',
      targetType: 'supplier',
      targetId: supplierUid,
      description:
          'Marked $orderCount commission transaction(s) as settled for $supplierName (Rs $amountLabel)',
      reason: 'Transaction IDs: $ids',
    );
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

  Future<CommissionSettingsModel> loadCommissionSettings() async {
    final doc = await _db.doc(FirestorePaths.commissionSettingsDoc).get();
    return CommissionSettingsModel.fromMap(doc.data());
  }

  Stream<CommissionSettingsModel> watchCommissionSettings() {
    return _db.doc(FirestorePaths.commissionSettingsDoc).snapshots().map(
      (doc) => CommissionSettingsModel.fromMap(doc.data()),
    );
  }

  Future<void> saveCommissionSettings({
    required double maxOutstandingAmount,
    required int maxUnsettledAgeDays,
  }) async {
    final actorId = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (actorId == null) return;

    final settings = CommissionSettingsModel(
      maxOutstandingAmount: maxOutstandingAmount,
      maxUnsettledAgeDays: maxUnsettledAgeDays,
    );
    await _db
        .doc(FirestorePaths.commissionSettingsDoc)
        .set(settings.toMap(actorId), SetOptions(merge: true));

    await _logAction(
      actionType: 'update_commission_settings',
      targetType: 'settings',
      targetId: FirestorePaths.commissionSettingsDoc,
      description:
          'Updated commission thresholds to Rs ${maxOutstandingAmount.toStringAsFixed(0)} outstanding and $maxUnsettledAgeDays day age limit',
    );
  }

  Stream<List<SupplierCommissionMonitorRow>> watchRestrictedSuppliers() {
    return _db
        .collection('suppliers')
        .where('commissionRestricted', isEqualTo: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => SupplierCommissionMonitorRow.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList()
            ..sort((a, b) => b.outstandingAmount.compareTo(a.outstandingAmount)),
        );
  }

  Stream<List<SupplierCommissionMonitorRow>> watchApproachingRestrictionSuppliers() {
    return _db
        .collection('suppliers')
        .where('commissionReminderStage', whereIn: ['gentle', 'urgent'])
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => SupplierCommissionMonitorRow.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .where((row) => !row.restricted)
              .toList()
            ..sort((a, b) => b.oldestUnsettledDays.compareTo(a.oldestUnsettledDays)),
        );
  }

  Future<void> manuallyRestrictSupplierCommission({
    required String supplierUid,
    required String supplierName,
    required String reason,
  }) async {
    await _db.collection('suppliers').doc(supplierUid).set({
      'commissionRestricted': true,
      'commissionRestrictionReason': 'manual',
      'commissionRestrictionOverride': 'force_restrict',
      'commissionRestrictedAt': FieldValue.serverTimestamp(),
      'commissionStatusUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _logAction(
      actionType: 'restrict_supplier_commission',
      targetType: 'supplier',
      targetId: supplierUid,
      description: 'Manually restricted $supplierName from marketplace visibility and RFQ bidding',
      reason: reason,
    );
  }

  Future<void> manuallyLiftCommissionRestriction({
    required String supplierUid,
    required String supplierName,
    required String reason,
  }) async {
    await _db.collection('suppliers').doc(supplierUid).set({
      'commissionRestricted': false,
      'commissionRestrictionReason': null,
      'commissionRestrictionOverride': 'force_allow',
      'commissionRestrictedAt': null,
      'commissionReminderStage': 'none',
      'commissionStatusUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _logAction(
      actionType: 'lift_commission_restriction',
      targetType: 'supplier',
      targetId: supplierUid,
      description: 'Manually lifted commission restriction for $supplierName',
      reason: reason,
    );
  }
}
