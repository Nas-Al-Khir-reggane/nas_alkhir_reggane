import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';

class WorkerManagementController extends GetxController {
  // أدوار العمال
  static const List<Map<String, dynamic>> workerRoles = [
    {'id': 'funeral_driver', 'name': 'سائق نقل جنازة', 'icon': Icons.airport_shuttle, 'color': AppTheme.primaryGreen},
    {'id': 'field_worker', 'name': 'متطوع ميداني', 'icon': Icons.engineering, 'color': Color(0xFF1565C0)},
    {'id': 'coordinator', 'name': 'منسق', 'icon': Icons.manage_accounts, 'color': Color(0xFF00695C)},
    {'id': 'volunteer', 'name': 'متطوع', 'icon': Icons.volunteer_activism, 'color': Color(0xFF2E7D32)},
    {'id': 'supervisor', 'name': 'مشرف', 'icon': Icons.supervisor_account, 'color': Color(0xFFE65100)},
    {'id': 'accountant', 'name': 'محاسب', 'icon': Icons.calculate, 'color': Color(0xFF880E4F)},
  ];

  RxList<UserModel> allWorkers = <UserModel>[].obs;
  RxList<UserModel> filteredWorkers = <UserModel>[].obs;
  RxString selectedRole = 'all'.obs;
  RxString selectedAvailability = 'all'.obs;
  TextEditingController searchController = TextEditingController();
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    listenToWorkers();
    searchController.addListener(filterWorkers);
  }

  void listenToWorkers() {
    FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      allWorkers.value = snap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();
      filterWorkers();
    });
  }

  void filterWorkers() {
    var list = allWorkers.toList();
    if (selectedRole.value != 'all') {
      list = list.where((w) => w.workerRole == selectedRole.value).toList();
    }
    if (selectedAvailability.value == 'available') {
      list = list.where((w) => w.isAvailable == true).toList();
    } else if (selectedAvailability.value == 'busy') {
      list = list.where((w) => w.isAvailable == false).toList();
    }
    if (searchController.text.isNotEmpty) {
      final query = searchController.text.toLowerCase();
      list = list.where((w) =>
          w.name.toLowerCase().contains(query) ||
          w.phone.contains(query)).toList();
    }
    filteredWorkers.value = list;
  }

  Future<void> addWorker(Map<String, dynamic> data) async {
    try {
      isLoading.value = true;
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: data['email'],
        password: data['password'],
      );
      
      await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
        ...data,
        'id': credential.user!.uid,
        'role': 'worker',
        'isApproved': true,
        'isAvailable': true,
        'isActive': true,
        'completedTasks': 0,
        'totalTrips': 0,
        'rating': 0.0,
        'ratingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'currentTasksCount': 0,
        'lastActivity': FieldValue.serverTimestamp(),
      });
      
      Get.back();
      Get.snackbar('✅ تم', 'تم إضافة المتطوع بنجاح',
        backgroundColor: AppTheme.successColor.withValues(alpha: 0.15),
        colorText: AppTheme.successColor);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إضافة المتطوع: $e',
          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.15));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateWorker(String id, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      Get.snackbar('✅ تم', 'تم تحديث بيانات المتطوع');
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء التحديث');
    }
  }

  Future<void> toggleWorkerStatus(String id, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(id).update({
        'isActive': !currentStatus,
      });
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ: $e');
    }
  }

  Future<void> toggleAvailability(String id, bool currentAvailability) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(id).update({
        'isAvailable': !currentAvailability,
      });
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ: $e');
    }
  }

  Future<void> rateWorker(String id, double rating) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
      final currentRating = (doc.data()?['rating'] ?? 0.0).toDouble();
      final ratingCount = doc.data()?['ratingCount'] ?? 0;
      final newRating = ((currentRating * ratingCount) + rating) / (ratingCount + 1);
      
      await FirebaseFirestore.instance.collection('users').doc(id).update({
        'rating': newRating,
        'ratingCount': ratingCount + 1,
      });
      Get.back();
      Get.snackbar('✅ تم', 'تم التقييم بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل التقييم');
    }
  }

  int get totalWorkers => allWorkers.length;
  int get availableWorkers => allWorkers.where((w) => w.isAvailable == true).length;
  int get busyWorkers => allWorkers.where((w) => w.isAvailable == false).length;
  int get fatalDrivers => allWorkers.where((w) => w.workerRole == 'funeral_driver').length;

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}

