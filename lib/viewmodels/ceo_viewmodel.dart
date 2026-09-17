// MVVM: ViewModel — business logic only
import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/subscription_model.dart';
import '../models/order_model.dart';
import '../models/partnership_request_model.dart';
import '../models/company_model.dart';
import '../models/supplier_model.dart';
import '../repositories/order_repository.dart';
import '../repositories/partnership_request_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/company_repository.dart';
import '../repositories/invitation_repository.dart';
import '../services/cloud_function_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/cloudinary_service.dart';
import '../constants/app_constants.dart';
import '../constants/firestore_paths.dart';
import '../utils/app_exception.dart';
import '../utils/invite_code_generator.dart';

class CeoViewModel extends ChangeNotifier {
  final String? _uid;
  final String _name;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final PartnershipRequestRepository _partnershipRepo;
  final UserRepository _userRepo;
  final CompanyRepository _companyRepo;
  final InvitationRepository _invitationRepo;
  final OrderRepository _orderRepo;
  final NotificationService _notificationService;
  final StorageService _storageService = StorageService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  CompanyModel? _company;
  List<SupplierModel> _allMarketplaceSuppliers = [];
  List<SupplierModel> _marketplaceSuppliers = [];
  String _marketplaceSearchQuery = '';
  String _marketplaceCity = 'All';
  String _marketplaceCategory = 'All';
  bool _marketplaceVerifiedOnly = false;
  String _marketplaceSortBy = 'Rating';

  String? _partnershipWatchCompanyId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _partnershipRequestsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _linkedSuppliersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _marketplaceSuppliersSub;
  final Map<String, PartnershipRequestModel> _latestPartnershipBySupplierId = {};
  final Set<String> _activePartnerSupplierIds = {};
  List<PartnershipRequestModel> _receivedPartnershipRequests = [];
  List<PartnershipRequestModel> _sentPartnershipRequests = [];
  bool _partnershipRequestsReady = false;

  bool _appealSubmitted = false;
  bool get appealSubmitted => _appealSubmitted;

