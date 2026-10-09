import 'package:get/get.dart';
import '../data/api/api_client.dart';
import '../services/socket/socket_service.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/repositories/auth_repository.dart';
import '../features/documents/repositories/document_repository.dart';
import '../features/documents/controllers/document_controller.dart';
import '../features/dashboard/controllers/active_booking_controller.dart';

Future<void> initDependencies() async {
  // 1. Core Services
  Get.put<ApiClient>(ApiClient(), permanent: true);
  Get.put<SocketService>(SocketService(), permanent: true);
  Get.put<ActiveBookingController>(ActiveBookingController(), permanent: true);

  // 2. Repositories (depends on ApiClient)
  Get.put<AuthRepository>(AuthRepository(apiClient: Get.find<ApiClient>()));
  Get.put<DocumentRepository>(
    DocumentRepository(apiClient: Get.find<ApiClient>()),
  );

  // 3. Controllers (depends on Repository)
  Get.put<AuthController>(
    AuthController(authRepository: Get.find<AuthRepository>()),
    permanent: true,
  );
  Get.lazyPut<DocumentController>(
    () =>
        DocumentController(documentRepository: Get.find<DocumentRepository>()),
    fenix: true,
  );
}

