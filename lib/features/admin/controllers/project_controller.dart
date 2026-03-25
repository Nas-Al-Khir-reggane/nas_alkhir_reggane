import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/project_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/constants/app_constants.dart';
import 'package:intl/intl.dart';
import '../../../data/services/offline_queue_service.dart';
import '../../../data/services/connectivity_service.dart';

class ProjectController extends GetxController {
  RxList<ProjectModel> allProjects = <ProjectModel>[].obs;
  RxList<ProjectModel> filteredProjects = <ProjectModel>[].obs;
  RxBool isLoading = false.obs;
  RxString selectedCategory = 'all'.obs;
  RxString selectedStatus = 'all'.obs;
  TextEditingController searchController = TextEditingController();

  OfflineQueueService get _queue => Get.find<OfflineQueueService>();
  ConnectivityService get _connectivity => Get.find<ConnectivityService>();

  static const List<Map<String, dynamic>> categories = [
    {
      'id': 'mosque',
      'name': 'عمارة المساجد وترميمها',
      'icon': Icons.mosque,
      'color': Color(0xFF00695C), // أخضر إسلامي عميق
    },
    {
      'id': 'orphan',
      'name': 'كفالة الأيتام والتعليم',
      'icon': Icons.menu_book,
      'color': Color(0xFF1565C0), // أزرق تعليمي
    },
    {
      'id': 'food',
      'name': 'إطعام الطعام والطرود',
      'icon': Icons.shopping_basket,
      'color': Color(0xFF2E7D32), // أخضر النماء
    },
    {
      'id': 'water',
      'name': 'سقي الماء وحفر الآبار',
      'icon': Icons.water_drop,
      'color': Color(0xFF0277BD), // أزرق مائي
    },
    {
      'id': 'medical',
      'name': 'مداواة المرضى والإسعاف',
      'icon': Icons.healing,
      'color': Color(0xFFC62828), // أحمر الرحمة
    },
    {
      'id': 'housing',
      'name': 'تفريج كرب الأسر والبيوت',
      'icon': Icons.home,
      'color': Color(0xFF795548), // بني ترابي للأرض
    },
    {
      'id': 'funeral',
      'name': 'إكرام الموتى (نقل الجنائز)',
      'icon': Icons.airport_shuttle,
      'color': Color(0xFF4527A0), // بنفسجي وقور
    },
    {
      'id': 'zakat',
      'name': 'زكاة المال والصدقات',
      'icon': Icons.savings,
      'color': Color(0xFFD4AF37), // لون الذهب والزكاة
    },
    {
      'id': 'general',
      'name': 'أبواب الخير العامة',
      'icon': Icons.volunteer_activism,
      'color': Color(0xFF546E7A),
    },
  ];

  @override
  void onInit() {
    super.onInit();
    listenToProjects();
    searchController.addListener(filterProjects);
  }

