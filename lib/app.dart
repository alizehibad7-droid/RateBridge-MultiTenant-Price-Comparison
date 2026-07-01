import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Constants & Models
import 'constants/route_names.dart';
import 'constants/app_colors.dart';
import 'models/material_model.dart';
import 'models/chat_thread_model.dart';

// ViewModels
import 'viewmodels/auth_viewmodel.dart';

// Localization
import 'l10n/app_localizations.dart';

// Auth Views
import 'views/auth/splash_view.dart';
import 'views/auth/role_selection_view.dart';
import 'views/auth/login_view.dart';
import 'views/auth/register_ceo_view.dart';
import 'views/auth/register_supplier_view.dart';
import 'views/auth/register_field_user_view.dart';
import 'views/auth/forgot_password_view.dart';
import 'views/auth/invite_landing_view.dart';
import 'views/auth/status_screens.dart';

// CEO Views
import 'views/ceo/ceo_dashboard_view.dart';
import 'views/ceo/ceo_pending_view.dart';
import 'views/ceo/ceo_invite_hub_view.dart';
import 'views/ceo/ceo_supplier_marketplace_view.dart';
import 'views/ceo/ceo_join_requests_view.dart';
import 'views/ceo/ceo_my_suppliers_view.dart';
import 'views/ceo/ceo_field_users_view.dart';
import 'views/ceo/ceo_orders_view.dart';
import 'views/ceo/ceo_subscription_view.dart';
import 'views/ceo/ceo_company_profile_view.dart';

// Field User Views
import 'views/field_user/shell/field_shell_view.dart';
import 'views/field_user/marketplace/field_marketplace_view.dart';
import 'views/field_user/marketplace/field_search_view.dart';
import 'views/field_user/field_categories_view.dart';
import 'views/field_user/field_recently_viewed_view.dart';
import 'views/field_user/compare/field_compare_view.dart';
import 'views/field_user/orders/field_place_order_view.dart';
import 'views/field_user/orders/field_orders_view.dart';
import 'views/field_user/orders/field_order_detail_view.dart';
import 'views/field_user/orders/field_weight_report_view.dart';
import 'views/field_user/orders/field_rate_supplier_view.dart';
import 'views/field_user/chat/field_chat_list_view.dart';
import 'views/field_user/chat/field_chat_thread_view.dart';
import 'views/field_user/chat/field_chat_thread_args.dart';
import 'views/field_user/notifications/field_notifications_view.dart';
import 'views/field_user/profile/field_profile_view.dart';
import 'views/field_user/suppliers/field_supplier_profile_view.dart';
import 'views/field_user/trends/field_price_trends_view.dart';
import 'views/field_user/field_page_transition.dart';
import 'models/material_listing.dart';
import 'models/order_model.dart';

// Supplier Views
import 'views/supplier/supplier_dashboard_view.dart';
import 'views/supplier/supplier_pending_view.dart';
import 'views/supplier/supplier_appeal_view.dart';
import 'views/supplier/supplier_materials_view.dart';
import 'views/supplier/supplier_add_material_view.dart';
import 'views/supplier/supplier_edit_material_view.dart';
import 'views/supplier/supplier_orders_view.dart';
import 'views/supplier/supplier_chat_view.dart';
import 'views/supplier/supplier_chat_thread_view.dart';
import 'views/supplier/supplier_ratings_view.dart';
import 'views/supplier/supplier_earnings_view.dart';
import 'views/supplier/supplier_profile_view.dart';
import 'views/supplier/partnerships/supplier_partnerships_hub_view.dart';
import 'views/supplier/supplier_company_directory_view.dart';
import 'views/supplier/supplier_notifications_view.dart';
import 'theme/supplier_theme.dart';
import 'theme/field_theme.dart';

// Admin Views
import 'views/admin/admin_dashboard_view.dart';
import 'views/admin/admin_notifications_view.dart';
import 'views/admin/admin_ceo_management_view.dart';
import 'views/admin/admin_categories_view.dart';
import 'views/admin/admin_payment_queue_view.dart';
import 'views/admin/admin_subscription_view.dart';

class RateBridgeApp extends StatefulWidget {
  const RateBridgeApp({super.key});

  @override
  State<RateBridgeApp> createState() => _RateBridgeAppState();
}

