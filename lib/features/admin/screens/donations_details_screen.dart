import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart' as intl;
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/admin_controller.dart';
import '../../../core/animations/visual_effects.dart';

class DonationsDetailsScreen extends StatelessWidget {
  const DonationsDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminController controller = Get.find<AdminController>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: VisualEffects.ambientBackground(
        isDark: Get.isDarkMode,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildAppBar(),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTotalDonationsCard(controller),
                      const SizedBox(height: 24),
                      Text('إحصائيات التبرعات الدورية', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                      const SizedBox(height: 16),
                      _buildBeautifulChart(controller),
                      const SizedBox(height: 24),
                      Text('أحدث التبرعات', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              _buildDonationsList(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text('تفاصيل التبرعات', style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, size: 20, color: AppTheme.textPrimary),
        onPressed: () => Get.back(),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.filter_list, color: AppTheme.textPrimary),
          onPressed: () {
            Get.snackbar('قريباً', 'ميزة التصفية قيد التطوير');
          },
        ),
      ],
    );
  }

  Widget _buildTotalDonationsCard(AdminController controller) {
    final formatCurrency = intl.NumberFormat.currency(symbol: 'دج', decimalDigits: 0, customPattern: '#,##0 \u00A4');

    return FadeInDown(
      duration: const Duration(milliseconds: 600),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.goldGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.goldAccent.withValues(alpha: 0.75),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.volunteer_activism, color: Colors.white, size: 40),
            const SizedBox(height: 12),
            const Text('إجمالي التبرعات المجمعة', style: TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Tajawal')),
            const SizedBox(height: 8),
            Obx(() => Text(
                  formatCurrency.format(controller.totalDonations.value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBeautifulChart(AdminController controller) {
    return FadeInUp(
      duration: const Duration(milliseconds: 700),
      child: Container(
        height: 250,
        padding: const EdgeInsets.only(top: 24, bottom: 16, left: 16, right: 16),
        decoration: AppTheme.glassDecoration,
        child: Obx(() {
          if (controller.donationsLastSixMonths.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final maxAmount = controller.donationsLastSixMonths.map((e) => e['amount'] as double).reduce((a, b) => a > b ? a : b);
          // Get the actual upper bound visually (add 20% padding)
          final maxY = maxAmount == 0 ? 1000.0 : maxAmount * 1.2;

          return BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${rod.toY.toInt()} دج\n',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: controller.donationsLastSixMonths[group.x.toInt()]['month'],
                          style: TextStyle(
                            color: AppTheme.goldAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < controller.donationsLastSixMonths.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            controller.donationsLastSixMonths[value.toInt()]['month'],
                            style: TextStyle(color: AppTheme.textHint, fontSize: 10, fontFamily: 'Tajawal'),
                          ),
                        );
                      }
                      return const Text('');
                    },
                    reservedSize: 28,
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: controller.donationsLastSixMonths.asMap().entries.map((entry) {
                final int index = entry.key;
                final double amount = (entry.value['amount'] as num).toDouble();
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: amount,
                      gradient: AppTheme.goldGradient,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: AppTheme.cardColor.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDonationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .orderBy('date', descending: true)
          .limit(20) // Show last 20 for performance
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator())));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text('لا توجد تبرعات مسجلة حتى الآن', style: TextStyle(color: AppTheme.textHint, fontFamily: 'Tajawal')),
              ),
            ),
          );
        }

        final formatCurrency = intl.NumberFormat.currency(symbol: 'دج', decimalDigits: 0, customPattern: '#,##0 \u00A4');
        
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                
                final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                final donorName = data['donorName'] ?? 'متبرع';
                final isAnonymous = data['isAnonymous'] ?? false;
                final projectName = data['projectName'] ?? 'عام';
                
                final displayName = isAnonymous ? 'فاعل خير (مجهول)' : donorName;

                return FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  delay: Duration(milliseconds: 50 * index),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: AppTheme.glassDecoration,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.goldAccent.withValues(alpha: 0.75),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.volunteer_activism, color: AppTheme.goldAccent),
                      ),
                      title: Text(
                        displayName,
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Text('إلى: $projectName', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontFamily: 'Tajawal')),
                          SizedBox(height: 2),
                          Text(data['paymentMethod'] == 'bank' ? 'بنكي' : 'نقدي', style: TextStyle(color: AppTheme.textHint, fontSize: 10)),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          formatCurrency.format(amount),
                          style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: snapshot.data!.docs.length,
            ),
          ),
        );
      },
    );
  }
}

