import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/services/cloudinary_service.dart';
import '../../../data/services/image_compression_service.dart';
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


  Future<List<String>> uploadAttachments({
    required String requestId,
    required String requesterId,
    required List<File> files,
  }) async {
    final List<String> urls = [];

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      // السماح بملفات أكبر قليلاً لـ Cloudinary إذا أردت، لكن سنبقي على الفلتر الحالي كحد أدنى
      if (await file.length() > 5 * 1024 * 1024) {
        Get.snackbar('حجم الملف', 'حجم الملف يجب أن لا يتجاوز 5 ميغابايت');
        continue;
      }

      try {
        // ضغط المرفق قبل الرفع
        final compressedFile = await ImageCompressionService.compressImage(file);
        final result = await CloudinaryService.uploadMedia(compressedFile ?? file);
        if (result != null) {
          urls.add(result);
        }
      } catch (e) {
        if (kDebugMode) print('Upload error: $e');
      }
    }

    return urls;
  }

  Future<void> submitRequest(Map<String, dynamic> data, {List<File> attachments = const []}) async {
    // نأخذ نسخة ثابتة من المرفقات لتجنب مسحها من الواجهة قبل اكتمال الرفع
    final filesToUpload = List<File>.from(attachments);
    
    final hasActive = myRequests.any(
      (r) => r.status == 'pending' || r.status == 'in_progress',
    );
    if (hasActive) {
      Get.defaultDialog(
        title: 'عذراً لا يمكن تقديم الطلب',
        content: const Text(
          'لديك طلب نشط حالياً قيد المعالجة. يرجى الانتظار حتى يتم إغلاقه أو إكماله من قبل الإدارة لتتمكن من تقديم طلب جديد.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 14),
        ),
        titleStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
        textConfirm: 'حسناً',
        confirmTextColor: Colors.white,
        buttonColor: Colors.red,
        onConfirm: () => Get.back(),
        radius: 12,
      );
      return;
    }

    isLoading.value = true;
    try {
      final authController = Get.find<AuthController>();
      final user = currentBeneficiary.value ?? authController.currentUser.value;
      
      if (user == null || user.id.isEmpty) {
        Get.snackbar("خطأ المصادقة", "لم يتم العثور على هوية المستخدم. الرجاء تسجيل الدخول مجدداً.");
        isLoading.value = false;
        return;
      }

      final fallbackName = user.email.split('@').first.isNotEmpty ? user.email.split('@').first : 'مستفيد';
      
      if (!_connectivity.isOnline.value && attachments.isNotEmpty) {
        Get.snackbar(
          'المرفقات تحتاج اتصالاً',
          'يرجى الاتصال بالإنترنت أولاً لإرفاق الملفات بشكل آمن',
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15),
          colorText: AppTheme.warningColor,
        );
        isLoading.value = false;
        return;
      }

      final details = Map<String, dynamic>.from(data['details'] ?? const {});

      final requestData = {
        ...data,
        'requesterId': user.id,
        'requesterName': (data['beneficiaryName'] != null && data['beneficiaryName'].toString().isNotEmpty) 
            ? data['beneficiaryName'] 
            : (user.name.isNotEmpty ? user.name : fallbackName),
        'phone': data['beneficiaryPhone'] ?? details['رقم الهاتف'] ?? details['رقم هاتف التواصل'] ?? details['phone'] ?? user.phone,
        'wilaya': user.wilaya,
        'commune': user.commune,
        'address': data['beneficiaryAddress'] ?? user.address,
        'status': 'pending',
        'attachments': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (data['type'] == 'blood_donation' || data['type'] == 'blood_emergency') {
        requestData['bloodType'] = details['الفصيلة'] ?? details['فصيلة الدم'] ?? details['bloodType'] ?? '';
        requestData['hospital'] = details['المستشفى'] ?? details['hospital'] ?? details['deliveryLocation'] ?? '';
        requestData['patientName'] = details['اسم المريض'] ?? details['المريض'] ?? requestData['requesterName'] ?? '';
      }

      if (data['type'] == 'funeral_ghusl') {
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
        final docRef = FirebaseFirestore.instance.collection('service_requests').doc();
        await docRef.set(requestData);

        if (filesToUpload.isNotEmpty) {
          final attachmentPaths = await uploadAttachments(
            requestId: docRef.id,
            requesterId: user.id,
            files: filesToUpload,
          );
          await docRef.update({
            'attachments': attachmentPaths,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        try {
          await FirebaseFirestore.instance
              .collection('service_types')
              .doc(data['type'])
              .update({'popularity': FieldValue.increment(1)});
        } catch (e) {
          debugPrint('Error updating popularity: $e');
        }

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
      final firestore = FirebaseFirestore.instance;
      final requestRef = firestore.collection('service_requests').doc(requestId);

      await firestore.runTransaction((tx) async {
        final requestSnap = await tx.get(requestRef);
        if (!requestSnap.exists) {
          throw Exception('الطلب غير موجود');
        }

        final requestData = requestSnap.data() as Map<String, dynamic>;
        if (requestData['rating'] != null) {
          throw Exception('تم تقييم هذا الطلب مسبقاً');
        }

        tx.update(requestRef, {
          'rating': rating,
          'ratingComment': comment,
          'ratedAt': FieldValue.serverTimestamp(),
        });

        final assignedWorkerId = (requestData['assignedTo'] ?? '').toString();
        if (assignedWorkerId.isEmpty) {
          return;
        }

        final workerRef = firestore.collection('users').doc(assignedWorkerId);
        final workerSnap = await tx.get(workerRef);
        if (!workerSnap.exists) {
          return;
        }

        final workerData = workerSnap.data() as Map<String, dynamic>;
        if ((workerData['role'] ?? '').toString() != UserRole.worker.name) {
          return;
        }

        final currentAvg = ((workerData['rating'] ?? 0) as num).toDouble();
        final currentCount = ((workerData['ratingCount'] ?? 0) as num).toInt();
        final nextCount = currentCount + 1;
        final nextAvg = ((currentAvg * currentCount) + rating) / nextCount;

        tx.update(workerRef, {
          'rating': nextAvg,
          'ratingCount': nextCount,
          'lastActivity': FieldValue.serverTimestamp(),
        });
      });

      Get.back();
      Get.snackbar('شكراً', 'تم تقييم الخدمة بنجاح');
      
      // ✨ إشعار الإدارة بتقييم الخدمة
      try {
        await NotificationService.notifyAllAdmins(
          type: 'service_rating',
          title: '✨ تقييم وعلامة رضا للعمل ($rating/5)',
          body: comment.isNotEmpty ? 'ثناء ودعاء: $comment' : 'الحمد لله، تم إنجاز الطلب وتقييمه بنجاح. بارك الله في جهودكم.',
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
        title: '🚨 فرصة لكسب الأجر!',
        body: 'طلب جديد للإغاثة ينتظر المعالجة. بادر بقضائها، فصنائع المعروف تقي مصارع السوء.',
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
