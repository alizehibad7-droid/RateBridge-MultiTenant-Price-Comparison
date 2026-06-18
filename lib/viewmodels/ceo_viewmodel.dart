// MVVM: ViewModel — business logic only
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/order_model.dart';
import '../models/join_request_model.dart';
import '../models/company_model.dart';
import '../models/supplier_model.dart';
import '../repositories/order_repository.dart';
import '../repositories/join_request_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/company_repository.dart';
import '../repositories/invitation_repository.dart';
import '../services/cloud_function_service.dart';
import '../utils/invite_code_generator.dart';

class CeoViewModel extends ChangeNotifier {
  final String? _uid;
  final String _name;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final OrderRepository _orderRepo;
  final JoinRequestRepository _joinRepo;
  final UserRepository _userRepo;
  final CompanyRepository _companyRepo;
  final InvitationRepository _invitationRepo;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  CompanyModel? _company;
  List<SupplierModel> _marketplaceSuppliers = [];

  CeoViewModel(
      this._uid,
      this._name,
      this._orderRepo,
      this._joinRepo,
      this._userRepo,
      this._companyRepo,
      this._invitationRepo, [
        CloudFunctionService? cloudFunctionService
      ]) {
    if (_uid != null) {
      _loadCompanyData();
    }
  }

  String? get uid => _uid;
  String get name => _name;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  CompanyModel? get company => _company;
  List<SupplierModel> get marketplaceSuppliers => _marketplaceSuppliers;

  Future<void> _loadCompanyData() async {
    final uid = _uid;
    if (uid == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _userRepo.getUserDoc(uid);
      String currentCompanyId = user.companyId;
      CompanyModel? companyDoc;

      if (currentCompanyId.isNotEmpty) {
        companyDoc = await _companyRepo.getCompanyById(currentCompanyId);
      }

      if (companyDoc == null) {
        final query = await _db.collection('companies')
            .where('ceoUid', isEqualTo: uid)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          companyDoc = CompanyModel.fromMap(data);

          if (currentCompanyId != doc.id) {
            await _userRepo.updateUserDoc(uid, {'companyId': doc.id});
          }
        }
      }

      if (companyDoc != null) {
        _company = companyDoc;
        if (_company!.inviteCode == null ||
            _company!.inviteCode!.isEmpty ||
            _company!.inviteCode == 'RB-XXXXXX') {
          await regenerateInviteCode();
        }
      } else {
        _errorMessage = currentCompanyId.isEmpty
            ? "Account not associated with a company."
            : "Company profile not found.";
      }
    } catch (e) {
      _errorMessage = "Failed to load company details: ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDashboard() async => await _loadCompanyData();

  Future<void> regenerateInviteCode() async {
    final uid = _uid;
    if (_company == null || uid == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final oldKey = _company!.inviteCode;
      if (oldKey != null && oldKey.startsWith('RB-') && oldKey != 'RB-XXXXXX') {
        try { await _invitationRepo.updateStatus(oldKey, 'expired'); } catch (_) {}
      }

      final newKey = await _generateUniqueInviteCode();
      await _db.collection('companies').doc(_company!.id).update({
        'inviteCode': newKey,
        'inviteCodeGeneratedAt': FieldValue.serverTimestamp(),
      });

      _company = _company?.copyWith(inviteCode: newKey);
      _successMessage = "New invite code generated.";
    } catch (e) {
      _errorMessage = "Failed to generate key.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> _generateUniqueInviteCode() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final candidate = InviteCodeGenerator.generate();
      final existing = await _db.collection('companies').where('inviteCode', isEqualTo: candidate).limit(1).get();
      if (existing.docs.isEmpty) return candidate;
    }
    return InviteCodeGenerator.generate(length: 8);
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  // --- Real-time Streams ---

  Stream<UserModel?> watchCeoStatus() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _db.collection('users').doc(uid).snapshots().map((doc) =>
    doc.exists ? UserModel.fromMap(doc.data() as Map<String, dynamic>) : null);
  }

  Stream<Map<String, dynamic>> watchDashboardStats(String companyId) {
    if (companyId.isEmpty) return Stream.value({});

    return _db.collection('companies').doc(companyId).snapshots().asyncMap((doc) async {
      if (!doc.exists) return {};

      final suppliers = await _db.collection('companies').doc(companyId).collection('suppliers').where('status', isEqualTo: 'active').get();
      final team = await _db.collection('users').where('companyId', isEqualTo: companyId).where('role', isEqualTo: 'field_user').get();
      final joinRequests = await _db.collection('joinRequests').where('companyId', isEqualTo: companyId).where('status', isEqualTo: 'pending').get();

      final pendingApprovals = await _db.collection('orders')
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: 'pending_approval')
          .get();

      final sub = await _db.collection('subscriptions').doc(companyId).get();
      final plan = sub.exists ? (sub.data()?['plan'] ?? 'Free') : 'Free';
      final expiresAt = sub.exists ? (sub.data()?['expiresAt'] as Timestamp?)?.toDate() : null;

      final companyData = doc.data() as Map<String, dynamic>?;

      return {
        'companyName': companyData?['name'] ?? 'Workspace',
        'inviteCode': companyData?['inviteCode'] ?? 'RB-XXXXXX',
        'plan': plan,
        'activeSupplierCount': suppliers.docs.length,
        'fieldUserCount': team.docs.length,
        'pendingJoinCount': joinRequests.docs.length,
        'pendingOrderApprovals': pendingApprovals.docs.length,
        'expiresAt': expiresAt,
      };
    });
  }

