import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/theme/app_theme.dart';
import '../controllers/admin_controller.dart';

class HizbManagementScreen extends StatefulWidget {
  const HizbManagementScreen({super.key});

  @override
  State<HizbManagementScreen> createState() => _HizbManagementScreenState();
}

class _HizbManagementScreenState extends State<HizbManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminController controller = Get.find<AdminController>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    controller.listenToHizbMembers();
    controller.fetchHizbAlertsHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('إدارة حزب المائة ألف', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'المشتركون', icon: Icon(Icons.people_alt_rounded)),
            Tab(text: 'سجل النداءات', icon: Icon(Icons.history_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMembersTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => controller.showHizbAlertDialog(context),
        label: Text('إرسال نداء جديد', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.campaign_rounded),
        backgroundColor: AppTheme.goldAccent,
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildMembersTab() {
    return Obx(() {
      if (controller.hizbMembers.isEmpty) {
        return const Center(child: Text('لا يوجد مشتركون حالياً'));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: controller.hizbMembers.length,
        itemBuilder: (context, index) {
          final user = controller.hizbMembers[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.goldAccent.withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: AppTheme.goldAccent),
              ),
              title: Text(user.name, style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
              subtitle: Text(user.phone, style: GoogleFonts.tajawal(fontSize: 12)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'نشط',
                  style: GoogleFonts.tajawal(color: AppTheme.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildHistoryTab() {
    return Obx(() {
      if (controller.hizbAlertsHistory.isEmpty) {
        return const Center(child: Text('لا يوجد سجل للنداءات حالياً'));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: controller.hizbAlertsHistory.length,
        itemBuilder: (context, index) {
          final alert = controller.hizbAlertsHistory[index];
          final date = alert['timestamp'] != null 
              ? (alert['timestamp'] as dynamic).toDate() 
              : DateTime.now();
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          alert['title'] ?? 'بدون عنوان',
                          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        intl.DateFormat('yyyy/MM/dd HH:mm').format(date),
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        onPressed: () {
                          Get.dialog(
                            AlertDialog(
                              title: const Text('تأكيد الحذف'),
                              content: const Text('هل أنت متأكد أنك تريد حذف هذا النداء من السجل نهائياً؟'),
                              actions: [
                                TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
                                TextButton(
                                  onPressed: () {
                                    Get.back(); // إغلاق الحوار
                                    controller.deleteHizbAlert(alert['id']);
                                  }, 
                                  child: const Text('حذف', style: TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    alert['body'] ?? '',
                    style: GoogleFonts.tajawal(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildSmallInfoCard(Icons.people, '${alert['recipientsCount'] ?? 0} مستلم'),
                      const SizedBox(width: 8),
                      if (alert['requestId'] != null && alert['requestId'].toString().isNotEmpty)
                        _buildSmallInfoCard(Icons.link, 'مرتبط بطلب'),
                      if (alert['projectId'] != null && alert['projectId'].toString().isNotEmpty)
                        _buildSmallInfoCard(Icons.folder, 'مرتبط بمشروع'),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildSmallInfoCard(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.goldAccent),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }
}