  CeoViewModel(
      this._uid,
      this._name,
      this._orderRepo,
      this._partnershipRepo,
      this._userRepo,
      this._companyRepo,
      this._invitationRepo,
      this._notificationService, [
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
  bool get partnershipRequestsReady => _partnershipRequestsReady;
  List<PartnershipRequestModel> get receivedPartnershipRequests =>
      List<PartnershipRequestModel>.unmodifiable(_receivedPartnershipRequests);
  List<PartnershipRequestModel> get sentPartnershipRequests =>
      List<PartnershipRequestModel>.unmodifiable(_sentPartnershipRequests);
  List<PartnershipRequestModel> get pendingReceivedPartnershipRequests =>
      _receivedPartnershipRequests
          .where((r) => r.status == 'pending')
          .toList(growable: false);

  /// CEO Sent partnership requests that are currently waiting for supplier approval.
  List<PartnershipRequestModel> get pendingSentPartnershipRequests =>
      _sentPartnershipRequests
          .where((r) => r.status == 'pending')
          .toList(growable: false);

  void clearAppealState() {
    _appealSubmitted = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> submitAppeal(String message, File? file, String? phone, {Uint8List? webBytes}) async {
    if (_uid == null) {
      _errorMessage = 'User authentication error. Please log in again.';
      notifyListeners();
      return;
    }

    developer.log('[Appeal] CEO Submission Started for UID: $_uid');
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Duplicate Check
      developer.log('[Appeal] Step 1: Checking for existing pending appeals...');
      final existing = await _db.collection('appeals')
          .where('uid', isEqualTo: _uid)
          .where('status', isEqualTo: 'pending')
          .get()
          .timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('Connection check timed out.'));

      if (existing.docs.isNotEmpty) {
        developer.log('[Appeal] Blocked: Existing pending appeal found.');
        throw Exception('Your appeal is already under review.');
      }

      // 2. Cloudinary Upload
      String? imageUrl;
      if (webBytes != null || file != null) {
        developer.log('[Appeal] Step 2: Uploading image to Cloudinary...');
        if (webBytes != null) {
          imageUrl = await CloudinaryService.uploadImageBytes(
            bytes: webBytes,
            folder: 'ratebridge/appeals',
            filename: 'ceo_appeal_${_uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ).timeout(const Duration(seconds: 45), onTimeout: () => throw TimeoutException('Image upload timed out.'));
        } else if (file != null) {
          imageUrl = await CloudinaryService.uploadImage(
            filePath: file.path,
            folder: 'ratebridge/appeals',
          ).timeout(const Duration(seconds: 45), onTimeout: () => throw TimeoutException('Image upload timed out.'));
        }

        if (imageUrl == null) {
          developer.log('[Appeal] Error: Cloudinary upload returned null.');
          throw Exception('Failed to upload supporting document. Please try again.');
        }
        developer.log('[Appeal] Step 2: Image uploaded successfully: $imageUrl');
      }

      // 3. Prepare Data
      developer.log('[Appeal] Step 3: Fetching user data...');
      final userDoc = await _userRepo.getUserDoc(_uid!).timeout(const Duration(seconds: 10));
      
      // 4. Firestore Write
      developer.log('[Appeal] Step 4: Writing appeal to Firestore...');
      await _db.collection('appeals').add({
        'uid': _uid,
        'role': 'CEO',
        'name': userDoc.name,
        'companyId': _company?.id ?? userDoc.companyId,
        'message': message,
        'phone': phone,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'rejectionReason': userDoc.rejectionReason ?? '',
      }).timeout(const Duration(seconds: 15), onTimeout: () => throw TimeoutException('Firestore write timed out.'));

      developer.log('[Appeal] Final Step: Submission complete.');
      _appealSubmitted = true;
    } catch (e) {
      developer.log('[Appeal] Submission Failed: $e');
      _errorMessage = e is TimeoutException 
          ? 'Network timeout. Please check your internet connection and try again.' 
          : e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
        ensurePartnershipStatusWatch(companyDoc.id);
        final companyActive =
            _company!.status.toLowerCase() == 'active';
        if (companyActive &&
            (_company!.inviteCode == null ||
                _company!.inviteCode!.isEmpty ||
                _company!.inviteCode == 'RB-XXXXXX')) {
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

      _company = _company?.copyWith(
        inviteCode: newKey,
        inviteCodeGeneratedAt: DateTime.now(),
      );
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

  @override
  void dispose() {
    _marketplaceSuppliersSub?.cancel();
    _stopPartnershipStatusWatch();
    super.dispose();
  }

  void ensurePartnershipStatusWatch(String companyId) {
    if (companyId.isEmpty) return;
    if (_partnershipWatchCompanyId == companyId &&
        _partnershipRequestsSub != null) {
      return;
    }

    _stopPartnershipStatusWatch();
    _partnershipWatchCompanyId = companyId;

    _partnershipRequestsSub = _db
        .collection(FirestorePaths.partnershipRequestsCol)
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .listen(
      (snap) {
        final all = snap.docs
            .map((doc) => PartnershipRequestModel.fromMap(doc.id, doc.data()))
            .toList();

        _latestPartnershipBySupplierId.clear();
        final grouped = <String, List<PartnershipRequestModel>>{};
        for (final req in all) {
          grouped.putIfAbsent(req.supplierId, () => []).add(req);
        }
        for (final entry in grouped.entries) {
          entry.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _latestPartnershipBySupplierId[entry.key] = entry.value.first;
        }

        _receivedPartnershipRequests = _sortPartnershipRequestsNewest(
          all.where((r) => r.initiatedBy == 'supplier'),
        );
        _sentPartnershipRequests = _sortPartnershipRequestsNewest(
          all.where((r) => r.initiatedBy == 'ceo'),
        );
        _partnershipRequestsReady = true;
        notifyListeners();
      },
      onError: (_) {
        _partnershipRequestsReady = true;
        _errorMessage = 'Failed to load partnership requests.';
        notifyListeners();
      },
    );

    _linkedSuppliersSub = _db
        .collection(FirestorePaths.companiesCol)
        .doc(companyId)
        .collection('suppliers')
        .snapshots()
        .listen(
      (snap) {
        _activePartnerSupplierIds
          ..clear()
          ..addAll(
            snap.docs.where((doc) {
              final status =
                  (doc.data()['status'] as String?)?.toLowerCase() ?? 'active';
              return status == 'active' || status == 'approved';
            }).map((doc) => doc.id),
          );
        notifyListeners();
      },
      onError: (_) {
        notifyListeners();
      },
    );
  }

  void _stopPartnershipStatusWatch() {
    _partnershipRequestsSub?.cancel();
    _linkedSuppliersSub?.cancel();
    _partnershipRequestsSub = null;
    _linkedSuppliersSub = null;
    _partnershipWatchCompanyId = null;
    _latestPartnershipBySupplierId.clear();
    _activePartnerSupplierIds.clear();
    _receivedPartnershipRequests = [];
    _sentPartnershipRequests = [];
    _partnershipRequestsReady = false;
  }

  List<PartnershipRequestModel> _sortPartnershipRequestsNewest(
    Iterable<PartnershipRequestModel> requests,
  ) {
    return List<PartnershipRequestModel>.from(requests)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  String? linkRejectionReasonFor(String supplierId) {
    if (supplierId.isEmpty) return null;
    final request = _latestPartnershipBySupplierId[supplierId];
    if (request?.status == 'rejected') {
      return request!.rejectionReason;
    }
    return null;
  }

  String linkStatusFor(String supplierId) {
    if (supplierId.isEmpty) return 'Not Invited';
    if (_activePartnerSupplierIds.contains(supplierId)) {
      return 'Already Partners';
    }

    final request = _latestPartnershipBySupplierId[supplierId];
    if (request == null) return 'Not Invited';

    switch (request.status) {
      case 'pending':
        return 'Request Pending';
      case 'accepted':
        // Stale accepted request without an active link is not a partner.
        return 'Not Invited';
      case 'rejected':
        return 'Request Rejected';
      case 'removed':
        return 'Not Invited';
      default:
        return 'Not Invited';
    }
  }

  /// Blocks duplicate email invites when the supplier is already linked or has
  /// a pending partnership / invite. Uses [linkStatusFor] (same as Marketplace).
  Future<String?> blockReasonForSupplierEmailInvite(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return 'Enter a supplier email address.';

    final companyId = _company?.id ?? '';
    if (companyId.isEmpty) {
      return 'Company not ready. Please try again.';
    }

    ensurePartnershipStatusWatch(companyId);
    await _waitForPartnershipStatusReady();

    final supplier = await _findSupplierByEmail(trimmed);
    if (supplier != null) {
      await _ensureActivePartnerKnown(companyId, supplier.id);
      switch (linkStatusFor(supplier.id)) {
        case 'Already Partners':
          return "You're already partnered with this supplier";
        case 'Request Pending':
          return 'A partnership request with this supplier is already pending';
      }
    }

    // Also catch pending email invites (invitations collection) and any
    // pending partnership rows that stored this email.
    final lower = trimmed.toLowerCase();
    final pendingByEmail = _latestPartnershipBySupplierId.values.any(
      (req) =>
          req.status == 'pending' &&
          (req.supplierEmail?.trim().toLowerCase() ?? '') == lower,
    );
    if (pendingByEmail) {
      return 'A partnership request with this supplier is already pending';
    }

    if (await _invitationRepo.hasPendingSupplierInvite(
      companyId: companyId,
      email: trimmed,
    )) {
      return 'An invite to this email is already pending';
    }

    return null;
  }

  Future<void> _waitForPartnershipStatusReady({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_partnershipRequestsReady) return;
    final end = DateTime.now().add(timeout);
    while (!_partnershipRequestsReady && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  /// One-shot fill for [supplierId] when the live watch has not caught up yet.
  Future<void> _ensureActivePartnerKnown(
    String companyId,
    String supplierId,
  ) async {
    if (supplierId.isEmpty || _activePartnerSupplierIds.contains(supplierId)) {
      return;
    }
    final linkSnap = await _db
        .collection(FirestorePaths.companiesCol)
        .doc(companyId)
        .collection('suppliers')
        .doc(supplierId)
        .get();
    if (!linkSnap.exists) return;
    final status =
        (linkSnap.data()?['status'] as String?)?.toLowerCase() ?? 'active';
    if (status == 'active' || status == 'approved') {
      _activePartnerSupplierIds.add(supplierId);
    }
  }

  Future<SupplierModel?> _findSupplierByEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();

    // Prefer already-loaded marketplace cache when available.
    for (final supplier in _allMarketplaceSuppliers) {
      if (supplier.email.trim().toLowerCase() == lower) return supplier;
    }

    Future<SupplierModel?> queryExact(String value) async {
      final snap = await _db
          .collection('suppliers')
          .where('email', isEqualTo: value)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return SupplierModel.fromMap({...doc.data(), 'id': doc.id});
    }

    final exact = await queryExact(trimmed);
    if (exact != null) return exact;
    if (lower != trimmed) {
      final byLower = await queryExact(lower);
      if (byLower != null) return byLower;
    }
    return null;
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
      final partnershipPending = await _db
          .collection('partnershipRequests')
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: 'pending')
          .where('initiatedBy', isEqualTo: 'supplier')
          .get();

      final pendingApprovals = await _db.collection('orders')
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: 'pending_approval')
          .get();

      final sub = await _db.collection('subscriptions').doc(companyId).get();
      final plan = sub.exists ? (sub.data()?['plan'] ?? 'Free') : 'Free';
      final expiresAt = sub.exists ? (sub.data()?['expiresAt'] as Timestamp?)?.toDate() : null;

      final companyData = doc.data();

      return {
        'companyName': companyData?['name'] ?? 'Workspace',
        'inviteCode': companyData?['inviteCode'] ?? 'RB-XXXXXX',
        'plan': plan,
        'activeSupplierCount': suppliers.docs.length,
        'fieldUserCount': team.docs.length,
        'pendingJoinCount': partnershipPending.docs.length,
        'pendingOrderApprovals': pendingApprovals.docs.length,
        'expiresAt': expiresAt,
      };
    });
  }

  Stream<List<OrderModel>> watchCompanyOrders(String companyId, String status) {
    if (companyId.isEmpty) {
      return Stream.value(const []);
    }

    final uid = _uid;

    Query<Map<String, dynamic>> buildQuery({required bool withOrderBy}) {
      Query<Map<String, dynamic>> query =
          _db.collection('orders').where('companyId', isEqualTo: companyId);
      if (status != 'All') {
        final statuses = _orderStatusesForTab(status);
        if (statuses.length == 1) {
          query = query.where('status', isEqualTo: statuses.first);
        } else if (statuses.isNotEmpty) {
          query = query.where('status', whereIn: statuses);
        }
      }
      if (withOrderBy) {
        query = query.orderBy('createdAt', descending: true);
      }
      return query;
    }

    return buildQuery(withOrderBy: true).snapshots().transform(
      StreamTransformer.fromHandlers(
        handleData: (snap, sink) {
          var orders = snap.docs
              .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
              .toList();
          if (uid != null) {
            orders = orders.where((o) => !o.hiddenBy.contains(uid)).toList();
          }
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          sink.add(orders);
        },
        handleError: (error, stackTrace, sink) async {
          if (error is FirebaseException &&
              error.code == 'failed-precondition') {
            try {
              final snap = await buildQuery(withOrderBy: false).get();
              var orders = snap.docs
                  .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
                  .toList();
              if (uid != null) {
                orders = orders.where((o) => !o.hiddenBy.contains(uid)).toList();
              }
              orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              sink.add(orders);
              return;
            } catch (_) {}
          }
          sink.addError(error, stackTrace);
        },
      ),
    );
  }

  List<String> _orderStatusesForTab(String tabLabel) {
    switch (tabLabel) {
      case 'Pending':
        return [
          AppConstants.statusPendingApproval,
          AppConstants.statusPending,
          AppConstants.statusAccepted,
          AppConstants.statusInProgress,
          AppConstants.statusDelivered,
          AppConstants.statusCancellationRequested,
        ];
      case 'Confirmed':
        return [AppConstants.statusConfirmed];
      case 'Cancelled':
        return [
          AppConstants.statusCancelled,
          AppConstants.statusRejected,
        ];
      default:
        // Attempt to match by name if not one of the custom grouped labels
        return [tabLabel.toLowerCase().replaceAll(' ', '_')];
    }
  }

  Future<void> approveOrder(OrderModel order) async {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      if (order.status != AppConstants.statusPendingApproval) {
        throw Exception('Only orders awaiting approval can be approved.');
      }

      // Refresh from Firestore so we notify the real supplier uid on the doc.
      final fresh = await _orderRepo.getOrderById(order.orderId) ?? order;
      final supplierId = fresh.supplierId.trim().isNotEmpty
          ? fresh.supplierId.trim()
          : order.supplierId.trim();
      if (supplierId.isEmpty) {
        throw Exception(
          'Cannot notify supplier: this order has no supplier id.',
        );
      }

      await _orderRepo.updateStatus(
        fresh.orderId,
        fresh.companyId.isNotEmpty ? fresh.companyId : order.companyId,
        AppConstants.statusPending,
      );

      try {
        await _notificationService.notifyOrderApprovedByCeo(
          supplierId: supplierId,
          orderId: fresh.orderId,
          companyId:
              fresh.companyId.isNotEmpty ? fresh.companyId : order.companyId,
          materialName: fresh.materialName.isNotEmpty
              ? fresh.materialName
              : order.materialName,
          fieldUserName: fresh.fieldUserName.isNotEmpty
              ? fresh.fieldUserName
              : order.fieldUserName,
          companyName: _company?.name,
        );
      } catch (notifyError) {
        // Status already updated — surface notify failure so it isn't silent.
        _errorMessage =
            'Order approved, but supplier notification failed: $notifyError';
        notifyListeners();
        return;
      }

      _successMessage = 'Order approved and supplier notified.';
    } catch (e) {
      _errorMessage = 'Failed to approve order: $e';
    }
    notifyListeners();
  }

  Future<void> rejectOrder(OrderModel order, {String reason = ''}) async {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      if (order.status != AppConstants.statusPendingApproval) {
        throw Exception('Only orders awaiting approval can be rejected.');
      }
      await _orderRepo.updateStatus(
        order.orderId,
        order.companyId,
        AppConstants.statusRejected,
        reason: reason.trim().isEmpty ? 'Rejected by CEO' : reason.trim(),
        rejectedBy: 'ceo',
      );
      await _notificationService.notifyOrderRejected(
        fieldUserUid: order.fieldUserUid,
        orderId: order.orderId,
        companyId: order.companyId,
        materialName: order.materialName,
        supplierName: order.supplierName,
        reason: reason.trim().isEmpty ? 'Rejected by company approval' : reason.trim(),
      );
      _successMessage = 'Order rejected.';
    } catch (e) {
      _errorMessage = 'Failed to reject order: $e';
    }
    notifyListeners();
  }

  // --- Marketplace Implementation ---

  final List<String> _marketplaceStatuses = ['Active', 'active'];

  bool _isActiveMarketplaceSupplier(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'active';
  }

  List<SupplierModel> _suppliersFromDocs(Iterable<QueryDocumentSnapshot> docs) {
    final suppliers = <SupplierModel>[];
    for (final doc in docs) {
      try {
        final raw = doc.data();
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        data['id'] = doc.id;
        final supplier = SupplierModel.fromMap(data);
        if (_isActiveMarketplaceSupplier(supplier.status) &&
            !supplier.commissionRestricted) {
          suppliers.add(supplier);
        }
      } catch (_) {}
    }
    return suppliers;
  }

  Future<List<SupplierModel>> _fetchMarketplaceSuppliers() async {
    try {
      final snap = await _db
          .collection('suppliers')
          .where('status', whereIn: _marketplaceStatuses)
          .get();
      return _suppliersFromDocs(snap.docs);
    } catch (_) {
      final snap = await _db.collection('suppliers').get();
      return _suppliersFromDocs(snap.docs);
    }
  }

  Future<void> loadMarketplace() async {
    final companyId = _company?.id;
    if (companyId != null && companyId.isNotEmpty) {
      ensurePartnershipStatusWatch(companyId);
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _marketplaceSuppliersSub?.cancel();
    try {
      _marketplaceSuppliersSub = _db
          .collection('suppliers')
          .where('status', whereIn: _marketplaceStatuses)
          .snapshots()
          .listen(
        (snap) {
          _allMarketplaceSuppliers = _suppliersFromDocs(snap.docs);
          _applyMarketplaceFilters();
          _isLoading = false;
          notifyListeners();
        },
        onError: (_) {
          _fetchMarketplaceSuppliers().then((suppliers) {
            _allMarketplaceSuppliers = suppliers;
            _applyMarketplaceFilters();
            _isLoading = false;
            notifyListeners();
          });
        },
      );
    } catch (e) {
      _errorMessage = 'Failed to load marketplace. Please try again.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchSuppliers(String queryText) async {
    _marketplaceSearchQuery = queryText.trim();
    if (_allMarketplaceSuppliers.isEmpty && queryText.isEmpty) {
      return loadMarketplace();
    }
    _applyMarketplaceFilters();
    notifyListeners();
  }

  Future<void> applyFilters({
    String? city,
    String? category,
    bool? verifiedOnly,
  }) async {
    if (city != null) _marketplaceCity = city;
    if (category != null) _marketplaceCategory = category;
    if (verifiedOnly != null) _marketplaceVerifiedOnly = verifiedOnly;

    if (_allMarketplaceSuppliers.isEmpty) {
      await loadMarketplace();
      return;
    }

    _applyMarketplaceFilters();
    notifyListeners();
  }

  Future<void> sortSuppliers(String criteria) async {
    _marketplaceSortBy = criteria;
    _applyMarketplaceFilters();
    notifyListeners();
  }

  void _applyMarketplaceFilters() {
    final query = _marketplaceSearchQuery.toLowerCase();
    final city = _marketplaceCity;
    final category = _marketplaceCategory;

    var list = _allMarketplaceSuppliers.where((supplier) {
      if (query.isNotEmpty) {
        final haystacks = [
          supplier.name,
          supplier.email,
          supplier.city,
          supplier.materialType,
          supplier.businessType,
          supplier.ownerFullName,
        ];
        final matchesQuery = haystacks.any(
          (value) => (value ?? '').toString().toLowerCase().contains(query),
        );
        if (!matchesQuery) return false;
      }

      if (city != 'All' &&
          supplier.city.trim().toLowerCase() != city.trim().toLowerCase()) {
        return false;
      }

      if (category != 'All') {
        final material = supplier.materialType.trim().toLowerCase();
        final businessType = (supplier.businessType ?? '').trim().toLowerCase();
        final cats = supplier.categories
            .map((c) => c.trim().toLowerCase())
            .where((c) => c.isNotEmpty);
        final target = category.trim().toLowerCase();
        final matchesCategory = material == target ||
            businessType == target ||
            cats.contains(target);
        if (!matchesCategory) return false;
      }

      if (_marketplaceVerifiedOnly && !supplier.isVerified) {
        return false;
      }

      return true;
    }).toList();

    if (_marketplaceSortBy == 'Name') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    }

    _marketplaceSuppliers = list;
  }

  Future<void> sendPartnershipRequest(
    String supplierId, {
    String? message,
  }) async {
    final company = _company;
    if (company == null || supplierId.isEmpty) return;

    final plan = kPlans.firstWhere((p) => p.planKey == company.plan,
        orElse: () => kPlans.first);
    if (plan.maxSuppliers != -1 &&
        _activePartnerSupplierIds.length >= plan.maxSuppliers) {
      _errorMessage =
          'Supplier limit reached for your ${plan.name} plan (${plan.maxSuppliers}). Please upgrade for more connections.';
      notifyListeners();
      return;
    }

    try {
      final supplierDoc =
          await _db.collection('suppliers').doc(supplierId).get();
      if (!supplierDoc.exists) return;
      final supplierData = supplierDoc.data()!;

      final requestId = await _partnershipRepo.createRequest(
        companyId: company.id,
        companyName: company.name,
        supplierId: supplierId,
        supplierName:
            supplierData['name'] ?? supplierData['businessName'] ?? 'Supplier',
        initiatedBy: 'ceo',
        message: message,
        supplierEmail: supplierData['email'] as String?,
        supplierCity: supplierData['city'] as String?,
        supplierCategories: supplierData['categories'] is List
            ? List<String>.from(supplierData['categories'])
            : const [],
        supplierRating: (supplierData['rating'] as num? ?? 0).toDouble(),
      );

      await _notificationService.notifyPartnershipInvitation(
        recipientUserId: supplierId,
        companyName: company.name,
        requestId: requestId,
        companyId: company.id,
      );

      _successMessage = 'Partnership request sent successfully.';
    } on AppException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to send partnership request. Please try again.';
    }
    notifyListeners();
  }

  @Deprecated('Use sendPartnershipRequest')
  Future<void> sendInvitation(String supplierId) =>
      sendPartnershipRequest(supplierId);

  @Deprecated('Use receivedPartnershipRequests / sentPartnershipRequests')
  Stream<List<PartnershipRequestModel>> watchPartnershipRequests(
    String companyId,
    String type,
  ) {
    if (companyId.isEmpty) return Stream.value(const []);
    ensurePartnershipStatusWatch(companyId);
    final list = type == 'Sent'
        ? _sentPartnershipRequests
        : _receivedPartnershipRequests;
    return Stream.value(List<PartnershipRequestModel>.from(list));
  }

  @Deprecated('Use receivedPartnershipRequests / sentPartnershipRequests')
  Stream<List<PartnershipRequestModel>> watchJoinRequests(
    String companyId,
    String type,
  ) =>
      watchPartnershipRequests(companyId, type);

  Future<void> acceptPartnershipRequest(String reqId) async {
    final company = _company;
    if (company != null) {
      final plan = kPlans.firstWhere((p) => p.planKey == company.plan,
          orElse: () => kPlans.first);
      if (plan.maxSuppliers != -1 &&
          _activePartnerSupplierIds.length >= plan.maxSuppliers) {
        _errorMessage =
            'Supplier limit reached for your ${plan.name} plan (${plan.maxSuppliers}). Please upgrade to accept more partnerships.';
        notifyListeners();
        return;
      }
    }

    try {
      final reqSnap = await _db
          .collection(FirestorePaths.partnershipRequestsCol)
          .doc(reqId)
          .get();
      final reqData = reqSnap.data();
      await _partnershipRepo.acceptRequest(reqId);
      if (reqData != null &&
          PartnershipRequestModel.fromMap(reqId, reqData).isSupplierInitiated) {
        await _notificationService.notifyPartnershipAccepted(
          recipientUserId: reqData['supplierId'] as String,
          senderName: _company?.name ?? reqData['companyName'] as String? ?? '',
          companyId: reqData['companyId'] as String,
        );
      }
      _successMessage = 'Partnership accepted.';
    } on AppException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Failed to accept partnership. Please try again.';
    }
    notifyListeners();
  }

