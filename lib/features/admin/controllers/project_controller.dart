import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/project_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/constants/app_constants.dart';
import 'package:intl/intl.dart';

class ProjectController extends GetxController {
  RxList<ProjectModel> allProjects = <ProjectModel>[].obs;
  RxList<ProjectModel> filteredProjects = <ProjectModel>[].obs;
  RxBool isLoading = false.obs;
  RxString selectedCategory = 'all'.obs;
  RxString selectedStatus = 'all'.obs;
  TextEditingController searchController = TextEditingController();

  static const List<Map<String, dynamic>> categories = [
    {'id': 'construction', 'name': 'بناء وتعمير', 'icon': Icons.construction, 'color': Color(0xFF795548)},
    {'id': 'education', 'name': 'تعليم وكفالة أيتام', 'icon': Icons.school, 'color': Color(0xFF1565C0)},
    {'id': 'food', 'name': 'إغاثة غذائية', 'icon': Icons.fastfood, 'color': Color(0xFF2E7D32)},
    {'id': 'medical', 'name': 'مساعدة طبية', 'icon': Icons.nightlight_round, 'color': Color(0xFFC62828)},
    {'id': 'financial', 'name': 'مساعدة مالية', 'icon': Icons.attach_money, 'color': Color(0xFFFF8F00)},
    {'id': 'funeral', 'name': 'نقل الجنازات', 'icon': Icons.airport_shuttle, 'color': Color(0xFF4A148C)},
    {'id': 'religious', 'name': 'ديني واجتماعي', 'icon': Icons.mosque, 'color': Color(0xFF00695C)},
    {'id': 'infrastructure', 'name': 'بنية تحتية', 'icon': Icons.engineering, 'color': Color(0xFF37474F)},
    {'id': 'other', 'name': 'أخرى', 'icon': Icons.more_horiz, 'color': Color(0xFF546E7A)},
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
    try {
      await FirebaseFirestore.instance.collection(AppConstants.projectsCollection).add({
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
      });
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
    try {
      await FirebaseFirestore.instance.collection(AppConstants.projectsCollection).doc(id).update({
        ...data, 'updatedAt': FieldValue.serverTimestamp()
      });
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
