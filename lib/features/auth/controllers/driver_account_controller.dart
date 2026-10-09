import 'package:get/get.dart';
import '../repositories/auth_repository.dart';
import '../models/driver_account_models.dart';

class DriverAccountController extends GetxController {
  final AuthRepository authRepository;

  DriverAccountController({required this.authRepository});

  final RxBool isLoading = false.obs;
  final RxBool isError = false.obs;
  final RxString errorMessage = ''.obs;

  final Rxn<DriverAccountInfo> accountInfo = Rxn<DriverAccountInfo>();
  final Rxn<DriverVehicleInfo> vehicleInfo = Rxn<DriverVehicleInfo>();

  @override
  void onInit() {
    super.onInit();
    fetchDriverInfo();
  }

  Future<void> fetchDriverInfo() async {
    isLoading.value = true;
    isError.value = false;
    errorMessage.value = '';

    try {
      final accountResFuture = authRepository.getDriverAccountInfo();
      final vehicleResFuture = authRepository.getDriverVehicleInfo();

      final results = await Future.wait([accountResFuture, vehicleResFuture]);
      final accountRes = results[0];
      final vehicleRes = results[1];

      if (accountRes.isOk && accountRes.body != null) {
        accountInfo.value = DriverAccountInfo.fromJson(accountRes.body);
      } else {
        isError.value = true;
        if (accountRes.statusCode == 404) {
          errorMessage.value = 'Profile information not found';
        } else if (accountRes.statusCode == 401) {
          errorMessage.value = 'Session expired. Please log in again.';
        } else {
          errorMessage.value = 'Failed to load profile info (${accountRes.statusCode})';
        }
      }

      if (vehicleRes.isOk && vehicleRes.body != null) {
        vehicleInfo.value = DriverVehicleInfo.fromJson(vehicleRes.body);
      } else {
        if (vehicleRes.statusCode == 404) {
          vehicleInfo.value = DriverVehicleInfo(vehicleDetails: null, vehicleDocuments: []);
        }
      }
    } catch (e) {
      isError.value = true;
      errorMessage.value = 'Network error: ${e.toString()}';
    } finally {
      isLoading.value = false;
    }
  }
}
