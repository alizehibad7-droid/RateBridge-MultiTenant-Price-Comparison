import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/ceo_viewmodel.dart';
import 'viewmodels/admin_viewmodel.dart';
import 'viewmodels/supplier_viewmodel.dart';
import 'viewmodels/field_user_viewmodel.dart';
import 'viewmodels/field_order_viewmodel.dart';
import 'viewmodels/invite_viewmodel.dart';
import 'viewmodels/comparison_viewmodel.dart';
import 'viewmodels/order_viewmodel.dart';
import 'viewmodels/subscription_viewmodel.dart';
import 'repositories/user_repository.dart';
import 'repositories/company_repository.dart';
import 'repositories/material_repository.dart';
import 'repositories/order_repository.dart';
import 'repositories/transaction_repository.dart';
import 'repositories/price_history_repository.dart';
import 'repositories/supplier_repository.dart';
import 'repositories/join_request_repository.dart';
import 'repositories/invitation_repository.dart';
import 'services/firebase_auth_service.dart';
import 'services/firestore_service.dart';
import 'services/storage_service.dart';
import 'services/cloud_function_service.dart';
import 'services/dynamic_link_service.dart';
import 'services/gemini_service.dart';
import 'services/voice_search_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SharedPreferences? prefs;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint("Startup Error: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        if (prefs != null) 
          Provider<SharedPreferences>.value(value: prefs)
        else 
          FutureProvider<SharedPreferences?>(
            create: (_) => SharedPreferences.getInstance(), 
            initialData: null
          ),
          
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<CloudFunctionService>(create: (_) => CloudFunctionService()),
        Provider<DynamicLinkService>(create: (_) => DynamicLinkService()),
        Provider<GeminiService>(create: (_) => GeminiService()),
        Provider<VoiceSearchService>(create: (_) => VoiceSearchService()),
        
        ProxyProvider<FirestoreService, FirebaseAuthService>(
          update: (context, firestore, previous) => FirebaseAuthService(firestore),
        ),
        
        ProxyProvider2<FirebaseAuthService, FirestoreService, UserRepository>(
          update: (context, auth, firestore, previous) => UserRepository(auth, firestore),
        ),

        ProxyProvider<FirestoreService, CompanyRepository>(
          update: (context, firestore, previous) => CompanyRepository(firestore),
        ),
        
        ProxyProvider<FirestoreService, MaterialRepository>(
          update: (context, firestore, previous) => MaterialRepository(firestore),
        ),

        ProxyProvider<FirestoreService, OrderRepository>(
          update: (context, firestore, previous) => OrderRepository(firestore),
        ),

        ProxyProvider<FirestoreService, TransactionRepository>(
          update: (context, firestore, previous) => TransactionRepository(firestore),
        ),

        ProxyProvider<FirestoreService, PriceHistoryRepository>(
          update: (context, firestore, previous) => PriceHistoryRepository(firestore),
        ),

        ProxyProvider<FirestoreService, SupplierRepository>(
          update: (context, firestore, previous) => SupplierRepository(firestore),
        ),

        ProxyProvider<FirestoreService, JoinRequestRepository>(
          update: (context, firestore, previous) => JoinRequestRepository(firestore),
        ),

        ProxyProvider<FirestoreService, InvitationRepository>(
          update: (context, firestore, previous) => InvitationRepository(firestore),
        ),

        ChangeNotifierProxyProvider<UserRepository, AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<UserRepository>(), 
            context.read<FirebaseAuthService>()
          ),
          update: (context, repo, previous) => previous ?? AuthViewModel(
            repo, 
            context.read<FirebaseAuthService>()
          ),
        ),

        ChangeNotifierProxyProvider2<OrderRepository, CloudFunctionService, OrderViewModel>(
          create: (context) => OrderViewModel(
            context.read<OrderRepository>(),
            context.read<CloudFunctionService>(),
          ),
          update: (context, repo, cloud, previous) {
            final vm = previous ?? OrderViewModel(repo, cloud);
            vm.updateAuth(context.read<AuthViewModel>());
            return vm;
          },
        ),

        ChangeNotifierProvider<SubscriptionViewModel>(
          create: (context) => SubscriptionViewModel(),
        ),

        ChangeNotifierProxyProvider4<InvitationRepository, JoinRequestRepository, DynamicLinkService, CloudFunctionService, InviteViewModel>(
          create: (context) => InviteViewModel(
            context.read<InvitationRepository>(),
            context.read<JoinRequestRepository>(),
            context.read<DynamicLinkService>(),
            context.read<CloudFunctionService>(),
          ),
          update: (context, inv, join, dyn, cloud, previous) {
            final vm = previous ?? InviteViewModel(inv, join, dyn, cloud);
            vm.updateAuth(context.read<AuthViewModel>());
            return vm;
          },
        ),

        ChangeNotifierProxyProvider4<MaterialRepository, OrderRepository, GeminiService, AuthViewModel, FieldUserViewModel>(
          create: (context) => FieldUserViewModel(
            context.read<MaterialRepository>(),
            context.read<OrderRepository>(),
            context.read<GeminiService>(),
          ),
          update: (context, mat, ord, gem, auth, previous) {
            final vm = previous ?? FieldUserViewModel(mat, ord, gem);
            vm.updateAuth(auth);
            return vm;
          },
        ),

        ChangeNotifierProxyProvider2<OrderRepository, MaterialRepository, FieldOrderViewModel>(
          create: (context) => FieldOrderViewModel(
            context.read<OrderRepository>(),
            context.read<MaterialRepository>(),
          ),
          update: (context, ord, mat, previous) => previous ?? FieldOrderViewModel(ord, mat),
        ),

        ChangeNotifierProxyProvider2<MaterialRepository, GeminiService, ComparisonViewModel>(
          create: (context) => ComparisonViewModel(
            context.read<MaterialRepository>(),
            context.read<GeminiService>(),
          ),
          update: (context, mat, gem, previous) => previous ?? ComparisonViewModel(mat, gem),
        ),

        ChangeNotifierProxyProvider<AuthViewModel, CeoViewModel>(
          create: (context) => CeoViewModel(
            null, 
            'CEO',
            context.read<OrderRepository>(),
            context.read<JoinRequestRepository>(),
            context.read<UserRepository>(),
            context.read<CompanyRepository>(),
            context.read<InvitationRepository>(),
            context.read<CloudFunctionService>(),
          ),
          update: (context, auth, previous) {
            if (previous == null || previous.uid != auth.user?.uid) {
              return CeoViewModel(
                auth.user?.uid, 
                auth.user?.name ?? 'CEO',
                context.read<OrderRepository>(),
                context.read<JoinRequestRepository>(),
                context.read<UserRepository>(),
                context.read<CompanyRepository>(),
                context.read<InvitationRepository>(),
                context.read<CloudFunctionService>(),
              );
            }
            return previous;
          },
        ),

        ChangeNotifierProxyProvider<AuthViewModel, AdminViewModel>(
          create: (_) => AdminViewModel(),
          update: (_, auth, previous) {
            final vm = previous ?? AdminViewModel();
            vm.updateAuth(auth);
            return vm;
          },
        ),

        ChangeNotifierProxyProvider<AuthViewModel, SupplierViewModel>(
          create: (context) => SupplierViewModel(
            context.read<MaterialRepository>(),
            context.read<OrderRepository>(),
            context.read<TransactionRepository>(),
            context.read<StorageService>(),
            context.read<PriceHistoryRepository>(),
            context.read<CloudFunctionService>(),
            context.read<UserRepository>(),
            context.read<CompanyRepository>(),
          ),
          update: (context, auth, previous) {
            previous?.updateAuth(auth);
            return previous ?? SupplierViewModel(
              context.read<MaterialRepository>(),
              context.read<OrderRepository>(),
              context.read<TransactionRepository>(),
              context.read<StorageService>(),
              context.read<PriceHistoryRepository>(),
              context.read<CloudFunctionService>(),
              context.read<UserRepository>(),
              context.read<CompanyRepository>(),
            );
          },
        ),
      ],
      child: const RateBridgeApp(),
    ),
  );
}
