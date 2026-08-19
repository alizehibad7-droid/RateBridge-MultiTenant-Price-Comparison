import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/ceo_viewmodel.dart';
import 'viewmodels/admin_viewmodel.dart';
import 'viewmodels/supplier_viewmodel.dart';
import 'viewmodels/field_user/field_session_viewmodel.dart';
import 'viewmodels/field_user/field_catalog_viewmodel.dart';
import 'viewmodels/field_user/field_compare_viewmodel.dart';
import 'viewmodels/field_user/field_trends_viewmodel.dart';
import 'viewmodels/field_user/field_orders_viewmodel.dart';
import 'viewmodels/field_user/field_chat_viewmodel.dart';
import 'viewmodels/field_user/field_notifications_viewmodel.dart';
import 'viewmodels/field_user/field_rating_viewmodel.dart';
import 'viewmodels/field_user/field_supplier_profile_viewmodel.dart';
import 'viewmodels/invite_viewmodel.dart';
import 'viewmodels/comparison_viewmodel.dart';
import 'viewmodels/order_viewmodel.dart';
import 'viewmodels/chat_viewmodel.dart';
import 'viewmodels/subscription_viewmodel.dart';
import 'viewmodels/notification_viewmodel.dart';
import 'viewmodels/material_viewmodel.dart';
import 'viewmodels/rfq_viewmodel.dart';
import 'viewmodels/dispute_viewmodel.dart';
import 'repositories/user_repository.dart';
import 'repositories/company_repository.dart';
import 'repositories/material_repository.dart';
import 'repositories/order_repository.dart';
import 'repositories/transaction_repository.dart';
import 'repositories/price_history_repository.dart';
import 'repositories/supplier_repository.dart';
import 'repositories/partnership_request_repository.dart';
import 'repositories/join_request_repository.dart';
import 'repositories/invitation_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/notification_repository.dart';
import 'services/firebase_auth_service.dart';
import 'services/firestore_service.dart';
import 'services/storage_service.dart';
import 'services/cloud_function_service.dart';
import 'services/dynamic_link_service.dart';
import 'services/gemini_service.dart';
import 'services/ai_context_service.dart';
import 'services/voice_search_service.dart';
import 'services/recently_viewed_service.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';

