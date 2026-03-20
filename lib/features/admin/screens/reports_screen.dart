import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/constants/app_constants.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
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
    return DataTable(
      columns: const [
        DataColumn(label: Text('المؤشر')),
        DataColumn(label: Text('القيمة', textAlign: TextAlign.center)),
      ],
      rows: const [
        DataRow(cells: [DataCell(Text('إجمالي التبرعات المحصلة')), DataCell(Text('1.5M دج'))]),
        DataRow(cells: [DataCell(Text('إجمالي طلبات الخدمة المنجزة')), DataCell(Text('120 طلب'))]),
        DataRow(cells: [DataCell(Text('نسبة النمو الشهري')), DataCell(Text('+15%', style: TextStyle(color: Colors.green)))]),
      ],
    );
  }

  Widget _buildBarChart() {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 20,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  const style = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10);
                  String text;
                  switch (value.toInt()) {
                    case 0: text = 'جانفي'; break;
                    case 1: text = 'فيفري'; break;
                    case 2: text = 'مارس'; break;
                    case 3: text = 'أفريل'; break;
                    case 4: text = 'ماي'; break;
                    case 5: text = 'جوان'; break;
                    default: text = ''; break;
                  }
                  return SideTitleWidget(meta: meta, child: Text(text, style: style));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 8, color: Colors.blue, width: 15)]),
            BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 10, color: Colors.blue, width: 15)]),
            BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 14, color: Colors.blue, width: 15)]),
            BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 15, color: Colors.blue, width: 15)]),
            BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 13, color: Colors.blue, width: 15)]),
            BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 18, color: Colors.blue, width: 15)]),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: [
            PieChartSectionData(color: Colors.green, value: 40, title: 'غذائية', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            PieChartSectionData(color: Colors.blue, value: 30, title: 'طبية', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            PieChartSectionData(color: Colors.red, value: 15, title: 'جنائز', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            PieChartSectionData(color: Colors.orange, value: 15, title: 'أخرى', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: 5,
          minY: 0,
          maxY: 6,
          lineBarsData: [
            LineChartBarData(
              spots: const [FlSpot(0, 1), FlSpot(1, 1.5), FlSpot(2, 2.8), FlSpot(3, 3.2), FlSpot(4, 4.5), FlSpot(5, 5)],
              isCurved: true,
              color: Colors.purple,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.purple.withOpacity(0.2)),
            ),
          ],
        ),
      ),
    );
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
