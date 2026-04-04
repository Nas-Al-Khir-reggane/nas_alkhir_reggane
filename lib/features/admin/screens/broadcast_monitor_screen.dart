import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/animations/scroll_animations.dart';
import '../../../data/models/broadcast_model.dart';
import '../../../data/models/user_model.dart';
import '../controllers/admin_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BroadcastMonitorScreen extends StatefulWidget {
  const BroadcastMonitorScreen({super.key});

  @override
  State<BroadcastMonitorScreen> createState() => _BroadcastMonitorScreenState();
}

class _BroadcastMonitorScreenState extends State<BroadcastMonitorScreen> {
  final AdminController controller = Get.find<AdminController>();
  String? _selectedRoleFilter; // null means All

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('رادار المتابعة الحية', 
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.activeBroadcasts.isEmpty) {
          return _buildEmptyState();
        }

        final broadcast = controller.activeBroadcasts.first;

        return Column(
          children: [
            _buildMainCounter(broadcast),
            _buildFilters(),
            Expanded(
              child: _buildViewersList(broadcast),
            ),
            _buildActions(broadcast),
          ],
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar_rounded, size: 80, 
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('لا يوجد نداء نشط حالياً',
            style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildMainCounter(BroadcastModel broadcast) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text('إجمالي المتفاعلين الآن', 
            style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          ScrollAnimations.numberCounter(
            value: broadcast.viewCount,
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(broadcast.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final filters = [
      {'label': 'الكل', 'value': null},
      {'label': 'متطوعين', 'value': 'worker'},
      {'label': 'متبرعين', 'value': 'donor'},
      {'label': 'مستفيدين', 'value': 'beneficiary'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedRoleFilter == f['value'];
          return Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: FilterChip(
              label: Text(f['label'] as String),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  _selectedRoleFilter = f['value'];
                });
              },
              selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              checkmarkColor: Theme.of(context).colorScheme.primary,
              labelStyle: GoogleFonts.tajawal(
                color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildViewersList(BroadcastModel broadcast) {
    if (broadcast.viewedByUserIds.isEmpty) {
      return Center(
        child: Text('لم يتفاعل أحد بعد', 
          style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }

    // بناء استعلام المستخدمين
    Query query = FirebaseFirestore.instance.collection('users');
    
    // فلترة حسب الرتبة إذا تم اختيارها
    if (_selectedRoleFilter != null) {
      query = query.where('role', isEqualTo: _selectedRoleFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        // فلترة المستخدمين الذين هم في قائمة ViewedByUserIds
        final viewers = snapshot.data!.docs.where((doc) {
          return broadcast.viewedByUserIds.contains(doc.id);
        }).toList();

        if (viewers.isEmpty) {
          return Center(
            child: Text('لا يوجد متفاعلون في هذه الفئة', 
              style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: viewers.length,
          itemBuilder: (context, index) {
            final userDoc = viewers[index];
            final userData = userDoc.data() as Map<String, dynamic>;
            final user = UserModel.fromMap(userData, userDoc.id);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
                      ? CachedNetworkImageProvider(user.profileImage!)
                      : null,
                  child: user.profileImage == null || user.profileImage!.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(user.name, style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
                subtitle: Text(_getRoleLabel(user.role), 
                  style: GoogleFonts.tajawal(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
                trailing: const Icon(Icons.check_circle, color: Colors.green, size: 20),
              ),
            );
          },
        );
      },
    );
  }

  String _getRoleLabel(UserRole? role) {
    switch (role) {
      case UserRole.worker: return 'متطوع';
      case UserRole.donor: return 'متبرع';
      case UserRole.beneficiary: return 'مستفيد';
      case UserRole.admin: return 'مدير';
      case UserRole.superAdmin: return 'مدير عام';
      default: return 'مستخدم';
    }
  }

  Widget _buildActions(BroadcastModel broadcast) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _confirmDelete(broadcast.id),
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: Text('حذف الإعلان والبيانات', 
                style: GoogleFonts.tajawal(color: Colors.red, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    Get.dialog(
      AlertDialog(
        title: Text('تأكيد الحذف', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
        content: Text('سيتم مسح هذا الإعلان وكافة إحصائيات المشاهدة نهائياً. هل أنت متأكد؟',
          style: GoogleFonts.tajawal()),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              controller.deleteBroadcast(id);
              Get.back();
              Get.back(); // العودة للخلف بعد الحذف
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('حذف نهائي', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
