import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/user_model.dart';
import 'package:intl/intl.dart';

/// خدمة تفريغ وتصدير البيانات من التطبيق
class ExportService {
  
  /// تصدير قائمة المستخدمين بصيغة Excel
  static Future<void> exportUsersToExcel(List<UserModel> users) async {
    try {
      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
      
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['المستخدمين'];
      excel.setDefaultSheet('المستخدمين');

      // العناوين
      List<String> headers = [
        'المعرّف',
        'الاسم',
        'البريد الإلكتروني',
        'رقم الهاتف',
        'الولاية',
        'البلدية',
        'الدور',
        'الحالة',
        'فصيلة الدم',
        'تاريخ التسجيل'
      ];
      _appendStyleRow(sheetObject, headers, isHeader: true);

      // البيانات
      for (var user in users) {
        String dateStr = DateFormat('yyyy/MM/dd HH:mm').format(user.createdAt);
            
        List<String> row = [
          user.memberId ?? 'بدون عضوية',
          user.name,
          user.email,
          user.phone,
          user.wilaya,
          user.commune,
          user.role.displayName,
          user.isApproved ? 'مُفعّل' : 'قيد الانتظار',
          user.bloodType ?? 'غير محدد',
          dateStr
        ];
        _appendStyleRow(sheetObject, row);
      }

      // حفظ الملف
      final dir = await getApplicationDocumentsDirectory();
      final date = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final String filePath = '${dir.path}/users_export_$date.xlsx';
      
      final bytes = excel.encode();
      if (bytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);
          
        if (Get.isDialogOpen ?? false) Get.back(); // Close loading
        
        // مشاركة الملف
        await Share.shareXFiles([XFile(filePath)], text: 'قائمة مستخدمي جمعية ناس الخير');
      }

    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      debugPrint('Export Error: $e');
      Get.snackbar('خطأ', 'فشل تصدير البيانات: $e', backgroundColor: Colors.red.withValues(alpha: 0.15));
    }
  }
  
  static void _appendStyleRow(Sheet sheet, List<String> data, {bool isHeader = false}) {
    // يمكننا إضافة تنسيقات للخلايا هنا لاحقا
    // مبدئياً سنضيفها كنصوص عادية
    List<CellValue?> cells = data.map((e) => TextCellValue(e)).toList();
    sheet.appendRow(cells);
  }
}
