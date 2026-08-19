// MVVM: ViewModel — business logic only
import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rfq_model.dart';
import '../models/rfq_bid_model.dart';
import '../models/material_model.dart';
import '../models/order_model.dart';
import '../models/rating_model.dart';
import '../models/transaction_model.dart';
import '../constants/app_constants.dart';
import '../constants/firestore_paths.dart';
import '../models/company_model.dart';
import '../models/user_model.dart';
import '../models/invitation_model.dart';
import '../repositories/material_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/price_history_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/company_repository.dart';
import '../models/partner_company_stats.dart';
import '../models/partnership_request_model.dart';
import '../repositories/partnership_request_repository.dart';
import '../services/cloudinary_service.dart';
import '../utils/app_exception.dart';
import '../services/storage_service.dart';
import '../services/cloud_function_service.dart';
import '../services/notification_service.dart';
import 'auth_viewmodel.dart';

enum SupplierStatus { unknown, pending, rejected, active }

class SupplierViewModel extends ChangeNotifier {
  final MaterialRepository _materialRepo;
  final OrderRepository _orderRepo;
  final TransactionRepository _transactionRepo;
  final StorageService _storageService;
  final UserRepository _userRepo;
  final CompanyRepository _companyRepo;
  final PartnershipRequestRepository _partnershipRepo;
  final NotificationService _notificationService;
  final CloudFunctionService _cloudFunctions;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  SupplierViewModel(
    this._materialRepo,
    this._orderRepo,
    this._transactionRepo,
    this._storageService,
    PriceHistoryRepository _,
    this._cloudFunctions,
    this._userRepo,
    this._companyRepo,
    this._partnershipRepo,
    this._notificationService,
  );

  static String monthKey([DateTime? date]) =>
      DateFormat('yyyy-MM').format(date ?? DateTime.now());

  String? _supplierUid;
  String? _selectedCompanyId;
  String? _rejectionReason;
  String? _error;
  String? _successMessage;
  bool _isLoading = false;
  bool _appealSubmitted = false;

  List<MaterialModel> _materials = [];
  List<OrderModel> _orders = [];
  List<RatingModel> _ratings = [];
  List<TransactionModel> _transactions = [];
  List<CompanyModel> _companies = [];
  List<CompanyModel> _companyDirectory = [];
  List<CompanyModel> _allCompanyDirectory = [];
  String _directorySearchQuery = '';
  String? _directoryCityFilter;
  List<OrderModel> _allSupplierOrders = [];
  List<TransactionModel> _allSupplierTransactions = [];
  List<RatingModel> _allSupplierRatings = [];
  bool _partnershipHubDataLoaded = false;
  List<InvitationModel> _invitations = [];
  List<Map<String, dynamic>> _monthlyChart = [];
  List<MonthlyEarning> _monthlyEarnings = [];
  UserModel? _profile;
  String _status = 'pending';

  StreamSubscription? _statusSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _partnershipRequestsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _linkedCompaniesSub;
  List<PartnershipRequestModel> _allPartnershipRequests = [];
  final Map<String, PartnershipRequestModel> _latestPartnershipByCompanyId = {};
  final Set<String> _activePartnerCompanyIds = {};
  List<PartnershipRequestModel> _incomingPartnershipRequests = [];
  List<PartnershipRequestModel> _outgoingPartnershipRequests = [];
  bool _partnershipListsReady = false;
  StreamSubscription? _companiesSubscription;
  StreamSubscription? _materialsSubscription;
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _earningsSubscription;
  StreamSubscription? _invitationsSubscription;
  StreamSubscription? _ratingsSubscription;

  bool _isDashboardLoading = false;
  bool _companiesLoaded = false;
  bool _companiesLoadFailed = false;
  bool _materialsInitialized = false;
  bool _ordersInitialized = false;
  bool _earningsInitialized = false;
  bool _ratingsInitialized = false;

  // Dashboard Aggregates
  double totalEarnings = 0;
  double netEarnings = 0;
  double pendingEarnings = 0;
  double completedPayouts = 0;