class _RateBridgeAppState extends State<RateBridgeApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    
    _router = GoRouter(
      initialLocation: RouteNames.splash,
      refreshListenable: Provider.of<AuthViewModel>(context, listen: false),
      routes: [
        GoRoute(path: RouteNames.splash, builder: (context, state) => const SplashView()),
        GoRoute(path: RouteNames.roleSelection, builder: (context, state) => const RoleSelectionView()),
        GoRoute(path: RouteNames.login, builder: (context, state) => const LoginView()),
        GoRoute(path: RouteNames.registerCEO, builder: (context, state) => const RegisterCeoView()),
        GoRoute(path: RouteNames.registerSupplier, builder: (context, state) => const RegisterSupplierView()),
        GoRoute(path: RouteNames.registerFieldUser, builder: (context, state) => const RegisterFieldUserView()),
        GoRoute(path: RouteNames.forgotPassword, builder: (context, state) => const ForgotPasswordView()),
        GoRoute(path: RouteNames.inviteLanding, builder: (context, state) => InviteLandingView(companyId: state.uri.queryParameters['companyId'] ?? '', code: state.pathParameters['token'] ?? '')),

        GoRoute(path: RouteNames.pendingApproval, builder: (context, state) => const PendingApprovalView()),
        GoRoute(path: RouteNames.suspended, builder: (context, state) => const SuspendedView()),
        GoRoute(path: RouteNames.rejected, builder: (context, state) => const RejectedView()),

        GoRoute(path: RouteNames.ceoDashboard, builder: (context, state) => const CeoDashboardView()),
        GoRoute(path: RouteNames.ceoPending, builder: (context, state) => const CeoPendingView()),
        GoRoute(path: RouteNames.ceoInvite, builder: (context, state) => const CeoInviteHubView()),
        GoRoute(path: RouteNames.ceoMarketplace, builder: (context, state) => const CeoSupplierMarketplaceView()),
        GoRoute(path: RouteNames.ceoJoinRequests, builder: (context, state) => const CeoJoinRequestsView()),
        GoRoute(path: RouteNames.ceoMySuppliers, builder: (context, state) => const CeoMySuppliersView()),
        GoRoute(path: RouteNames.ceoFieldUsers, builder: (context, state) => const CeoFieldUsersView()),
        GoRoute(path: RouteNames.ceoOrders, builder: (context, state) => const CeoOrdersView()),
        GoRoute(path: RouteNames.ceoSubscription, builder: (context, state) => const CeoSubscriptionView()),
        GoRoute(path: RouteNames.ceoProfile, builder: (context, state) => const CeoCompanyProfileView()),

        GoRoute(
          path: RouteNames.fieldHome,
          builder: (context, state) {
            final tab =
                int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
            return FieldTheme.wrap(
              FieldShellView(initialTabIndex: tab.clamp(0, 4)),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldMarketplace,
          pageBuilder: (context, state) => fieldTransitionPage(
            key: state.pageKey,
            child: FieldMarketplaceView(
              initialCategory: state.uri.queryParameters['category'],
            ),
          ),
        ),
        GoRoute(
          path: RouteNames.fieldCategory,
          pageBuilder: (context, state) {
            final categoryName = Uri.decodeComponent(
              state.pathParameters['categoryName'] ?? '',
            );
            return fieldTransitionPage(
              key: state.pageKey,
              child: FieldMarketplaceView(initialCategory: categoryName),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldSearch,
          pageBuilder: (context, state) => fieldTransitionPage(
            key: state.pageKey,
            child: const FieldSearchView(),
          ),
        ),
        GoRoute(
          path: RouteNames.fieldCategories,
          pageBuilder: (context, state) => fieldTransitionPage(
            key: state.pageKey,
            child: const FieldCategoriesView(),
          ),
        ),
        GoRoute(
          path: RouteNames.fieldRecentlyViewed,
          pageBuilder: (context, state) => fieldTransitionPage(
            key: state.pageKey,
            child: const FieldRecentlyViewedView(),
          ),
        ),
        GoRoute(
          path: RouteNames.fieldCompare,
          pageBuilder: (context, state) {
            final raw = state.pathParameters['materialId'] ?? '';
            final materialName = Uri.decodeComponent(raw);
            return fieldTransitionPage(
              key: state.pageKey,
              child: FieldCompareView(materialName: materialName),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldTrend,
          pageBuilder: (context, state) {
            final materialId = Uri.decodeComponent(
              state.pathParameters['matId'] ?? '',
            );
            final supplierUid = Uri.decodeComponent(
              state.pathParameters['supplierUid'] ?? '',
            );
            return fieldTransitionPage(
              key: state.pageKey,
              child: FieldPriceTrendsView(
                materialId: materialId,
                supplierUid: supplierUid,
              ),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldPriceTrends,
          pageBuilder: (context, state) {
            final materialName = Uri.decodeComponent(
              state.pathParameters['materialName'] ?? '',
            );
            return fieldTransitionPage(
              key: state.pageKey,
              child: FieldPriceTrendsView(
                materialId: materialName,
                supplierUid: '_',
              ),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldPlaceOrder,
          pageBuilder: (context, state) => fieldTransitionPage(
            key: state.pageKey,
            child: FieldPlaceOrderView(
              material: state.extra as MaterialListing,
            ),
          ),
        ),
        GoRoute(
          path: RouteNames.fieldOrders,
          pageBuilder: (context, state) => fieldTransitionPage(
            key: state.pageKey,
            child: const FieldOrdersView(),
          ),
        ),
        GoRoute(
          path: RouteNames.fieldOrderDetail,
          pageBuilder: (context, state) {
            final orderId = state.pathParameters['orderId'];
            final order = state.extra is OrderModel ? state.extra as OrderModel : null;
            return fieldTransitionPage(
              key: state.pageKey,
              child: FieldOrderDetailView(order: order, orderId: orderId),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldWeightReport,
          pageBuilder: (context, state) {
            final orderId = state.pathParameters['orderId'];
            final order = state.extra is OrderModel ? state.extra as OrderModel : null;
            return fieldTransitionPage(
              key: state.pageKey,
              child: FieldWeightReportView(order: order, orderId: orderId),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldRateSupplier,
          pageBuilder: (context, state) => fieldTransitionPage(
            key: state.pageKey,
            child: FieldRateSupplierView(order: state.extra as OrderModel),
          ),
        ),
        GoRoute(
          path: RouteNames.fieldChat,
          pageBuilder: (context, state) => fieldTransitionPage(
            key: state.pageKey,
            child: const FieldChatListView(),
          ),
        ),
        GoRoute(
          path: RouteNames.fieldChatThread,
          pageBuilder: (context, state) {
            final args = state.extra as FieldChatThreadArgs?;
            final pathSupplierUid = state.pathParameters['orderId'];
            return fieldTransitionPage(
              key: state.pageKey,
              child: FieldChatThreadView(
                supplierUid: args?.supplierUid ?? pathSupplierUid ?? '',
                supplierName: args?.supplierName ?? '',
                orderId: args?.orderId,
              ),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldNotifications,
          pageBuilder: (context, state) => fieldTransitionPage(
            key: state.pageKey,
            child: const FieldNotificationsView(),
          ),
        ),
        GoRoute(
          path: RouteNames.fieldProfile,
          pageBuilder: (context, state) => fieldTransitionPage(
            key: state.pageKey,
            child: const FieldProfileView(),
          ),
        ),
        GoRoute(
          path: RouteNames.fieldSupplierProfile,
          pageBuilder: (context, state) => fieldTransitionPage(
            key: state.pageKey,
            child: FieldSupplierProfileView(
              supplierUid: state.pathParameters['supplierUid'] ?? '',
            ),
          ),
        ),

        GoRoute(path: RouteNames.supplierDashboard, builder: (context, state) => SupplierTheme.wrap(const SupplierDashboardView())),
        GoRoute(path: RouteNames.supplierPending, builder: (context, state) => SupplierTheme.wrap(const SupplierPendingView())),
        GoRoute(path: RouteNames.supplierAppeal, builder: (context, state) => SupplierTheme.wrap(const SupplierAppealView())),
        GoRoute(path: RouteNames.supplierMaterials, builder: (context, state) => SupplierTheme.wrap(const SupplierMaterialsView())),
        GoRoute(path: RouteNames.supplierAddMaterial, builder: (context, state) => SupplierTheme.wrap(const SupplierAddMaterialView())),
        GoRoute(path: RouteNames.supplierEditMaterial, builder: (context, state) => SupplierTheme.wrap(SupplierEditMaterialView(material: state.extra as MaterialModel))),
        GoRoute(
          path: RouteNames.supplierOrders,
          builder: (context, state) {
            final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
            return SupplierTheme.wrap(SupplierOrdersView(initialTabIndex: tab));
          },
        ),
        GoRoute(path: RouteNames.supplierChat, builder: (context, state) => SupplierTheme.wrap(const SupplierChatView())),
        GoRoute(
          path: RouteNames.supplierChatThread,
          builder: (context, state) {
            final thread = state.extra as ChatThreadModel?;
            if (thread == null) {
              return SupplierTheme.wrap(
                const Scaffold(body: Center(child: Text('Chat not found'))),
              );
            }
            return SupplierTheme.wrap(SupplierChatThreadView(thread: thread));
          },
        ),
        GoRoute(path: RouteNames.supplierRatings, builder: (context, state) => SupplierTheme.wrap(const SupplierRatingsView())),
        GoRoute(path: RouteNames.supplierEarnings, builder: (context, state) => SupplierTheme.wrap(const SupplierEarningsView())),
        GoRoute(path: RouteNames.supplierProfile, builder: (context, state) => SupplierTheme.wrap(const SupplierProfileView())),
        GoRoute(
          path: RouteNames.supplierPartnershipRequests,
          redirect: (context, state) =>
              '${RouteNames.supplierMyCompanies}?tab=1',
        ),
        GoRoute(
          path: RouteNames.supplierCompanyDirectory,
          builder: (context, state) =>
              SupplierTheme.wrap(const SupplierCompanyDirectoryView()),
        ),
        GoRoute(
          path: RouteNames.supplierMyCompanies,
          builder: (context, state) {
            final tab =
                int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
            return SupplierTheme.wrap(
              SupplierPartnershipsHubView(initialTab: tab),
            );
          },
        ),
        GoRoute(path: RouteNames.supplierNotifications, builder: (context, state) => SupplierTheme.wrap(const SupplierNotificationsView())),

        GoRoute(path: RouteNames.adminDashboard, builder: (context, state) => const AdminDashboardView()),
        GoRoute(path: RouteNames.adminNotifications, builder: (context, state) => const AdminNotificationsView()),
        GoRoute(path: RouteNames.adminCompanies, builder: (context, state) => const AdminCeoManagementView()),
        GoRoute(path: RouteNames.adminCategories, builder: (context, state) => const AdminCategoriesView()),
        GoRoute(path: RouteNames.adminPayments, builder: (context, state) => const AdminPaymentQueueView()),
        GoRoute(path: RouteNames.adminSubscription, builder: (context, state) => const AdminSubscriptionView()),
      ],
      redirect: (context, state) {
        final authVM = Provider.of<AuthViewModel>(context, listen: false);
        final path = state.matchedLocation;
        final isPublic = path == RouteNames.login || 
                         path == RouteNames.registerCEO || 
                         path == RouteNames.registerSupplier || 
                         path == RouteNames.registerFieldUser || 
                         path == RouteNames.forgotPassword || 
                         path.startsWith('/invite') || 
                         path == RouteNames.splash ||
                         path == RouteNames.roleSelection;
        
        if (authVM.status == AuthStatus.loading) return null;
        if (authVM.user == null) return isPublic ? null : RouteNames.login;

        final role = authVM.user!.role.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
        final status = (authVM.user!.status ?? 'pending').toLowerCase();
        
        if (status == 'pending') {
          if (path != RouteNames.pendingApproval && path != RouteNames.ceoPending && path != RouteNames.supplierPending) {
             if (role == 'ceo') return RouteNames.ceoPending;
             if (role == 'supplier') return RouteNames.supplierPending;
             return RouteNames.pendingApproval;
          }
          return null;
        }
        
        if (status == 'suspended') {
          return path == RouteNames.suspended ? null : RouteNames.suspended;
        }
        
        if (status == 'rejected') {
          if (path != RouteNames.rejected && path != RouteNames.ceoPending && path != RouteNames.supplierPending && path != RouteNames.supplierAppeal) {
             if (role == 'ceo') return RouteNames.ceoPending; 
             if (role == 'supplier') return RouteNames.supplierPending; 
             return RouteNames.rejected;
          }
          return null;
        }

        if (isPublic) {
          if (role == 'admin') return RouteNames.adminDashboard;
          if (role == 'ceo') return RouteNames.ceoDashboard;
          if (role == 'supplier') return RouteNames.supplierDashboard;
          if (role == 'fielduser') return RouteNames.fieldHome;
        }

        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RATEBRIDGE',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      locale: const Locale('en'),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.secondary,
          onSecondary: Colors.white,
          surface: AppColors.background,
          onSurface: AppColors.textPrimary,
          error: AppColors.error,
          surfaceContainerHighest: AppColors.surface,
          surfaceContainer: Colors.white,
          outline: AppColors.border,
        ),
        
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1.2, color: AppColors.textPrimary),
          displayMedium: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.2, color: AppColors.textPrimary),
          headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.3, color: AppColors.textPrimary),
          titleLarge: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: AppColors.textPrimary),
          bodyLarge: GoogleFonts.plusJakartaSans(fontSize: 16, color: AppColors.textPrimary, height: 1.5, letterSpacing: 0.1),
          bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          labelLarge: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AppColors.textSecondary),
        ),

        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        ),

        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: AppColors.textPrimary, size: 24),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3),
          ),
        ),
        
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: const BorderSide(color: AppColors.border, width: 1.5),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),

        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 1,
          space: 1,
        ),

        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
          weight: 300, 
        ),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
      ],
      routerConfig: _router,
    );
  }
}