/// Call once after [Firebase.initializeApp], before any Firestore reads.
void configureFirestoreForPlatform() {
  if (!kIsWeb) return;
  FirebaseFirestore.instance.settings = const Settings(
    webExperimentalAutoDetectLongPolling: true,
  );
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    SharedPreferences? prefs;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      configureFirestoreForPlatform();
      prefs = await SharedPreferences.getInstance();

      // Initialize FCM only on mobile platforms
      if (!kIsWeb) {
        await FCMService().initialize();
      }
    } catch (e) {
      debugPrint("Firebase/Startup Error: $e");
    }

    runApp(
      MultiProvider(
        providers: [
          if (prefs != null)
            Provider<SharedPreferences>.value(value: prefs)
          else
            FutureProvider<SharedPreferences?>(
              create: (_) => SharedPreferences.getInstance(),
              initialData: null,
            ),

          Provider<FirestoreService>(create: (_) => FirestoreService()),
          Provider<StorageService>(create: (_) => StorageService()),
          Provider<CloudFunctionService>(create: (_) => CloudFunctionService()),
          Provider<DynamicLinkService>(create: (_) => DynamicLinkService()),
          Provider<GeminiService>(create: (_) => GeminiService()),
          ChangeNotifierProvider<AiContextService>(
            create: (_) => AiContextService(),
          ),
          Provider<VoiceSearchService>(create: (_) => VoiceSearchService()),

          ProxyProvider<FirestoreService, FirebaseAuthService>(
            update:
                (context, firestore, previous) =>
                    FirebaseAuthService(firestore),
          ),

          ProxyProvider2<FirebaseAuthService, FirestoreService, UserRepository>(
            update:
                (context, auth, firestore, previous) =>
                    UserRepository(auth, firestore),
          ),

          ProxyProvider<FirestoreService, CompanyRepository>(
            update:
                (context, firestore, previous) => CompanyRepository(firestore),
          ),

          ProxyProvider<FirestoreService, MaterialRepository>(
            update:
                (context, firestore, previous) => MaterialRepository(firestore),
          ),

          ProxyProvider<SharedPreferences, RecentlyViewedService>(
            update: (context, prefs, previous) => RecentlyViewedService(prefs),
          ),

          ProxyProvider<FirestoreService, OrderRepository>(
            update:
                (context, firestore, previous) => OrderRepository(firestore),
          ),

          ProxyProvider<FirestoreService, TransactionRepository>(
            update:
                (context, firestore, previous) =>
                    TransactionRepository(firestore),
          ),

          ProxyProvider<FirestoreService, PriceHistoryRepository>(
            update:
                (context, firestore, previous) =>
                    PriceHistoryRepository(firestore),
          ),

          ProxyProvider<FirestoreService, SupplierRepository>(
            update:
                (context, firestore, previous) => SupplierRepository(firestore),
          ),

          ProxyProvider<FirestoreService, PartnershipRequestRepository>(
            update:
                (context, firestore, previous) =>
                    PartnershipRequestRepository(firestore),
          ),

          ProxyProvider<FirestoreService, JoinRequestRepository>(
            update:
                (context, firestore, previous) =>
                    JoinRequestRepository(firestore),
          ),

          ProxyProvider<FirestoreService, InvitationRepository>(
            update:
                (context, firestore, previous) =>
                    InvitationRepository(firestore),
          ),

          ProxyProvider<FirestoreService, ChatRepository>(
            update: (context, firestore, previous) => ChatRepository(firestore),
          ),

          ProxyProvider<FirestoreService, NotificationRepository>(
            update:
                (context, firestore, previous) =>
                    NotificationRepository(firestore),
          ),

          ProxyProvider<NotificationRepository, NotificationService>(
            update: (context, repo, previous) => NotificationService(repo),
          ),

          ChangeNotifierProxyProvider<UserRepository, AuthViewModel>(
            create:
                (context) => AuthViewModel(
                  context.read<UserRepository>(),
                  context.read<FirebaseAuthService>(),
                ),
            update:
                (context, repo, previous) =>
                    previous ??
                    AuthViewModel(repo, context.read<FirebaseAuthService>()),
          ),

          ChangeNotifierProxyProvider2<
            OrderRepository,
            CloudFunctionService,
            OrderViewModel
          >(
            create:
                (context) => OrderViewModel(
                  context.read<OrderRepository>(),
                  context.read<CloudFunctionService>(),
                ),
            update: (context, repo, cloud, previous) {
              final vm = previous ?? OrderViewModel(repo, cloud);
              vm.updateAuth(context.read<AuthViewModel>());
              return vm;
            },
          ),

          ChangeNotifierProxyProvider2<
            FirestoreService,
            CloudFunctionService,
            SubscriptionViewModel
          >(
            create:
                (context) => SubscriptionViewModel(
                  context.read<FirestoreService>(),
                  context.read<CloudFunctionService>(),
                ),
            update:
                (context, firestore, cloud, previous) =>
                    previous ?? SubscriptionViewModel(firestore, cloud),
          ),

          ChangeNotifierProxyProvider4<
            InvitationRepository,
            JoinRequestRepository,
            DynamicLinkService,
            CloudFunctionService,
            InviteViewModel
          >(
            create:
                (context) => InviteViewModel(
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

          ChangeNotifierProxyProvider2<
            MaterialRepository,
            GeminiService,
            ComparisonViewModel
          >(
            create:
                (context) => ComparisonViewModel(
                  context.read<MaterialRepository>(),
                  context.read<GeminiService>(),
                ),
            update:
                (context, mat, gem, previous) =>
                    previous ?? ComparisonViewModel(mat, gem),
          ),

          // --- Field User Panel ViewModels ---
          ChangeNotifierProxyProvider3<
            CompanyRepository,
            UserRepository,
            AuthViewModel,
            FieldSessionViewModel
          >(
            create:
                (context) => FieldSessionViewModel(
                  context.read<CompanyRepository>(),
                  context.read<UserRepository>(),
                ),
            update: (context, companyRepo, userRepo, auth, previous) {
              final vm =
                  previous ?? FieldSessionViewModel(companyRepo, userRepo);
              vm.updateAuth(auth);
              return vm;
            },
          ),

          ChangeNotifierProxyProvider<
            MaterialRepository,
            FieldCatalogViewModel
          >(
            create:
                (context) =>
                    FieldCatalogViewModel(context.read<MaterialRepository>()),
            update:
                (context, mat, previous) =>
                    previous ?? FieldCatalogViewModel(mat),
          ),

          ChangeNotifierProxyProvider2<
            MaterialRepository,
            GeminiService,
            FieldCompareViewModel
          >(
            create:
                (context) => FieldCompareViewModel(
                  context.read<MaterialRepository>(),
                  context.read<GeminiService>(),
                ),
            update:
                (context, mat, gem, previous) =>
                    previous ?? FieldCompareViewModel(mat, gem),
          ),

          ChangeNotifierProxyProvider3<
            MaterialRepository,
            GeminiService,
            CompanyRepository,
            FieldTrendsViewModel
          >(
            create:
                (context) => FieldTrendsViewModel(
                  context.read<MaterialRepository>(),
                  context.read<GeminiService>(),
                  context.read<CompanyRepository>(),
                ),
            update:
                (context, mat, gem, comp, previous) =>
                    previous ?? FieldTrendsViewModel(mat, gem, comp),
          ),

          ChangeNotifierProxyProvider4<
            OrderRepository,
            TransactionRepository,
            CompanyRepository,
            MaterialRepository,
            FieldOrdersViewModel
          >(
            create:
                (context) => FieldOrdersViewModel(
                  context.read<OrderRepository>(),
                  context.read<TransactionRepository>(),
                  context.read<CompanyRepository>(),
                  context.read<MaterialRepository>(),
                  context.read<NotificationService>(),
                ),
            update:
                (context, ord, tx, comp, mat, previous) =>
                    previous ??
                    FieldOrdersViewModel(
                      ord,
                      tx,
                      comp,
                      mat,
                      context.read<NotificationService>(),
                    ),
          ),

          ChangeNotifierProxyProvider2<
            ChatRepository,
            NotificationService,
            FieldChatViewModel
          >(
            create:
                (context) => FieldChatViewModel(
                  context.read<ChatRepository>(),
                  context.read<NotificationService>(),
                ),
            update:
                (context, chat, notifications, previous) =>
                    previous ?? FieldChatViewModel(chat, notifications),
          ),

          ChangeNotifierProxyProvider<ChatRepository, ChatViewModel>(
            create: (context) => ChatViewModel(context.read<ChatRepository>()),
            update:
                (context, chat, previous) => previous ?? ChatViewModel(chat),
          ),

          ChangeNotifierProxyProvider<
            NotificationRepository,
            FieldNotificationsViewModel
          >(
            create:
                (context) => FieldNotificationsViewModel(
                  context.read<NotificationRepository>(),
                ),
            update:
                (context, notif, previous) =>
                    previous ?? FieldNotificationsViewModel(notif),
          ),

          ChangeNotifierProxyProvider<OrderRepository, FieldRatingViewModel>(
            create:
                (context) =>
                    FieldRatingViewModel(context.read<OrderRepository>()),
            update:
                (context, ord, previous) =>
                    previous ?? FieldRatingViewModel(ord),
          ),

          ChangeNotifierProxyProvider2<
            MaterialRepository,
            OrderRepository,
            FieldSupplierProfileViewModel
          >(
            create:
                (context) => FieldSupplierProfileViewModel(
                  context.read<MaterialRepository>(),
                  context.read<OrderRepository>(),
                ),
            update:
                (context, mat, ord, previous) =>
                    previous ?? FieldSupplierProfileViewModel(mat, ord),
          ),

          ChangeNotifierProxyProvider2<
            FirestoreService,
            CloudFunctionService,
            RfqViewModel
          >(
            create:
                (context) => RfqViewModel(
                  context.read<FirestoreService>(),
                  context.read<CloudFunctionService>(),
                ),
            update:
                (context, fire, functions, previous) =>
                    previous ?? RfqViewModel(fire, functions),
          ),

          ChangeNotifierProxyProvider2<
            FirestoreService,
            CloudFunctionService,
            DisputeViewModel
          >(
            create:
                (context) => DisputeViewModel(
                  context.read<FirestoreService>(),
                  context.read<CloudFunctionService>(),
                ),
            update:
                (context, fire, functions, previous) =>
                    previous ?? DisputeViewModel(fire, functions),
          ),

          ChangeNotifierProxyProvider<AuthViewModel, CeoViewModel>(
            create:
                (context) => CeoViewModel(
                  null,
                  'CEO',
                  context.read<OrderRepository>(),
                  context.read<PartnershipRequestRepository>(),
                  context.read<UserRepository>(),
                  context.read<CompanyRepository>(),
                  context.read<InvitationRepository>(),
                  context.read<NotificationService>(),
                  context.read<CloudFunctionService>(),
                ),
            update: (context, auth, previous) {
              if (previous == null || previous.uid != auth.user?.uid) {
                return CeoViewModel(
                  auth.user?.uid,
                  auth.user?.name ?? 'CEO',
                  context.read<OrderRepository>(),
                  context.read<PartnershipRequestRepository>(),
                  context.read<UserRepository>(),
                  context.read<CompanyRepository>(),
                  context.read<InvitationRepository>(),
                  context.read<NotificationService>(),
                  context.read<CloudFunctionService>(),
                );
              }
              return previous;
            },
          ),

          ChangeNotifierProxyProvider<AuthViewModel, NotificationViewModel>(
            create:
                (context) => NotificationViewModel(
                  context.read<NotificationRepository>(),
                ),
            update: (context, auth, previous) {
              final vm =
                  previous ??
                  NotificationViewModel(context.read<NotificationRepository>());
              vm.updateAuth(auth);
              return vm;
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

          ChangeNotifierProxyProvider<MaterialRepository, MaterialViewModel>(
            create:
                (context) =>
                    MaterialViewModel(context.read<MaterialRepository>()),
            update: (_, repo, previous) => previous ?? MaterialViewModel(repo),
          ),

          ChangeNotifierProxyProvider<AuthViewModel, SupplierViewModel>(
            create:
                (context) => SupplierViewModel(
                  context.read<MaterialRepository>(),
                  context.read<OrderRepository>(),
                  context.read<TransactionRepository>(),
                  context.read<StorageService>(),
                  context.read<PriceHistoryRepository>(),
                  context.read<CloudFunctionService>(),
                  context.read<UserRepository>(),
                  context.read<CompanyRepository>(),
                  context.read<PartnershipRequestRepository>(),
                  context.read<NotificationService>(),
                ),
            update: (context, auth, previous) {
              previous?.updateAuth(auth);
              return previous ??
                  SupplierViewModel(
                    context.read<MaterialRepository>(),
                    context.read<OrderRepository>(),
                    context.read<TransactionRepository>(),
                    context.read<StorageService>(),
                    context.read<PriceHistoryRepository>(),
                    context.read<CloudFunctionService>(),
                    context.read<UserRepository>(),
                    context.read<CompanyRepository>(),
                    context.read<PartnershipRequestRepository>(),
                    context.read<NotificationService>(),
                  );
            },
          ),
        ],
        child: const RateBridgeApp(),
      ),
    );
  } catch (e) {
    debugPrint("Global Main Error: $e");
    // Fallback minimal app to show something if everything else fails
    runApp(
      MaterialApp(home: Scaffold(body: Center(child: Text("Fatal Error: $e")))),
    );
  }
}