  // Getters
  String? get supplierUid => _supplierUid;
  String? get selectedCompanyId => _selectedCompanyId;
  String? get rejectionReason => _rejectionReason;
  String? get error => _error;
  String? get successMessage => _successMessage;
  bool get isLoading => _isLoading;
  bool get partnershipListsReady => _partnershipListsReady;
  List<PartnershipRequestModel> get incomingPartnershipRequests =>
      List<PartnershipRequestModel>.unmodifiable(_incomingPartnershipRequests);
  List<PartnershipRequestModel> get outgoingPartnershipRequests =>
      List<PartnershipRequestModel>.unmodifiable(_outgoingPartnershipRequests);
  List<PartnershipRequestModel> get allPartnershipRequests =>
      List<PartnershipRequestModel>.unmodifiable(_allPartnershipRequests);
  List<PartnershipRequestModel> get pendingCeoInvitations =>
      _allPartnershipRequests
          .where((r) => r.isCeoInitiated && r.status == 'pending')
          .toList(growable: false);
  List<PartnershipRequestModel> get pendingSupplierSentRequests =>
      _allPartnershipRequests
          .where((r) => r.isSupplierInitiated && r.status == 'pending')
          .toList(growable: false);
  List<PartnershipRequestModel> get pastPartnershipRequests =>
      _allPartnershipRequests
          .where((r) => r.status == 'rejected' || r.status == 'removed')
          .take(10)
          .toList(growable: false);
  int get pendingPartnershipRequestsCount =>
      _allPartnershipRequests.where((r) => r.status == 'pending').length;
  bool get hasAnyPartnershipRequests => _allPartnershipRequests.isNotEmpty;
  List<CompanyModel> get activePartnerCompanies =>
      List<CompanyModel>.unmodifiable(_companies);
  bool get partnershipHubDataLoaded => _partnershipHubDataLoaded;
  bool get isDashboardLoading => _isDashboardLoading;
  bool get companiesLoaded => _companiesLoaded;
  bool get companiesLoadFailed => _companiesLoadFailed;
  bool get appealSubmitted => _appealSubmitted;
  List<MaterialModel> get materials => _materials;
  List<OrderModel> get orders => _orders;
  List<RatingModel> get ratings => _ratings;
  List<TransactionModel> get transactions => _transactions;
  List<CompanyModel> get companies => _companies;
  List<CompanyModel> get companyDirectory => _companyDirectory;
  List<InvitationModel> get invitations => _invitations;
  List<Map<String, dynamic>> get monthlyChart => _monthlyChart;
  List<MonthlyEarning> get monthlyEarnings => _monthlyEarnings;
  UserModel? get profile => _profile;
  String get status => _status;

  int get totalMaterialsCount => _materials.length;

  int get pendingOrdersCount =>
      _orders.where((o) {
        return o.status.toLowerCase() == 'pending';
      }).length;

  int get activeOrdersCount =>
      _orders.where((o) {
        final status = o.status.toLowerCase();
        return status == 'accepted' || status == 'inprogress';
      }).length;

  int get inProgressOrdersCount => activeOrdersCount;

  int get ratingsCount => _ratings.length;

  List<OrderModel> get recentOrders {
    final sorted = List<OrderModel>.from(_orders)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(5).toList();
  }

  List<MaterialModel> get recentMaterials {
    final sorted = List<MaterialModel>.from(_materials)..sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return sorted.take(3).toList();
  }

  double get monthlyEarningsTotal {
    final settledFromTx = _transactions
        .where((t) {
          if (!t.isSettled) return false;
          if (_selectedCompanyId == null) return true;
          return t.companyId == _selectedCompanyId;
        })
        .fold(0.0, (sum, t) => sum + t.supplierEarning);

    final txOrderIds =
        _transactions.where((t) => t.isSettled).map((t) => t.orderId).toSet();
    final now = DateTime.now();
    final fromConfirmed = _orders
        .where((o) {
          if (o.status.toLowerCase() != 'confirmed') return false;
          if (_selectedCompanyId != null && o.companyId != _selectedCompanyId) {
            return false;
          }
          if (txOrderIds.contains(o.orderId)) return false;
          final d = o.confirmedAt ?? o.createdAt;
          return d.year == now.year && d.month == now.month;
        })
        .fold(0.0, (sum, o) {
          if (o.supplierEarning > 0) return sum + o.supplierEarning;
          return sum + (o.totalAmount * (1 - AppConstants.commissionRate));
        });

    return settledFromTx + fromConfirmed;
  }

  int get completedThisMonth =>
      _orders
          .where(
            (o) =>
                o.status == 'confirmed' &&
                o.createdAt.month == DateTime.now().month,
          )
          .length;

  double get averageRating {
    if (_ratings.isEmpty) return 0.0;
    final sum = _ratings.fold<double>(0, (acc, r) => acc + r.rating);
    return sum / _ratings.length;
  }

  void updateAuth(AuthViewModel auth) {
    final newUid = auth.user?.uid;
    if (_supplierUid == newUid) {
      if (newUid != null && auth.user != null) {
        _profile = auth.user;
        _status = auth.user!.status ?? 'pending';
        _rejectionReason = auth.user!.rejectionReason;
      }
      return;
    }

    _cancelSubscriptions();
    _supplierUid = newUid;
    _error = null;
    _companiesLoaded = false;
    _companiesLoadFailed = false;
    _selectedCompanyId = null;
    _companies = [];

    if (_supplierUid != null) {
      _profile = auth.user;
      _status = auth.user?.status ?? 'pending';
      _rejectionReason = auth.user?.rejectionReason;
      _ensureAuthAndLoad();
    }
    notifyListeners();
  }

  Future<void> retryInitialLoad() async {
    if (_supplierUid == null) return;
    _error = null;
    _companiesLoaded = false;
    _companiesLoadFailed = false;
    notifyListeners();
    await _ensureAuthAndLoad();
  }

  Future<void> _ensureAuthAndLoad() async {
    final uid = _supplierUid;
    if (uid == null) return;
    ensurePartnershipStatusWatch();
    loadLinkedCompanies();
    loadInvitations();
    loadNotificationPreferences();
  }

  static const Map<String, bool> defaultNotificationPrefs = {
    'pushEnabled': true,
    'newOrders': true,
    'orderUpdates': true,
    'chatMessages': true,
    'ratings': true,
    'earnings': true,
  };

  Map<String, bool> _notificationPrefs = Map<String, bool>.from(
    defaultNotificationPrefs,
  );
  bool _notificationPrefsLoaded = false;
  bool _notificationPrefsSaving = false;

