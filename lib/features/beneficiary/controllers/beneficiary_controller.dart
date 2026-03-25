import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/service_type_model.dart';
import '../../../data/models/user_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/offline_queue_service.dart';
import '../../../data/services/connectivity_service.dart';

class BeneficiaryController extends GetxController {
  RxList<ServiceRequestModel> myRequests = <ServiceRequestModel>[].obs;
  RxList<ServiceTypeModel> availableServices = <ServiceTypeModel>[].obs;
  RxBool isLoading = false.obs;
  Rx<UserModel?> currentBeneficiary = Rx<UserModel?>(null);

  StreamSubscription? _requestsSub;
  StreamSubscription? _serviceTypesSub;

  OfflineQueueService get _queue => Get.find<OfflineQueueService>();
  ConnectivityService get _connectivity => Get.find<ConnectivityService>();

  @override
  void onInit() {
    super.onInit();
    currentBeneficiary.value = Get.find<AuthController>().currentUser.value;
    loadMyRequests();
    loadServiceTypes();
  }

  void loadMyRequests() {
    if (currentBeneficiary.value == null) return;

    _requestsSub = FirebaseFirestore.instance
        .collection('service_requests')
        .where('requesterId', isEqualTo: currentBeneficiary.value?.id)
        .snapshots()
        .handleError((e) {
          if (kDebugMode) print('loadMyRequests error: $e');
        })
        .listen((snap) {
      final docs = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return ServiceRequestModel.fromMap(data);
      }).toList();
      docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      myRequests.value = docs;
    });
  }

  void loadServiceTypes() {
    _serviceTypesSub = FirebaseFirestore.instance
        .collection('service_types')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      availableServices.value = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return ServiceTypeModel.fromMap(data);
      }).toList();
    });
  }

  Future<void> submitRequest(Map<String, dynamic> data) async {
    final hasActive = myRequests.any(
      (r) => r.status == 'pending' || r.status == 'in_progress',
    );
    if (hasActive) {
      Get.snackbar(
        'تنبيه',
        'لديك طلب نشط بالفعل، يرجى الانتظار حتى معالجته',
        backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2),
        colorText: AppTheme.textPrimary,
      );
      return;
    }

    isLoading.value = true;
    try {
      final requestData = {
        ...data,
        'requesterId': currentBeneficiary.value?.id,
        'requesterName': currentBeneficiary.value?.name,
        'phone': currentBeneficiary.value?.phone,
        'wilaya': currentBeneficiary.value?.wilaya,
        'address': currentBeneficiary.value?.address,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!_connectivity.isOnline.value) {
        // ─── وضع بدون إنترنت: حفظ في الطابور ──────────────
        // نحتاج تحويل FieldValue لنص لأن SharedPreferences لا يدعمه
        final queueData = Map<String, dynamic>.from(requestData);
        queueData['createdAt'] = '__serverTimestamp__';
        queueData['updatedAt'] = '__serverTimestamp__';

        await _queue.enqueue(
          collection: 'service_requests',
          operation: 'add',
          data: queueData,
        );

        Get.back();
        Get.snackbar(
          '💾 تم الحفظ',
          'سيتم إرسال طلبك تلقائياً عند استعادة الاتصال بالإنترنت',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2),
          colorText: AppTheme.warningColor,
          duration: const Duration(seconds: 5),
          icon: const Icon(Icons.offline_bolt_rounded, color: Color(0xFFFFB300)),
          margin: const EdgeInsets.all(12),
          borderRadius: 16,
        );
      } else {
        // ─── وضع متصل: إرسال مباشر ──────────────────────────
        final docRef = await FirebaseFirestore.instance
            .collection('service_requests')
            .add(requestData);

        await _notifyAdmins(docRef.id, data['type']);

        Get.snackbar(
          '✅ تم الإرسال',
          'سيتم معالجة طلبك في أقرب وقت',
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
          colorText: AppTheme.successColor,
        );
        Get.back();
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في إرسال الطلب: $e',
        backgroundColor: AppTheme.errorColor.withValues(alpha: 0.2),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> rateService(String requestId, int rating, String comment) async {
    try {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .update({
        'rating': rating,
        'ratingComment': comment,
        'ratedAt': FieldValue.serverTimestamp(),
      });
      Get.back();
      Get.snackbar('شكراً', 'تم تقييم الخدمة بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في إرسال التقييم');
    }
  }

  Future<void> _notifyAdmins(String requestId, String type) async {
    try {
      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['admin', 'superAdmin']).get();

      for (var admin in admins.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': admin.id,
          'title': '🔔 طلب خدمة جديد',
          'body': 'طلب جديد ينتظر المعالجة',
          'requestId': requestId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error notifying admins: $e');
    }
  }

  @override
  void onClose() {
    _requestsSub?.cancel();
    _serviceTypesSub?.cancel();
    super.onClose();
  }
}