  Stream<List<OrderModel>> watchCompanyOrders(String companyId, String status) {
    Query query = _db.collection('orders').where('companyId', isEqualTo: companyId);
    if (status != 'All') {
      query = query.where('status', isEqualTo: status.toLowerCase().replaceAll(' ', '_'));
    }
    query = query.orderBy('createdAt', descending: true);

    return query.snapshots().map((snap) => snap.docs.map((doc) =>
        OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
  }

  // --- Marketplace Implementation ---

  final List<String> _marketplaceStatuses = ['Active', 'active', 'pending'];

  Future<void> loadMarketplace() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final snap = await _db.collection('suppliers')
          .where('status', whereIn: _marketplaceStatuses)
          .get();
      _marketplaceSuppliers = snap.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return SupplierModel.fromMap(data);
          })
          .toList();
    } catch (e) {
      _errorMessage = "Failed to load marketplace: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchSuppliers(String queryText) async {
    if (queryText.isEmpty) {
      return loadMarketplace();
    }
    _isLoading = true;
    notifyListeners();
    try {
      final lowercaseQuery = queryText.toLowerCase().trim();
      
      Query query = _db.collection('suppliers').where('status', whereIn: _marketplaceStatuses);

      // Support search by email directly if it looks like one
      if (lowercaseQuery.contains('@')) {
        query = query.where('email', isEqualTo: lowercaseQuery);
      } else {
        // Range filter on business name
        query = query.where('businessName', isGreaterThanOrEqualTo: queryText)
                     .where('businessName', isLessThanOrEqualTo: '$queryText\uf8ff');
      }

      final snap = await query.get();
      _marketplaceSuppliers = snap.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return SupplierModel.fromMap(data);
          })
          .toList();
    } catch (e) {
      _errorMessage = "Search failed. Note: Searching by name is case-sensitive.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyFilters({String? city, String? category, bool? verifiedOnly}) async {
    _isLoading = true;
    notifyListeners();
    try {
      Query query = _db.collection('suppliers').where('status', whereIn: _marketplaceStatuses);

      if (city != null && city != 'All') {
        query = query.where('city', isEqualTo: city);
      }
      if (category != null && category != 'All') {
        query = query.where('materialType', isEqualTo: category);
      }
      if (verifiedOnly == true) {
        query = query.where('isVerified', isEqualTo: true);
      }

      final snap = await query.get();
      _marketplaceSuppliers = snap.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return SupplierModel.fromMap(data);
          })
          .toList();
    } catch (e) {
      _errorMessage = "Failed to apply filters: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sortSuppliers(String criteria) async {
    if (criteria == 'Rating') {
      _marketplaceSuppliers.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (criteria == 'Name') {
      _marketplaceSuppliers.sort((a, b) => a.name.compareTo(b.name));
    }
    notifyListeners();
  }

  Stream<String> watchLinkStatus(String companyId, String supplierId) {
    if (companyId.isEmpty || supplierId.isEmpty) return Stream.value('Not Invited');

    return _db.collection('joinRequests')
        .where('companyId', isEqualTo: companyId)
        .where('supplierUid', isEqualTo: supplierId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return 'Not Invited';
      final data = snap.docs.first.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'pending';
      if (status == 'accepted') return 'Linked';
      if (status == 'rejected') return 'Rejected';
      return 'Invited';
    });
  }

  Future<void> sendInvitation(String supplierId) async {
    final company = _company;
    if (company == null || supplierId.isEmpty) return;
    try {
      final supplierDoc = await _db.collection('suppliers').doc(supplierId).get();
      if (!supplierDoc.exists) return;
      final supplierData = supplierDoc.data()!;

      await _joinRepo.createJoinRequest(
          supplierId,
          company.id,
          supplierData['name'] ?? supplierData['businessName'] ?? '',
          supplierData['city'] ?? '',
          [], 
          (supplierData['rating'] as num? ?? 0.0).toDouble(),
          "Company ${company.name} wants to link with you.",
          initiatedBy: 'company'
      );

      _successMessage = "Invitation sent successfully.";
    } catch (e) {
      _errorMessage = "Failed to send invitation: $e";
    }
    notifyListeners();
  }

  // --- Join Requests ---

  Stream<List<JoinRequestModel>> watchJoinRequests(String companyId, String type) {
    if (companyId.isEmpty) return Stream.value([]);
    
    Query query = _db.collection('joinRequests').where('companyId', isEqualTo: companyId);

    if (type == 'Sent') {
      query = query.where('initiatedBy', isEqualTo: 'company');
    } else {
      query = query.where('initiatedBy', isEqualTo: 'supplier');
    }

    return query.orderBy('createdAt', descending: true).snapshots().map((snap) =>
        snap.docs.map((doc) => JoinRequestModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
  }

  Future<void> deleteInvitation(String reqId) async {
    await _db.collection('joinRequests').doc(reqId).delete();
  }

  Future<void> acceptJoinRequest(String reqId, String supplierUid) async {
    await _joinRepo.updateRequestStatus(reqId, 'accepted');
    final company = _company;
    if (company != null) {
      final supplierDoc = await _db.collection('users').doc(supplierUid).get();
      if (supplierDoc.exists) {
        final data = supplierDoc.data()!;
        await _db.collection('companies').doc(company.id).collection('suppliers').doc(supplierUid).set({
          'name': data['name'],
          'city': data['city'],
          'materialType': data['businessType'] ?? 'General',
          'status': 'active',
          'linkedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> rejectJoinRequest(String reqId, String reason) async {
    await _joinRepo.updateRequestStatus(reqId, 'rejected', reason: reason);
  }

  Stream<List<Map<String, dynamic>>> watchMySuppliers(String companyId) {
    return _db.collection('companies').doc(companyId).collection('suppliers')
        .snapshots().map((snap) => snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  Future<void> removeSupplier(String supplierId) async {
    final company = _company;
    if (company == null) return;
    await _db.collection('companies').doc(company.id).collection('suppliers').doc(supplierId).delete();
  }

  Future<void> reactivateFieldUser(String uid) async {
    await _db.collection('users').doc(uid).update({'status': 'active'});
  }

  Future<void> loadCompanyProfile() async {
    await _loadCompanyData();
  }

  Future<void> updateCompanyProfile(Map<String, dynamic> data) async {
    final company = _company;
    if (company == null) return;
    await _db.collection('companies').doc(company.id).update(data);
    await _loadCompanyData();
  }

  Stream<List<UserModel>> watchFieldUsers(String companyId, String filter) {
    Query query = _db.collection('users')
        .where('companyId', isEqualTo: companyId)
        .where('role', isEqualTo: 'field_user');

    if (filter != 'All') {
      query = query.where('status', isEqualTo: filter.toLowerCase());
    }

    return query.snapshots().map((snap) => snap.docs.map((doc) =>
        UserModel.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }

  Future<void> approveFieldUser(String uid) async =>
      await _db.collection('users').doc(uid).update({'status': 'active', 'approved': true, 'approvedAt': FieldValue.serverTimestamp()});

  Future<void> rejectFieldUser(String uid, String reason) async =>
      await _db.collection('users').doc(uid).update({'status': 'rejected', 'rejectionReason': reason});

  Future<void> deactivateFieldUser(String uid) async =>
      await _db.collection('users').doc(uid).update({'status': 'deactivated'});

  /// Activates or deactivates a linked supplier for this company.
  Future<void> toggleSupplierStatus(
      String supplierId, String companyId, bool activate) async {
    try {
      final newStatus = activate ? 'active' : 'deactivated';
      await _db
          .collection('companies')
          .doc(companyId)
          .collection('suppliers')
          .doc(supplierId)
          .update({'status': newStatus});
      _successMessage =
      activate ? 'Supplier activated.' : 'Supplier deactivated.';
    } catch (e) {
      _errorMessage = 'Failed to update supplier status: $e';
    }
    notifyListeners();
  }

  /// Cancels a pending or accepted order.
  Future<void> cancelOrder(String orderId, String companyId) async {
    try {
      await _db
          .collection('companies')
          .doc(companyId)
          .collection('orders')
          .doc(orderId)
          .update({'status': 'cancelled'});

      // Mirror on root orders collection if you use one
      await _db
          .collection('orders')
          .doc(orderId)
          .update({'status': 'cancelled'}).catchError((_) {});

      _successMessage = 'Order cancelled.';
    } catch (e) {
      _errorMessage = 'Failed to cancel order: $e';
    }
    notifyListeners();
  }
}
