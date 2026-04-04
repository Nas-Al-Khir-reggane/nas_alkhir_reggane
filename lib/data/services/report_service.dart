import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import '../models/service_request_model.dart';
import '../models/donation_model.dart';
import '../models/strategic_goal_model.dart';
import 'package:intl/intl.dart' as intl;
import 'package:arabic_reshaper/arabic_reshaper.dart';

class ReportService {
  // دالة مساعدة لإصلاح اللغة العربية (الربط والاتجاه)
  static String _fixArabic(String text) {
    if (text.isEmpty) return "";
    try {
      // 1. إعادة تشكيل الحروف (توصيلها)
      final reshaper = ArabicReshaper();
      final reshaped = reshaper.reshape(text);
      return reshaped;
    } catch (e) {
      return text;
    }
  }

  static Future<void> generateMonthlyReport({
    required String adminName,
    required String organizationName,
    required int totalDonations,
    required int pendingRequests,
    required int totalBeneficiaries,
    required List<ServiceRequestModel> recentRequests,
    required List<DonationModel> recentDonations,
    List<StrategicGoalModel> activeGoals = const [],
  }) async {
    final pdf = pw.Document();
    
    // تحميل الخط العربي
    final fontData = await rootBundle.load("assets/fonts/Tajawal-Bold.ttf");
    final arabicFont = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl, // تحديد اتجاه الصفحة بالكامل RTL
        theme: pw.ThemeData.withFont(base: arabicFont),
        header: (context) => _buildHeader(organizationName),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.Center(
            child: pw.Header(
              level: 0, 
              text: _fixArabic("تقرير الأداء الشهري والشامل - جمعية ناس الخير"),
              textStyle: pw.TextStyle(fontSize: 22, color: PdfColors.green900),
            ),
          ),
          pw.SizedBox(height: 20),
          
          // 1. قسم الإحصائيات العامة (كروت)
          _buildStatsSection(
            totalDonations: totalDonations,
            pendingRequests: pendingRequests,
            totalBeneficiaries: totalBeneficiaries,
          ),
          
          pw.SizedBox(height: 30),

          // 2. قسم التحديات الاستراتيجية (بصمة الأثر)
          if (activeGoals.isNotEmpty) ...[
            _buildSectionTitle("حالة التحديات الاستراتيجية (بصمة الأثر)"),
            _buildGoalsTable(activeGoals),
            pw.SizedBox(height: 30),
          ],
          
          // 3. قسم المستفيدين الميداني (شامل كل المعطيات)
          _buildSectionTitle("سجل المستفيدين والطلبات الميدانية التفصيلي"),
          _buildRequestsTable(recentRequests),
          
          pw.SizedBox(height: 30),
          
          // 4. قسم التبرعات (شامل كل المعطيات)
          _buildSectionTitle("سجل تبرعات المحسنين التفصيلي"),
          _buildDonationsTable(recentDonations),
          
          pw.SizedBox(height: 40),
          
          // التوقيع الرسمي
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_fixArabic("ختم الجمعية:")),
                  pw.SizedBox(height: 40),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(_fixArabic("توقيع المدير المسؤول: $adminName")),
                  pw.Text(_fixArabic("تاريخ صدور التقرير: ${intl.DateFormat('yyyy/MM/dd').format(DateTime.now())}")),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Report_${intl.DateFormat('yyyy_MM_dd').format(DateTime.now())}',
    );
  }

  static pw.Widget _buildHeader(String orgName) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.green)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(_fixArabic("نـاس الخيـر"), style: pw.TextStyle(fontSize: 20, color: PdfColors.green900, fontWeight: pw.FontWeight.bold)),
          pw.Text(_fixArabic(orgName), style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Text(
        _fixArabic("صفحة ${context.pageNumber} من ${context.pagesCount} - تم توليد هذا التقرير آلياً عبر نظام ناس الخير الذكي"),
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const pw.BoxDecoration(color: PdfColors.green50),
      child: pw.Text(_fixArabic(title), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
    );
  }

  static pw.Widget _buildStatsSection({
    required int totalDonations,
    required int pendingRequests,
    required int totalBeneficiaries,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        _buildStatBox("إجمالي التبرعات", "$totalDonations ${_fixArabic("دج")}"),
        _buildStatBox("طلبات الميدان", "$pendingRequests"),
        _buildStatBox("المستفيدون", "$totalBeneficiaries"),
      ],
    );
  }

  static pw.Widget _buildStatBox(String label, String value) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.green200),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
      ),
      child: pw.Column(
        children: [
          pw.Text(_fixArabic(label), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 6),
          pw.Text(_fixArabic(value), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
        ],
      ),
    );
  }

  static pw.Widget _buildGoalsTable(List<StrategicGoalModel> goals) {
    return pw.TableHelper.fromTextArray(
      context: null,
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: [_fixArabic('التحدي الاستراتيجي'), _fixArabic('الهدف'), _fixArabic('المحقق'), _fixArabic('النسبة')],
      data: goals.map((g) => [
        _fixArabic(g.title),
        "${g.targetValue.toInt()} ${_fixArabic(g.unit)}",
        "${g.currentValue.toInt()} ${_fixArabic(g.unit)}",
        "${(g.progressPercentage * 100).toInt()}%",
      ]).toList(),
    );
  }

  static pw.Widget _buildRequestsTable(List<ServiceRequestModel> requests) {
    return pw.TableHelper.fromTextArray(
      context: null,
      border: pw.TableBorder.all(color: PdfColors.grey200),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headers: [_fixArabic('الاسم'), _fixArabic('الهاتف'), _fixArabic('الولاية/البلدية'), _fixArabic('نوع الخدمة'), _fixArabic('الحالة'), _fixArabic('التاريخ')],
      data: requests.map((r) => [
        _fixArabic(r.requesterName),
        r.phone,
        _fixArabic("${r.wilaya} / ${r.commune}"),
        _fixArabic(r.typeName),
        _fixArabic(r.status),
        intl.DateFormat('yyyy/MM/dd').format(r.createdAt),
      ]).toList(),
    );
  }

  static pw.Widget _buildDonationsTable(List<DonationModel> donations) {
    return pw.TableHelper.fromTextArray(
      context: null,
      border: pw.TableBorder.all(color: PdfColors.grey200),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headers: [_fixArabic('اسم المحسن'), _fixArabic('المبلغ'), _fixArabic('المشروع المدعوم'), _fixArabic('التاريخ')],
      data: donations.map((d) => [
        _fixArabic(d.donorName),
        "${d.amount.toInt()} ${_fixArabic("دج")}",
        _fixArabic(d.projectName),
        intl.DateFormat('yyyy/MM/dd').format(d.date),
      ]).toList(),
    );
  }
}
