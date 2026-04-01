import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';
import '../controllers/worker_management_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../chat/screens/chat_screen.dart'; // استيراد شاشة الدردشة
import 'package:cached_network_image/cached_network_image.dart';

class WorkersScreen extends StatelessWidget {
  const WorkersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(WorkerManagementController());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // AppBar مخصص
          _buildAppBar(context, controller),

          // إحصائات سريعة
          _buildQuickStats(context, controller),

          // شريط البحث
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: controller.searchController,
              decoration: AppTheme.inputDecoration('ابحث باسم المتطوع أو هاتفه...', Icons.search),
              style: TextStyle(color: AppTheme.textPrimary),
            ),
          ),

          // فلتر الأدوار - أفقي
          _buildRoleFilter(context, controller),

          const SizedBox(height: 8),

          // فلتر التوفر
          _buildAvailabilityFilter(context, controller),

          const SizedBox(height: 12),

          // قائمة العمال
          Expanded(
            child: Obx(() {
              if (controller.filteredWorkers.isEmpty) {
                return _buildEmptyState();
              }
              return RefreshIndicator(
                onRefresh: () async => controller.listenToWorkers(),
                color: AppTheme.primaryGreen,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: controller.filteredWorkers.length,
                  itemBuilder: (context, index) {
                    final worker = controller.filteredWorkers[index];
                    return FadeInUp(
                      delay: Duration(milliseconds: index * 60),
                      child: _buildWorkerCard(context, worker, controller),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, WorkerManagementController controller) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('👥 فريق العمل',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                          fontFamily: 'Tajawal')),
                  Obx(() => Text(
                      '${controller.totalWorkers} عضو | ${controller.availableWorkers} متاح',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
                ],
              ),
            ),
            // زر دردشة الفريق السرية
            GestureDetector(
              onTap: () => Get.to(() => const ChatScreen(isGroupChat: true)),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: const Icon(Icons.groups_rounded, color: AppTheme.primaryGreen, size: 22),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => showAddWorkerSheet(context),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.greenGlow,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: const Row(
                  children: [
                    Icon(Icons.person_add, color: Colors.black, size: 20),
                    SizedBox(width: 8),
                    Text('إضافة متطوع',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, WorkerManagementController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Obx(() => Row(
            children: [
              _buildTeamStat(context, 'المتاحون', controller.availableWorkers, AppTheme.successColor, Icons.check_circle_outline),
              const SizedBox(width: 8),
              _buildTeamStat(context, 'مشغولون', controller.busyWorkers, AppTheme.warningColor, Icons.work_outline),
              const SizedBox(width: 8),
              _buildTeamStat(context, 'السائقون', controller.fatalDrivers, const Color(0xFF4A148C), Icons.airport_shuttle),
              const SizedBox(width: 8),
              _buildTeamStat(context, 'الإجمالي', controller.totalWorkers, AppTheme.primaryGreen, Icons.group),
            ],
          )),
    );
  }

  Widget _buildTeamStat(BuildContext context, String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const Spacer(),
                Text(value.toString(),
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleFilter(BuildContext context, WorkerManagementController controller) {
    final roles = [{'id': 'all', 'name': 'الكل', 'icon': Icons.apps}, ...WorkerManagementController.workerRoles];
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: roles.length,
        itemBuilder: (context, index) {
          final role = roles[index];
          return Obx(() {
            final isSelected = controller.selectedRole.value == role['id'];
            return GestureDetector(
              onTap: () {
                controller.selectedRole.value = role['id'] as String;
                controller.filterWorkers();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.primaryGradient : null,
                  color: isSelected ? null : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? Colors.transparent : AppTheme.glassBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(role['icon'] as IconData,
                        size: 14, color: isSelected ? Colors.black : AppTheme.textHint),
                    const SizedBox(width: 6),
                    Text(role['name'] as String,
                        style: TextStyle(color: isSelected ? Colors.black : AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildAvailabilityFilter(BuildContext context, WorkerManagementController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ['all', 'available', 'busy'].map((s) {
          return Expanded(
            child: Obx(() {
              final isSelected = controller.selectedAvailability.value == s;
              Color activeColor = AppTheme.primaryGreen;
              if (s == 'available') activeColor = AppTheme.successColor;
              if (s == 'busy') activeColor = AppTheme.warningColor;

              return GestureDetector(
                onTap: () {
                  controller.selectedAvailability.value = s;
                  controller.filterWorkers();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor.withValues(alpha: 0.75) : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? activeColor : AppTheme.glassBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: s == 'available'
                              ? AppTheme.successColor
                              : s == 'busy'
                                  ? AppTheme.warningColor
                                  : AppTheme.textHint,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(s == 'all' ? 'الكل' : s == 'available' ? 'متاح' : 'مشغول',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: isSelected ? activeColor : AppTheme.textHint,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWorkerCard(BuildContext context, UserModel worker, WorkerManagementController controller) {
    final roleData = WorkerManagementController.workerRoles.firstWhere(
      (r) => r['id'] == worker.workerRole,
      orElse: () => {'name': 'غير محدد', 'icon': Icons.person, 'color': Colors.grey},
    );
    final roleName = roleData['name'] as String;
    final roleIcon = roleData['icon'] as IconData;
    final roleColor = roleData['color'] as Color;

    return GestureDetector(
      onTap: () => Get.toNamed('/admin/worker-detail', arguments: worker),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(
              color: worker.isAvailable ? AppTheme.glassBorder : AppTheme.warningColor.withValues(alpha: 0.75)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الأفاتار مع مؤشر التوفر
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: roleColor.withValues(alpha: 0.15),
                    backgroundImage: (worker.profileImage != null && worker.profileImage!.isNotEmpty)
                        ? CachedNetworkImageProvider(worker.profileImage!) as ImageProvider
                        : null,
                    child: (worker.profileImage == null || worker.profileImage!.isEmpty)
                        ? Text(worker.name.isNotEmpty ? worker.name.substring(0, 1) : '?',
                            style: TextStyle(color: roleColor, fontSize: 22, fontWeight: FontWeight.w700))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: worker.isAvailable ? AppTheme.successColor : AppTheme.warningColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).cardColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(worker.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 2),
                            Text(worker.rating.toStringAsFixed(1),
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(roleIcon, color: roleColor, size: 12),
                          const SizedBox(width: 4),
                          Text(roleName,
                              style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: AppTheme.textHint, size: 14),
                        const SizedBox(width: 4),
                        Expanded(child: Text(worker.wilaya, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, color: AppTheme.textHint, size: 14),
                        const SizedBox(width: 4),
                        Text(worker.lastActivity != null ? timeago.format(worker.lastActivity!, locale: 'ar') : 'غير نشط',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildWorkerMiniStat('✅', worker.completedTasks.toString(), 'منجز'),
                        const SizedBox(width: 12),
                        _buildWorkerMiniStat('⏳', worker.currentTasksCount.toString(), 'حالي'),
                        if (worker.workerRole == 'funeral_driver') ...[
                          const SizedBox(width: 12),
                          _buildWorkerMiniStat('🚗', worker.totalTrips.toString(), 'رحلة'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildWorkerAction(Icons.phone, 'اتصال', AppTheme.successColor, () async {
                          final url = 'tel:${worker.phone}';
                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(Uri.parse(url));
                          }
                        }),
                        const SizedBox(width: 8),
                        _buildWorkerAction(Icons.chat_bubble_outline, 'دردشة', AppTheme.primaryGreen, () {
                          Get.toNamed(AppRoutes.chatPrivate, arguments: {'userId': worker.id, 'userName': worker.name});
                        }),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildWorkerAction(Icons.assignment_ind, 'إسناد', AppTheme.warningColor,
                              () => _showAssignTaskSheet(context, worker)),
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: AppTheme.textHint, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Theme.of(context).colorScheme.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Icon(Icons.edit, color: AppTheme.primaryGreen, size: 18),
                                  Text(' تعديل')
                                ])),
                            PopupMenuItem(
                                value: 'toggle_avail',
                                child: Row(children: [
                                  Icon(worker.isAvailable ? Icons.do_not_disturb : Icons.check_circle,
                                      color: AppTheme.warningColor, size: 18),
                                  Text(worker.isAvailable ? ' تعيين مشغول' : ' تعيين متاح')
                                ])),
                            const PopupMenuItem(
                                value: 'rate',
                                child: Row(children: [
                                  Icon(Icons.star_outline, color: Colors.amber, size: 18),
                                  Text(' تقييم')
                                ])),
                            PopupMenuItem(
                                value: 'disable',
                                child: Row(children: [
                                  Icon(Icons.block, color: AppTheme.errorColor, size: 18),
                                  Text(' تعطيل', style: TextStyle(color: AppTheme.errorColor))
                                ])),
                          ],
                          onSelected: (val) {
                            if (val == 'toggle_avail') {
                              controller.toggleAvailability(worker.id, worker.isAvailable);
                            } else if (val == 'disable') {
                              controller.toggleWorkerStatus(worker.id, worker.isActive);
                            } else if (val == 'rate') {
                              _showRateWorkerDialog(context, worker, controller);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkerAction(IconData icon, String label, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerMiniStat(String emoji, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 3),
        Text(value, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(color: AppTheme.textHint, fontSize: 9)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: AppTheme.textHint.withValues(alpha: 0.75)),
          const SizedBox(height: 16),
          Text('لا يوجد عمال مطابقين للبحث', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }

  static void showAddWorkerSheet(BuildContext context) {
    final controller = Get.isRegistered<WorkerManagementController>()
        ? Get.find<WorkerManagementController>()
        : Get.put(WorkerManagementController());
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final notesController = TextEditingController();
    String? selectedWilaya;
    RxString selectedWorkerRole = ''.obs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('إضافة متطوع جديد',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Get.back()),
                  ],
                ),
                const SizedBox(height: 20),
                _buildLabel('الاسم الكامل *'),
                TextField(
                    controller: nameController,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: AppTheme.inputDecoration('الاسم الكامل', Icons.person_outline)),
                const SizedBox(height: 16),
                _buildLabel('رقم الهاتف *'),
                TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: AppTheme.inputDecoration('0XXXXXXXXX', Icons.phone_outlined)),
                const SizedBox(height: 16),
                _buildLabel('الولاية *'),
                DropdownButtonFormField<String>(
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: AppTheme.inputDecoration('اختر الولاية', Icons.location_on_outlined),
                  items: AppConstants.algeriaWilayas
                      .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                      .toList(),
                  onChanged: (v) => selectedWilaya = v,
                ),
                const SizedBox(height: 16),
                _buildLabel('الدور *'),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.1,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: WorkerManagementController.workerRoles.map((role) {
                    return Obx(() {
                      final isSelected = selectedWorkerRole.value == role['id'];
                      final color = role['color'] as Color;
                      return GestureDetector(
                        onTap: () => selectedWorkerRole.value = role['id'] as String,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.75) : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: isSelected ? color : AppTheme.glassBorder, width: isSelected ? 2 : 1),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(role['icon'] as IconData,
                                  color: isSelected ? color : AppTheme.textHint, size: 22),
                              const SizedBox(height: 6),
                              Text(role['name'] as String,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  style: TextStyle(
                                      color: isSelected ? color : AppTheme.textSecondary,
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            ],
                          ),
                        ),
                      );
                    });
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildLabel('البريد الإلكتروني *'),
                TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: AppTheme.inputDecoration('email@example.com', Icons.email_outlined)),
                const SizedBox(height: 16),
                _buildLabel('كلمة المرور *'),
                TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: AppTheme.inputDecoration('6 أحرف على الأقل', Icons.lock_outline)),
                const SizedBox(height: 16),
                _buildLabel('ملاحظات'),
                TextField(
                    controller: notesController,
                    maxLines: 2,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: AppTheme.inputDecoration('ملاحظات إضافية...', Icons.notes)),
                const SizedBox(height: 24),
                Obx(() => controller.isLoading.value
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                    : AppTheme.gradientButton(
                        text: 'إضافة المتطوع',
                        icon: Icons.person_add,
                        onPressed: () {
                          if (nameController.text.isEmpty ||
                              phoneController.text.isEmpty ||
                              selectedWilaya == null ||
                              selectedWorkerRole.isEmpty ||
                              emailController.text.isEmpty ||
                              passwordController.text.isEmpty) {
                            Get.snackbar('تنبيه', 'يرجى ملء جميع الحقول المطلوبة',
                                backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15));
                            return;
                          }
                          controller.addWorker({
                            'name': nameController.text,
                            'phone': phoneController.text,
                            'wilaya': selectedWilaya,
                            'workerRole': selectedWorkerRole.value,
                            'email': emailController.text,
                            'password': passwordController.text,
                            'notes': notesController.text,
                            'address': '', // Default empty address
                          });
                        },
                      )),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
    );
  }

  void _showAssignTaskSheet(BuildContext context, UserModel worker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إسناد مهمة لـ ${worker.name}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 16),
              Text('اختر الطلب المعلق', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('service_requests')
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('لا توجد طلبات معلقة', style: TextStyle(color: AppTheme.textHint)));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final request = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        final requestId = snapshot.data!.docs[index].id;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.volunteer_activism, color: AppTheme.primaryGreen, size: 20),
                          ),
                          title: Text(AppConstants.translateServiceType(request['serviceName'] ?? request['type'] ?? 'طلب خدمة'),
                              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                          subtitle: Text('${request['requesterName'] ?? ''} - ${request['wilaya'] ?? ''}',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          trailing: AppTheme.statusBadge(request['urgency'] ?? 'normal'),
                          onTap: () async {
                            await FirebaseFirestore.instance.collection('service_requests').doc(requestId).update({
                              'assignedTo': worker.id,
                              'assignedToName': worker.name,
                              'status': 'in_progress',
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            await FirebaseFirestore.instance.collection('users').doc(worker.id).update({
                              'isAvailable': false,
                              'currentTasksCount': FieldValue.increment(1),
                            });
                            Get.back();
                            Get.snackbar('✅ تم الإسناد', 'تم إسناد المهمة لـ ${worker.name}');
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRateWorkerDialog(BuildContext context, UserModel worker, WorkerManagementController controller) {
    double selectedRating = 5.0;
    Get.dialog(
      StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('تقييم ${worker.name}', style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('اختر التقييم المناسب لأداء المتطوع', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 20),
              _buildRatingStars(selectedRating, (rating) => setDialogState(() => selectedRating = rating)),
              const SizedBox(height: 12),
              Text(
                selectedRating >= 5 ? 'ممتاز' : selectedRating >= 4 ? 'جيد جداً' : selectedRating >= 3 ? 'جيد' : 'مقبول',
                style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
            AppTheme.gradientButton(
              text: 'حفظ',
              onPressed: () => controller.rateWorker(worker.id, selectedRating),
            ),
          ],
        );
      }),
    );
  }

  static Widget _buildRatingStars(double currentRating, Function(double) onRatingChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final star = index + 1;
        return GestureDetector(
          onTap: () => onRatingChanged(star.toDouble()),
          child: Icon(
            star <= currentRating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 36,
          ),
        );
      }),
    );
  }
}

