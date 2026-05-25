import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../controllers/admin_controller.dart';
import '../widgets/blood_stats_graphic.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AdminController controller = Get.find<AdminController>();
  final ScreenshotController _screenshotController = ScreenshotController();
  String _filter = 'شهري';
  bool _isGeneratingPdf = false;
  bool _isSharingBlood = false;

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
                    pw.Text("تقرير الإحصاءات والأداء الشامل", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: const PdfColor(0, 0.5, 0.2))),
                    pw.Text("جمعية ناس الخير رغان", style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                  ],
                )
              ),
              pw.SizedBox(height: 15),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("ملخص المؤشرات العامة:", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(1),
                      },
                      children: [
                        _buildPdfRow("إجمالي التبرعات المالية (دج)", "$totalDons د.ج"),
                        _buildPdfRow("عدد الطلبات المسجلة", "$monthlyReqCount طلب"),
                        _buildPdfRow("المشاريع النشطة والجارية", "$activeProj مشروع قائم"),
                        _buildPdfRow("المستفيدين التقريبي", "${monthlyReqCount * 3} مستفيد"),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text("توزيع طلبات الخدمات التنموية:", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: const PdfColor(0, 0.5, 0.2))),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("نوع الخدمة", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("عدد الطلبات", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("النسبة المئوية", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    ]
                  ),
                  ...controller.serviceTypeDistribution.map((e) => pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_translateServiceType(e['name']), style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(e['count'].toString(), style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("${e['percentage']}%", style: const pw.TextStyle(fontSize: 9))),
                    ]
                  ))
                ]
              ),
              if (controller.activeGoals.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text("تقدم الأهداف الإستراتيجية والتشغيلية:", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: const PdfColor(0, 0.5, 0.2))),
                pw.SizedBox(height: 8),
                ...controller.activeGoals.map((goal) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(goal.title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text("المستهدف: ${goal.targetValue} | الحالي: ${goal.currentValue} (${(goal.progressPercentage * 100).toStringAsFixed(1)}%)", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ]
                  )
                ))
              ],
              if (controller.activeProjectsList.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text("المشاريع القائمة وتفاصيلها المادية:", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: const PdfColor(0, 0.5, 0.2))),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("اسم المشروع", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("الميزانية المستهدفة", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("المبلغ المجموع", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      ]
                    ),
                    ...controller.activeProjectsList.map((p) => pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(p.name, style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("${p.budget} دج", style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("${p.collected} دج", style: pw.TextStyle(color: const PdfColor(0, 0.5, 0), fontSize: 9))),
                      ]
                    ))
                  ]
                ),
              ],
              if (controller.totalBloodUnits.value > 0 || controller.userCountByBloodType.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text("إحصائيات الدم الشاملة:", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: const PdfColor(0.7, 0, 0))),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _buildPdfRow("إجمالي وحدات بنك الدم المتوفرة", "${controller.totalBloodUnits.value} وحدة"),
                    _buildPdfRow("عدد الأرواح التي تم إنقاذها", "${controller.livesSaved.value} شخص"),
                    _buildPdfRow("إجمالي الأعضاء المسجلين فصائلهم", "${controller.totalRegisteredUsers.value} عضو"),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (controller.totalBloodUnits.value > 0)
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("مخزون بنك الدم بالوحدات:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: const PdfColor(0.7, 0, 0))),
                            pw.SizedBox(height: 4),
                            pw.Table(
                              border: pw.TableBorder.all(color: PdfColors.grey300),
                              children: [
                                pw.TableRow(
                                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                                  children: [
                                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("الفصيلة", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("الكمية", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                                  ]
                                ),
                                ...controller.bloodStatsByType.entries.map((e) => pw.TableRow(
                                  children: [
                                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(e.key.replaceAll('_pos', '+').replaceAll('_neg', '-').toUpperCase(), style: const pw.TextStyle(fontSize: 8))),
                                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("${e.value} وحدة", style: const pw.TextStyle(fontSize: 8))),
                                  ]
                                ))
                              ]
                            ),
                          ],
                        ),
                      ),
                    if (controller.totalBloodUnits.value > 0 && controller.userCountByBloodType.isNotEmpty)
                      pw.SizedBox(width: 15),
                    if (controller.userCountByBloodType.isNotEmpty)
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("توزيع الأعضاء المسجلين حسب الزمرة:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: const PdfColor(0, 0.4, 0.8))),
                            pw.SizedBox(height: 4),
                            pw.Table(
                              border: pw.TableBorder.all(color: PdfColors.grey300),
                              children: [
                                pw.TableRow(
                                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                                  children: [
                                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("الزمرة", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("الأعضاء", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                                  ]
                                ),
                                ...controller.userCountByBloodType.entries.map((e) {
                                  final totalUsers = controller.totalRegisteredUsers.value;
                                  final pct = totalUsers > 0 ? (e.value / totalUsers * 100).toStringAsFixed(1) : '0';
                                  return pw.TableRow(
                                    children: [
                                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(e.key, style: const pw.TextStyle(fontSize: 8))),
                                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("${e.value} (%$pct)", style: const pw.TextStyle(fontSize: 8))),
                                    ]
                                  );
                                })
                              ]
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],

              pw.SizedBox(height: 30),
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text("نسأل الله القبول والبركة في عمل الجميع.", style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
              ),
              pw.Center(
                child: pw.Text("تم استخراج التقرير آلياً - نظام ناس الخير رغان الإداري الذكي.", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
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
        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(label, style: const pw.TextStyle(fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
      ]
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, int delay) {
    return FadeInUp(
      delay: Duration(milliseconds: delay),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 15)],
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
          Expanded(
            child: Text(
              title, 
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
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
        padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 16),
        decoration: AppTheme.glassDecoration,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxYValue,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppTheme.backgroundColor.withValues(alpha: 0.15),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${rod.toY.toInt()} د.ج',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45, getTitlesWidget: (v, m) => Text(NumberFormat.compact().format(v), style: TextStyle(color: AppTheme.textHint, fontSize: 12, fontWeight: FontWeight.w600)))),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    if (value.toInt() >= 0 && value.toInt() < data.length) {
                      String monthAr = _translateMonth(data[data.length - 1 - value.toInt()]['month']);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(monthAr, style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 13)),
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
                    gradient: const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.primaryGreen], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                    width: 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxYValue, color: AppTheme.backgroundColor),
                  )
                ],
              );
            }),
          ),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutQuint,
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
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                    );
                  }).toList(),
                ),
                duration: const Duration(milliseconds: 800),
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
                          Expanded(child: Text(_translateServiceType(e['name']), style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    );
                  }).toList().cast<Widget>(),
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
            Icon(Icons.bar_chart_rounded, size: 50, color: AppTheme.textHint.withValues(alpha: 0.15)),
            const SizedBox(height: 10),
            Text('جاري جمع البيانات الكافية...', style: TextStyle(color: AppTheme.textHint, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Get.isDarkMode ? AppTheme.darkSurface : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  isScrollable: false,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  indicator: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.primaryGreen, width: 1.5),
                  ),
                  labelColor: AppTheme.primaryGreen,
                  unselectedLabelColor: AppTheme.textHint,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Tajawal', fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Tajawal', fontSize: 13),
                  tabs: [
                    Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text("المخططات والإحصائيات", style: const TextStyle(fontFamily: 'Tajawal')),
                      ),
                    ),
                    Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text("سجل النشاطات المفصل", style: const TextStyle(fontFamily: 'Tajawal')),
                      ),
                    ),
                    Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text("إحصائيات الدم", style: const TextStyle(fontFamily: 'Tajawal')),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildStatsTab(),
                    _buildDetailedLogsTab(),
                    _buildBloodStatsTab(),
                  ],
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
      ),
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
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
                  decoration: BoxDecoration(
                    color: Get.isDarkMode ? AppTheme.darkSurface : Colors.black.withValues(alpha: 0.05), 
                    borderRadius: BorderRadius.circular(20), 
                    border: Border.all(color: AppTheme.glassBorder)
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filter,
                      dropdownColor: AppTheme.surfaceColor,
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
          const SizedBox(height: 160),
        ],
      ),
    );
  }

  Widget _buildDetailedLogsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('حدث خطأ في تحميل السجل', style: TextStyle(color: AppTheme.errorColor)));
        }

        // فلترة الرسائل والمحادثات اليومية لتقليل الفوضى
        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final type = (data['type'] ?? '').toString();
          return type != 'new_message' && type != 'message';
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_turned_in_rounded, size: 64, color: AppTheme.textHint.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text('لا توجد نشاطات مسجلة حالياً', style: TextStyle(color: AppTheme.textHint, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 100, top: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final title = data['title'] ?? 'عملية بالنظام';
            final body = data['body'] ?? '';
            final senderName = data['senderName'] ?? 'النظام';
            final logType = data['type'] as String?;
            final color = _getLogColor(logType);
            
            return FadeInUp(
              delay: Duration(milliseconds: (index % 10) * 40),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_getLogIcon(logType), color: color, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary, fontFamily: 'Tajawal')),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text('بواسطة: ', style: TextStyle(color: AppTheme.textHint, fontSize: 11, fontFamily: 'Tajawal')),
                                    Text(senderName, style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(DateFormat('yyyy/MM/dd').format(date), style: TextStyle(color: AppTheme.textHint, fontSize: 10, fontFamily: 'Tajawal')),
                              Text(DateFormat('HH:mm').format(date), style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Get.isDarkMode ? AppTheme.backgroundColor : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.glassBorder),
                        ),
                        child: Text(body, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4, fontFamily: 'Tajawal')),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getLogColor(String? type) {
    if (type == null) return AppTheme.primaryGreen;
    if (type.contains('blood')) return AppTheme.errorColor;
    if (type.contains('reject') || type.contains('cancel')) return AppTheme.errorColor;
    if (type.contains('approve') || type.contains('accept')) return Colors.green;
    if (type.contains('new')) return Colors.blue;
    return AppTheme.primaryGreen;
  }

  IconData _getLogIcon(String? type) {
    if (type == null) return Icons.event_note;
    if (type.contains('blood')) return Icons.bloodtype;
    if (type.contains('reject') || type.contains('cancel')) return Icons.cancel;
    if (type.contains('approve') || type.contains('accept')) return Icons.check_circle;
    if (type.contains('new_request')) return Icons.assignment_add;
    if (type.contains('new_donation')) return Icons.volunteer_activism;
    if (type.contains('update')) return Icons.update;
    return Icons.notifications;
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22), 
            color: AppTheme.textPrimary, 
            onPressed: () => Get.back(),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'التقارير والإحصاءات', 
                  style: TextStyle(
                    color: AppTheme.textPrimary, 
                    fontSize: 22, 
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  )
                ),
                Text(
                  'تحليل الأداء واستخراج المستندات', 
                  style: TextStyle(
                    color: AppTheme.textSecondary, 
                    fontSize: 13, 
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Tajawal',
                  )
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1), 
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.1)),
            ),
            child: const Icon(Icons.analytics_rounded, color: AppTheme.primaryGreen, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodStatsTab() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBloodHeader(),
            const SizedBox(height: 16),
            _buildBloodSummaryCards(),
            const SizedBox(height: 30),
            _buildRegisteredUsersBloodStatsSection(),
            const SizedBox(height: 120),
          ],
        ),
      );
    });
  }

  Widget _buildRegisteredUsersBloodStatsSection() {
    final userCounts = controller.userCountByBloodType;
    final totalUsers = controller.totalRegisteredUsers.value;
    
    if (userCounts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('توزيع زمر دم الأعضاء المسجلين'),
          _buildChartEmptyState(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('توزيع فصائل دم الأعضاء المسجلين (إجمالي: $totalUsers عضو)'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassDecoration,
          child: Column(
            children: [
              // رسم بياني دائري مبسط لزمر الأعضاء المسجلين
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 35,
                    sections: userCounts.entries.map((e) {
                      final percentage = totalUsers > 0 ? (e.value / totalUsers * 100).toStringAsFixed(1) : '0';
                      final color = _getBloodTypeColor(e.key);
                      return PieChartSectionData(
                        value: e.value.toDouble(),
                        title: '${e.key}\n$percentage%',
                        color: color,
                        radius: 50,
                        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Tajawal'),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // قائمة تفصيلية بالأعداد والنسب المئوية
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: userCounts.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: AppTheme.glassBorder),
                  itemBuilder: (context, index) {
                    final entry = userCounts.entries.toList()[index];
                    final label = entry.key;
                    final count = entry.value;
                    final pct = totalUsers > 0 ? (count / totalUsers * 100).toStringAsFixed(1) : '0';
                    final color = _getBloodTypeColor(label);
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.1),
                        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Tajawal')),
                      ),
                      title: Text('فصيلة $label', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: LinearProgressIndicator(
                          value: totalUsers > 0 ? count / totalUsers : 0,
                          backgroundColor: AppTheme.glassBorder,
                          color: color,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$count عضو', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 14)),
                          Text('%$pct', style: TextStyle(color: AppTheme.textHint, fontSize: 12, fontFamily: 'Tajawal')),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getBloodTypeColor(String bloodType) {
    switch (bloodType.toUpperCase()) {
      case 'A+': return Colors.red[800]!;
      case 'A-': return Colors.red[400]!;
      case 'B+': return Colors.pink[800]!;
      case 'B-': return Colors.pink[400]!;
      case 'AB+': return Colors.purple[800]!;
      case 'AB-': return Colors.purple[400]!;
      case 'O+': return Colors.orange[800]!;
      case 'O-': return Colors.orange[500]!;
      default: return Colors.red[600]!;
    }
  }

  Widget _buildBloodHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("تحليلات فصائل الدم", style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        IconButton(
          icon: _isSharingBlood 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen))
              : const Icon(Icons.share_rounded, color: AppTheme.primaryGreen),
          onPressed: _shareBloodStats,
          tooltip: 'مشاركة الإحصائيات كصورة',
        ),
      ],
    );
  }

  Widget _buildBloodSummaryCards() {
    final totalDonors = controller.userCountByBloodType.values.fold(0, (a, b) => a + b);
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      children: [
        _buildMetricCard(
          'المتبرعون المسجلين',
          totalDonors.toString(),
          Icons.people_alt_rounded,
          Colors.blue,
          100,
        ),
        _buildMetricCard(
          'عمليات إنقاذ ميسرة',
          controller.livesSaved.value.toString(),
          Icons.favorite,
          Colors.green,
          200,
        ),
      ],
    );
  }



  Future<void> _shareBloodStats() async {
    setState(() => _isSharingBlood = true);
    try {
      final image = await _screenshotController.captureFromWidget(
        Material(
          child: BloodStatsGraphic(
            userCounts: controller.userCountByBloodType,
            totalRegisteredUsers: controller.totalRegisteredUsers.value,
            livesSaved: controller.livesSaved.value,
          ),
        ),
      );

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/blood_stats.png').create();
      await imagePath.writeAsBytes(image);

      final shareText = 'إحصائيات مجتمع متبرعي الدم - جمعية ناس الخير رغان 🩸\n\n'
          'ساهم معنا في إنقاذ الأرواح بالتسجيل وتحديد فصيلة دمك في تطبيق ناس الخير رقان.\n'
          'رابط تحميل التطبيق المباشر على متجر قوقل بلاي:\n'
          'https://play.google.com/store/apps/details?id=com.nasalkheir.dz.app';

      await Share.shareXFiles([XFile(imagePath.path)], text: shareText);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تصدير الإحصائيات: $e', backgroundColor: AppTheme.errorColor, colorText: Colors.white);
    } finally {
      setState(() => _isSharingBlood = false);
    }
  }
}