  Future<void> acceptJoinRequest(String reqId, String supplierUid) async {
    await acceptPartnershipRequest(reqId);
  }

  Future<void> rejectPartnershipRequest(String reqId, String reason) async {
    try {
      final reqSnap = await _db
          .collection(FirestorePaths.partnershipRequestsCol)
          .doc(reqId)
          .get();
      final reqData = reqSnap.data();
      await _partnershipRepo.rejectRequest(reqId, reason);
      if (reqData != null &&
          PartnershipRequestModel.fromMap(reqId, reqData).isSupplierInitiated) {
        await _notificationService.notifyPartnershipDeclined(
          recipientUserId: reqData['supplierId'] as String,
          senderName: _company?.name ?? reqData['companyName'] as String? ?? '',
          companyId: reqData['companyId'] as String,
        );
      }
      _successMessage = 'Partnership request rejected.';
    } on AppException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Failed to reject partnership. Please try again.';
    }
    notifyListeners();
  }

  Future<void> rejectJoinRequest(String reqId, String reason) async {
    await rejectPartnershipRequest(reqId, reason);
  }

  Future<void> withdrawPartnershipRequest(String requestId) async {
    try {
      await _partnershipRepo.withdrawRequest(requestId);
      _successMessage = 'Partnership request withdrawn.';
    } on AppException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to withdraw partnership request: $e';
    }
    notifyListeners();
  }

  Stream<List<Map<String, dynamic>>> watchMySuppliers(String companyId) {
    if (companyId.isEmpty) return Stream.value(const []);

    return _db
        .collection('companies')
        .doc(companyId)
        .collection('suppliers')
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isEmpty) return <Map<String, dynamic>>[];

      final profiles = await Future.wait(
        snap.docs.map(
          (doc) => _db.collection('suppliers').doc(doc.id).get(),
        ),
      );

      final results = <Map<String, dynamic>>[];
      for (var i = 0; i < snap.docs.length; i++) {
        final doc = snap.docs[i];
        final link = Map<String, dynamic>.from(doc.data());
        link['id'] = doc.id;

        final profileSnap = profiles[i];
        final profile = profileSnap.exists && profileSnap.data() != null
            ? Map<String, dynamic>.from(profileSnap.data()!)
            : const <String, dynamic>{};

        // Link docs from some accept paths only store status/ids (or
        // `supplierName`). Prefer link fields, then profile name/businessName.
        final displayName = _firstNonEmpty([
          link['name'],
          link['supplierName'],
          link['businessName'],
          profile['name'],
          profile['businessName'],
        ]) ??
            'Supplier';

        link['name'] = displayName;
        link['businessName'] = _firstNonEmpty([
              link['businessName'],
              profile['businessName'],
              profile['name'],
            ]) ??
            displayName;
        link['supplierName'] = _firstNonEmpty([
              link['supplierName'],
              displayName,
            ]) ??
            displayName;
        link['city'] = _firstNonEmpty([
              link['city'],
              profile['city'],
            ]) ??
            '';
        link['materialType'] = _firstNonEmpty([
              link['materialType'],
              profile['materialType'],
              profile['businessType'],
            ]) ??
            'General';
        link['email'] = _firstNonEmpty([
              link['email'],
              profile['email'],
            ]) ??
            '';
        link['rating'] =
            link['rating'] ?? profile['rating'] ?? profile['globalAvgRating'] ?? 0;

        results.add(link);
      }
      return results;
    });
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  Future<void> removeSupplier(String supplierId) async {
    final company = _company;
    if (company == null) return;
    try {
      await _partnershipRepo.removePartnership(
        companyId: company.id,
        supplierId: supplierId,
      );
      await _notificationService.notifyPartnershipRemoved(
        recipientUserId: supplierId,
        companyName: company.name,
        companyId: company.id,
      );
      _successMessage = 'Partnership removed.';
    } catch (e) {
      _errorMessage = 'Failed to remove partnership: $e';
    }
    notifyListeners();
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

  /// Cancels a pending order, or requests cancel when supplier already accepted.
  Future<void> cancelOrder(
    String orderId,
    String companyId, {
    String? reason,
    OrderModel? order,
  }) async {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      final resolvedCompanyId =
          companyId.isNotEmpty ? companyId : (_company?.id ?? '');
      if (resolvedCompanyId.isEmpty) {
        throw Exception('Company not ready.');
      }

      OrderModel? current = order;
      if (current == null || current.orderId != orderId) {
        final doc = await _db.collection('orders').doc(orderId).get();
        if (!doc.exists || doc.data() == null) {
          throw Exception('Order not found.');
        }
        current = OrderModel.fromMap(orderId, doc.data()!);
      }

      final status = current.status.toLowerCase();
      final canDirect = status == AppConstants.statusPending ||
          status == AppConstants.statusPendingApproval;
      final needsRequest = status == AppConstants.statusAccepted ||
          status == AppConstants.statusInProgress.toLowerCase() ||
          status.replaceAll('_', '') == 'inprogress';

      if (canDirect) {
        await _orderRepo.cancelOrderDirect(
          orderId: orderId,
          companyId: resolvedCompanyId,
        );
        await _notificationService.notifyOrderCancelled(
          supplierId: current.supplierId,
          orderId: orderId,
          companyId: resolvedCompanyId,
          materialName: current.materialName,
          fieldUserName: _company?.name ?? 'Company',
        );
        _successMessage = 'Order cancelled.';
      } else if (needsRequest) {
        final trimmed = reason?.trim() ?? '';
        if (trimmed.isEmpty) {
          throw Exception('Please enter a cancellation reason.');
        }
        await _orderRepo.requestOrderCancellation(
          orderId: orderId,
          companyId: resolvedCompanyId,
          reason: trimmed,
        );
        await _notificationService.notifyCancellationRequested(
          supplierId: current.supplierId,
          orderId: orderId,
          companyId: resolvedCompanyId,
          materialName: current.materialName,
          companyName: _company?.name ?? 'Company',
          reason: trimmed,
        );
        _successMessage =
            'Cancellation requested. Waiting for supplier response.';
      } else {
        throw Exception('This order cannot be cancelled in its current status.');
      }
    } catch (e) {
      _errorMessage = 'Failed to cancel order: $e';
    }
    notifyListeners();
  }

  /// Soft-deletes a single order from history.
  Future<void> hideOrder(String orderId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _orderRepo.hideOrderForUser(orderId, uid);
      _successMessage = 'Order removed from history.';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Bulk soft-deletes orders.
  Future<void> hideOrders(List<String> orderIds) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _orderRepo.hideOrdersForUser(orderIds, uid);
      _successMessage = 'Orders removed from history.';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
