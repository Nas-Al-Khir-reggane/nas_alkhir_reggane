import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/models/user_model.dart';
import '../../admin/controllers/admin_controller.dart';

class BloodDonorProfileScreen extends StatefulWidget {
  const BloodDonorProfileScreen({super.key});

  @override
  State<BloodDonorProfileScreen> createState() => _BloodDonorProfileScreenState();
}

class _BloodDonorProfileScreenState extends State<BloodDonorProfileScreen> {
  final AuthController authController = Get.find<AuthController>();
  final AdminController adminController = Get.find<AdminController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Obx(() {
        final user = authController.currentUser.value;
        if (user == null) return const Center(child: CircularProgressIndicator());

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(user),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 100),
                child: Column(
                  children: [
                    _buildHeroCard(user),
                    const SizedBox(height: 24),
                    _buildDonationStats(user),
                    const SizedBox(height: 24),
                    _buildRestPeriodCountdown(user),
                    const SizedBox(height: 24),
                    _buildSettingsSection(user),
                    const SizedBox(height: 24),
                    _buildHistorySection(user),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSliverAppBar(UserModel user) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.errorColor,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [AppTheme.errorColor, AppTheme.errorColor.withValues(alpha: 0.9)],
                ),
              ),
            ),
            Positioned(
              right: -50,
              top: -50,
              child: Icon(Icons.bloodtype, size: 250, color: Colors.white.withValues(alpha: 0.15)),
            ),
          ],
        ),
        title: Text(
          'الملف الطبي',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Get.back(),
      ),
    );
  }

  Widget _buildHeroCard(UserModel user) {
    final String rank = _getRankName(user.bloodDonationsCount);
    final Color rankColor = _getRankColor(user.bloodDonationsCount);

    return FadeInDown(
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [rankColor, rankColor.withValues(alpha: 0.9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: rankColor.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -20,
              left: -20,
              child: Icon(Icons.verified_user, size: 150, color: Colors.white.withValues(alpha: 0.15)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('هوية المتبرع الرقمية', 
                            style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(user.name, 
                            style: GoogleFonts.tajawal(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(user.bloodType ?? '??', 
                          style: GoogleFonts.tajawal(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.military_tech, color: AppTheme.goldAccent, size: 20),
                            const SizedBox(width: 6),
                            Text(rank, 
                              style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.qr_code_2, color: Colors.white54, size: 40),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationStats(UserModel user) {
    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: Row(
        children: [
          _buildStatItem('تبرعات الدم', user.bloodDonationsCount.toString(), Icons.volunteer_activism, Colors.redAccent),
          const SizedBox(width: 16),
          _buildStatItem('أرواح أُنقذت', (user.bloodDonationsCount).toString(), Icons.favorite_rounded, Colors.pinkAccent),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassDecoration,
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(value, 
              style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            Text(label, 
              style: GoogleFonts.tajawal(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildRestPeriodCountdown(UserModel user) {
    if (user.lastDonatedAt == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final difference = now.difference(user.lastDonatedAt!);
    final daysPassed = difference.inDays;
    final cooldownDays = user.smartDonationCoolOffDays;
    final progress = (daysPassed / cooldownDays).clamp(0.0, 1.0);
    final remaining = cooldownDays - daysPassed;

    return FadeInUp(
      delay: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassDecoration,
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: Colors.grey.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(remaining > 0 ? Colors.orange : Colors.green),
                      ),
                    ),
                    Text('${(progress * 100).toInt()}%', 
                      style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(remaining > 0 ? 'فترة الاستراحة الطبية' : 'جاهز للتبرع الآن', 
                        style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(remaining > 0 ? 'متبقي $remaining يوم لموعدك التالي' : 'جزاك الله خيراً على عطائك المستمر', 
                        style: GoogleFonts.tajawal(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(UserModel user) {
    return FadeInUp(
      delay: const Duration(milliseconds: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text('إعدادات التبرع', 
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          ),
          Container(
            decoration: AppTheme.glassDecoration,
            child: Column(
              children: [
                _buildToggleItem(
                  'استقبال تنبيهات الطوارئ', 
                  'ستصلك إشعارات فورية عند وجود حاجة لفصيلتك', 
                  user.receiveBloodAlerts,
                  (val) => adminController.updateUserDonorSettings(receiveAlerts: val),
                ),
                const Divider(height: 1, indent: 20, endIndent: 20),
                _buildToggleItem(
                  'جاهزية التبرع حالياً', 
                  'يمكنك تعطيلها مؤقتاً إذا كنت غير قادر على التبرع', 
                  user.isDonorAvailable,
                  (val) => adminController.updateUserDonorSettings(isAvailable: val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String title, String subtitle, bool value, Function(bool) onChanged) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      title: Text(title, style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: GoogleFonts.tajawal(fontSize: 11, color: AppTheme.textSecondary)),
      trailing: Switch.adaptive(
        value: value,
        activeThumbColor: AppTheme.errorColor,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildHistorySection(UserModel user) {
    return FadeInUp(
      delay: const Duration(milliseconds: 500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text('سجل الاستجابات الميدانية', 
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('service_requests')
                .where('type', whereIn: ['blood_donation', 'blood_emergency'])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyHistory();
              }

              // ✨ فلترة محلية: فقط الطلبات التي استجاب لها هذا المتبرع
              final filteredDocs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final List<dynamic> responses = data['donorResponses'] ?? [];
                return responses.any((r) => r['userId'] == user.id);
              }).toList();

              if (filteredDocs.isEmpty) {
                return _buildEmptyHistory();
              }

              return ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data = filteredDocs[index].data() as Map<String, dynamic>;
                  final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final hospitalName = data['details']?['المستشفى'] ?? data['details']?['hospital'] ?? 'مستشفى غير محدد';
                  final status = data['status'] ?? 'pending';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: AppTheme.glassDecoration,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (status == 'completed' ? Colors.green : Colors.orange).withValues(alpha: 0.15), 
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          status == 'completed' ? Icons.check_circle : Icons.hourglass_top,
                          color: status == 'completed' ? Colors.green : Colors.orange, 
                          size: 20,
                        ),
                      ),
                      title: Text(hospitalName, style: GoogleFonts.tajawal(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text(intl.DateFormat('yyyy/MM/dd').format(date), style: GoogleFonts.tajawal(fontSize: 11)),
                      trailing: Text(
                        status == 'completed' ? 'تم التبرع' : 'قيد المتابعة', 
                        style: GoogleFonts.tajawal(
                          color: status == 'completed' ? Colors.green : Colors.orange, 
                          fontSize: 10, fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: AppTheme.glassDecoration,
      child: Column(
        children: [
          Icon(Icons.history, color: AppTheme.textSecondary.withValues(alpha: 0.15), size: 40),
          const SizedBox(height: 12),
          Text('لا يوجد سجل استجابات بعد', style: GoogleFonts.tajawal(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  String _getRankName(int count) {
    if (count >= 15) return 'بطل بلاتيني 🏆';
    if (count >= 10) return 'بطل ذهبي 🥇';
    if (count >= 5) return 'بطل فضي 🥈';
    if (count >= 1) return 'بطل برونزي 🥉';
    return 'متطوع جديد 🌱';
  }

  Color _getRankColor(int count) {
    if (count >= 15) return const Color(0xFFE5E4E2); // Platinum
    if (count >= 10) return const Color(0xFFFFD700); // Gold
    if (count >= 5) return const Color(0xFFC0C0C0); // Silver
    if (count >= 1) return const Color(0xFFCD7F32); // Bronze
    return AppTheme.errorColor; // Default Red
  }
}

