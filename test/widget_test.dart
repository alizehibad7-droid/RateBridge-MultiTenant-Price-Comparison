import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ratebridge/app.dart';
import 'package:ratebridge/viewmodels/auth_viewmodel.dart';
import 'package:ratebridge/viewmodels/ceo_viewmodel.dart';
import 'package:ratebridge/viewmodels/admin_viewmodel.dart';
import 'package:ratebridge/viewmodels/supplier_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_session_viewmodel.dart';
import 'package:ratebridge/repositories/user_repository.dart';
import 'package:ratebridge/repositories/company_repository.dart';
import 'package:ratebridge/repositories/material_repository.dart';
import 'package:ratebridge/repositories/order_repository.dart';
import 'package:ratebridge/repositories/transaction_repository.dart';
import 'package:ratebridge/repositories/price_history_repository.dart';
import 'package:ratebridge/repositories/supplier_repository.dart';
import 'package:ratebridge/repositories/join_request_repository.dart';
import 'package:ratebridge/repositories/invitation_repository.dart';
import 'package:ratebridge/repositories/notification_repository.dart';
import 'package:ratebridge/services/notification_service.dart';
import 'package:ratebridge/services/firebase_auth_service.dart';
import 'package:ratebridge/services/firestore_service.dart';
import 'package:ratebridge/services/storage_service.dart';
import 'package:ratebridge/services/cloud_function_service.dart';
import 'package:ratebridge/services/dynamic_link_service.dart';
import 'package:ratebridge/services/gemini_service.dart';

void main() {
  testWidgets('App branding smoke test', (WidgetTester tester) async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final firestoreService = FirestoreService();
    final firebaseAuthService = FirebaseAuthService(firestoreService);
    final userRepository = UserRepository(firebaseAuthService, firestoreService);
    final materialRepository = MaterialRepository(firestoreService);
    final orderRepository = OrderRepository(firestoreService);
    final transactionRepository = TransactionRepository(firestoreService);
    final storageService = StorageService();
    final priceHistoryRepository = PriceHistoryRepository(firestoreService);
    final cloudFunctionService = CloudFunctionService();
    final companyRepository = CompanyRepository(firestoreService);
    final joinRequestRepository = JoinRequestRepository(firestoreService);
    final invitationRepository = InvitationRepository(firestoreService);
    final notificationRepository = NotificationRepository(firestoreService);
    final notificationService = NotificationService(notificationRepository);
    final geminiService = GeminiService();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SharedPreferences>.value(value: prefs),
          Provider<FirestoreService>.value(value: firestoreService),
          Provider<FirebaseAuthService>.value(value: firebaseAuthService),
          Provider<UserRepository>.value(value: userRepository),
          Provider<MaterialRepository>.value(value: materialRepository),
          Provider<OrderRepository>.value(value: orderRepository),
          Provider<TransactionRepository>.value(value: transactionRepository),
          Provider<StorageService>.value(value: storageService),
          Provider<PriceHistoryRepository>.value(value: priceHistoryRepository),
          Provider<CloudFunctionService>.value(value: cloudFunctionService),
          Provider<CompanyRepository>.value(value: companyRepository),
          Provider<JoinRequestRepository>.value(value: joinRequestRepository),
          Provider<InvitationRepository>.value(value: invitationRepository),
          Provider<NotificationRepository>.value(value: notificationRepository),
          Provider<NotificationService>.value(value: notificationService),
          Provider<GeminiService>.value(value: geminiService),
          
          ChangeNotifierProvider(
            create: (context) => AuthViewModel(userRepository, firebaseAuthService),
          ),
          ChangeNotifierProxyProvider<AuthViewModel, CeoViewModel>(
            create: (context) => CeoViewModel(
              null, 
              'CEO',
              orderRepository,
              joinRequestRepository,
              userRepository,
              companyRepository,
              invitationRepository,
              notificationService,
              cloudFunctionService,
            ),
            update: (context, auth, previous) => CeoViewModel(
              auth.user?.uid,
              auth.user?.name ?? 'CEO',
              orderRepository,
              joinRequestRepository,
              userRepository,
              companyRepository,
              invitationRepository,
              notificationService,
              cloudFunctionService,
            ),
          ),
          ChangeNotifierProxyProvider<AuthViewModel, AdminViewModel>(
            create: (context) => AdminViewModel(),
            update: (context, auth, previous) => AdminViewModel(),
          ),
          ChangeNotifierProxyProvider<AuthViewModel, SupplierViewModel>(
            create: (context) => SupplierViewModel(
              materialRepository,
              orderRepository,
              transactionRepository,
              storageService,
              priceHistoryRepository,
              cloudFunctionService,
              userRepository,
              companyRepository,
              notificationService,
            ),
            update: (context, auth, previous) {
              final vm = previous ?? SupplierViewModel(
                materialRepository,
                orderRepository,
                transactionRepository,
                storageService,
                priceHistoryRepository,
                cloudFunctionService,
                userRepository,
                companyRepository,
                notificationService,
              );
              vm.updateAuth(auth);
              return vm;
            },
          ),
          ChangeNotifierProvider(
            create: (context) => FieldSessionViewModel(
              companyRepository,
              userRepository,
            ),
          ),
        ],
        child: const RateBridgeApp(),
      ),
    );

    // Verify that the splash screen displays the app name
    expect(find.text('RATEBRIDGE'), findsOneWidget);
    
    // Updated to match the actual text in SplashView
    expect(find.text('CONNECTING CONSTRUCTION'), findsOneWidget);
    
    // Pump frames to handle animation
    await tester.pump(const Duration(milliseconds: 500));
  });
}
