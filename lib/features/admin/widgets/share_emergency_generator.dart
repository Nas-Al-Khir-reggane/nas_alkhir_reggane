import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/theme/app_theme.dart';
import '../../../data/models/service_request_model.dart';

class ShareEmergencyGenerator {
  static Future<void> shareEmergency(ServiceRequestModel request, BuildContext context) async {
    try {
      ScreenshotController screenshotController = ScreenshotController();
      
      String deepLink = 'https://nasalkhir.app/emergency?id=${request.id}';
      
      final reqMap = request.toMap();
      String bloodType = request.bloodType.isNotEmpty ? request.bloodType : (reqMap['bloodType'] ?? 'غير محدد').toString();
      String hospital = request.hospital.isNotEmpty ? request.hospital : (reqMap['hospital'] ?? 'مستشفى غير محدد').toString();
      String phone = request.phone.isNotEmpty ? request.phone : (reqMap['phone'] ?? 'غير متوفر').toString();
      // موقع المستشفى أو مكان التبرع (ولاية + بلدية الطلب)
      final String location = [request.wilaya, request.commune].where((s) => s.isNotEmpty).join(' - ');
      // عنوان الطالب التفصيلي (العنوان الدقيق داخل الولاية)
      final String detailedAddress = request.address.trim();
      final String createdAtText = intl.DateFormat('yyyy/MM/dd HH:mm').format(request.createdAt);
      
      // بناء الودجت مع SingleChildScrollView لمنع الـ Overflow نهائياً في الصورة
      Widget cardWidget = MediaQuery(
        data: const MediaQueryData(size: Size(600, 1200), devicePixelRatio: 2.0),
        child: Material(
          color: Colors.white,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              width: 600,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.1), width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // الهيدر
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.errorColor, Color(0xFFB71C1C)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.water_drop_rounded, color: Colors.white, size: 40),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            'نداء استغاثة عاجل\nقطرة دم تنقذ حيوات',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.tajawal(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // المحتوى
                  Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: [
                        Text(
                          '﴿ وَمَنْ أَحْيَاهَا فَكَأَنَّمَا أَحْيَا النَّاسَ جَمِيعًا ﴾\nمريض في أمس الحاجة لإغاثتكم، لا تبخلوا عليه بقطرات من دمائكم.',
                          style: GoogleFonts.tajawal(
                            fontSize: 18,
                            color: const Color(0xFF424242),
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildBadge(Icons.bloodtype, 'الفصيلة', bloodType, AppTheme.errorColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildBadge(Icons.volunteer_activism_rounded, 'المستشفى', hospital, AppTheme.primaryGreen),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // معلومات الحالة - مفصولة بوضوح بين الموقع والمستشفى
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE9ECEF)),
                          ),
                          child: Column(
                            children: [
                              // 🏥 موقع المستشفى (الولاية والبلدية)
                              _buildDataRow('🏥 المستشفى:', hospital.isNotEmpty ? hospital : 'غير محدد', icon: Icons.local_hospital_rounded, iconColor: const Color(0xFFD32F2F)),
                              const Divider(height: 16),
                              // 📍 موقع الطلب (الولاية والبلدية التي يقطن فيها الطالب)
                              _buildDataRow('📍 ولاية الطالب:', location.isEmpty ? 'غير محدد' : location, icon: Icons.location_on_rounded, iconColor: const Color(0xFF1976D2)),
                              if (detailedAddress.isNotEmpty) ...[
                                const Divider(height: 12),
                                _buildDataRow('🏠 عنوان الطالب:', detailedAddress, icon: Icons.home_rounded, iconColor: const Color(0xFF388E3C)),
                              ],
                              const Divider(height: 16),
                              _buildDataRow('🕐 وقت النداء:', createdAtText),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // التواصل
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBBDEFB)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF1976D2), size: 24),
                              const SizedBox(width: 10),
                              Text(
                                'للتواصل السريع: $phone',
                                style: GoogleFonts.tajawal(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0D47A1),
                                ),
                                textDirection: TextDirection.ltr,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // الفوتر
                  Container(
                    padding: const EdgeInsets.all(20),
                    color: const Color(0xFFF1F3F5),
                    child: Row(
                      children: [
                        QrImageView(
                          data: deepLink,
                          version: QrVersions.auto,
                          size: 80.0,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تطبيق ناس الخير رقان',
                                style: GoogleFonts.tajawal(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'امسح الرمز للاستجابة السريعة وتأكيد حضورك عبر التطبيق.',
                                style: GoogleFonts.tajawal(
                                  fontSize: 13,
                                  color: const Color(0xFF495057),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final uint8list = await screenshotController.captureFromWidget(
        cardWidget,
        delay: const Duration(milliseconds: 200),
      );

      final dir = await getApplicationDocumentsDirectory();
      final imagePath = await File('${dir.path}/emergency_${request.id}.png').create();
      await imagePath.writeAsBytes(uint8list);

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: '🚨 نداء استغاثة عاجل لتبرع بالدم 🩸\n'
            'الفصيلة المطلوبة: $bloodType\n'
            '🏥 المستشفى: ${hospital.isNotEmpty ? hospital : "غير محدد"}\n'
            '📍 ولاية الطالب: ${location.isNotEmpty ? location : "غير محدد"}\n'
            'لمزيد من التفاصيل: $deepLink\n\n'
            'لتحميل التطبيق: https://nas-al-khir-reggane.github.io/nas_alkhir_reggane/',
      );

    } catch (e) {
      Get.snackbar('خطأ', 'فشل تجهيز الصورة: $e');
    }
  }

  static Widget _buildBadge(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 5),
          Text(label, style: GoogleFonts.tajawal(fontSize: 12, color: Colors.grey[600])),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  static Widget _buildDataRow(String label, String value, {bool isBold = false, IconData? icon, Color? iconColor}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: iconColor ?? Colors.grey[600]),
          const SizedBox(width: 4),
        ],
        Text(label, style: GoogleFonts.tajawal(fontSize: 13, color: Colors.grey[600])),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
