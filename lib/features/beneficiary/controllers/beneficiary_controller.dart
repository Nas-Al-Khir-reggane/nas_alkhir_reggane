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
import '../../../data/services/notification_service.dart';

class BeneficiaryController extends GetxController {
  RxList<ServiceRequestModel> myRequests = <ServiceRequestModel>[].obs;
  RxList<ServiceTypeModel> availableServices = <ServiceTypeModel>[].obs;
  RxBool isLoading = false.obs;
  RxBool isLoadingServices = false.obs;
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
    isLoadingServices.value = true;
    _serviceTypesSub = FirebaseFirestore.instance
        .collection('service_types')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      List<ServiceTypeModel> services = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return ServiceTypeModel.fromMap(data);
      }).toList();

      services.sort((a, b) {
        if (a.id == 'other') return 1;
        if (b.id == 'other') return -1;
        int popCompare = b.popularity.compareTo(a.popularity);
        if (popCompare != 0) return popCompare;
        return a.name.compareTo(b.name);
      });

      availableServices.value = services;
      isLoadingServices.value = false;
    }, onError: (error) {
      isLoadingServices.value = false;
      if (kDebugMode) print('Error loading services: $error');
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
        backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15),
        colorText: AppTheme.textPrimary,
      );
      return;
    }

    isLoading.value = true;
    try {
      final user = currentBeneficiary.value;
      final fallbackName = (user != null) ? user.email.split('@').first : 'مدير';
      final requestData = {
        ...data,
        'requesterId': user?.id ?? Get.find<AuthController>().currentUser.value?.id ?? '',
        'requesterName': (data['beneficiaryName'] != null && data['beneficiaryName'].toString().isNotEmpty) 
            ? data['beneficiaryName'] 
            : ((user != null && user.name.isNotEmpty) ? user.name : fallbackName),
        'phone': data['beneficiaryPhone'] ?? user?.phone ?? '',
        'wilaya': user?.wilaya ?? '',
        'commune': user?.commune ?? '',
        'address': data['beneficiaryAddress'] ?? user?.address ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (data['type'] == 'blood_donation' || data['type'] == 'blood_emergency') {
        final details = data['details'] ?? {};
        requestData['bloodType'] = details['الفصيلة'] ?? details['bloodType'] ?? '';
        requestData['hospital'] = details['المستشفى'] ?? details['hospital'] ?? '';
      }

      if (data['type'] == 'funeral_ghusl') {
        final details = data['details'] ?? {};
        requestData['deceasedGender'] = details['جنس المتوفى'] ?? details['gender'] ?? '';
        requestData['washingLocation'] = details['مكان الغسل'] ?? details['location'] ?? '';
        requestData['supplies'] = details['المستلزمات'] ?? details['supplies'] ?? '';
      }

      if (!_connectivity.isOnline.value) {
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
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15),
          colorText: AppTheme.warningColor,
          duration: const Duration(seconds: 5),
          icon: const Icon(Icons.offline_bolt_rounded, color: Color(0xFFFFB300)),
          margin: const EdgeInsets.all(12),
          borderRadius: 16,
        );
      } else {
        final docRef = await FirebaseFirestore.instance
            .collection('service_requests')
            .add(requestData);

        await FirebaseFirestore.instance
            .collection('service_types')
            .doc(data['type'])
            .update({'popularity': FieldValue.increment(1)});

        await _notifyAdminsOnNewRequest(docRef.id, data['type']);

        Get.back();
        Get.snackbar(
          '✅ تم الإرسال',
          'سيتم معالجة طلبك في أقرب وقت',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.15),
          colorText: AppTheme.successColor,
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.all(12),
          borderRadius: 16,
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في إرسال الطلب: $e',
        backgroundColor: AppTheme.errorColor.withValues(alpha: 0.15),
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
      
      // ✨ إشعار الإدارة بتقييم الخدمة
      try {
        await NotificationService.notifyAllAdmins(
          type: 'service_rating',
          title: '⭐ تقييم جديد ($rating/5)',
          body: comment.isNotEmpty ? 'تعليق: $comment' : 'تم استلام تقييم جديد لطلب منجز',
          data: {
            'requestId': requestId,
            'collection': 'service_requests',
          },
        );
      } catch (e) {
        debugPrint('Error notifying admins about rating: $e');
      }
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في إرسال التقييم');
    }
  }

  Future<void> _notifyAdminsOnNewRequest(String requestId, String type) async {
    try {
      // استخدام الدالة المركزية لضمان وصول الإشعار لكل المدراء بما فيهم المدير العام
      await NotificationService.notifyAllAdmins(
        type: 'new_request',
        title: '🔔 طلب خدمة جديد',
        body: 'طلب جديد ينتظر المعالجة',
        data: {
          'requestId': requestId,
          'collection': 'service_requests',
          'serviceType': type,
        },
      );
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

