// MVVM: ViewModel
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/company_model.dart';
import '../models/user_model.dart';
import '../models/category_model.dart';
import '../models/payment_proof_model.dart';
import '../models/subscription_model.dart';
import '../models/transaction_model.dart';
import '../models/order_model.dart';
import '../models/rating_model.dart';
import '../services/notification_service.dart';
import '../utils/invite_code_generator.dart';
import '../utils/app_exception.dart';
import '../constants/firestore_paths.dart';
import 'auth_viewmodel.dart';

enum AnalyticsViewMode { overall, ceoDetail, supplierDetail }

// Admin Data Models
class PlatformTransaction {
  final String id;
  final String type; // 'subscription' | 'order_payment' | 'commission'
  final String companyName;
  final String? supplierName;
  final double amount;
  final String status; // 'pending' | 'confirmed' | 'failed' | 'settled'
  final DateTime? date;
  final String payerRole;
  final String? screenshotUrl;
  final String? rejectionReason;

  PlatformTransaction({
    required this.id,
    required this.type,
    required this.companyName,
    this.supplierName,
    required this.amount,
    required this.status,
    this.date,
    this.payerRole = '',
    this.screenshotUrl,
    this.rejectionReason,
  });
}

class AdminStats {
  final int totalUsers;
  final int totalCEOs;
  final int totalCompanies;
  final int totalFieldUsers;
  final int totalSuppliers;
  final int totalOrders;
  final int activeOrders;
  final int completedOrders;
  final int cancelledOrders;
  final double avgSupplierRating;
  final int totalReviews;
  final double totalRevenue;

  AdminStats({
    this.totalUsers = 0,
    this.totalCEOs = 0,
    this.totalCompanies = 0,
    this.totalFieldUsers = 0,
    this.totalSuppliers = 0,
    this.totalOrders = 0,
    this.activeOrders = 0,
    this.completedOrders = 0,
    this.cancelledOrders = 0,
    this.avgSupplierRating = 0.0,
    this.totalReviews = 0,
    this.totalRevenue = 0.0,
  });
}

class CEOPerformanceData {
  final String ceoUid;
  final String companyId;
  final String companyName;
  final int fieldUserCount;
  final int totalOrders;
  final int completedOrders;
  final int activeOrders;
  final int cancelledOrders;
  final double completionRate;

  CEOPerformanceData({
    required this.ceoUid,
    required this.companyId,
    required this.companyName,
    this.fieldUserCount = 0,
    this.totalOrders = 0,
    this.completedOrders = 0,
    this.activeOrders = 0,
    this.cancelledOrders = 0,
    this.completionRate = 0.0,
  });
}

class SupplierPerformanceData {
  final String supplierUid;
  final String businessName;
  final int totalOrders;
  final int completedOrders;
  final int activeOrders;
  final int cancelledOrders;
  final double completionRate;
  final double averageRating;
  final int totalReviews;

  SupplierPerformanceData({
    required this.supplierUid,
    required this.businessName,
    this.totalOrders = 0,
    this.completedOrders = 0,
    this.activeOrders = 0,
    this.cancelledOrders = 0,
    this.completionRate = 0.0,
    this.averageRating = 0.0,
    this.totalReviews = 0,
  });
}

class AdminViewModel extends ChangeNotifier {
  final FirebaseFirestore _db;
  final NotificationService? _notificationService;

  String? _uid;
  String? _adminName;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _analyticsError;
  String? get analyticsError => _analyticsError;

  List<Map<String, dynamic>> _suppliersList = [];
  List<Map<String, dynamic>> get suppliersList => _suppliersList;

  List<Map<String, dynamic>> _ceosList = [];
  List<Map<String, dynamic>> get ceosList => _ceosList;

  List<CompanyModel> _companies = [];
  List<CompanyModel> get companiesList => _companies;

  List<PlatformTransaction> _transactions = [];
  List<PlatformTransaction> get transactions => _transactions;

  List<PaymentProofModel> _pendingPayments = [];
  List<PaymentProofModel> get pendingPayments => _pendingPayments;

  List<PaymentProofModel> _confirmedPayments = [];
  List<PaymentProofModel> get confirmedPayments => _confirmedPayments;

  AdminStats _stats = AdminStats();
  AdminStats get stats => _stats;

  List<UserModel> _allUsers = [];
  List<UserModel> get allUsers => _allUsers;

  List<OrderModel> _recentOrders = [];
  List<OrderModel> get recentOrders => _recentOrders;

  List<CEOPerformanceData> _ceoPerformance = [];
  List<CEOPerformanceData> get ceoPerformance => _ceoPerformance;

