import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/service_type_model.dart';

class BeneficiaryController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RxList<ServiceRequestModel> myRequests = <ServiceRequestModel>[].obs;
  RxList<ServiceTypeModel> availableServices = <ServiceTypeModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadServiceTypes();
  }

  void loadServiceTypes() {
    _firestore
        .collection(AppConstants.serviceTypesCollection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      availableServices.value = snap.docs.map((doc) => ServiceTypeModel.fromMap(doc.data())).toList();
    });
  }

  void loadMyRequests(String userId) {
    _firestore
        .collection(AppConstants.serviceRequestsCollection)
        .where('requesterId', isEqualTo: userId)
        .snapshots()
        .listen((snap) {
      myRequests.value = snap.docs.map((doc) => ServiceRequestModel.fromMap(doc.data())).toList();
    });
  }

  Future<void> submitRequest(ServiceRequestModel request) async {
    try {
      await _firestore.collection(AppConstants.serviceRequestsCollection).doc(request.id).set(request.toMap());
      
      await _firestore.collection('notifications').add({
        'title': 'طلب خدمة جديد',
        'body': 'تم إنشاء طلب خدمة جديد من المستفيد ${request.requesterName}',
        'type': 'new_request',
        'createdAt': FieldValue.serverTimestamp(),
      });

      Get.snackbar("نجاح", "تم إرسال طلبك بنجاح");
      Get.back();
    } catch (e) {
      Get.snackbar("خطأ", "فشل إرسال الطلب: ${e.toString()}");
    }
  }
}
