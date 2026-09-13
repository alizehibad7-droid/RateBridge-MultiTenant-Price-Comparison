import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/company_model.dart';
import '../../repositories/company_repository.dart';
import '../../repositories/user_repository.dart';
import '../auth_viewmodel.dart';

/// Session context for the Field User Panel — current user and company.
class FieldSessionViewModel extends ChangeNotifier {
  final CompanyRepository _companyRepo;
  final UserRepository _userRepo;

  UserModel? _user;
  CompanyModel? _company;
  bool _isLoading = false;
  String? _errorMessage;

  FieldSessionViewModel(this._companyRepo, this._userRepo);

  UserModel? get user => _user;
  CompanyModel? get company => _company;
  String? get companyId => _user?.companyId;
  String get companyName => _company?.name ?? 'Loading...';
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void updateAuth(AuthViewModel auth) {
    _user = auth.user;
    if (_user != null) {
      loadCompanyContext();
    } else {
      _company = null;
    }
    notifyListeners();
  }

  Future<void> loadCompanyContext() async {
    if (_user == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _company = await _companyRepo.getCompanyById(_user!.companyId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    if (_user == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _user = await _userRepo.getUserDoc(_user!.uid);
      await loadCompanyContext();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({String? name, String? phone}) async {
    if (_user == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updated = _user!.copyWith(
        name: name ?? _user!.name,
        phone: phone ?? _user!.phone,
      );
      await _userRepo.updateUserDoc(_user!.uid, {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
      });
      _user = updated;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
