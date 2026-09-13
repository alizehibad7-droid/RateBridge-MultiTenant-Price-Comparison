import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ratebridge/repositories/chat_repository.dart';
import 'package:ratebridge/repositories/company_repository.dart';
import 'package:ratebridge/repositories/invitation_repository.dart';
import 'package:ratebridge/repositories/join_request_repository.dart';
import 'package:ratebridge/repositories/material_repository.dart';
import 'package:ratebridge/repositories/notification_repository.dart';
import 'package:ratebridge/repositories/order_repository.dart';
import 'package:ratebridge/repositories/partnership_request_repository.dart';
import 'package:ratebridge/repositories/price_history_repository.dart';
import 'package:ratebridge/repositories/supplier_repository.dart';
import 'package:ratebridge/repositories/transaction_repository.dart';
import 'package:ratebridge/repositories/user_repository.dart';
import 'package:ratebridge/services/cloud_function_service.dart';
import 'package:ratebridge/services/cloudinary_service.dart';
import 'package:ratebridge/services/dynamic_link_service.dart';
import 'package:ratebridge/services/firebase_auth_service.dart';
import 'package:ratebridge/services/firestore_service.dart';
import 'package:ratebridge/services/notification_service.dart';
import 'package:ratebridge/services/storage_service.dart';
import 'package:ratebridge/viewmodels/admin_viewmodel.dart';
import 'package:ratebridge/viewmodels/auth_viewmodel.dart';
import 'package:ratebridge/viewmodels/dispute_viewmodel.dart';
import 'package:ratebridge/viewmodels/ceo_viewmodel.dart';
import 'package:ratebridge/viewmodels/invite_viewmodel.dart';
import 'package:ratebridge/viewmodels/notification_viewmodel.dart';
import 'package:ratebridge/viewmodels/chat_viewmodel.dart';
import 'package:ratebridge/viewmodels/material_viewmodel.dart';
import 'package:ratebridge/viewmodels/rfq_viewmodel.dart';
import 'package:ratebridge/viewmodels/subscription_viewmodel.dart';
import 'package:ratebridge/viewmodels/supplier_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_catalog_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_chat_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_compare_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_orders_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_rating_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_session_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_supplier_profile_viewmodel.dart';
import 'package:ratebridge/viewmodels/field_user/field_trends_viewmodel.dart';

// --- Firebase SDK ---

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// Query, CollectionReference, DocumentReference, and DocumentSnapshot are
// sealed in cloud_firestore — mock FirebaseFirestore / FirestoreService
// instead of those types.

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult extends Mock implements HttpsCallableResult {}

// --- App services used by ViewModels ---

class MockFirestoreService extends Mock implements FirestoreService {}

class MockFirebaseAuthService extends Mock implements FirebaseAuthService {}

class MockCloudFunctionService extends Mock implements CloudFunctionService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockStorageService extends Mock implements StorageService {}

class MockCloudinaryService extends Mock implements CloudinaryService {}

class MockDynamicLinkService extends Mock implements DynamicLinkService {}

// --- Repositories ---

class MockUserRepository extends Mock implements UserRepository {}

class MockCompanyRepository extends Mock implements CompanyRepository {}

class MockMaterialRepository extends Mock implements MaterialRepository {}

class MockOrderRepository extends Mock implements OrderRepository {}

class MockChatRepository extends Mock implements ChatRepository {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockSupplierRepository extends Mock implements SupplierRepository {}

class MockInvitationRepository extends Mock implements InvitationRepository {}

class MockJoinRequestRepository extends Mock implements JoinRequestRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockPriceHistoryRepository extends Mock
    implements PriceHistoryRepository {}

class MockPartnershipRequestRepository extends Mock
    implements PartnershipRequestRepository {}

// --- ViewModels used by widget tests ---

class MockAuthViewModel extends Mock implements AuthViewModel {}

class MockInviteViewModel extends Mock implements InviteViewModel {}

class MockAdminViewModel extends Mock implements AdminViewModel {}

class MockDisputeViewModel extends Mock implements DisputeViewModel {}

class MockNotificationViewModel extends Mock implements NotificationViewModel {}

class MockSubscriptionViewModel extends Mock implements SubscriptionViewModel {}

class MockCeoViewModel extends Mock implements CeoViewModel {}

class MockRfqViewModel extends Mock implements RfqViewModel {}

class MockSupplierViewModel extends Mock implements SupplierViewModel {}

class MockChatViewModel extends Mock implements ChatViewModel {}

class MockMaterialViewModel extends Mock implements MaterialViewModel {}

class MockFieldSessionViewModel extends Mock implements FieldSessionViewModel {}

class MockFieldCatalogViewModel extends Mock implements FieldCatalogViewModel {}

class MockFieldOrdersViewModel extends Mock implements FieldOrdersViewModel {}

class MockFieldRatingViewModel extends Mock implements FieldRatingViewModel {}

class MockFieldChatViewModel extends Mock implements FieldChatViewModel {}

class MockFieldCompareViewModel extends Mock implements FieldCompareViewModel {}

class MockFieldSupplierProfileViewModel extends Mock
    implements FieldSupplierProfileViewModel {}

class MockFieldTrendsViewModel extends Mock implements FieldTrendsViewModel {}
