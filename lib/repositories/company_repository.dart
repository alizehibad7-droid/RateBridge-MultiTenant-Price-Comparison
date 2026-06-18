import '../models/company_model.dart';
import '../services/firestore_service.dart';

class CompanyRepository {
  final FirestoreService _firestoreService;

  CompanyRepository(this._firestoreService);

  Future<CompanyModel?> getCompanyById(String companyId) async {
    return await _firestoreService.getCompany(companyId);
  }

  Future<void> createCompany(CompanyModel company) async {
    await _firestoreService.saveCompany(company);
  }

  Future<List<CompanyModel>> getAllCompanies() async {
    return await _firestoreService.getCompanies();
  }
}
