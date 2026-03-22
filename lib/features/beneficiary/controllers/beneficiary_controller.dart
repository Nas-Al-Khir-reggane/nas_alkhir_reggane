import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/service_type_model.dart';
import '../../../data/models/user_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/theme/app_theme.dart';

class BeneficiaryController extends GetxController {
  RxList<ServiceRequestModel> myRequests = <ServiceRequestModel>[].obs;
  RxList<ServiceTypeModel> availableServices = <ServiceTypeModel>[].obs;
  RxBool isLoading = false.obs;
  Rx<UserModel?> currentBeneficiary = Rx<UserModel?>(null);

  @override
  void onInit() {
    super.onInit();
    currentBeneficiary.value = Get.find<AuthController>().currentUser.value;
    loadMyRequests();
    loadServiceTypes();
  }

  void loadMyRequests() {
    if (currentBeneficiary.value == null) return;
    
    FirebaseFirestore.instance
        .collection('service_requests')
        .where('requesterId', isEqualTo: currentBeneficiary.value?.id)
        // بدون orderBy لتجنب الحاجة لـ Composite Index في Firestore
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
      // ترتيب محلي بدلاً من Firestore orderBy
      docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      myRequests.value = docs;
    });
  }

  void loadServiceTypes() {
    FirebaseFirestore.instance
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
    isLoading.value = true;
    try {
      final docRef = await FirebaseFirestore.instance.collection('service_requests').add({
        ...data,
        'requesterId': currentBeneficiary.value?.id,
        'requesterName': currentBeneficiary.value?.name,
        'phone': currentBeneficiary.value?.phone,
        'wilaya': currentBeneficiary.value?.wilaya,
        'address': currentBeneficiary.value?.address,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // إشعار للأدمين
      await _notifyAdmins(docRef.id, data['type']);
      
      Get.snackbar('✅ تم الإرسال', 'سيتم معالجة طلبك في أقرب وقت',
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
          colorText: AppTheme.successColor);
      Get.back();
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في إرسال الطلب: $e',
          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.2));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> rateService(String requestId, int rating, String comment) async {
    try {
      await FirebaseFirestore.instance.collection('service_requests').doc(requestId).update({
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
}
