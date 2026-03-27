import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../controllers/admin_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AdminController controller = Get.find<AdminController>();
  String _filter = 'شهري';
  bool _isGeneratingPdf = false;

  String _translateServiceType(String type) => AppConstants.translateServiceType(type);

  String _translateMonth(String month) {
    switch (month.toLowerCase()) {
      case 'jan': return 'يناير'; case 'january': return 'يناير';
      case 'feb': return 'فبراير'; case 'february': return 'فبراير';
      case 'mar': return 'مارس'; case 'march': return 'مارس';
      case 'apr': return 'أبريل'; case 'april': return 'أبريل';
      case 'may': return 'مايو';
      case 'jun': return 'يونيو'; case 'june': return 'يونيو';
      case 'jul': return 'يوليو'; case 'july': return 'يوليو';
      case 'aug': return 'أغسطس'; case 'august': return 'أغسطس';
      case 'sep': return 'سبتمبر'; case 'september': return 'سبتمبر';
      case 'oct': return 'أكتوبر'; case 'october': return 'أكتوبر';
      case 'nov': return 'نوفمبر'; case 'november': return 'نوفمبر';
      case 'dec': return 'ديسمبر'; case 'december': return 'ديسمبر';
      default: return month;
    }
  }

  Future<void> _generateAndSharePdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final pdf = pw.Document();
      
      // Load Arabic Font
      ByteData fontData;
      try {
        fontData = await rootBundle.load('assets/fonts/Tajawal-Medium.ttf');
      } catch (e) {
        fontData = await rootBundle.load('assets/fonts/Tajawal-Bold.ttf');
      }
      final ttf = pw.Font.ttf(fontData);

      final totalDons = controller.totalDonations.value;
      final monthlyReqCount = controller.monthlyRequests.isEmpty ? 0 : controller.monthlyRequests.map((e) => e['count'] as int).fold(0, (a, b) => a + b);
      final activeProj = controller.activeProjects.value;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("تقرير الإحصاءات والأداء", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: const PdfColor(0, 0.5, 0.2))),
                    pw.Text("جمعية ناس الخير", style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
                  ],
                )
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("مخصل عام:", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(1),
                      },
                      children: [
                        _buildPdfRow("إجمالي التبرعات (المؤكدة)", "$totalDons د.ج"),
                        _buildPdfRow("عدد الطلبات والمشوارع", "$monthlyReqCount طلب مسجل حديثاً"),
                        _buildPdfRow("المشاريع النشطة والجارية", "$activeProj مشروع قائم"),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Text("توزيع الخدمات:", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("نوع الخدمة", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("عدد الطلبات", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("النسبة", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ]
                  ),
                  ...controller.serviceTypeDistribution.map((e) => pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(_translateServiceType(e['name']))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(e['count'].toString())),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("${e['percentage']}%")),
                    ]
                  ))
                ]
              ),
              pw.SizedBox(height: 40),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text("نشكر جميع المحسنين وفاعلي الخير على المساهمة.", style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600)),
              ),
              pw.Center(
                child: pw.Text("تم استخراج هذا التقرير آلياً عبر نظام إدارة ناس الخير.", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: 'nas_al_kheir_report.pdf');
    } catch (e) {
      Get.snackbar("خطأ", "فشل توليد التقرير: $e", backgroundColor: AppTheme.errorColor, colorText: Colors.white);
    } finally {
      setState(() => _isGeneratingPdf = false);
    }
  }

  pw.TableRow _buildPdfRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(label)),
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
      ]
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, int delay) {
    return FadeInUp(
      delay: Duration(milliseconds: delay),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 15)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: AppTheme.textHint, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopDashboard() {
    return Obx(() {
      final totalDons = controller.totalDonations.value;
      final activeProj = controller.activeProjects.value;
      final monthlyReqCount = controller.monthlyRequests.isEmpty ? 0 : controller.monthlyRequests.map((e) => e['count'] as int).fold(0, (a, b) => a + b);

      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.2,
        children: [
          _buildMetricCard("إجمالي التبرعات (دج)", NumberFormat.compact(locale: 'ar').format(totalDons), Icons.volunteer_activism_rounded, AppTheme.primaryGreen, 100),
          _buildMetricCard("المشاريع النشطة", "$activeProj", Icons.architecture_rounded, Colors.blue, 200),
          _buildMetricCard("طلبات الشهر", "$monthlyReqCount", Icons.description_outlined, Colors.orange, 300),
          _buildMetricCard("المستفيدين التقريبي", "${monthlyReqCount * 3}", Icons.people_alt_outlined, Colors.purple, 400),
        ],
      );
    });
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return Obx(() {
      final data = controller.donationsLastSixMonths;
      if (data.isEmpty) return _buildChartEmptyState();
      
      final maxYValue = data.isEmpty ? 20.0 : data.map((e) => (e['amount'] as num).toDouble()).fold(0.0, (a, b) => a > b ? a : b) * 1.2 + 1;

      return Container(
        height: 250,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        decoration: AppTheme.glassDecoration,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxYValue,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppTheme.darkBg.withValues(alpha: 0.9),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${rod.toY.toInt()} د.ج',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text(NumberFormat.compact().format(v), style: TextStyle(color: AppTheme.textHint, fontSize: 10)))),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    if (value.toInt() >= 0 && value.toInt() < data.length) {
                      String monthAr = _translateMonth(data[data.length - 1 - value.toInt()]['month']);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(monthAr, style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 10)),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: AppTheme.glassBorder, strokeWidth: 1)),
            barGroups: List.generate(data.length, (index) {
              final reverseIndex = data.length - 1 - index;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: (data[reverseIndex]['amount'] as num).toDouble(), 
                    gradient: const LinearGradient(colors: [AppTheme.primaryGreen, Colors.teal], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                    width: 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxYValue, color: AppTheme.darkBg),
                  )
                ],
              );
            }),
          ),
          swapAnimationDuration: const Duration(milliseconds: 800),
          swapAnimationCurve: Curves.easeOutQuint,
        ),
      );
    });
  }

  Widget _buildPieChart() {
    return Obx(() {
      final data = controller.serviceTypeDistribution;
      if (data.isEmpty) return _buildChartEmptyState();

      return Container(
        height: 280,
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassDecoration,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 40,
                  sections: data.map((e) {
                    return PieChartSectionData(
                      color: e['color'] as Color,
                      value: (e['count'] as num).toDouble(),
                      title: '${e['percentage']}%',
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    );
                  }).toList(),
                ),
                swapAnimationDuration: const Duration(milliseconds: 800),
              ),
            ),
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: data.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: e['color'] as Color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_translateServiceType(e['name']), style: TextStyle(color: AppTheme.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildChartEmptyState() {
    return Container(
      height: 200,
      decoration: AppTheme.glassDecoration,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 50, color: AppTheme.textHint.withValues(alpha: 0.3)),
            const SizedBox(height: 10),
            Text('جاري جمع البيانات الكافية...', style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInDown(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("نظرة عامة", style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: AppTheme.darkSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.glassBorder)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _filter,
                                dropdownColor: AppTheme.darkBg,
                                style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                                icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryGreen, size: 18),
                                items: const [
                                  DropdownMenuItem(value: 'شهري', child: Text("شهري")),
                                  DropdownMenuItem(value: 'سنوي', child: Text("سنوي")),
                                ],
                                onChanged: (val) => setState(() => _filter = val!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTopDashboard(),
                    const SizedBox(height: 30),
                    FadeInUp(delay: const Duration(milliseconds: 200), child: _buildSectionTitle("حجم التبرعات المسجلة")),
                    FadeInUp(delay: const Duration(milliseconds: 300), child: _buildBarChart()),
                    const SizedBox(height: 30),
                    FadeInUp(delay: const Duration(milliseconds: 400), child: _buildSectionTitle("الخدمات المقدمة (توزيع)")),
                    FadeInUp(delay: const Duration(milliseconds: 500), child: _buildPieChart()),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FadeInUp(
        delay: const Duration(milliseconds: 600),
        child: FloatingActionButton.extended(
          onPressed: _isGeneratingPdf ? null : _generateAndSharePdf,
          backgroundColor: AppTheme.primaryGreen,
          icon: _isGeneratingPdf 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_rounded, color: Colors.black),
          label: const Text("استخراج التقرير", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), color: AppTheme.textPrimary, onPressed: () => Get.back()),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('التقارير والإحصاءات', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
                  Text('تحليل البيانات واستخراج المستندات', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.analytics_outlined, color: AppTheme.primaryGreen),
          ),
        ],
      ),
    );
  }
}
