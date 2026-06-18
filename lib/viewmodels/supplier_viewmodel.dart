// MVVM: ViewModel — business logic only
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/material_model.dart';
import '../models/order_model.dart';
import '../models/rating_model.dart';
import '../models/transaction_model.dart';
import '../models/company_model.dart';
import '../models/user_model.dart';
import '../models/invitation_model.dart';
import '../repositories/material_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/price_history_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/company_repository.dart';
import '../services/storage_service.dart';
import '../services/cloud_function_service.dart';
import 'auth_viewmodel.dart';

enum SupplierStatus { unknown, pending, rejected, active }

class SupplierViewModel extends ChangeNotifier {
  final MaterialRepository _materialRepo;
  final OrderRepository _orderRepo;
  final TransactionRepository _transactionRepo;
  final StorageService _storageService;
  final PriceHistoryRepository _priceHistoryRepo;
  final CloudFunctionService _cloudFunctions;
  final UserRepository _userRepo;
  final CompanyRepository _companyRepo;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  SupplierViewModel(
    this._materialRepo,
    this._orderRepo,
    this._transactionRepo,
    this._storageService,
    this._priceHistoryRepo,
    this._cloudFunctions,
    this._userRepo,
    this._companyRepo,
  );

  String? _supplierUid;
  String? _selectedCompanyId;
  String? _rejectionReason;
  String? _error;
  bool _isLoading = false;
  bool _appealSubmitted = false;

  List<MaterialModel> _materials = [];
  List<OrderModel> _orders = [];
  List<RatingModel> _ratings = [];
  List<TransactionModel> _transactions = [];
  List<CompanyModel> _companies = [];
  List<InvitationModel> _invitations = [];
  List<Map<String, dynamic>> _monthlyChart = [];
  UserModel? _profile;
  String _status = 'pending';

  StreamSubscription? _statusSubscription;
  StreamSubscription? _materialsSubscription;
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _earningsSubscription;
  StreamSubscription? _invitationsSubscription;

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
  bool get isLoading => _isLoading;
  bool get appealSubmitted => _appealSubmitted;
  List<MaterialModel> get materials => _materials;
  List<OrderModel> get orders => _orders;
  List<RatingModel> get ratings => _ratings;
  List<TransactionModel> get transactions => _transactions;
  List<CompanyModel> get companies => _companies;
  List<InvitationModel> get invitations => _invitations;
  List<Map<String, dynamic>> get monthlyChart => _monthlyChart;
  UserModel? get profile => _profile;
  String get status => _status;

  int get totalMaterialsCount => _materials.length;
  
  int get pendingOrdersCount => _orders.where((o) => o.status == 'pending').length;
  int get inProgressOrdersCount => _orders.where((o) => o.status == 'accepted' || o.status == 'inProgress').length;
  int get completedThisMonth => _orders.where((o) => o.status == 'confirmed' && o.createdAt.month == DateTime.now().month).length;

  double get averageRating {
    if (_ratings.isEmpty) return 0.0;
    final sum = _ratings.fold<double>(0, (acc, r) => acc + (r.rating ?? 0.0));
    return sum / _ratings.length;
  }

  void updateAuth(AuthViewModel auth) {
    if (_supplierUid != auth.user?.uid) {
      _supplierUid = auth.user?.uid;
      if (_supplierUid != null) {
        watchStatus();
        loadLinkedCompanies();
        loadInvitations();
        loadProfile();
      } else {
        _cancelSubscriptions();
      }
      notifyListeners();
    }
  }

  void _cancelSubscriptions() {
    _statusSubscription?.cancel();
    _materialsSubscription?.cancel();
    _ordersSubscription?.cancel();
    _earningsSubscription?.cancel();
    _invitationsSubscription?.cancel();
  }

