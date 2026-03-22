import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AdminController controller = Get.find<AdminController>();
  String _filter = 'شهري';

  Future<void> _exportToPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text("تقرير جمعية ناس الخير - $_filter"),
              ),
              pw.SizedBox(height: 20),
              pw.Text("إحصاءات عامة:"),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 20, top: 10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("مجموع التبرعات: 1,500,000 دج"),
                    pw.Text("عدد الخدمات المقدمة: 120 خدمة"),
                    pw.Text("عدد المستفيدين: 450 مستفيد"),
                    pw.Text("المركبات العاملة: 5 مركبات"),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text("هذا التقرير تم استخراجه تلقائياً من نظام إدارة الجمعية."),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Widget _buildSummaryTable() {
    return Obx(() {
      final totalDons = controller.totalDonations.value;
      final monthlyReqCount = controller.monthlyRequests.isEmpty ? 0 : controller.monthlyRequests.map((e) => e['count'] as int).fold(0, (a, b) => a + b);

      return DataTable(
        columns: const [
          DataColumn(label: Text('المؤشر')),
          DataColumn(label: Text('القيمة', textAlign: TextAlign.center)),
        ],
        rows: [
          DataRow(cells: [const DataCell(Text('إجمالي التبرعات (المؤكدة)')), DataCell(Text('$totalDons دج'))]),
          DataRow(cells: [const DataCell(Text('طلبات هذا الشهر')), DataCell(Text('$monthlyReqCount طلب'))]),
          DataRow(cells: [const DataCell(Text('المشاريع النشطة')), DataCell(Text('${controller.activeProjects.value} مشروع'))]),
        ],
      );
    });
  }

  Widget _buildBarChart() {
    return Obx(() {
      final data = controller.donationsLastSixMonths;
      if (data.isEmpty) return const SizedBox(height: 200, child: Center(child: Text('لا توجد بيانات')));
      
      final maxYValue = data.isEmpty ? 20.0 : data.map((e) => (e['amount'] as num).toDouble()).fold(0.0, (a, b) => a > b ? a : b) * 1.2 + 1;

      return SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxYValue,
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    if (value.toInt() >= 0 && value.toInt() < data.length) {
                      return SideTitleWidget(meta: meta, child: Text(data[data.length - 1 - value.toInt()]['month'], style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)));
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(data.length, (index) {
              final reverseIndex = data.length - 1 - index;
              return BarChartGroupData(
                x: index,
                barRods: [BarChartRodData(toY: (data[reverseIndex]['amount'] as num).toDouble(), color: Colors.blue, width: 15)],
              );
            }),
          ),
        ),
      );
    });
  }

  Widget _buildPieChart() {
    return Obx(() {
      final data = controller.serviceTypeDistribution;
      if (data.isEmpty) return const SizedBox(height: 200, child: Center(child: Text('لا توجد بيانات')));

      return SizedBox(
        height: 200,
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: data.map((e) {
              return PieChartSectionData(
                color: e['color'] as Color,
                value: (e['count'] as num).toDouble(),
                title: (e['percentage'] as num) > 0 ? '${e['name']}\n${e['percentage']}%' : '',
                radius: 50,
                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
              );
            }).toList(),
          ),
        ),
      );
    });
  }

  Widget _buildLineChart() {
    return Obx(() {
      final data = controller.monthlyRequests;
      if (data.isEmpty) return const SizedBox(height: 200, child: Center(child: Text('لا توجد بيانات')));

      final spots = data.map((e) => FlSpot((e['day'] as num).toDouble(), (e['count'] as num).toDouble())).toList();
      final maxYValue = spots.isEmpty ? 5.0 : spots.map((e) => e.y).fold(0.0, (a, b) => a > b ? a : b) * 1.5 + 1;

      return SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minX: 1,
            maxX: data.length.toDouble(),
            minY: 0,
            maxY: maxYValue,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Colors.purple,
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: Colors.purple.withValues(alpha: 0.2)),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("التقارير والإحصاءات"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportToPdf,
            tooltip: "تصدير كـ PDF",
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("تصفية البيانات", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _filter,
                  items: const [
                    DropdownMenuItem(value: 'شهري', child: Text("شهري")),
                    DropdownMenuItem(value: 'سنوي', child: Text("سنوي")),
                  ],
                  onChanged: (val) => setState(() => _filter = val!),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text("التبرعات الشهرية (دج)", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildBarChart(),
            const SizedBox(height: 32),
            const Text("توزيع الخدمات حسب النوع", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildPieChart(),
            const SizedBox(height: 32),
            const Text("نمو عدد المستفيدين (بالآلاف)", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildLineChart(),
            const SizedBox(height: 32),
            const Text("جدول ملخص الإحصاءات", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(elevation: 2, child: _buildSummaryTable()),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