  void listenToProjects() {
    FirebaseFirestore.instance
        .collection(AppConstants.projectsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      allProjects.value = snap.docs.map((d) {
        final data = d.data();
        return ProjectModel.fromMap(data, d.id);
      }).toList();
      filterProjects();
    });
  }

  void filterProjects() {
    var list = allProjects.toList();
    if (selectedCategory.value != 'all') {
      list = list.where((p) => p.category == selectedCategory.value).toList();
    }
    if (selectedStatus.value != 'all') {
      list = list.where((p) => p.status == selectedStatus.value).toList();
    }
    if (searchController.text.isNotEmpty) {
      final query = searchController.text.toLowerCase();
      list = list.where((p) => 
        p.name.toLowerCase().contains(query) || 
        p.description.toLowerCase().contains(query)
      ).toList();
    }
    filteredProjects.value = list;
  }

  Future<void> addProject({
    required String name,
    required String category,
    required String description,
    required double budget,
    required DateTime endDate,
  }) async {
    final data = {
      'name': name,
      'category': category,
      'description': description,
      'budget': budget,
      'endDate': Timestamp.fromDate(endDate),
      'collected': 0.0,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': Get.find<AuthController>().currentUser.value?.id ?? '',
      'donorsCount': 0,
      'assignedWorkers': [],
      'volunteers': [],
    };

    if (!_connectivity.isOnline.value) {
      final queueData = Map<String, dynamic>.from(data);
      queueData['createdAt'] = '__serverTimestamp__';
      queueData['endDate'] = endDate.toIso8601String();
      await _queue.enqueue(collection: AppConstants.projectsCollection, operation: 'add', data: queueData);
      Get.snackbar('💾 تم الحفظ', 'سيتم نشر المشروع عند استعادة الاتصال',
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2),
          colorText: AppTheme.warningColor, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection(AppConstants.projectsCollection).add(data);
      Get.snackbar('✅ تم', 'تم إضافة المشروع بنجاح',
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
          colorText: AppTheme.successColor);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إضافة المشروع: $e',
          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.2),
          colorText: AppTheme.errorColor);
    }
  }

  Future<void> updateProject(String id, Map<String, dynamic> data) async {
    final updateData = {...data, 'updatedAt': FieldValue.serverTimestamp()};
    if (!_connectivity.isOnline.value) {
      final queueData = Map<String, dynamic>.from(updateData);
      queueData['updatedAt'] = '__serverTimestamp__';
      await _queue.enqueue(collection: AppConstants.projectsCollection, operation: 'update', data: queueData, docId: id);
      Get.snackbar('💾 تم الحفظ', 'سيتم تطبيق التعديل عند استعادة الاتصال',
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2),
          colorText: AppTheme.warningColor, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      await FirebaseFirestore.instance.collection(AppConstants.projectsCollection).doc(id).update(updateData);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحديث المشروع: $e');
    }
  }

  Future<void> toggleProjectStatus(String id, String currentStatus) async {
    try {
      final newStatus = currentStatus == 'active' ? 'paused' : 'active';
      await FirebaseFirestore.instance.collection(AppConstants.projectsCollection).doc(id).update({'status': newStatus});
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تغيير حالة المشروع: $e');
    }
  }

  Future<void> deleteProject(String id) async {
    if (!_connectivity.isOnline.value) {
      await _queue.enqueue(collection: AppConstants.projectsCollection, operation: 'delete', data: {}, docId: id);
      Get.snackbar('💾 تم الحفظ', 'سيتم حذف المشروع عند استعادة الاتصال',
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.2),
          colorText: AppTheme.warningColor, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      await FirebaseFirestore.instance.collection(AppConstants.projectsCollection).doc(id).delete();
      Get.snackbar('🗑️ تم الحذف', 'تم حذف المشروع',
          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.2),
          colorText: AppTheme.errorColor);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل حذف المشروع: $e');
    }
  }

  Future<void> assignWorkerToProject(String projectId, String workerId) async {
    try {
      await FirebaseFirestore.instance.collection(AppConstants.projectsCollection).doc(projectId).update({
        'assignedWorkers': FieldValue.arrayUnion([workerId])
      });
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إسناد العامل: $e');
    }
  }

  Future<void> unassignWorkerFromProject(String projectId, String workerId) async {
    try {
      await FirebaseFirestore.instance.collection(AppConstants.projectsCollection).doc(projectId).update({
        'assignedWorkers': FieldValue.arrayRemove([workerId])
      });
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إزالة العامل: $e');
    }
  }

  Future<void> shareProject(ProjectModel project) async {
    final progress = project.progressPercentage.toStringAsFixed(1);
    final text = '''
🌿 جمعية ناس الخير رقان
📁 ${project.name}
${project.description}
💰 تم جمع: ${formatNumber(project.collected)} دج من ${formatNumber(project.budget)} دج
📊 نسبة الإنجاز: $progress%
تبرع الآن وساهم في هذا المشروع الخيري
    ''';
    await Share.share(text);
  }

  // إحصائيات
  int get totalProjects => allProjects.length;
  int get activeCount => allProjects.where((p) => p.status == 'active').length;
  int get completedCount => allProjects.where((p) => p.status == 'completed').length;
  int get pausedCount => allProjects.where((p) => p.status == 'paused').length;
  double get totalCollected => allProjects.fold(0.0, (total, p) => total + p.collected);

  String formatNumber(num number) {
    return NumberFormat("#,###").format(number);
  }

  String daysLeft(DateTime? deadline) {
    if (deadline == null) return "غير محدد";
    final now = DateTime.now();
    final difference = deadline.difference(now).inDays;
    if (difference < 0) return "منتهي";
    if (difference == 0) return "اليوم";
    return "$difference يوم متبقي";
  }

  String timeAgo(DateTime? date) {
    if (date == null) return "غير معروف";
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) return 'منذ ${(difference.inDays / 365).floor()} سنة';
    if (difference.inDays > 30) return 'منذ ${(difference.inDays / 30).floor()} شهر';
    if (difference.inDays > 0) return 'منذ ${difference.inDays} يوم';
    if (difference.inHours > 0) return 'منذ ${difference.inHours} ساعة';
    if (difference.inMinutes > 0) return 'منذ ${difference.inMinutes} دقيقة';
    return 'الآن';
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
