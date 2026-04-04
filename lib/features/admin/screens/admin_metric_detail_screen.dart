import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/admin_controller.dart';

class AdminMetricDetailScreen extends StatefulWidget {
  final MetricType type;
  final String title;
  final Color color;

  const AdminMetricDetailScreen({
    super.key,
    required this.type,
    required this.title,
    required this.color,
  });

  @override
  State<AdminMetricDetailScreen> createState() => _AdminMetricDetailScreenState();
}

class _AdminMetricDetailScreenState extends State<AdminMetricDetailScreen> {
  final controller = Get.find<AdminController>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    controller.loadChartDataForMetric(widget.type, controller.selectedPeriod.value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 0. اختيار الفترة
            _buildPeriodSelector(),

            // 1. القسم العلوي: الرسم البياني
            _buildChartSection(context),
            
            const SizedBox(height: 24),
            
            // 2. القسم السفلي: القائمة التفصيلية
            _buildDetailedList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Obx(() => Row(
        children: [
          _buildPeriodBtn('weekly', 'أسبوعي'),
          _buildPeriodBtn('monthly', 'شهري'),
          _buildPeriodBtn('yearly', 'سنوي'),
        ],
      )),
    );
  }

  Widget _buildPeriodBtn(String period, String label) {
    final isSelected = controller.selectedPeriod.value == period;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.loadChartDataForMetric(widget.type, period),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? widget.color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [BoxShadow(color: widget.color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Tajawal',
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      height: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.color.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: widget.color.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Obx(() {
                String periodName = 'الأسبوعي';
                if (controller.selectedPeriod.value == 'monthly') periodName = 'الشهري';
                if (controller.selectedPeriod.value == 'yearly') periodName = 'السنوي';
                return Text('تحليل الأداء $periodName', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', color: widget.color));
              }),
              Icon(Icons.show_chart_rounded, color: AppTheme.textSecondary, size: 20),
            ],
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Obx(() {
              if (controller.chartData.isEmpty) {
                return Center(child: CircularProgressIndicator(color: widget.color));
              }
              return LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[100]!, strokeWidth: 1)),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < controller.chartLabels.length) {
                            // إظهار بعض العناوين فقط إذا كان العدد كبيراً (مثل الشهري)
                            if (controller.selectedPeriod.value == 'monthly' && value.toInt() % 5 != 0) return const Text('');
                            return Text(controller.chartLabels[value.toInt()], 
                              style: TextStyle(fontSize: 9, color: AppTheme.textSecondary, fontFamily: 'Tajawal'));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(controller.chartData.length, (i) => FlSpot(i.toDouble(), controller.chartData[i])),
                      isCurved: true,
                      color: widget.color,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [widget.color.withValues(alpha: 0.2), widget.color.withValues(alpha: 0.0)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }



  Widget _buildDetailedList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 8, bottom: 12),
            child: Text('السجلات التفصيلية الأخيرة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Tajawal')),
          ),
          Obx(() {
            switch (widget.type) {
              case MetricType.donations:
                return _buildDonationsList(controller.recentDonations);
              case MetricType.requests:
                return _buildRequestsList(controller.recentRequests);
              case MetricType.projects:
                return _buildProjectsList(controller.activeProjectsList);
              case MetricType.team:
                return _buildTeamActivitySection();
            }
          }),
        ],
      ),
    );
  }

  Widget _buildProjectsList(List projects) {
    if (projects.isEmpty) return _buildEmptyState('لا توجد مشاريع نشطة حالياً');
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final p = projects[index];
        return FadeInRight(
          delay: Duration(milliseconds: index * 50),
          child: _buildListItem(
            title: p.name,
            subtitle: 'تم جمع ${p.collected.toInt()} من ${p.budget.toInt()} دج',
            trailing: '${((p.collected / p.budget) * 100).toInt()}%',
            icon: Icons.volunteer_activism_rounded,
            iconColor: Colors.orange,
          ),
        );
      },
    );
  }

  Widget _buildTeamActivitySection() {
    return Column(
      children: [
        // ملخص الفريق
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('المتطوعين', controller.availableWorkers.value.toString()),
              _buildStatItem('التحديثات الميدانية', controller.fieldUpdates.length.toString()),
            ],
          ),
        ),

        // قائمة التحديثات
        if (controller.fieldUpdates.isEmpty) 
          _buildEmptyState('لا توجد تحديثات ميدانية ألكخيرة')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controller.fieldUpdates.length,
            itemBuilder: (context, index) {
              final update = controller.fieldUpdates[index];
              return FadeInRight(
                delay: Duration(milliseconds: index * 50),
                child: _buildListItem(
                  title: update.workerName,
                  subtitle: update.description,
                  trailing: 'منذ قليل',
                  icon: Icons.engineering_rounded,
                  iconColor: widget.color,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.color, fontFamily: 'Tajawal')),
        Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontFamily: 'Tajawal')),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: Colors.grey[400], fontFamily: 'Tajawal')),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationsList(List donations) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: donations.length,
      itemBuilder: (context, index) {
        final d = donations[index];
        return FadeInRight(
          delay: Duration(milliseconds: index * 50),
          child: _buildListItem(
            title: d.donorName,
            subtitle: d.projectName,
            trailing: '${d.amount.toInt()} دج',
            icon: Icons.favorite_rounded,
            iconColor: Colors.redAccent,
          ),
        );
      },
    );
  }

  Widget _buildRequestsList(List requests) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final r = requests[index];
        return FadeInRight(
          delay: Duration(milliseconds: index * 50),
          child: _buildListItem(
            title: r.requesterName,
            subtitle: '${r.type} - ${r.wilaya}',
            trailing: r.status,
            icon: Icons.help_outline_rounded,
            iconColor: Colors.blue,
          ),
        );
      },
    );
  }



  Widget _buildListItem({
    required String title,
    required String subtitle,
    required String trailing,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Tajawal')),
                Text(subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontFamily: 'Tajawal')),
              ],
            ),
          ),
          Text(trailing, style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Tajawal')),
        ],
      ),
    );
  }
}
