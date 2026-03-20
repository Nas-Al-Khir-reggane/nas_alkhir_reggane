import 'dart:io';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/service_request_model.dart';

class WorkerController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  RxList<ServiceRequestModel> assignedRequests = <ServiceRequestModel>[].obs;
  Rx<UserModel?> currentWorker = Rx<UserModel?>(null);

  void loadMyTasks(String workerId) {
    _firestore
        .collection(AppConstants.serviceRequestsCollection)
        .where('assignedTo', isEqualTo: workerId)
        .where('status', isNotEqualTo: 'completed')
        .snapshots()
        .listen((snap) {
      assignedRequests.value = snap.docs.map((doc) => ServiceRequestModel.fromMap(doc.data())).toList();
    });
  }

  Future<void> submitUpdate(String requestId, String text, File? imageFile) async {
    try {
      String? imageUrl;
      if (imageFile != null) {
        String fileName = "updates/${DateTime.now().millisecondsSinceEpoch}.jpg";
        TaskSnapshot snapshot = await _storage.ref(fileName).putFile(imageFile);
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      await _firestore.collection(AppConstants.serviceRequestsCollection).doc(requestId).update({
        'updates': FieldValue.arrayUnion([
          {
            'text': text,
            'imageUrl': imageUrl,
            'timestamp': Timestamp.now(),
          }
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await _firestore.collection('notifications').add({
        'title': 'تحديث جديد',
        'body': 'تم إضافة تحديث على الطلب $requestId',
        'type': 'admin_update',
        'createdAt': FieldValue.serverTimestamp(),
      });

      Get.snackbar("نجاح", "تمت إضافة التحديث بنجاح");
      Get.back();
    } catch (e) {
      Get.snackbar("خطأ", "فشل إضافة التحديث: ${e.toString()}");
    }
  }

  Future<void> completeTask(String taskId) async {
    try {
      await _firestore.collection(AppConstants.serviceRequestsCollection).doc(taskId).update({
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      Get.snackbar("نجاح", "تم إكمال المهمة بنجاح");
    } catch (e) {
      Get.snackbar("خطأ", "فشل إكمال المهمة: ${e.toString()}");
    }
  }
}
