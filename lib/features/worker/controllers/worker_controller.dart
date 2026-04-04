import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/chat_message_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/os_tracking_service.dart';
import '../../../data/services/cloudinary_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class WorkerController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RxList<ServiceRequestModel> myTasks = <ServiceRequestModel>[].obs;
  RxList<ServiceRequestModel> completedTasks = <ServiceRequestModel>[].obs;
  RxList<String> myProjectIds = <String>[].obs; // Projects assigned to this worker
  Rx<UserModel?> currentWorker = Rx<UserModel?>(null);
  RxBool isLoading = false.obs;
  RxBool isAvailable = true.obs;
  Rx<ChatMessageModel?> lastAdminMessage = Rx<ChatMessageModel?>(null);
  RxBool isTracking = false.obs;
  final OSTrackingService _trackingService = Get.put(OSTrackingService());

  StreamSubscription? _myTasksSub;
  StreamSubscription? _completedTasksSub;
  StreamSubscription? _adminMessageSub;
  StreamSubscription? _projectsSub;

  @override
  void onInit() {
    super.onInit();
    currentWorker.value = Get.find<AuthController>().currentUser.value;
    isAvailable.value = currentWorker.value?.isAvailable ?? true;
    loadMyTasks();
    loadMyProjects();
    loadLastAdminMessage();
  }

  void loadMyTasks() {
    if (currentWorker.value == null) return;

    _myTasksSub = _firestore
        .collection(AppConstants.serviceRequestsCollection)
        .where('assignedTo', isEqualTo: currentWorker.value?.id)
        .where('status', whereIn: ['in_progress', 'pending', 'assigned', 'issue', 'on_hold'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      myTasks.value = snap.docs.map((d) {
        var data = d.data();
        data['id'] = d.id;
        return ServiceRequestModel.fromMap(data);
      }).where((t) => t.type != 'blood_donation' && t.type != 'blood_emergency').toList();
    });

    _completedTasksSub = _firestore
        .collection(AppConstants.serviceRequestsCollection)
        .where('assignedTo', isEqualTo: currentWorker.value?.id)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .listen((snap) {
      completedTasks.value = snap.docs.map((d) {
        var data = d.data();
        data['id'] = d.id;
        return ServiceRequestModel.fromMap(data);
      }).where((t) => t.type != 'blood_donation' && t.type != 'blood_emergency').toList();
    });
  }

  void loadMyProjects() {
    if (currentWorker.value == null) return;
    
    _projectsSub = _firestore
        .collection(AppConstants.projectsCollection)
        .where('assignedWorkers', arrayContains: currentWorker.value?.id)
        .snapshots()
        .listen((snap) {
      myProjectIds.value = snap.docs.map((d) => d.id).toList();
    });
  }

  void loadLastAdminMessage() {
    if (currentWorker.value == null) return;

    _adminMessageSub = _firestore
        .collection(AppConstants.chatCollection)
        .doc('group_team')
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isNotEmpty) {
        var data = snap.docs.first.data();
        data['id'] = snap.docs.first.id;
        lastAdminMessage.value = ChatMessageModel.fromMap(data);
      }
    });
  }

  Future<void> toggleAvailability() async {
    final newStatus = !isAvailable.value;
    isAvailable.value = newStatus;
    await _firestore.collection(AppConstants.usersCollection).doc(currentWorker.value?.id).update({'isAvailable': newStatus});
    
    Get.snackbar(
      newStatus ? '✅ أنت الآن متاح' : '⏸️ أنت الآن مشغول',
      newStatus ? 'ستصلك المهام الجديدة' : 'لن تُسند إليك مهام جديدة',
      backgroundColor: (newStatus ? Get.theme.colorScheme.primary : Get.theme.colorScheme.error).withValues(alpha: 0.15),
      colorText: newStatus ? Get.theme.colorScheme.primary : Get.theme.colorScheme.error,
    );
  }

  Future<void> submitQuickUpdate({
    required String requestId,
    required String type,
    required String description,
    File? imageFile,
    String? projectId,
    bool changeStatusToIssue = false,
  }) async {
    isLoading.value = true;
    try {
      String? mediaUrl;
      if (imageFile != null) {
        mediaUrl = await CloudinaryService.uploadMedia(imageFile);
      }

      final updateData = {
        'workerId': currentWorker.value?.id,
        'workerName': currentWorker.value?.name,
        'type': type,
        'description': description,
        'mediaUrl': mediaUrl,
        'imageUrl': mediaUrl,
        'requestId': requestId,
        'projectId': projectId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 1. Save update
      await _firestore.collection(AppConstants.serviceRequestsCollection).doc(requestId).collection('updates').add(updateData);
      await _firestore.collection('worker_updates').add(updateData);

      // 2. Change status if issue reported
      if (changeStatusToIssue) {
        await _firestore.collection(AppConstants.serviceRequestsCollection).doc(requestId).update({
          'status': 'issue',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // تحديث آخر نشاط للعامل
      await _firestore.collection(AppConstants.usersCollection).doc(currentWorker.value?.id).update({
        'lastActivity': FieldValue.serverTimestamp(),
      });

      // إشعار للأدمين
      await _notifyAdmin(requestId, type, description, isUrgent: changeStatusToIssue);

      // العودة أولاً لضمان ظهور الرسالة على الشاشة الرئيسية
      Get.back();

      Get.snackbar(
        changeStatusToIssue ? '⚠️ تم الإبلاغ عن مشكلة' : '✅ تم إرسال التحديث',
        changeStatusToIssue ? 'تم إخطار الإدارة بوجود عائق في الميدان' : 'تم إرسال التقرير الميداني بنجاح',
        backgroundColor: changeStatusToIssue ? AppTheme.errorColor : AppTheme.primaryGreen,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(15),
        borderRadius: 15,
        icon: Icon(
          changeStatusToIssue ? Icons.warning_amber_rounded : Icons.check_circle_outline,
          color: Colors.white,
        ),
        duration: const Duration(seconds: 4),
      );
      
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إرسال التحديث: ${e.toString()}', 
        backgroundColor: AppTheme.errorColor, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> startTask(ServiceRequestModel task) async {
    try {
      isLoading.value = true;
      
      // 1. تحديث حالة الطلب إلى "قيد التنفيذ"
      await _firestore
          .collection(AppConstants.serviceRequestsCollection)
          .doc(task.id)
          .update({
            'status': 'in_progress',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // 2. إذا كان هناك مركبة مسندة للطلب، ابدأ التتبع
      String? vehicleId = task.assignedCarId;
      
      if (vehicleId != null && vehicleId.isNotEmpty) {
        await _trackingService.startTracking(vehicleId);
        isTracking.value = true;
      }

      Get.snackbar("على بركة الله", "تم بدء المهمة وتفعيل التتبع الحي للمركبة", 
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
          colorText: AppTheme.primaryGreen);
    } catch (e) {
      Get.snackbar("خطأ", "فشل بدء المهمة: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> completeTask(String requestId) async {
    try {
      isLoading.value = true;
      
      final doc = await _firestore
          .collection(AppConstants.serviceRequestsCollection)
          .doc(requestId).get();

      if (!doc.exists) {
        Get.snackbar('خطأ', 'الطلب غير موجود');
        return;
      }
      final data = doc.data()!;
      if (data['assignedTo'] != currentWorker.value?.id) {
        Get.snackbar('غير مصرح', 'هذه المهمة ليست مسندة إليك');
        return;
      }

      // إيقاف التتبع عند إتمام المهمة
      _trackingService.stopTracking();
      isTracking.value = false;

      final batch = _firestore.batch();
      
      // تحديث حالة الطلب
      final requestRef = _firestore.collection(AppConstants.serviceRequestsCollection).doc(requestId);
      batch.update(requestRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // تحرير المركبة إن وجدت
      String? vehicleId = data['assignedCarId'];
      if (vehicleId != null && vehicleId.isNotEmpty) {
        batch.update(_firestore.collection('vehicles').doc(vehicleId), {
           'isAvailable': true,
           'status': 'ready',
        });
      }

      // تحديث إحصائات الفريق والإشعارات
      await _notifyCompletion(data, requestId);
      
      // تحديث إحصائيات الأخ المتطوع
      final workerRef = _firestore.collection(AppConstants.usersCollection).doc(currentWorker.value?.id);
      
      await batch.commit();

      // تجديد الإحصائيات في التطبيق
      await _firestore.runTransaction((tx) async {
        final workerSnap = await tx.get(workerRef);
        if (!workerSnap.exists) return;
        final workerData = workerSnap.data() as Map<String, dynamic>;
        final currentTasks = ((workerData['currentTasksCount'] ?? 0) as num).toInt();
        final safeCurrentTasks = currentTasks > 0 ? currentTasks - 1 : 0;
        tx.update(workerRef, {
          'completedTasks': FieldValue.increment(1),
          'currentTasksCount': safeCurrentTasks,
          'isAvailable': true,
          'lastActivity': FieldValue.serverTimestamp(),
        });
      });
      
      isAvailable.value = true;

      Get.back(); // إغلاق شاشة التحديث
      Get.back(); // إغلاق شاشة التفاصيل
      
      _showCompletionDialog();

    } catch (e) {
      Get.snackbar('خطأ', 'فشل إنهاء المهمة: $e',
          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.1), colorText: AppTheme.errorColor);
    } finally {
      isLoading.value = false;
    }
  }

  void _showCompletionDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: Get.theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 80),
            const SizedBox(height: 20),
            const Text(
              '🎉 هنيئاً لك!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
            ),
            const SizedBox(height: 12),
            const Text(
              'تم إتمام المهمة بنجاح، تقبل الله عملك الصالح وجعله في ميزان حسناتك.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontFamily: 'Tajawal', height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: AppTheme.gradientButton(
                text: 'آمين، العودة للرئيسية',
                onPressed: () => Get.back(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _notifyCompletion(Map<String, dynamic> data, String requestId) async {
    final requesterId = data['requesterId']?.toString();
    if (requesterId != null && requesterId.isNotEmpty) {
      await NotificationService.sendNotification(
        userId: requesterId,
        type: 'request_update',
        title: 'تحديث حالة الطلب',
        body: '🕊️ الحمد لله، تم قضاء حاجتك بنجاح. تقبل الله من الجميع.',
        data: {'requestId': requestId},
      );
    }
  }

  Future<void> _notifyAdmin(String requestId, String type, String description, {bool isUrgent = false}) async {
    await NotificationService.notifyAllAdmins(
      type: isUrgent ? 'emergency' : 'status_change',
      title: isUrgent ? '🚨 بلاغ عاجل من الميدان' : '✨ بشارة: تحديث في الميدان',
      body: isUrgent 
          ? 'أبلغ المتطوع ${currentWorker.value?.name} عن عقبة: $description'
          : 'قام الأخ ${currentWorker.value?.name} بإضافة نداء/تحديث مبشر: $description',
      data: {'requestId': requestId, 'type': type},
    );
  }


  // إحصائات
  int get currentTasksCount => myTasks.length;
  int get completedTasksCount => completedTasks.length;

  @override
  void onClose() {
    _myTasksSub?.cancel();
    _completedTasksSub?.cancel();
    _adminMessageSub?.cancel();
    _projectsSub?.cancel();
    super.onClose();
  }
}
