import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import '../../widgets/custom_snackbar.dart';

class NetworkController extends GetxController {
  final Connectivity _connectivity = Connectivity();

  @override
  void onInit() {
    super.onInit();
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> connectivityResult) {
    if (connectivityResult.contains(ConnectivityResult.none)) {
      CustomSnackbar.show(
        'Please connect to the internet',
        type: SnackbarType.error,
        duration: const Duration(days: 1),
        isDismissible: false,
      );
    } else {
      if (Get.isSnackbarOpen) {
        Get.closeCurrentSnackbar();
      }
    }
  }
}

class NetworkBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(NetworkController(), permanent: true);
  }
}
