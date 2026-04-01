import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/admin/controllers/admin_controller.dart';
import '../../features/admin/controllers/project_controller.dart';
import '../../features/worker/controllers/worker_controller.dart';
import '../../features/donor/controllers/donor_controller.dart';
import '../../features/beneficiary/controllers/beneficiary_controller.dart';
import '../../features/chat/controllers/chat_controller.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/offline_queue_service.dart';
import '../../data/services/connectivity_service.dart';
import '../services/version_service.dart';
import '../animations/sound_manager.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // تفعيل Persistence لضمان عمل الإشعارات حتى مع ضعف الإنترنت
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Firestore settings already set or error: $e');
    }

    // Controllers (يجب تهيئة AuthController أولاً لأنه أساس الخدمات الأخرى)
    Get.put(AuthController(), permanent: true);

    // خدمات النظام (يتم تشغيلها فوراً وبشكل دائم)
    Get.put(SoundManager(), permanent: true);
    Get.put(NotificationService(), permanent: true);
    Get.put(ConnectivityService(), permanent: true);
    Get.put(OfflineQueueService(), permanent: true);
    Get.put(VersionService(), permanent: true);

    // بقية الـ Controllers
    Get.lazyPut(() => AdminController(), fenix: true);
    Get.lazyPut(() => ProjectController(), fenix: true);
    Get.lazyPut(() => WorkerController(), fenix: true);
    Get.lazyPut(() => DonorController(), fenix: true);
    Get.lazyPut(() => BeneficiaryController(), fenix: true);
    Get.lazyPut(() => ChatController(), fenix: true);
  }
}

