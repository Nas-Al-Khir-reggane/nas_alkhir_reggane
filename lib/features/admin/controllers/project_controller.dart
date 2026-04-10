import 'dart:ui' as ui;
import 'package:nas_al_kheir/core/widgets/project_share_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/repositories/project_repository.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/project_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/constants/app_constants.dart';
import 'package:intl/intl.dart';
import '../../../data/services/offline_queue_service.dart';
import '../../../data/services/connectivity_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/models/user_model.dart';

class ProjectController extends GetxController {
  RxList<ProjectModel> allProjects = <ProjectModel>[].obs;
  RxList<ProjectModel> filteredProjects = <ProjectModel>[].obs;
  RxBool isLoading = false.obs;
  RxString selectedCategory = 'all'.obs;
  RxString selectedStatus = 'all'.obs;
  TextEditingController searchController = TextEditingController();

  OfflineQueueService get _queue => Get.find<OfflineQueueService>();
  ConnectivityService get _connectivity => Get.find<ConnectivityService>();

  final ProjectRepository _repository = ProjectRepository();

  static const List<Map<String, dynamic>> categories = AppConstants.projectCategories;

  @override
  void onInit() {
    super.onInit();
    listenToProjects();
    searchController.addListener(filterProjects);
  }

  void listenToProjects() {
    _repository.listenToProjects().listen((projects) {
      allProjects.value = projects;
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
    bool isSubscription = false, 
    bool isMonthlyGoal = false, 
  }) async {
    final currentUser = Get.find<AuthController>().currentUser.value;
    if (currentUser?.role != UserRole.superAdmin) {
      Get.snackbar('❌ وصول مرفوض', 'إضافة المشاريع متاحة للمنسق العام فقط',
          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.15),
          colorText: AppTheme.errorColor);
      return;
    }

    if (isLoading.value) return; // 🛡️ حماية الضغط المزدوج
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
      'isSubscription': isSubscription, 
      'isMonthlyGoal': isMonthlyGoal, 
    };

    if (!_connectivity.isOnline.value) {
      final queueData = Map<String, dynamic>.from(data);
      queueData['createdAt'] = '__serverTimestamp__';
      queueData['endDate'] = endDate.toIso8601String();
      await _queue.enqueue(collection: AppConstants.projectsCollection, operation: 'add', data: queueData);
      
      Get.back(); // إغلاق الصفحة أولاً
      Get.snackbar('💾 تم الحفظ', 'سيتم نشر المشروع عند استعادة الاتصال',
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15),
          colorText: AppTheme.warningColor, 
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
          borderRadius: 16);
      return;
    }

    try {
      isLoading.value = true;
      final docRef = await _repository.addProject(data);
      
      // إرسال إشعار عام للجميع بالمشروع الجديد
      await NotificationService.notifyAll(
        type: 'new_project',
        title: '🌿 باب جديد من أبواب الخير: $name',
        body: 'أبشركم، تم إطلاق مشروع [$name]. فرصة جديدة لنضع بصمة أثر ونغرس غرساً يبقى أجرُه. ﴿وَافْعَلُوا الْخَيْرَ لَعَلَّكُمْ تُفْلِحُونَ﴾',
        data: {
          'projectId': docRef.id,
          'category': category,
        },
      );
      
      Get.back(); // إغلاق الصفحة أولاً
      Get.snackbar('✅ تم', 'تم إضافة المشروع بنجاح',
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.15),
          colorText: AppTheme.successColor,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
          borderRadius: 16,
          duration: const Duration(seconds: 4));
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إضافة المشروع: $e',
          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.15),
          colorText: AppTheme.errorColor);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateProject(String id, Map<String, dynamic> data) async {
    if (isLoading.value) return; // 🛡️ حماية الضغط المزدوج
    final updateData = {...data, 'updatedAt': FieldValue.serverTimestamp()};
    if (!_connectivity.isOnline.value) {
      final queueData = Map<String, dynamic>.from(updateData);
      queueData['updatedAt'] = '__serverTimestamp__';
      await _queue.enqueue(collection: AppConstants.projectsCollection, operation: 'update', data: queueData, docId: id);
      Get.snackbar('💾 تم الحفظ', 'سيتم تطبيق التعديل عند استعادة الاتصال',
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15),
          colorText: AppTheme.warningColor, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      isLoading.value = true;
      await _repository.updateProject(id, updateData);
      Get.snackbar('✅ تم التحديث', 'تم حفظ التعديلات بنجاح',
          backgroundColor: AppTheme.successColor.withValues(alpha: 0.15),
          colorText: AppTheme.successColor,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحديث المشروع: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleProjectStatus(String id, String currentStatus) async {
    if (isLoading.value) return; // 🛡️ حماية الضغط المزدوج
    try {
      isLoading.value = true;
      await _repository.toggleProjectStatus(id, currentStatus);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تغيير حالة المشروع: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteProject(String id) async {
    if (isLoading.value) return; // 🛡️ حماية الضغط المزدوج
    if (!_connectivity.isOnline.value) {
      await _queue.enqueue(collection: AppConstants.projectsCollection, operation: 'delete', data: {}, docId: id);
      Get.snackbar('💾 تم الحفظ', 'سيتم حذف المشروع عند استعادة الاتصال',
          backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15),
          colorText: AppTheme.warningColor, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      isLoading.value = true;
      await _repository.deleteProject(id);
      Get.back(); // الخروج التلقائي عند الحذف
      Get.snackbar('🗑️ تم الحذف', 'تم حذف المشروع',
          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.15),
          colorText: AppTheme.errorColor);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل حذف المشروع: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> assignWorkerToProject(String projectId, String workerId) async {
    try {
      await _repository.assignWorkerToProject(projectId, workerId);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إسناد المتطوع: $e');
    }
  }

  Future<void> unassignWorkerFromProject(String projectId, String workerId) async {
    try {
      await _repository.unassignWorkerFromProject(projectId, workerId);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل إزالة المتطوع: $e');
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

لتحميل التطبيق: https://nas-al-khir-reggane.github.io/nas_alkhir_reggane/
    ''';
    await Share.share(text);
  }

  Future<void> shareProjectImage(ProjectModel project, Color color, String catName) async {
    final screenshotController = ScreenshotController();
    
    try {
      // توليد الصورة من ويدجت البطاقة الاحترافية (خارج الشجرة)
      final Uint8List imageBytes = await screenshotController.captureFromWidget(
        Material(
          color: Colors.transparent,
          child: Directionality(
            textDirection: ui.TextDirection.rtl,
            child: MediaQuery(
              data: const MediaQueryData(size: Size(400, 1000), devicePixelRatio: 1.0),
              child: ProjectShareCard(
                project: project,
                categoryColor: color,
                categoryName: catName,
              ),
            ),
          ),
        ),
        delay: const Duration(milliseconds: 100),
      );

      await _saveAndShareImage(imageBytes, 'project_${project.id}.png');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل توليد بطاقة المشاركة: $e');
    }
  }

  Future<void> _saveAndShareImage(Uint8List bytes, String fileName) async {
    final directory = await getTemporaryDirectory();
    final imagePath = await File('${directory.path}/$fileName').create();
    await imagePath.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(imagePath.path)],
      text: 'ساهم معنا في هذا المشروع الخيري 🌿 #ناس_الخير\n\nلتحميل التطبيق: https://nas-al-khir-reggane.github.io/nas_alkhir_reggane/',
    );
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

  int daysLeftNum(DateTime? deadline) {
    if (deadline == null) return 0;
    final now = DateTime.now();
    final difference = deadline.difference(now).inDays;
    return difference > 0 ? difference : 0;
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