  void watchStatus() {
    if (_supplierUid == null) return;
    _statusSubscription?.cancel();
    _statusSubscription = _userRepo.watchUserDoc(_supplierUid!).listen((user) {
      _status = user.status ?? 'pending';
      _rejectionReason = user.rejectionReason;
      notifyListeners();
    });
  }

  Future<void> loadLinkedCompanies() async {
    if (_supplierUid == null) return;
    _db.collection('suppliers').doc(_supplierUid).collection('companies')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snap) async {
      final companyList = <CompanyModel>[];
      for (var doc in snap.docs) {
        final c = await _companyRepo.getCompanyById(doc.id);
        if (c != null) companyList.add(c);
      }
      _companies = companyList;
      if (_selectedCompanyId == null && _companies.isNotEmpty) {
        switchCompany(_companies.first.id);
      }
      notifyListeners();
    });
  }

  void switchCompany(String companyId) {
    if (_selectedCompanyId == companyId) return;
    _selectedCompanyId = companyId;
    loadMaterials(companyId);
    loadOrders(companyId, null);
    loadEarnings(DateTime.now().month.toString()); // Simplified month
    loadRatings(_supplierUid!, companyId);
    notifyListeners();
  }

  // --- Invitations ---

  void loadInvitations() {
    if (_supplierUid == null) return;
    _invitationsSubscription?.cancel();
    _invitationsSubscription = _db.collection('invitations')
        .where('supplierUid', isEqualTo: _supplierUid)
        .snapshots()
        .listen((snap) {
      _invitations = snap.docs.map((d) => InvitationModel.fromMap(d.id, d.data())).toList();
      notifyListeners();
    });
  }

  Future<void> acceptInvitation(String inviteId, String companyId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final batch = _db.batch();
      
      batch.update(_db.collection('invitations').doc(inviteId), {'status': 'accepted'});
      
      final supplierRef = _db.collection('suppliers').doc(_supplierUid);
      final companyRef = _db.collection('companies').doc(companyId);
      
      batch.set(supplierRef.collection('companies').doc(companyId), {
        'id': companyId,
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
        'companyRating': 0,
        'onboardingComplete': false,
      });

      batch.set(companyRef.collection('suppliers').doc(_supplierUid), {
        'id': _supplierUid,
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      batch.update(supplierRef, {'totalCompanies': FieldValue.increment(1)});

      await batch.commit();
      _selectedCompanyId = companyId;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectInvitation(String inviteId) async {
    await _db.collection('invitations').doc(inviteId).update({'status': 'rejected'});
  }

  // --- Materials ---

  Future<void> addMaterial(MaterialModel material, File? imageFile, String companyId) async {
    _isLoading = true;
    notifyListeners();
    try {
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await _storageService.uploadFile(file: imageFile, path: 'materials/${material.id}');
      }
      final newMat = material.copyWith(profileImageUrl: imageUrl, supplierId: _supplierUid);
      
      final batch = _db.batch();
      final companyMatRef = _db.collection('companies').doc(companyId).collection('materials').doc(newMat.id);
      batch.set(companyMatRef, newMat.toMap());
      
      final globalMatRef = _db.collection('materials').doc(newMat.id);
      batch.set(globalMatRef, newMat.toMap());
      
      final historyRef = globalMatRef.collection('priceHistory').doc();
      batch.set(historyRef, {
        'price': newMat.pricePerUnit,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateMaterial(String matId, Map<String, dynamic> data, File? imageFile, String companyId) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (imageFile != null) {
        data['profileImageUrl'] = await _storageService.uploadFile(file: imageFile, path: 'materials/$matId');
      }
      
      if (data.containsKey('pricePerUnit')) {
        await _db.collection('materials').doc(matId).collection('priceHistory').add({
          'price': data['pricePerUnit'],
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      
      await _db.collection('materials').doc(matId).update(data);
      await _db.collection('companies').doc(companyId).collection('materials').doc(matId).update(data);
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
      await _db.collection('companies').doc(companyId).collection('materials').doc(matId).delete();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMaterials(String companyId) async {
    _materialsSubscription?.cancel();
    _materialsSubscription = _db.collection('companies').doc(companyId).collection('materials')
        .where('supplierId', isEqualTo: _supplierUid)
        .snapshots()
        .listen((snap) {
      _materials = snap.docs.map((d) => MaterialModel.fromMap(d.data())).toList();
      notifyListeners();
    });
  }

  // --- Orders ---

  Future<void> loadOrders(String companyId, String? statusFilter) async {
    if (_supplierUid == null) return;
    _ordersSubscription?.cancel();
    _ordersSubscription = _orderRepo.getOrdersForSupplier(_supplierUid!).listen((data) {
      _orders = data.where((o) => o.companyId == companyId).toList();
      notifyListeners();
    });
  }

  Future<void> acceptOrder(String orderId, String companyId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _orderRepo.updateStatus(orderId, companyId, 'accepted');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectOrder(String orderId, String companyId, String reason) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _orderRepo.updateStatus(orderId, companyId, 'rejected', reason: reason);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markDelivered(String orderId, String companyId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _orderRepo.updateStatus(orderId, companyId, 'delivered', deliveredAt: DateTime.now());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Onboarding ---

  Future<void> completeCompanyOnboarding(String companyId, Map<String, dynamic> details) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _db.collection('suppliers').doc(_supplierUid)
          .collection('companies').doc(companyId)
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
    if (_supplierUid == null) return;
    _earningsSubscription?.cancel();
    _isLoading = true;
    notifyListeners();
    try {
      _earningsSubscription = _transactionRepo.watchSupplierEarnings(_supplierUid!, month).listen((txs) {
        _transactions = txs;
        
        // Calculate totals
        totalEarnings = txs.fold(0.0, (sum, tx) => sum + tx.totalAmount);
        netEarnings = txs.fold(0.0, (sum, tx) => sum + tx.supplierEarning);
        
        notifyListeners();
      });
      final summary = await _transactionRepo.getMonthlyEarningsSummary(_supplierUid!, 6);
      _monthlyChart = summary.map((e) => {'month': e.month, 'amount': e.net}).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> changeMonth(String month) async {
    await loadEarnings(month);
  }

  Future<void> loadProfile() async {
    if (_supplierUid == null) return;
    _profile = await _userRepo.getUserDoc(_supplierUid!);
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> fields) async {
    if (_supplierUid == null) return;
    await _userRepo.updateUserDoc(_supplierUid!, fields);
    await loadProfile();
  }

  Future<void> submitAppeal(String message, File? file, String? phone) async {
    _isLoading = true;
    notifyListeners();
    try {
      String? imageUrl;
      if (file != null) {
        imageUrl = await _storageService.uploadFile(file: file, path: 'appeals/$_supplierUid');
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
    _isLoading = true;
    notifyListeners();
    try {
      _companies = await _companyRepo.getAllCompanies();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchCompanies(String query) async {
    final all = await _companyRepo.getAllCompanies();
    _companies = all.where((c) => c.name.toLowerCase().contains(query.toLowerCase())).toList();
    notifyListeners();
  }

  Future<void> sendJoinRequest(String companyId, String message) async {
    await _db.collection('joinRequests').add({
      'companyId': companyId,
      'supplierUid': _supplierUid,
      'message': message,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'supplierName': _profile?.name ?? 'Supplier',
    });
  }

  Future<void> loadRatings(String supplierUid, String companyId) async {
    _db.collection('ratings')
        .where('supplierUid', isEqualTo: supplierUid)
        .snapshots().listen((snap) {
      _ratings = snap.docs.map((d) => RatingModel.fromMap(d.id, d.data())).toList();
      notifyListeners();
    });
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
    if (_selectedCompanyId != null) {
      await loadMaterials(_selectedCompanyId!);
      await loadOrders(_selectedCompanyId!, null);
      await loadEarnings(DateTime.now().month.toString());
    }
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
