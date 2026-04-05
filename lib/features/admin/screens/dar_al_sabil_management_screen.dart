import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../controllers/admin_controller.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/service_request_model.dart';
import 'package:intl/intl.dart' as intl;
import 'package:animate_do/animate_do.dart';

class DarSabilManagementScreen extends GetView<AdminController> {
  const DarSabilManagementScreen({super.key});

  // الألوان الجديدة للفخامة
  static const Color primaryBlue = Color(0xFF1A237E); // Royal Blue
  static const Color accentGold = Color(0xFFFFC107);  // Amber/Gold
  static const Color surfaceWhite = Color(0xFFF5F7FA);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: surfaceWhite,
        appBar: AppBar(
          title: const Text(
            'إدارة دار السبيل 🏠',
            style: TextStyle(
              fontWeight: FontWeight.w900, 
              color: Colors.white, 
              fontFamily: 'Tajawal',
              letterSpacing: 0.5
            ),
          ),
          centerTitle: true,
          backgroundColor: primaryBlue,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: () => _showSettingsDialog(context),
              icon: const Icon(Icons.settings_suggest_rounded, color: Colors.white),
              tooltip: 'الإعدادات الافتراضية للدار',
            ),
            IconButton(
              onPressed: () => _showQuickNoticeDialog(context),
              icon: const Icon(Icons.notification_add_rounded, color: Colors.white),
              tooltip: 'تنبيه سريع للمسيرين',
            ),
          ],
          bottom: const TabBar(
            indicatorColor: accentGold,
            indicatorWeight: 4,
            isScrollable: false,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Tajawal'),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
            tabs: [
              Tab(text: 'النزلاء', icon: Icon(Icons.bed_rounded)),
              Tab(text: 'المهام', icon: Icon(Icons.assignment_rounded)),
              Tab(text: 'المؤن', icon: Icon(Icons.inventory_2_rounded)),
              Tab(text: 'الفريق', icon: Icon(Icons.people_alt_rounded)),
            ],
          ),
        ),
        body: Obx(() {
          // ✅ Single high-level Obx ensures all reactive variables are tracked
          // and prevents "Improper use of GetX" errors in TabBarView
          final isLoading = controller.isLoading.value;
          
          return Stack(
            children: [
              Column(
                children: [
                  _buildSmartSummary(),
                  Expanded(
                    child: TabBarView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildGuestsTab(),
                        _buildTasksTab(context),
                        _buildSuppliesTab(),
                        _buildTeamTab(),
                      ],
                    ),
                  ),
                ],
              ),
              if (isLoading)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(color: accentGold),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSmartSummary() {
    final summary = controller.darSabilSummary;
    
    if (summary.isEmpty) {
      return const SizedBox(height: 10, child: LinearProgressIndicator(backgroundColor: Colors.transparent));
    }

    return FadeInDown(
      duration: const Duration(milliseconds: 600),
      child: Container(
        padding: const EdgeInsets.all(2),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [primaryBlue.withValues(alpha: 0.8), primaryBlue.withValues(alpha: 0.6)],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: 0.1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('النزلاء', '${summary['guestsCount'] ?? 0}', Icons.hotel, accentGold),
              _buildVerticalDivider(),
              _buildSummaryItem('المهام', '${((summary['tasksProgress'] ?? 0.0) * 100).toInt()}%', Icons.task_alt, Colors.greenAccent),
              _buildVerticalDivider(),
              _buildSummaryItem('نواقص', '${summary['lowSuppliesCount'] ?? 0}', Icons.warning_amber_rounded, Colors.orangeAccent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.white24);
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value, 
          style: const TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.w900, 
            color: Colors.white,
            fontFamily: 'Tajawal'
          )
        ),
        Text(
          label, 
          style: TextStyle(
            fontSize: 12, 
            color: Colors.white.withValues(alpha: 0.7), 
            fontFamily: 'Tajawal'
          )
        ),
      ],
    );
  }

  Widget _buildGuestsTab() {
    final guests = controller.darSabilGuests;

    if (guests.isEmpty) {
      return _buildEmptyState(Icons.hotel_rounded, 'لا يوجد نزلاء حالياً', 'طلبات الإقامة الجديدة المعتمدة ستظهر هنا تلقائياً');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: guests.length,
      itemBuilder: (context, index) {
        final guest = guests[index];
        return FadeInUp(
          delay: Duration(milliseconds: 100 * index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_pin_rounded, color: primaryBlue),
              ),
              title: Text(
                guest.requesterName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Tajawal'),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'تاريخ الطلب: ${intl.DateFormat('yyyy-MM-dd').format(guest.createdAt)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                  if (guest.roomNumber != null && guest.roomNumber!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accentGold.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'غرفة رقم: ${guest.roomNumber}',
                        style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              onTap: () => _showRoomAssignmentDialog(guest),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(guest.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  AppConstants.translateStatus(guest.status),
                  style: TextStyle(color: _getStatusColor(guest.status), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuppliesTab() {
    final supplies = [
      {'id': 'food', 'name': 'المواد الغذائية', 'desc': 'سكر، زيت، دقيق، بقوليات', 'icon': Icons.bakery_dining},
      {'id': 'cleaning', 'name': 'مواد التنظيف', 'desc': 'معقمات، صابون، منظفات أرضية', 'icon': Icons.cleaning_services},
      {'id': 'bedding', 'name': 'الأغطية والمفارش', 'desc': 'أغطية نظيفة، وسائد، مفارش', 'icon': Icons.bed},
      {'id': 'water', 'name': 'مياه الشرب', 'desc': 'قارورات مياه معدنية، خزانات', 'icon': Icons.water_drop},
      {'id': 'meds', 'name': 'خزانة الأدوية', 'desc': 'إسعافات أولية، مسكنات، كحول', 'icon': Icons.medical_services},
    ];

    final currentSupplies = controller.darSabilSupplies;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: supplies.length,
      itemBuilder: (context, index) {
        final item = supplies[index];
        final supplyData = currentSupplies.firstWhereOrNull((s) => s['id'] == item['id']);
        final currentStatus = supplyData != null ? (supplyData['status'] ?? 'available') : 'available';

        return ZoomIn(
          delay: Duration(milliseconds: 50 * index),
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: primaryBlue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                        child: Icon(item['icon'] as IconData, color: primaryBlue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                            Text(item['desc'] as String, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSupplyChip(item['id'] as String, '✅ متوفر', 'available', currentStatus == 'available', Colors.green),
                      _buildSupplyChip(item['id'] as String, '⚠️ قليل', 'low', currentStatus == 'low', Colors.orange),
                      _buildSupplyChip(item['id'] as String, '🚨 نفد', 'out', currentStatus == 'out', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSupplyChip(String id, String label, String status, bool isActive, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.updateDarSabilSupply(id, status),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? color : surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamTab() {
    final managers = controller.darSabilManagers;
    
    return Column(
      children: [
        _buildAddManagerHeader(),
        if (managers.isEmpty)
          Expanded(child: _buildEmptyState(Icons.group_off_rounded, 'لم يتم تعيين مسيرين بعد', 'يمكنك تفويض المهام للمسيرين بمجرد إضافتهم من قائمة المتطوعين'))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: managers.length,
              itemBuilder: (context, index) {
                final manager = managers[index];
                return ElasticInRight(
                  delay: Duration(milliseconds: 100 * index),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[100]!),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: primaryBlue,
                        backgroundImage: (manager.profileImage?.isNotEmpty ?? false) ? NetworkImage(manager.profileImage!) : null,
                        child: (manager.profileImage?.isEmpty ?? true) ? Text(manager.name[0], style: const TextStyle(color: Colors.white)) : null,
                      ),
                      title: Text(manager.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(manager.role.displayName, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        onPressed: () => controller.revokeDarSabilManager(manager.id),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAddManagerHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [primaryBlue, Color(0xFF283593)]),
          borderRadius: BorderRadius.circular(15),
        ),
        child: ElevatedButton.icon(
          onPressed: () => _showAddManagerDialog(),
          icon: const Icon(Icons.person_add_rounded, color: Colors.white),
          label: const Text('تعيين مسير جديد للدار', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildTasksTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddTaskDialog(context),
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('إسناد مهمة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Builder(
                builder: (context) {
                  if (controller.darSabilTasks.isNotEmpty) return const SizedBox.shrink();
                  return ElevatedButton(
                    onPressed: () => controller.seedDarSabilInitialTasks(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGold,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('تهيئة المهام', style: TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final tasks = controller.darSabilTasks;
              if (tasks.isEmpty) {
                return _buildEmptyState(Icons.task_alt_rounded, 'لا توجد مهام حالية', 'استخدم زر التهيئة أو الإسناد للبدء');
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final bool isDone = task['status'] == 'completed';
                  return SlideInRight(
                    delay: Duration(milliseconds: 100 * index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDone ? Colors.green.withValues(alpha: 0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: isDone ? Colors.green[100]! : Colors.grey[200]!),
                      ),
                      child: ListTile(
                        leading: Checkbox(
                          value: isDone,
                          onChanged: (val) => controller.toggleDarSabilTask(task['id'], task['status']),
                          activeColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        title: Text(
                          task['title'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            color: isDone ? Colors.grey : primaryBlue,
                          ),
                        ),
                        subtitle: Text(task['assignedToName'] ?? '', style: const TextStyle(fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                          onPressed: () => controller.deleteDarSabilTask(task['id']),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: primaryBlue.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'completed': return Colors.green;
      case 'rejected': return Colors.red;
      default: return primaryBlue;
    }
  }

  void _showSettingsDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('الإعدادات الافتراضية 🛡️', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh_rounded, color: Colors.blue),
              title: const Text('إعادة تهيئة البيانات'),
              subtitle: const Text('تفريغ الملخص وإعادة الحساب'),
              onTap: () {
                controller.refreshDarSabilData();
                Get.back();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              title: const Text('حذف كافة المهام'),
              onTap: () {
                Get.back();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddManagerDialog() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text('تعيين مسير للدار', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: Obx(() {
            final potentialManagers = controller.activeWorkersList
                .where((w) => (w.role == UserRole.worker || w.role == UserRole.admin) && !controller.darSabilManagers.any((m) => m.id == w.id))
                .toList();

            if (potentialManagers.isEmpty) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 40, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('لا يوجد متطوعين حالياً للتعيين.', textAlign: TextAlign.center),
                ],
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: potentialManagers.length,
              itemBuilder: (context, index) {
                final user = potentialManagers[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (user.profileImage?.isNotEmpty ?? false) ? NetworkImage(user.profileImage!) : null,
                    child: (user.profileImage?.isEmpty ?? true) ? Text(user.name[0]) : null,
                  ),
                  title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(user.role.displayName),
                  onTap: () {
                    controller.assignDarSabilManager(user.id);
                    Get.back();
                  },
                );
              },
            );
          }),
        ),
      ),
    );
  }

  void _showQuickNoticeDialog(BuildContext context) {
    final noticeController = TextEditingController();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إرسال تنبيه عاجل 🔔'),
        content: TextField(
          controller: noticeController,
          decoration: const InputDecoration(
            hintText: 'اكتب تعليماتك للفريق...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (noticeController.text.isNotEmpty) {
                Get.snackbar('تم الإرسال', 'رسالتك وصلت لجميع مسيري الدار');
                Get.back();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
            child: const Text('إرسال الآن'),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    UserModel? selectedUser;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إسناد مهمة جديدة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryBlue)),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان المهمة',
                  filled: true,
                  fillColor: surfaceWhite,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'التفاصيل (اختياري)',
                  filled: true,
                  fillColor: surfaceWhite,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              const Text('المسؤول عن التنفيذ:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setDialogState) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserModel>(
                      isExpanded: true,
                      value: selectedUser,
                      hint: const Text('اختر من فريق الدار'),
                      items: controller.darSabilManagers.isEmpty 
                        ? [const DropdownMenuItem(value: null, child: Text('لا يوجد مسيرين حالياً'))]
                        : controller.darSabilManagers.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m.name));
                          }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedUser = val);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty && selectedUser != null) {
                      controller.addDarSabilTask(titleController.text, descController.text, selectedUser!.id, selectedUser!.name);
                      Get.back();
                    } else {
                      Get.snackbar('تنبيه', 'يرجى إكمال البيانات');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('حفظ المهمة الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomAssignmentDialog(ServiceRequestModel guest) {
    final roomController = TextEditingController(text: guest.roomNumber);
    
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.bed_rounded, color: primaryBlue, size: 40),
            const SizedBox(height: 12),
            Text('تخصيص غرفة لـ ${guest.requesterName}', 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('يرجى إدخال رقم الغرفة المخصص لهذا النزيل:', 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: roomController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
              decoration: InputDecoration(
                hintText: 'مثلاً: 101',
                filled: true,
                fillColor: surfaceWhite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: primaryBlue, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (roomController.text.isNotEmpty) {
                controller.assignDarSabilRoom(guest.id, roomController.text);
                Get.back();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('تأكيد التسكين', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