  List<SupplierPerformanceData> _supplierPerformance = [];
  List<SupplierPerformanceData> get supplierPerformance => _supplierPerformance;

  final Map<String, List<OrderModel>> _companyOrdersCache = {};
  final Map<String, List<OrderModel>> _supplierOrdersCache = {};
  final Map<String, List<RatingModel>> _supplierRatingsCache = {};

  StreamSubscription? _paymentQueueSub;
  StreamSubscription? _statsSub;
  bool _isAnalyticsLoading = false;

  String _timeRange = '30 Days';
  String get timeRange => _timeRange;

  // Persistent Analytics Navigation State
  AnalyticsViewMode _analyticsMode = AnalyticsViewMode.overall;
  AnalyticsViewMode get analyticsMode => _analyticsMode;
  
  String _selectedPartnerId = '';
  String get selectedPartnerId => _selectedPartnerId;

  int _ceoDetailTabIndex = 0;
  int get ceoDetailTabIndex => _ceoDetailTabIndex;

  int _supplierDetailTabIndex = 0;
  int get supplierDetailTabIndex => _supplierDetailTabIndex;

  AdminViewModel([this._notificationService, FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  @override
  void dispose() {
    _paymentQueueSub?.cancel();
    _statsSub?.cancel();
    super.dispose();
  }

  void updateAuth(AuthViewModel auth) {
    if (auth.user != null && (auth.user!.role.toLowerCase() == 'admin' || auth.user!.role.toLowerCase() == 'administrator')) {
      if (_uid != auth.user!.uid) {
        _uid = auth.user!.uid;
        _adminName = auth.user!.name;
        loadDashboardData();
        loadPaymentQueue();
        loadCEOs();
        loadSuppliers();
        loadAllUsers();
      }
    }
  }

  // Analytics Navigation Methods
  void setAnalyticsMode(AnalyticsViewMode mode, {String id = '', int tabIndex = 0}) {
    _analyticsMode = mode;
    _selectedPartnerId = id;
    if (mode == AnalyticsViewMode.ceoDetail) _ceoDetailTabIndex = tabIndex;
    if (mode == AnalyticsViewMode.supplierDetail) _supplierDetailTabIndex = tabIndex;
    notifyListeners();
  }

  void setCEODetailTab(int index) {
    if (_ceoDetailTabIndex == index) return;
    _ceoDetailTabIndex = index;
    notifyListeners();
  }

  void setSupplierDetailTab(int index) {
    if (_supplierDetailTabIndex == index) return;
    _supplierDetailTabIndex = index;
    notifyListeners();
  }

  void setTimeRange(String range) {
    if (_timeRange == range) return;
    _timeRange = range;
    loadAnalytics(); // Re-fetch
    notifyListeners();
  }

  DateTime? get _filterStartDate {
    final now = DateTime.now();
    switch (_timeRange) {
      case '7 Days': return now.subtract(const Duration(days: 7));
      case '30 Days': return now.subtract(const Duration(days: 30));
      case '3 Months': return now.subtract(const Duration(days: 90));
      case 'All Time': return null;
      default: return now.subtract(const Duration(days: 30));
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
    if (actorId == null || actorId.isEmpty) return;
    final actorName = (_adminName != null && _adminName!.trim().isNotEmpty)
        ? _adminName!.trim()
        : (FirebaseAuth.instance.currentUser?.displayName?.trim().isNotEmpty == true
            ? FirebaseAuth.instance.currentUser!.displayName!.trim()
            : 'Admin');
    try {
      await _db.collection('audit_logs').add({
        'actorId': actorId,
        'actorName': actorName,
        'actionType': actionType,
        'targetType': targetType,
        'targetId': targetId,
        'description': description,
        if (reason != null && reason.trim().isNotEmpty)
          'reason': reason.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      developer.log("Error saving audit log: $e");
    }
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
      final name = (doc.data()?['name'] ?? doc.data()?['companyName'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    } catch (e) {
      developer.log('Failed to load company name for $companyId: $e');
    }
    return companyId;
  }

  Future<String> _supplierName(String uid) async {
    try {
      final supplierDoc = await _db.collection('suppliers').doc(uid).get();
      final business = (supplierDoc.data()?['businessName'] ?? supplierDoc.data()?['name'] ?? '').toString().trim();
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
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _db.collection('companies').get(),
        _db.collection('transactions').orderBy('date', descending: true).limit(50).get(),
        _db.collection('orders').orderBy('createdAt', descending: true).limit(10).get(),
      ]);

      final companySnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final txSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final orderSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;

      _companies = companySnap.docs.map((doc) => CompanyModel.fromMap(doc.data())).toList();

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
          payerRole: data['payerRole'] as String? ?? '',
          screenshotUrl: data['screenshotUrl'] as String?,
          rejectionReason: data['rejectionReason'] as String?,
        );
      }).toList();

      _recentOrders = orderSnap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList();
      
      await refreshStats();
      
      if (!_isAnalyticsLoading) {
        await loadAnalytics();
      }
    } catch (e) {
      developer.log("AdminViewModel Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAnalytics() async {
    if (_isAnalyticsLoading) return;
    
    _isAnalyticsLoading = true;
    _analyticsError = null;
    
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _db.collection('companies').get(),
        _db.collection('suppliers').get(),
        _db.collection('users').where('role', isEqualTo: 'CEO').get(),
        _db.collection('users').where('role', isEqualTo: 'Supplier').get(),
        _db.collection('users').where('role', isEqualTo: 'field_user').get(),
        _db.collection('orders').get(),
        _db.collection('ratings').get(),
      ]);

      final companiesSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final supplierProfilesSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final ceosSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
      final suppliersSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;
      final fieldUsersSnap = results[4] as QuerySnapshot<Map<String, dynamic>>;
      final ordersSnap = results[5] as QuerySnapshot<Map<String, dynamic>>;
      final ratingsSnap = results[6] as QuerySnapshot<Map<String, dynamic>>;

      final Map<String, CompanyModel> companyMap = {
        for (var doc in companiesSnap.docs) doc.id: CompanyModel.fromMap(doc.data())
      };
      
      final Map<String, Map<String, dynamic>> supplierProfileMap = {
        for (var doc in supplierProfilesSnap.docs) doc.id: doc.data()
      };

      _companyOrdersCache.clear();
      _supplierOrdersCache.clear();
      _supplierRatingsCache.clear();

      final startDate = _filterStartDate;

      for (var doc in companiesSnap.docs) _companyOrdersCache[doc.id] = [];
      for (var doc in ceosSnap.docs) {
        final cid = doc.data()['companyId'];
        if (cid != null) _companyOrdersCache.putIfAbsent(cid, () => []);
      }
      for (var doc in suppliersSnap.docs) _supplierOrdersCache[doc.id] = [];
      for (var doc in supplierProfilesSnap.docs) _supplierOrdersCache[doc.id] = [];

      for (var doc in ordersSnap.docs) {
        final order = OrderModel.fromMap(doc.id, doc.data());
        if (startDate != null && order.createdAt.isBefore(startDate)) continue;

        if (order.companyId.isNotEmpty) {
          _companyOrdersCache.putIfAbsent(order.companyId, () => []).add(order);
        }
        if (order.supplierId.isNotEmpty) {
          _supplierOrdersCache.putIfAbsent(order.supplierId, () => []).add(order);
        }
      }
      
      _companyOrdersCache.forEach((key, list) => list.sort((a, b) => b.createdAt.compareTo(a.createdAt)));
      _supplierOrdersCache.forEach((key, list) => list.sort((a, b) => b.createdAt.compareTo(a.createdAt)));

      final Map<String, int> companyFieldUserCount = {};
      for (var doc in fieldUsersSnap.docs) {
        final companyId = (doc.data()['companyId'] ?? '').toString();
        if (companyId.isNotEmpty) {
          companyFieldUserCount[companyId] = (companyFieldUserCount[companyId] ?? 0) + 1;
        }
      }

      for (var doc in ratingsSnap.docs) {
        final rating = RatingModel.fromMap(doc.id, doc.data());
        if (startDate != null && rating.createdAt.isBefore(startDate)) continue;
        _supplierRatingsCache.putIfAbsent(rating.supplierUid, () => []).add(rating);
      }
      _supplierRatingsCache.forEach((key, list) => list.sort((a, b) => b.createdAt.compareTo(a.createdAt)));

      _ceoPerformance = ceosSnap.docs.map((doc) {
        final uid = doc.id;
        final userData = doc.data();
        final companyId = userData['companyId'] ?? '';
        final company = companyMap[companyId];
        final companyName = company?.name ?? userData['name'] ?? 'Unknown Company';
        final orders = _companyOrdersCache[companyId] ?? [];
        int completed = 0; int active = 0; int cancelled = 0;
        for (var o in orders) {
          final status = o.status.toLowerCase();
          if (status == 'confirmed' || status == 'delivered') completed++;
          else if (['pending', 'accepted'].contains(status)) active++;
          else if (['cancelled', 'rejected'].contains(status)) cancelled++;
        }
        return CEOPerformanceData(
          ceoUid: uid, companyId: companyId, companyName: companyName,
          fieldUserCount: companyFieldUserCount[companyId] ?? 0,
          totalOrders: orders.length, completedOrders: completed, activeOrders: active, cancelledOrders: cancelled,
          completionRate: orders.isNotEmpty ? (completed / orders.length) * 100 : 0.0,
        );
      }).toList();

      _supplierPerformance = suppliersSnap.docs.map((doc) {
        final uid = doc.id;
        final userData = doc.data();
        final profile = supplierProfileMap[uid];
        final bizName = profile?['businessName'] ?? profile?['name'] ?? userData['name'] ?? 'Supplier';
        final orders = _supplierOrdersCache[uid] ?? [];
        final ratings = _supplierRatingsCache[uid] ?? [];
        int completed = 0; int active = 0; int cancelled = 0;
        for (var o in orders) {
          final status = o.status.toLowerCase();
          if (status == 'confirmed' || status == 'delivered') completed++;
          else if (['pending', 'accepted'].contains(status)) active++;
          else if (['cancelled', 'rejected'].contains(status)) cancelled++;
        }
        double avgRating = ratings.isEmpty ? 0.0 : ratings.map((r) => r.rating).reduce((a, b) => a + b) / ratings.length;
        return SupplierPerformanceData(
          supplierUid: uid, businessName: bizName, totalOrders: orders.length, completedOrders: completed,
          activeOrders: active, cancelledOrders: cancelled, completionRate: orders.isNotEmpty ? (completed / orders.length) * 100 : 0.0,
          averageRating: avgRating, totalReviews: ratings.length,
        );
      }).toList();

      await _calculateStatsFromLoadedData(
        companiesSnap.docs.length, ceosSnap.docs.length, fieldUsersSnap.docs.length, suppliersSnap.docs.length,
        ordersSnap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList(),
        ratingsSnap.docs.map((d) => RatingModel.fromMap(d.id, d.data())).toList()
      );

    } catch (e) {
      developer.log("Error loading analytics: $e");
      _analyticsError = "Failed to load real-time analytics: $e";
    } finally {
      _isAnalyticsLoading = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _calculateStatsFromLoadedData(int companies, int ceos, int fieldUsers, int suppliers, List<OrderModel> allOrders, List<RatingModel> allRatings) async {
    final startDate = _filterStartDate;
    final orders = startDate == null ? allOrders : allOrders.where((o) => o.createdAt.isAfter(startDate)).toList();
    final ratings = startDate == null ? allRatings : allRatings.where((r) => r.createdAt.isAfter(startDate)).toList();
    int active = 0; int completed = 0; int cancelled = 0;
    for (var o in orders) {
      final status = o.status.toLowerCase();
      if (['pending', 'accepted', 'delivered'].contains(status)) active++;
      else if (status == 'confirmed') completed++;
      else if (status == 'cancelled') cancelled++;
    }
    double avgRating = ratings.isEmpty ? 0.0 : ratings.map((r) => r.rating.toDouble()).reduce((a, b) => a + b) / ratings.length;
    _stats = AdminStats(
      totalUsers: _allUsers.length, totalCEOs: ceos, totalFieldUsers: fieldUsers, totalSuppliers: suppliers,
      totalCompanies: companies, totalOrders: orders.length, activeOrders: active, completedOrders: completed,
      cancelledOrders: cancelled, avgSupplierRating: avgRating, totalReviews: ratings.length, totalRevenue: _stats.totalRevenue,
    );
  }

  Future<List<OrderModel>> getCompanyOrders(String companyId) async {
    if (_companyOrdersCache.containsKey(companyId) && _companyOrdersCache[companyId]!.isNotEmpty) return _companyOrdersCache[companyId]!;
    try {
      final snap = await _db.collection('orders').where('companyId', isEqualTo: companyId).get();
      var orders = snap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList();
      final startDate = _filterStartDate;
      if (startDate != null) orders = orders.where((o) => o.createdAt.isAfter(startDate)).toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _companyOrdersCache[companyId] = orders;
      return orders;
    } catch (e) { return []; }
  }

  Future<List<OrderModel>> getSupplierOrders(String supplierUid) async {
    if (_supplierOrdersCache.containsKey(supplierUid) && _supplierOrdersCache[supplierUid]!.isNotEmpty) return _supplierOrdersCache[supplierUid]!;
    try {
      var snap = await _db.collection('orders').where('supplierId', isEqualTo: supplierUid).get();
      if (snap.docs.isEmpty) snap = await _db.collection('orders').where('supplierUid', isEqualTo: supplierUid).get();
      var orders = snap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList();
      final startDate = _filterStartDate;
      if (startDate != null) orders = orders.where((o) => o.createdAt.isAfter(startDate)).toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _supplierOrdersCache[supplierUid] = orders;
      return orders;
    } catch (e) { return []; }
  }

  Future<List<RatingModel>> getSupplierRatings(String supplierUid) async {
    if (_supplierRatingsCache.containsKey(supplierUid) && _supplierRatingsCache[supplierUid]!.isNotEmpty) return _supplierRatingsCache[supplierUid]!;
    try {
      final snap = await _db.collection('ratings').where('supplierUid', isEqualTo: supplierUid).get();
      var ratings = snap.docs.map((d) => RatingModel.fromMap(d.id, d.data())).toList();
      final startDate = _filterStartDate;
      if (startDate != null) ratings = ratings.where((r) => r.createdAt.isAfter(startDate)).toList();
      ratings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _supplierRatingsCache[supplierUid] = ratings;
      return ratings;
    } catch (e) { return []; }
  }

  Map<DateTime, int> getHistoricalOrderTrend(List<OrderModel> orders) {
    final Map<DateTime, int> trend = {};
    if (orders.isEmpty) return trend;
    for (var order in orders) {
      final date = DateTime(order.createdAt.year, order.createdAt.month, order.createdAt.day);
      trend[date] = (trend[date] ?? 0) + 1;
    }
    return trend;
  }

  Future<void> loadAllUsers() async {
    try {
      final snap = await _db.collection('users').get();
      _allUsers = snap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();
      notifyListeners();
    } catch (e) {}
  }

  Future<void> refreshStats() async {
    try {
      final results = await Future.wait([
        _db.collection('users').count().get(),
        _db.collection('users').where('role', isEqualTo: 'CEO').count().get(),
        _db.collection('users').where('role', isEqualTo: 'field_user').count().get(),
        _db.collection('users').where('role', isEqualTo: 'Supplier').count().get(),
        _db.collection('companies').count().get(),
        _db.collection('orders').count().get(),
        _db.collection('orders').where('status', whereIn: ['pending', 'accepted', 'delivered']).count().get(),
        _db.collection('orders').where('status', isEqualTo: 'confirmed').count().get(),
        _db.collection('orders').where('status', isEqualTo: 'cancelled').count().get(),
        _db.collection('ratings').get(),
        _db.collection('payment_proofs').where('status', isEqualTo: 'confirmed').get(),
      ]);
      final usersCount = results[0] as AggregateQuerySnapshot;
      final ceosCount = results[1] as AggregateQuerySnapshot;
      final fieldUsersCount = results[2] as AggregateQuerySnapshot;
      final suppliersCount = results[3] as AggregateQuerySnapshot;
      final companiesCount = results[4] as AggregateQuerySnapshot;
      final ordersCount = results[5] as AggregateQuerySnapshot;
      final activeOrdersCount = results[6] as AggregateQuerySnapshot;
      final completedOrdersCount = results[7] as AggregateQuerySnapshot;
      final cancelledOrdersCount = results[8] as AggregateQuerySnapshot;
      final ratingsSnap = results[9] as QuerySnapshot<Map<String, dynamic>>;
      final confirmedPayments = results[10] as QuerySnapshot<Map<String, dynamic>>;
      double avgRating = ratingsSnap.docs.isEmpty ? 0.0 : ratingsSnap.docs.map((r) => (r.data()['rating'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / ratingsSnap.docs.length;
      double totalRevenue = 0.0;
      for (var doc in confirmedPayments.docs) totalRevenue += (doc.data()['amount'] as num? ?? 0).toDouble();
      _stats = AdminStats(
        totalUsers: usersCount.count ?? 0, totalCEOs: ceosCount.count ?? 0, totalFieldUsers: fieldUsersCount.count ?? 0,
        totalSuppliers: suppliersCount.count ?? 0, totalCompanies: companiesCount.count ?? 0, totalOrders: ordersCount.count ?? 0,
        activeOrders: activeOrdersCount.count ?? 0, completedOrders: completedOrdersCount.count ?? 0, cancelledOrders: cancelledOrdersCount.count ?? 0,
        avgSupplierRating: avgRating, totalReviews: ratingsSnap.docs.length, totalRevenue: totalRevenue,
      );
      notifyListeners();
    } catch (e) {}
  }

  Future<void> loadPaymentQueue() async {
    _paymentQueueSub?.cancel();
    _isLoading = true;
    notifyListeners();
    _paymentQueueSub = _db.collection('payment_proofs').orderBy('createdAt', descending: true).snapshots().listen((snap) {
      final all = snap.docs.map((doc) => PaymentProofModel.fromMap(doc.id, doc.data())).toList();
      _pendingPayments = all.where((p) => p.status == 'pending').toList();
      _confirmedPayments = all.where((p) => p.status != 'pending' && p.status != 'rejected').toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> confirmPayment(PaymentProofModel payment) async {
    if (payment.status == 'confirmed' || payment.status == 'settled') return;
    _isLoading = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final batch = _db.batch();
      final paymentRef = _db.collection('payment_proofs').doc(payment.id);
      final targetStatus = payment.type == 'commission' ? 'settled' : 'confirmed';
      batch.update(paymentRef, {'status': targetStatus, 'confirmedAt': FieldValue.serverTimestamp(), 'confirmedBy': _uid ?? 'admin'});
      if (payment.type == 'subscription' && payment.planId != null) {
        final plan = kPlans.firstWhere((p) => p.planKey == payment.planId, orElse: () => kPlans.first);
        final expiry = plan.durationDays > 0 ? now.add(Duration(days: plan.durationDays)) : null;
        final subRef = _db.collection('subscriptions').doc(payment.companyId);
        batch.set(subRef, {'plan': plan.planKey, 'status': 'active', 'startedAt': FieldValue.serverTimestamp(), 'expiresAt': expiry != null ? Timestamp.fromDate(expiry) : null, 'adminGranted': false}, SetOptions(merge: true));
        final historyEntry = SubscriptionHistoryEntry(plan: plan.planKey, action: 'purchased', date: now, amountPaid: payment.amount.toInt(), note: 'Confirmed by Admin');
        batch.update(subRef, {'history': FieldValue.arrayUnion([historyEntry.toMap()])});
        final companyRef = _db.collection('companies').doc(payment.companyId);
        batch.update(companyRef, {'plan': plan.planKey, 'planExpiry': expiry != null ? Timestamp.fromDate(expiry) : null, 'aiEnabled': plan.aiUnlocked, 'status': 'active'});
      } else if (payment.type == 'commission' && payment.relatedTransactions != null) {
        for (var txId in payment.relatedTransactions!) batch.update(_db.collection(FirestorePaths.transactionsCol).doc(txId), {'status': 'settled', 'settledAt': FieldValue.serverTimestamp(), 'settledBy': _uid ?? 'admin', 'paymentProofId': payment.id});
      }
      await batch.commit();
      if (_notificationService != null) {
        if (payment.type == 'subscription') {
          final plan = kPlans.firstWhere((p) => p.planKey == payment.planId, orElse: () => kPlans.first);
          await _notificationService!.notifySubscriptionDecision(ceoUid: payment.payerId, companyId: payment.companyId, title: 'Subscription Activated! ✅', message: 'Your ${plan.name} subscription has been activated successfully.', data: {'planId': plan.planKey, 'status': 'active'});
        } else if (payment.type == 'commission') {
          await _notificationService!.notifyPaymentStatus(userId: payment.payerId, companyId: payment.companyId, title: 'Commission Payment Confirmed ✅', message: 'Your commission payment of Rs ${payment.amount} has been settled.', data: {'status': 'settled'});
        }
      }
      await _logAction(actionType: 'confirm_payment', targetType: 'payment_proof', targetId: payment.id, description: 'Confirmed ${payment.type} payment from ${payment.payerName}');
    } catch (e) {} finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> rejectPayment(PaymentProofModel payment, String reason) async {
    _isLoading = true; notifyListeners();
    try {
      await _db.collection('payment_proofs').doc(payment.id).update({'status': 'rejected', 'adminNotes': reason});
      if (_notificationService != null) await _notificationService!.notifyPaymentStatus(userId: payment.payerId, companyId: payment.companyId, title: 'Payment Rejected ❌', message: 'Your payment proof for ${payment.type} was rejected. Reason: $reason', data: {'status': 'rejected', 'reason': reason});
      await _logAction(actionType: 'reject_payment', targetType: 'payment_proof', targetId: payment.id, description: 'Rejected ${payment.type} payment from ${payment.payerName}', reason: reason);
    } catch (e) {} finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> loadCEOs() async {
    _isLoading = true; notifyListeners();
    try {
      final userSnap = await _db.collection('users').where('role', isEqualTo: 'CEO').get();
      List<Map<String, dynamic>> temp = [];
      for (var doc in userSnap.docs) {
        final ceo = UserModel.fromMap(doc.data(), doc.id);
        final companySnap = await _db.collection('companies').doc(ceo.companyId).get();
        temp.add({'ceo': ceo, 'company': companySnap.exists ? CompanyModel.fromMap(companySnap.data()!) : null});
      }
      _ceosList = temp;
    } finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> acceptCEO(String? companyId, String ceoUid) async {
    _isLoading = true; notifyListeners();
    try {
      final batch = _db.batch();
      if (companyId != null && companyId.isNotEmpty) batch.update(_db.collection('companies').doc(companyId), {'status': 'active', 'inviteCode': InviteCodeGenerator.generate(), 'inviteCodeGeneratedAt': FieldValue.serverTimestamp()});
      batch.update(_db.collection('users').doc(ceoUid), {'status': 'active', 'approved': true});
      await batch.commit();
      final ceoName = await _userName(ceoUid);
      final resolvedId = await _resolvedCompanyId(ceoUid, companyId);
      final companyName = await _companyName(resolvedId);
      await _logAction(actionType: 'approve_ceo', targetType: 'ceo', targetId: ceoUid, description: 'Approved CEO $ceoName for company $companyName');
      loadCEOs();
    } finally { _isLoading = false; notifyListeners(); }
  }
  
  Future<void> approveCEO(String? companyId, String ceoUid) => acceptCEO(companyId, ceoUid);

  Future<void> suspendCEO(String? companyId, String ceoUid) async {
    final resolvedId = await _resolvedCompanyId(ceoUid, companyId);
    final ceoName = await _userName(ceoUid);
    final companyName = await _companyName(resolvedId);
    await _db.collection('users').doc(ceoUid).update({'status': 'suspended'});
    if (resolvedId.isNotEmpty) await _db.collection('companies').doc(resolvedId).update({'status': 'suspended'});
    await _logAction(actionType: 'ban_company', targetType: 'company', targetId: resolvedId.isNotEmpty ? resolvedId : ceoUid, description: 'Banned company $companyName (CEO: $ceoName)');
    loadCEOs();
  }

  Future<void> activateCEO(String? companyId, String ceoUid) async {
    final resolvedId = await _resolvedCompanyId(ceoUid, companyId);
    final ceoName = await _userName(ceoUid);
    final companyName = await _companyName(resolvedId);
    await _db.collection('users').doc(ceoUid).update({'status': 'active'});
    if (resolvedId.isNotEmpty) await _db.collection('companies').doc(resolvedId).update({'status': 'active'});
    await _logAction(actionType: 'reactivate_company', targetType: 'company', targetId: resolvedId.isNotEmpty ? resolvedId : ceoUid, description: 'Reactivated company $companyName (CEO: $ceoName)');
    loadCEOs();
  }

  Future<void> rejectCEO(String? companyId, String ceoUid, String reason) async {
    final resolvedId = await _resolvedCompanyId(ceoUid, companyId);
    final ceoName = await _userName(ceoUid);
    final companyName = await _companyName(resolvedId);
    await _db.collection('users').doc(ceoUid).update({'status': 'rejected', 'rejectionReason': reason});
    if (resolvedId.isNotEmpty) await _db.collection('companies').doc(resolvedId).update({'status': 'rejected', 'rejectionReason': reason});
    await _logAction(actionType: 'reject_ceo', targetType: 'ceo', targetId: ceoUid, description: 'Rejected CEO application for $ceoName ($companyName)', reason: reason);
    loadCEOs();
  }

  Future<void> loadSuppliers() async {
    final snap = await _db.collection('users').where('role', isEqualTo: 'Supplier').get();
    _suppliersList = snap.docs.map((d) => {'user': UserModel.fromMap(d.data(), d.id)}).toList();
    notifyListeners();
  }

  Future<void> approveSupplier(String uid) async {
    _isLoading = true; notifyListeners();
    try {
      await _db.collection('users').doc(uid).update({'status': 'active', 'approved': true});
      await _db.collection('suppliers').doc(uid).update({'status': 'Active', 'isVerified': true});
      final supplierName = await _supplierName(uid);
      await _logAction(actionType: 'approve_supplier', targetType: 'supplier', targetId: uid, description: 'Approved supplier $supplierName');
      loadSuppliers();
    } finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> suspendSupplier(String uid) async {
    final supplierName = await _supplierName(uid);
    await _db.collection('users').doc(uid).update({'status': 'suspended'});
    await _db.collection('suppliers').doc(uid).update({'status': 'Suspended'});
    await _logAction(actionType: 'ban_supplier', targetType: 'supplier', targetId: uid, description: 'Banned supplier $supplierName');
    loadSuppliers();
  }

  Future<void> reactivateSupplier(String uid) async {
    final supplierName = await _supplierName(uid);
    await _db.collection('users').doc(uid).update({'status': 'active', 'approved': true});
    await _db.collection('suppliers').doc(uid).update({'status': 'Active', 'isVerified': true});
    await _logAction(actionType: 'reactivate_supplier', targetType: 'supplier', targetId: uid, description: 'Reactivated supplier $supplierName');
    loadSuppliers();
  }

  Future<void> rejectSupplier(String uid, String reason) async {
    final supplierName = await _supplierName(uid);
    await _db.collection('users').doc(uid).update({'status': 'rejected', 'rejectionReason': reason});
    await _db.collection('suppliers').doc(uid).update({'status': 'Rejected'});
    await _logAction(actionType: 'reject_supplier', targetType: 'supplier', targetId: uid, description: 'Rejected supplier application for $supplierName', reason: reason);
    loadSuppliers();
  }

  Future<void> deleteSupplierPermanently(String uid) async {
    await _db.collection('users').doc(uid).delete();
    await _db.collection('suppliers').doc(uid).delete();
    await _logAction(actionType: 'delete_supplier', targetType: 'supplier', targetId: uid, description: 'Permanently deleted supplier account and data');
    loadSuppliers();
  }

  Future<void> acceptAppeal(Map<String, dynamic> appeal, String appealId) async {
    _isLoading = true; notifyListeners();
    try {
      final uid = appeal['uid'] as String; final role = (appeal['role'] as String).toLowerCase();
      final batch = _db.batch();
      batch.update(_db.collection('appeals').doc(appealId), {'status': 'accepted', 'respondedAt': FieldValue.serverTimestamp(), 'respondedBy': _uid ?? 'admin'});
      if (role == 'supplier') {
        batch.update(_db.collection('users').doc(uid), {'status': 'active', 'approved': true});
        batch.update(_db.collection('suppliers').doc(uid), {'status': 'Active', 'isVerified': true});
      } else if (role == 'ceo') {
        final companyId = appeal['companyId'] as String; String inviteCode = InviteCodeGenerator.generate();
        batch.update(_db.collection('users').doc(uid), {'status': 'active', 'approved': true});
        if (companyId.isNotEmpty) batch.update(_db.collection('companies').doc(companyId), {'status': 'active', 'inviteCode': inviteCode, 'inviteCodeGeneratedAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
      await _logAction(actionType: 'accept_appeal', targetType: 'appeal', targetId: appealId, description: 'Accepted appeal');
      if (_notificationService != null) await _notificationService!.notifyPaymentStatus(userId: uid, companyId: appeal['companyId'] ?? '', title: 'Appeal Accepted ✅', message: 'Your account appeal has been accepted.', data: {'status': 'active'});
    } finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> rejectAppeal(Map<String, dynamic> appeal, String appealId, String reason) async {
    _isLoading = true; notifyListeners();
    try {
      await _db.collection('appeals').doc(appealId).update({'status': 'rejected', 'adminResponse': reason, 'respondedAt': FieldValue.serverTimestamp(), 'respondedBy': _uid ?? 'admin'});
      await _logAction(actionType: 'reject_appeal', targetType: 'appeal', targetId: appealId, description: 'Rejected appeal', reason: reason);
    } finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> addCategory(String name, String unit, List<String> brands, List<String> grades) async {
    final docRef = await _db.collection('categories').add({'name': name, 'unit': unit, 'brands': brands, 'grades': grades, 'active': true, 'createdAt': FieldValue.serverTimestamp()});
    await _logAction(actionType: 'add_category', targetType: 'category', targetId: docRef.id, description: 'Added category: $name');
  }

  Future<void> editCategory(String id, String name, String unit, List<String> brands, List<String> grades) async {
    await _db.collection('categories').doc(id).update({'name': name, 'unit': unit, 'brands': brands, 'grades': grades});
    await _logAction(actionType: 'edit_category', targetType: 'category', targetId: id, description: 'Updated category: $name');
  }

  Future<void> setCategoryActive(String id, bool active) async => await _db.collection('categories').doc(id).update({'active': active});
  Future<void> deleteCategory(String id) async => await _db.collection('categories').doc(id).delete();
  Stream<List<CategoryModel>> watchCategories() => _db.collection('categories').snapshots().map((s) => s.docs.map((d) => CategoryModel.fromDoc(d.id, d.data())).toList());
}
