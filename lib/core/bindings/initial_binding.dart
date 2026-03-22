import 'package:get/get.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/admin/controllers/admin_controller.dart';
import '../../features/worker/controllers/worker_controller.dart';
import '../../features/donor/controllers/donor_controller.dart';
import '../../features/beneficiary/controllers/beneficiary_controller.dart';
import '../../data/services/notification_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AuthController(), fenix: true);
    Get.lazyPut(() => AdminController(), fenix: true);
    Get.lazyPut(() => WorkerController(), fenix: true);
    Get.lazyPut(() => DonorController(), fenix: true);
    Get.lazyPut(() => BeneficiaryController(), fenix: true);
    Get.lazyPut(() => NotificationService(), fenix: true);
  }
}
