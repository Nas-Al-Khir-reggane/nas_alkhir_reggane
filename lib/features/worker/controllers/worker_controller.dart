import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/chat_message_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/services/notification_service.dart';
import '../../../core/constants/app_constants.dart';

class WorkerController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  RxList<ServiceRequestModel> myTasks = <ServiceRequestModel>[].obs;
  RxList<ServiceRequestModel> completedTasks = <ServiceRequestModel>[].obs;
  RxList<String> myProjectIds = <String>[].obs; // Projects assigned to this worker
  Rx<UserModel?> currentWorker = Rx<UserModel?>(null);
  RxBool isLoading = false.obs;
  RxBool isAvailable = true.obs;
  Rx<ChatMessageModel?> lastAdminMessage = Rx<ChatMessageModel?>(null);

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
        .where('status', whereIn: ['in_progress', 'pending'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      myTasks.value = snap.docs.map((d) {
        var data = d.data();
        data['id'] = d.id;
        return ServiceRequestModel.fromMap(data);
      }).toList();
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
      }).toList();
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
    String? projectId, // Optional: if this update is linked to a project
  }) async {
    isLoading.value = true;
    try {
      String? imageUrl;
      if (imageFile != null) {
        final ref = _storage.ref('updates/${currentWorker.value?.id}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(imageFile);
        imageUrl = await ref.getDownloadURL();
      }

      final updateData = {
        'workerId': currentWorker.value?.id,
        'workerName': currentWorker.value?.name,
        'type': type,
        'description': description,
        'imageUrl': imageUrl,
        'requestId': requestId,
        'projectId': projectId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 1. Save to Request sub-collection
      await _firestore.collection(AppConstants.serviceRequestsCollection).doc(requestId).collection('updates').add(updateData);

      // 2. Save to Global updates for Projects (to be visible in Project details)
      if (projectId != null || (projectId == null && myProjectIds.isNotEmpty)) {
        // If not specified, we can try to find if this request is linked to a project 
        // or just add it to the first project this worker is assigned to (for general updates)
        final targetProjectId = projectId ?? (myProjectIds.isNotEmpty ? myProjectIds.first : null);
        if (targetProjectId != null) {
          updateData['projectId'] = targetProjectId;
          await _firestore.collection('worker_updates').add(updateData);
        }
      }

      // تحديث آخر نشاط للعامل
      await _firestore.collection(AppConstants.usersCollection).doc(currentWorker.value?.id).update({
        'lastActivity': FieldValue.serverTimestamp(),
      });

      // إشعار للأدمين
      await _notifyAdmin(requestId, type, description);

      Get.snackbar('✅ تم الإرسال', 'تم إرسال التحديث بنجاح',
          backgroundColor: Get.theme.colorScheme.primary.withValues(alpha: 0.15), colorText: Get.theme.colorScheme.primary);
      
      Get.back(); // Return from update screen
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إرسال التحديث: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _notifyAdmin(String requestId, String type, String description) async {
    await NotificationService.notifyAllAdmins(
      type: 'status_change',
      title: 'تحديث مهمة',
      body: 'قام ${currentWorker.value?.name} بإضافة تحديث: $description',
      data: {'requestId': requestId, 'type': type},
    );
  }

  Future<void> completeTask(String requestId) async {
    try {
      await _firestore.collection(AppConstants.serviceRequestsCollection).doc(requestId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // تحديث إحصائات العامل
      await _firestore.collection(AppConstants.usersCollection).doc(currentWorker.value?.id).update({
        'completedTasks': FieldValue.increment(1),
        'isAvailable': true,
        'lastActivity': FieldValue.serverTimestamp(),
      });
      isAvailable.value = true;
      
      Get.snackbar('🎉 أحسنت!', 'تم إتمام المهمة بنجاح',
          backgroundColor: Get.theme.colorScheme.primary.withValues(alpha: 0.15), colorText: Get.theme.colorScheme.primary);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إنهاء المهمة: $e',
          backgroundColor: Get.theme.colorScheme.error.withValues(alpha: 0.15), colorText: Get.theme.colorScheme.error);
    }
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