  bool get notificationPrefsLoaded => _notificationPrefsLoaded;
  bool get notificationPrefsSaving => _notificationPrefsSaving;
  Map<String, bool> get notificationPrefs =>
      Map<String, bool>.unmodifiable(_notificationPrefs);

  Map<String, bool> _parseNotificationPrefs(dynamic raw) {
    if (raw is! Map) {
      return Map<String, bool>.from(defaultNotificationPrefs);
    }
    return {
      for (final entry in defaultNotificationPrefs.entries)
        entry.key: raw[entry.key] == true,
    };
  }

  Future<void> loadNotificationPreferences() async {
    if (_supplierUid == null) return;
    try {
      final snap = await _db.collection('users').doc(_supplierUid!).get();
      _notificationPrefs = _parseNotificationPrefs(
        snap.data()?['notificationPreferences'],
      );
      _notificationPrefsLoaded = true;
    } catch (e) {
      _error ??= e.toString();
      _notificationPrefsLoaded = true;
    }
    notifyListeners();
  }

  Future<String?> saveNotificationPreferences(Map<String, bool> prefs) async {
    if (_supplierUid == null) return 'Not signed in';
    _notificationPrefsSaving = true;
    notifyListeners();
    try {
      await _userRepo.updateUserDoc(_supplierUid!, {
        'notificationPreferences': prefs,
      });
      _notificationPrefs = Map<String, bool>.from(prefs);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _notificationPrefsSaving = false;
      notifyListeners();
    }
  }

  void _cancelSubscriptions() {
    _statusSubscription?.cancel();
    _companiesSubscription?.cancel();
    _materialsSubscription?.cancel();
    _ordersSubscription?.cancel();
    _earningsSubscription?.cancel();
    _invitationsSubscription?.cancel();
    _ratingsSubscription?.cancel();
    _stopPartnershipStatusWatch();
  }

