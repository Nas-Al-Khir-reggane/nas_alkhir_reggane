import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/admin/controllers/admin_controller.dart';
import '../../features/admin/controllers/project_controller.dart';
import '../../features/worker/controllers/worker_controller.dart';
import '../../features/donor/controllers/donor_controller.dart';
import '../../features/beneficiary/controllers/beneficiary_controller.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/offline_queue_service.dart';
import '../../data/services/connectivity_service.dart';
import '../animations/sound_manager.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // تفعيل Persistence لضمان عمل الإشعارات حتى مع ضعف الإنترنت
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // خدمات النظام (يتم تشغيلها فوراً وبشكل دائم)
    Get.put(SoundManager(), permanent: true);
    Get.put(NotificationService(), permanent: true);
    Get.put(ConnectivityService(), permanent: true);
    Get.put(OfflineQueueService(), permanent: true);

    // Controllers
    Get.lazyPut(() => AuthController(), fenix: true);
    Get.lazyPut(() => AdminController(), fenix: true);
    Get.lazyPut(() => ProjectController(), fenix: true);
    Get.lazyPut(() => WorkerController(), fenix: true);
    Get.lazyPut(() => DonorController(), fenix: true);
    Get.lazyPut(() => BeneficiaryController(), fenix: true);
  }
}