  void ensurePartnershipStatusWatch() {
    final supplierId = _supplierUid;
    if (supplierId == null || supplierId.isEmpty) return;
    if (_partnershipRequestsSub != null) return;

    _partnershipRequestsSub = _db
        .collection(FirestorePaths.partnershipRequestsCol)
        .where('supplierId', isEqualTo: supplierId)
        .snapshots()
        .listen(
          (snap) {
            final all =
                snap.docs
                    .map(
                      (doc) =>
                          PartnershipRequestModel.fromMap(doc.id, doc.data()),
                    )
                    .toList();

            _latestPartnershipByCompanyId.clear();
            final grouped = <String, List<PartnershipRequestModel>>{};
            for (final req in all) {
              grouped.putIfAbsent(req.companyId, () => []).add(req);
            }
            for (final entry in grouped.entries) {
              entry.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              _latestPartnershipByCompanyId[entry.key] = entry.value.first;
            }

            _allPartnershipRequests = _sortPartnershipRequestsNewest(all);
            _incomingPartnershipRequests = _sortPartnershipRequestsNewest(
              all.where((r) => r.initiatedBy == 'ceo'),
            );
            _outgoingPartnershipRequests = _sortPartnershipRequestsNewest(
              all.where((r) => r.initiatedBy == 'supplier'),
            );
            _partnershipListsReady = true;
            notifyListeners();
          },
          onError: (_) {
            _partnershipListsReady = true;
            _error = 'Failed to load partnership requests.';
            notifyListeners();
          },
        );

    _linkedCompaniesSub = _db
        .collection(FirestorePaths.suppliersCol)
        .doc(supplierId)
        .collection('companies')
        .snapshots()
        .listen(
          (snap) {
            _activePartnerCompanyIds
              ..clear()
              ..addAll(
                snap.docs
                    .where((doc) {
                      final status =
                          (doc.data()['status'] as String?)?.toLowerCase() ??
                          'active';
                      return status == 'active' || status == 'approved';
                    })
                    .map((doc) => doc.id),
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
    _linkedCompaniesSub?.cancel();
    _partnershipRequestsSub = null;
    _linkedCompaniesSub = null;
    _allPartnershipRequests = [];
    _latestPartnershipByCompanyId.clear();
    _activePartnerCompanyIds.clear();
    _incomingPartnershipRequests = [];
    _outgoingPartnershipRequests = [];
    _partnershipListsReady = false;
  }

  List<PartnershipRequestModel> _sortPartnershipRequestsNewest(
    Iterable<PartnershipRequestModel> requests,
  ) {
    return List<PartnershipRequestModel>.from(requests)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  String? partnershipRejectionReasonFor(String companyId) {
    if (companyId.isEmpty) return null;
    final request = _latestPartnershipByCompanyId[companyId];
    if (request?.status == 'rejected') {
      return request!.rejectionReason;
    }
    return null;
  }

  String partnershipStatusFor(String companyId) {
    if (companyId.isEmpty) return 'Not Requested';
    if (_activePartnerCompanyIds.contains(companyId)) {
      return 'Already Partners';
    }

    final request = _latestPartnershipByCompanyId[companyId];
    if (request == null) return 'Not Requested';

    switch (request.status) {
      case 'pending':
        return 'Request Pending';
      case 'accepted':
        return 'Already Partners';
      case 'rejected':
        return 'Request Rejected';
      case 'removed':
        return 'Not Requested';
      default:
        return 'Not Requested';
    }
  }

  String directoryActionFor(String companyId) {
    if (_activePartnerCompanyIds.contains(companyId)) {
      return 'Partners ✓';
    }
    final request = _latestPartnershipByCompanyId[companyId];
    if (request?.status == 'pending') {
      return request!.isCeoInitiated ? 'Respond' : 'Pending';
    }
    if ((request?.status == 'rejected' || request?.status == 'removed') &&
        canReapplyToCompany(companyId)) {
      return 'Request Again';
    }
    return 'Send Request';
  }

  bool canReapplyToCompany(String companyId) {
    final request = _latestPartnershipByCompanyId[companyId];
    if (request == null) return true;
    if (request.status != 'rejected' && request.status != 'removed') {
      return false;
    }
    final closedAt = request.respondedAt ?? request.createdAt;
    return DateTime.now().difference(closedAt).inDays >= 7;
  }

  String pastRequestStatusLabel(PartnershipRequestModel request) {
    if (request.status == 'removed') return 'Removed';
    if (request.status == 'rejected') {
      if (request.isSupplierInitiated) return 'Declined by Them';
      return 'You Declined';
    }
    return request.status;
  }

  PartnerCompanyStats partnerStatsFor(String companyId) {
    final orders =
        _allSupplierOrders.where((o) => o.companyId == companyId).toList();
    final txs =
        _allSupplierTransactions
            .where((t) => t.companyId == companyId)
            .toList();
    final orderIds = orders.map((o) => o.orderId).toSet();
    final companyRatings =
        _allSupplierRatings.where((r) => orderIds.contains(r.orderId)).toList();
    final earnings = txs.fold<double>(0, (sum, tx) => sum + tx.supplierEarning);
    final avgRating =
        companyRatings.isEmpty
            ? 0.0
            : companyRatings.fold<double>(0, (sum, r) => sum + r.rating) /
                companyRatings.length;
    return PartnerCompanyStats(
      totalOrders: orders.length,
      avgRating: avgRating,
      totalEarnings: earnings,
    );
  }

  Future<void> loadPartnershipHubData() async {
    ensurePartnershipStatusWatch();
    _partnershipHubDataLoaded = false;
    notifyListeners();
    try {
      await Future.wait([
        loadLinkedCompanies(),
        loadCompanyDirectory(),
        _loadAllSupplierOrders(),
        _loadAllSupplierTransactions(),
        _loadAllSupplierRatings(),
      ]);
    } finally {
      _partnershipHubDataLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _loadAllSupplierOrders() async {
    if (_supplierUid == null) return;
    final snap =
        await _db
            .collection('orders')
            .where('supplierId', isEqualTo: _supplierUid)
            .get();
    _allSupplierOrders =
        snap.docs.map((doc) => OrderModel.fromMap(doc.id, doc.data())).toList();
  }

  Future<void> _loadAllSupplierTransactions() async {
    if (_supplierUid == null) return;
    final snap =
        await _db
            .collection('transactions')
            .where('supplierId', isEqualTo: _supplierUid)
            .get();
    _allSupplierTransactions =
        snap.docs
            .map((doc) => TransactionModel.fromMap(doc.id, doc.data()))
            .toList();
  }

  Future<void> _loadAllSupplierRatings() async {
    if (_supplierUid == null) return;
    final snap =
        await _db
            .collection('ratings')
            .where('supplierUid', isEqualTo: _supplierUid)
            .get();
    _allSupplierRatings =
        snap.docs
            .map((doc) => RatingModel.fromMap(doc.id, doc.data()))
            .toList();
  }

  void filterCompanyDirectoryByCity(String? city) {
    _directoryCityFilter = city;
    _applyCompanyDirectoryFilters();
  }

  void _applyCompanyDirectoryFilters() {
    var list = List<CompanyModel>.from(_allCompanyDirectory);
    final city = _directoryCityFilter;
    if (city != null && city != 'All' && city.isNotEmpty) {
      list = list.where((c) => c.city == city).toList();
    }
    final q = _directorySearchQuery;
    if (q.isNotEmpty) {
      list =
          list
              .where(
                (c) =>
                    c.name.toLowerCase().contains(q) ||
                    c.city.toLowerCase().contains(q),
              )
              .toList();
    }
    _companyDirectory = list;
    notifyListeners();
  }

  List<String> interestCategoriesFor(CompanyModel company) {
    final categories = <String>{};
    if (company.companyType != null && company.companyType!.isNotEmpty) {
      categories.add(company.companyType!);
    }
    return categories.take(3).toList();
  }

  void _resetDashboardLoadingFlags() {
    _isDashboardLoading = true;
    _materialsInitialized = false;
    _ordersInitialized = false;
    _earningsInitialized = false;
    _ratingsInitialized = false;
  }

  void _onDashboardStreamError(String section, Object error) {
    final message = error.toString();
    if (message.contains('permission-denied')) {
      _error =
          'Firestore access denied. Sign out and back in, or ask an admin to deploy security rules.';
    } else {
      _error = 'Some dashboard data could not be loaded ($section).';
    }
    if (section == 'materials') _materialsInitialized = true;
    if (section == 'orders') _ordersInitialized = true;
    if (section == 'earnings') _earningsInitialized = true;
    if (section == 'ratings') _ratingsInitialized = true;
    _checkDashboardReady();
    notifyListeners();
  }

  void _clearDashboardStreamError(String section) {
    final current = _error;
    if (current == null) return;
    if (current.contains('($section)') ||
        current.startsWith('$section:') ||
        current.contains(section)) {
      _error = null;
    }
  }

  void _finishDashboardLoadingSoon() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!_isDashboardLoading) return;
      _materialsInitialized = true;
      _ordersInitialized = true;
      _earningsInitialized = true;
      _ratingsInitialized = true;
      _isDashboardLoading = false;
      notifyListeners();
    });
  }

  void _finishCompaniesLoadingSoon() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_companiesLoaded) return;
      _companiesLoaded = true;
      notifyListeners();
    });
  }

  void _checkDashboardReady() {
    if (_materialsInitialized &&
        _ordersInitialized &&
        _earningsInitialized &&
        _ratingsInitialized) {
      if (_isDashboardLoading) {
        _isDashboardLoading = false;
        notifyListeners();
      }
    }
  }

  void watchStatus() {
    if (_supplierUid == null) return;
    _statusSubscription?.cancel();
    _statusSubscription = _userRepo
        .watchUserDoc(_supplierUid!)
        .listen(
          (user) {
            _status = user.status ?? 'pending';
            _rejectionReason = user.rejectionReason;
            notifyListeners();
          },
          onError: (_) {
            // Non-blocking — dashboard still renders.
          },
        );
  }

  Future<List<CompanyModel>> _resolveCompaniesFallback() async {
    final uid = _supplierUid;
    if (uid == null) return [];

    final found = <CompanyModel>[];
    final seen = <String>{};

    void add(CompanyModel? company) {
      if (company != null && seen.add(company.id)) {
        found.add(company);
      }
    }

    final profileCompanyId = _profile?.companyId ?? '';
    if (profileCompanyId.isNotEmpty) {
      add(await _companyRepo.getCompanyById(profileCompanyId));
    }

    final companiesSnap = await _db.collection('companies').get();
    for (final companyDoc in companiesSnap.docs) {
      final link =
          await _db
              .collection('companies')
              .doc(companyDoc.id)
              .collection('suppliers')
              .doc(uid)
              .get();
      if (!link.exists) continue;

      final status =
          (link.data()?['status'] as String?)?.toLowerCase() ?? 'active';
      if (status != 'active' && status != 'approved') continue;

      add(await _companyRepo.getCompanyById(companyDoc.id));

      await _db
          .collection('suppliers')
          .doc(uid)
          .collection('companies')
          .doc(companyDoc.id)
          .set({
            'id': companyDoc.id,
            'status': 'active',
            'joinedAt':
                link.data()?['joinedAt'] ?? FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    }

    return found;
  }

  Future<void> loadLinkedCompanies() async {
    if (_supplierUid == null) {
      _companiesLoaded = true;
      notifyListeners();
      return;
    }
    _companiesSubscription?.cancel();
    _companiesLoadFailed = false;
    _finishCompaniesLoadingSoon();
    _companiesSubscription = _db
        .collection('suppliers')
        .doc(_supplierUid)
        .collection('companies')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen(
          (snap) async {
            var companyList = <CompanyModel>[];
            for (var doc in snap.docs) {
              try {
                final c = await _companyRepo.getCompanyById(doc.id);
                if (c != null) companyList.add(c);
              } catch (_) {
                // Skip companies we cannot read.
              }
            }
            if (companyList.isEmpty) {
              try {
                companyList = await _resolveCompaniesFallback();
              } catch (e) {
                _error ??= e.toString();
              }
            }
            _companies = companyList;
            _companiesLoaded = true;
            _companiesLoadFailed = false;
            if (_selectedCompanyId == null && _companies.isNotEmpty) {
              switchCompany(_companies.first.id);
            }
            notifyListeners();
          },
          onError: (e) async {
            try {
              final fallback = await _resolveCompaniesFallback();
              _companies = fallback;
              _companiesLoaded = true;
              _companiesLoadFailed = fallback.isEmpty;
              _error = fallback.isEmpty ? e.toString() : null;
              if (_selectedCompanyId == null && _companies.isNotEmpty) {
                switchCompany(_companies.first.id);
              }
            } catch (_) {
              _companiesLoaded = true;
              _companiesLoadFailed = true;
              _error = e.toString();
            }
            notifyListeners();
          },
        );
  }

  void switchCompany(String companyId) {
    if (_selectedCompanyId == companyId) return;
    _selectedCompanyId = companyId;
    _error = null;
    _resetDashboardLoadingFlags();
    _finishDashboardLoadingSoon();
    loadMaterials(companyId);
    loadOrders(companyId, null);
    loadEarnings(monthKey());
    if (_supplierUid != null) {
      loadRatings(_supplierUid!, companyId);
    }
    notifyListeners();
  }

  // --- Invitations ---

  void loadInvitations() {
    if (_supplierUid == null) return;
    _invitationsSubscription?.cancel();
    _invitationsSubscription = _db
        .collection('invitations')
        .where('supplierUid', isEqualTo: _supplierUid)
        .snapshots()
        .listen(
          (snap) {
            _invitations =
                snap.docs
                    .map((d) => InvitationModel.fromMap(d.id, d.data()))
                    .toList();
            notifyListeners();
          },
          onError: (e) {
            _error ??= e.toString();
            notifyListeners();
          },
        );
  }

  Future<void> acceptInvitation(String inviteId, String companyId) async {
    _isLoading = true;
    _error = null;
    _successMessage = null;
    notifyListeners();
    try {
      await _cloudFunctions.callFunction('onInviteAccepted', {
        'token': inviteId,
        'companyId': companyId,
        'supplierUid': _supplierUid,
      });
      _selectedCompanyId = companyId;
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to accept invitation. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectInvitation(String inviteId) async {
    await _db.collection('invitations').doc(inviteId).update({
      'status': 'rejected',
    });
  }

  // --- Materials ---

  Future<void> addMaterial(
    MaterialModel material,
    File? imageFile,
    String companyId,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await CloudinaryService.uploadImage(
          filePath: imageFile.path,
          folder: 'ratebridge/materials',
        );
        if (imageUrl == null) {
          _error = 'Image upload failed. Please try again.';
          return;
        }
      }
      final newMat = material.copyWith(
        profileImageUrl: imageUrl,
        supplierId: _supplierUid,
      );

      final batch = _db.batch();
      final companyMatRef = _db
          .collection('companies')
          .doc(companyId)
          .collection('materials')
          .doc(newMat.id);
      batch.set(companyMatRef, newMat.toMap());

      final globalMatRef = _db.collection('materials').doc(newMat.id);
      batch.set(globalMatRef, newMat.toMap());

      await batch.commit();
      await _materialRepo.recordInitialMaterialPrice(
        materialId: newMat.id,
        price: newMat.pricePerUnit,
        supplierUid: _supplierUid,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateMaterial(
    String matId,
    Map<String, dynamic> data,
    File? imageFile,
    String companyId,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (imageFile != null) {
        final imageUrl = await CloudinaryService.uploadImage(
          filePath: imageFile.path,
          folder: 'ratebridge/materials',
        );
        if (imageUrl == null) {
          _error = 'Image upload failed. Please try again.';
          return;
        }
        data['profileImageUrl'] = imageUrl;
      }

      if (data.containsKey('pricePerUnit')) {
        final doc = await _db.collection('materials').doc(matId).get();
        final oldPrice =
            (doc.data()?['pricePerUnit'] as num?)?.toDouble() ?? 0.0;
        final newPrice = (data['pricePerUnit'] as num).toDouble();
        if (oldPrice != newPrice) {
          await _materialRepo.archiveMaterialPriceChange(
            materialId: matId,
            previousPrice: oldPrice,
            newPrice: newPrice,
            supplierUid: _supplierUid,
          );
        }
      }

      await _db.collection('materials').doc(matId).update(data);
      await _db
          .collection('companies')
          .doc(companyId)
          .collection('materials')
          .doc(matId)
          .update(data);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteMaterial(String matId, String companyId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _materialRepo.removeMaterial(matId);
      await _db
          .collection('companies')
          .doc(companyId)
          .collection('materials')
          .doc(matId)
          .delete();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMaterials(String companyId) async {
    if (_supplierUid == null) {
      _materialsInitialized = true;
      _checkDashboardReady();
      notifyListeners();
      return;
    }
    _materialsSubscription?.cancel();
    _materialsSubscription = _db
        .collection('companies')
        .doc(companyId)
        .collection('materials')
        .where('supplierId', isEqualTo: _supplierUid)
        .snapshots()
        .listen((snap) {
          _materials =
              snap.docs.map((d) {
                final data = Map<String, dynamic>.from(d.data());
                data.putIfAbsent('id', () => d.id);
                return MaterialModel.fromMap(data);
              }).toList();
          _clearDashboardStreamError('materials');
          _materialsInitialized = true;
          _checkDashboardReady();
          notifyListeners();
        }, onError: (e) => _onDashboardStreamError('materials', e));
  }

  // --- Orders ---

  Future<void> loadOrders(String companyId, String? statusFilter) async {
    if (_supplierUid == null) {
      _ordersInitialized = true;
      _checkDashboardReady();
      notifyListeners();
      return;
    }
    _ordersSubscription?.cancel();
    _ordersSubscription = _orderRepo.getOrdersForSupplier(_supplierUid!).listen(
      (data) {
        _orders = data.where((o) => o.companyId == companyId).toList();
        _clearDashboardStreamError('orders');
        _ordersInitialized = true;
        _checkDashboardReady();
        notifyListeners();
      },
      onError: (e) => _onDashboardStreamError('orders', e),
    );
  }

  Future<void> acceptOrder(String orderId, String companyId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final order = _orders.firstWhere(
        (o) => o.orderId == orderId,
        orElse: () => throw StateError('Order not found'),
      );
      await _orderRepo.updateStatus(orderId, companyId, 'accepted');
      await _notificationService.notifyOrderAccepted(
        fieldUserUid: order.fieldUserUid,
        orderId: orderId,
        companyId: companyId,
        materialName: order.materialName,
        supplierName: order.supplierName,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectOrder(
    String orderId,
    String companyId,
    String reason,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final order = _orders.firstWhere(
        (o) => o.orderId == orderId,
        orElse: () => throw StateError('Order not found'),
      );
      await _orderRepo.updateStatus(
        orderId,
        companyId,
        'rejected',
        reason: reason,
      );
      await _notificationService.notifyOrderRejected(
        fieldUserUid: order.fieldUserUid,
        orderId: orderId,
        companyId: companyId,
        materialName: order.materialName,
        supplierName: order.supplierName,
        reason: reason,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markDelivered(String orderId, String companyId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final order = _orders.firstWhere(
        (o) => o.orderId == orderId,
        orElse: () => throw StateError('Order not found'),
      );
      await _orderRepo.updateStatus(
        orderId,
        companyId,
        'delivered',
        deliveredAt: DateTime.now(),
      );
      await _notificationService.notifyOrderDelivered(
        fieldUserUid: order.fieldUserUid,
        orderId: orderId,
        companyId: companyId,
        materialName: order.materialName,
        supplierName: order.supplierName,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Onboarding ---

  Future<void> completeCompanyOnboarding(
    String companyId,
    Map<String, dynamic> details,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _db
          .collection('suppliers')
          .doc(_supplierUid)
          .collection('companies')
          .doc(companyId)
          .update({...details, 'onboardingComplete': true});
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Profile & Earnings ---

  Future<void> loadEarnings(String month) async {
    if (_supplierUid == null) {
      _earningsInitialized = true;
      _checkDashboardReady();
      notifyListeners();
      return;
    }
    _earningsSubscription?.cancel();
    try {
      _earningsSubscription = _transactionRepo
          .watchSupplierEarnings(_supplierUid!, month)
          .listen((txs) {
            _transactions = txs;
            totalEarnings = txs.fold(0.0, (sum, tx) => sum + tx.totalAmount);
            netEarnings = txs.fold(0.0, (sum, tx) => sum + tx.supplierEarning);
            _clearDashboardStreamError('earnings');
            _earningsInitialized = true;
            _checkDashboardReady();
            notifyListeners();
          }, onError: (e) => _onDashboardStreamError('earnings', e));
      try {
        final summary = await _transactionRepo.getMonthlyEarningsSummary(
          _supplierUid!,
          6,
        );
        _monthlyEarnings = summary.reversed.toList();
        _monthlyChart =
            summary.map((e) => {'month': e.month, 'amount': e.net}).toList();
        notifyListeners();
      } catch (_) {
        // Monthly chart is optional; live transaction stream drives card totals.
      }
    } catch (e) {
      _onDashboardStreamError('earnings', e);
    }
  }

  Future<void> changeMonth(String month) async {
    await loadEarnings(month);
  }

  Future<void> loadProfile() async {
    if (_supplierUid == null) return;
    if (_profile != null && _profile!.uid == _supplierUid) {
      notifyListeners();
      return;
    }
    final cached = _userRepo.cachedUser;
    if (cached != null && cached.uid == _supplierUid) {
      _profile = cached;
      notifyListeners();
      return;
    }
    try {
      _profile = await _userRepo.getUserDoc(_supplierUid!);
    } catch (e) {
      _error ??= e.toString();
    }
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> fields) async {
    if (_supplierUid == null) return;
    await _userRepo.updateUserDoc(_supplierUid!, fields);
    _profile = _userRepo.cachedUser ?? _profile;
    notifyListeners();
  }

  Future<void> submitAppeal(String message, File? file, String? phone) async {
    _isLoading = true;
    notifyListeners();
    try {
      String? imageUrl;
      if (file != null) {
        imageUrl = await _storageService.uploadFile(
          file: file,
          path: 'appeals/$_supplierUid',
        );
      }
      await _db.collection('appeals').add({
        'supplierUid': _supplierUid,
        'message': message,
        'phone': phone,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      _appealSubmitted = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCompanyDirectory() async {
    ensurePartnershipStatusWatch();
    _isLoading = true;
    notifyListeners();
    try {
      final all = await _companyRepo.getAllCompanies();
      _allCompanyDirectory =
          all.where((c) => c.status.toLowerCase() == 'active').toList();
      _applyCompanyDirectoryFilters();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchCompanies(String query) async {
    if (_allCompanyDirectory.isEmpty) {
      await loadCompanyDirectory();
    }
    _directorySearchQuery = query.trim().toLowerCase();
    _applyCompanyDirectoryFilters();
  }

  Future<bool> sendPartnershipRequest(
    String companyId, {
    String? message,
  }) async {
    if (_supplierUid == null) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final company = await _companyRepo.getCompanyById(companyId);
      if (company == null) {
        _error = 'Company not found.';
        return false;
      }
      await _partnershipRepo.createRequest(
        companyId: companyId,
        companyName: company.name,
        supplierId: _supplierUid!,
        supplierName: _profile?.name ?? _profile?.email ?? 'Supplier',
        initiatedBy: 'supplier',
        message: message,
        supplierEmail: _profile?.email,
        supplierCity: _profile?.city,
        supplierCategories: const [],
        supplierRating: 0,
      );
      return true;
    } on AppException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Failed to send partnership request. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<List<PartnershipRequestModel>> watchIncomingPartnershipRequests() {
    ensurePartnershipStatusWatch();
    return Stream.value(
      List<PartnershipRequestModel>.from(_incomingPartnershipRequests),
    );
  }

  Stream<List<PartnershipRequestModel>> watchOutgoingPartnershipRequests() {
    ensurePartnershipStatusWatch();
    return Stream.value(
      List<PartnershipRequestModel>.from(_outgoingPartnershipRequests),
    );
  }

  Future<String?> acceptPartnershipRequest(String requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final reqDoc =
          await _db
              .collection(FirestorePaths.partnershipRequestsCol)
              .doc(requestId)
              .get();
      final companyName = reqDoc.data()?['companyName'] as String? ?? 'Company';
      await _partnershipRepo.acceptRequest(requestId);
      await loadLinkedCompanies();
      await _loadAllSupplierOrders();
      return companyName;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> rejectPartnershipRequest(String requestId, String reason) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _partnershipRepo.rejectRequest(requestId, reason);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> withdrawPartnershipRequest(String requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _partnershipRepo.withdrawRequest(requestId);
      return true;
    } on AppException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> removePartnership(String companyId) async {
    if (_supplierUid == null) return null;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final company = await _companyRepo.getCompanyById(companyId);
      await _partnershipRepo.removePartnership(
        companyId: companyId,
        supplierId: _supplierUid!,
      );
      if (_selectedCompanyId == companyId) {
        _selectedCompanyId = null;
      }
      await loadLinkedCompanies();
      return company?.name ?? 'Company';
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void openCompanyContext(String companyId) {
    switchCompany(companyId);
  }

  @Deprecated('Use sendPartnershipRequest')
  Future<void> sendJoinRequest(String companyId, String message) async {
    await sendPartnershipRequest(companyId, message: message);
  }

  Future<void> loadRatings(String supplierUid, String companyId) async {
    _ratingsSubscription?.cancel();
    _ratingsSubscription = _db
        .collection('ratings')
        .where('supplierUid', isEqualTo: supplierUid)
        .snapshots()
        .listen((snap) {
          _ratings =
              snap.docs
                  .map((d) => RatingModel.fromMap(d.id, d.data()))
                  .toList();
          _clearDashboardStreamError('ratings');
          _ratingsInitialized = true;
          _checkDashboardReady();
          notifyListeners();
        }, onError: (e) => _onDashboardStreamError('ratings', e));
  }

  String? companyNameFor(String companyId) {
    try {
      return _companies.firstWhere((c) => c.id == companyId).name;
    } catch (_) {
      return null;
    }
  }

  void filterRatingsByMaterial(String name) {
    if (name == 'All') {
      loadRatings(_supplierUid!, _selectedCompanyId!);
    } else {
      _ratings = _ratings.where((r) => r.materialName == name).toList();
      notifyListeners();
    }
  }

  Future<void> loadDashboard() async {
    if (_supplierUid == null || _selectedCompanyId == null) return;
    _error = null;
    _resetDashboardLoadingFlags();
    notifyListeners();
    _finishDashboardLoadingSoon();
    loadMaterials(_selectedCompanyId!);
    loadOrders(_selectedCompanyId!, null);
    loadEarnings(monthKey());
    loadRatings(_supplierUid!, _selectedCompanyId!);
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  // --- RFQ / Bulk Quotes ---
  Stream<List<RfqModel>> streamOpenRfqsForSupplier() async* {
    if (_supplierUid == null) {
      yield const [];
      return;
    }

    final supplierDoc =
        await _db.collection('suppliers').doc(_supplierUid).get();
    final supplier = supplierDoc.data();
    final status = supplier?['status']?.toString().toLowerCase() ?? '';
    if (supplier == null || (status != 'active' && status != 'approved')) {
      yield const [];
      return;
    }

    List<String> strings(Object? value) =>
        value is List
            ? value.map((item) => item.toString().trim().toLowerCase()).toList()
            : const [];

    final declared = strings(supplier['declaredCategories']);
    final categories =
        declared.isNotEmpty ? declared : strings(supplier['categories']);
    final coverage = strings(supplier['deliveryCoverageAreas']);
    final supplierCity =
        supplier['city']?.toString().trim().toLowerCase() ?? '';
    if (categories.isEmpty || (coverage.isEmpty && supplierCity.isEmpty)) {
      yield const [];
      return;
    }

    yield* _db
        .collection('rfqs')
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snap) {
          final matches =
              snap.docs
                  .map((doc) => RfqModel.fromMap(doc.id, doc.data()))
                  .where((rfq) {
                    final category = rfq.category.trim().toLowerCase();
                    final city = rfq.city.trim().toLowerCase();
                    return categories.contains(category) &&
                        (coverage.contains(city) || supplierCity == city);
                  })
                  .toList();
          matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return matches;
        });
  }

  Future<void> submitRfqBid({
    required String rfqId,
    required double bidPrice,
    required String deliveryTime,
    String? note,
  }) async {
    if (_supplierUid == null) return;
    _isLoading = true;
    _error = null;
    _successMessage = null;
    notifyListeners();

    try {
      final result = await _cloudFunctions.callFunction('submitRfqBid', {
        'rfqId': rfqId,
        'bidPrice': bidPrice,
        'estimatedDeliveryTime': deliveryTime,
        'note': note,
      });
      final updated = result is Map && result['updated'] == true;
      _successMessage =
          updated ? 'Bid updated successfully.' : 'Bid submitted successfully.';
    } catch (e) {
      _error = e is AppException ? e.message : 'Failed to submit bid: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<RfqBidModel?> getMyBid(String rfqId) async {
    if (_supplierUid == null) return null;
    final doc =
        await _db
            .collection('rfqs')
            .doc(rfqId)
            .collection('bids')
            .doc(_supplierUid)
            .get();
    if (!doc.exists) return null;
    return RfqBidModel.fromMap(doc.id, doc.data()!);
  }
}
