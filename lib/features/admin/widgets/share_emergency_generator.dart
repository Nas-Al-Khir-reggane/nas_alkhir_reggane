import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/service_request_model.dart';
import 'package:intl/intl.dart' as intl;

class ShareEmergencyGenerator {
  static Future<void> shareEmergency(ServiceRequestModel request, BuildContext context) async {
    try {
      // 1. Ø¥Ù†Ø´Ø§Ø¡ Ù…ØªØ­ÙƒÙ… Ù„Ù‚Ø·Ø© Ø§Ù„Ø´Ø§Ø´Ø©
      ScreenshotController screenshotController = ScreenshotController();
      
      // 2. Ø§Ù„Ø±Ø§Ø¨Ø· Ø§Ù„Ø¹Ù…ÙŠÙ‚ Ù„Ù„Ù†Ø¯Ø§Ø¡
      String deepLink = 'https://nasalkhir.app/emergency?id=${request.id}';
      
      // 3. Ø§Ø³ØªØ®Ø±Ø§Ø¬ Ø§Ù„Ø¨ÙŠØ§Ù†Ø§Øª
      String bloodType = request.toMap()['bloodType'] ?? request.toMap()['details']?['الفصيلة'] ?? request.toMap()['details']?['bloodType'] ?? 'غير محدد';
      String hospital = request.toMap()['hospital'] ?? request.toMap()['details']?['المستشفى'] ?? request.toMap()['details']?['hospital'] ?? request.toMap()['deliveryLocation'] ?? 'مستشفى غير محدد';
      
      // 4. Ø¨Ù†Ø§Ø¡ ØªØµÙ…ÙŠÙ… Ø§Ù„Ø¨Ø·Ø§Ù‚Ø© Ø§Ù„ØµØ§Ù…Øª (Off-screen widget)
      Widget cardWidget = Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: 600,
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ø§Ù„Ù‡ÙŠØ¯Ø±
              Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.errorColor, const Color(0xFFC62828)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.campaign_rounded, color: Colors.white, size: 50),
                    const SizedBox(width: 16),
                    Text(
                      'Ù†Ø¯Ø§Ø¡ Ø§Ø³ØªØºØ§Ø«Ø© Ø¹Ø§Ø¬Ù„',
                      style: GoogleFonts.tajawal(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Ø§Ù„ØªÙØ§ØµÙŠÙ„
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Text(
                      'Ø­ÙŠØ§Ø©ÙŒ Ø¨Ø±ÙŠØ¦Ø© ØªÙ†ØªØ¸Ø±Ùƒ.. ÙƒÙ† Ø£Ù†Øª Ø§Ù„Ù…Ù†Ù‚Ø°!',
                      style: GoogleFonts.tajawal(
                        fontSize: 24,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    
                    // Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ø¯Ù…
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.75)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.bloodtype, color: AppTheme.errorColor, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  'Ø§Ù„ÙØµÙŠÙ„Ø© Ø§Ù„Ù…Ø·Ù„ÙˆØ¨Ø©',
                                  style: GoogleFonts.tajawal(fontSize: 18, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  bloodType,
                                  style: GoogleFonts.tajawal(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.errorColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.75)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.local_hospital, color: AppTheme.primaryGreen, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  'Ù…ÙˆÙ‚Ø¹ Ø§Ù„Ù…Ø³ØªØ´ÙÙ‰',
                                  style: GoogleFonts.tajawal(fontSize: 18, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  hospital,
                                  style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
              
              // Ø§Ù„ÙÙˆØªØ± (ØªÙˆØ¬ÙŠÙ‡ Ø§Ù„ÙƒØ§Ù…ÙŠØ±Ø§ Ù„Ù„Ù…Ø³Ø­)
              Container(
                padding: const EdgeInsets.all(30),
                color: const Color(0xFFFAFAFA),
                child: Row(
                  children: [
                    QrImageView(
                      data: deepLink,
                      version: QrVersions.auto,
                      size: 150.0,
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ØªØ·Ø¨ÙŠÙ‚ Ù†Ø§Ø³ Ø§Ù„Ø®ÙŠØ±',
                            style: GoogleFonts.tajawal(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ø§Ù…Ø³Ø­ Ø§Ù„Ø±Ù…Ø² Ø¨ÙˆØ§Ø³Ø·Ø© ÙƒØ§Ù…ÙŠØ±Ø§ Ù‡Ø§ØªÙÙƒ Ù„Ù„ÙˆØµÙˆÙ„ Ø§Ù„Ù…Ø¨Ø§Ø´Ø± Ù„Ù„Ù†Ø¯Ø§Ø¡ ÙˆØªØ£ÙƒÙŠØ¯ ØªØ¨Ø±Ø¹ÙƒØŒ Ø£Ùˆ Ù‚Ù… Ø¨ØªØ­Ù…ÙŠÙ„ Ø§Ù„ØªØ·Ø¨ÙŠÙ‚.',
                            style: GoogleFonts.tajawal(
                              fontSize: 18,
                              color: AppTheme.textSecondary,
                              height: 1.5,
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
      );

      // 5. Ø§Ù„ØªÙ‚Ø§Ø· Ø§Ù„ØµÙˆØ±Ø© Ø¨ØµÙ…Øª
      final uint8list = await screenshotController.captureFromWidget(
        cardWidget,
        delay: const Duration(milliseconds: 100),
      );

      // 6. Ø­ÙØ¸Ù‡Ø§ ÙÙŠ Ù…Ù„Ù Ù…Ø¤Ù‚Øª
      final dir = await getApplicationDocumentsDirectory();
      final imagePath = await File('${dir.path}/emergency_${request.id}.png').create();
      await imagePath.writeAsBytes(uint8list);

      // 7. ØªØ­Ø¶ÙŠØ± Ø±Ø³Ø§Ù„Ø© Ø§Ù„Ù…Ø´Ø§Ø±ÙƒØ© Ø§Ù„Ù†ØµÙŠØ© ÙƒÙ…Ø±ÙÙ‚ Ù„Ù„ØµÙˆØ±Ø©
      final String shareText = '''
ðŸš¨ Ù†Ø¯Ø§Ø¡ Ø§Ø³ØªØºØ§Ø«Ø© Ø¹Ø§Ø¬Ù„ ðŸš¨
Ù†Ø­ØªØ§Ø¬ Ø¥Ù„Ù‰ ØªØ¨Ø±Ø¹ Ø¨Ø§Ù„Ø¯Ù… Ù…Ù† ÙØµÙŠÙ„Ø© ($bloodType)
ðŸ“ ÙÙŠ: $hospital

Ù„Ù„Ø§Ø³ØªØ¬Ø§Ø¨Ø© Ø§Ù„ÙÙˆØ±ÙŠØ©ØŒ Ø§ÙØªØ­ Ø§Ù„Ø±Ø§Ø¨Ø· Ø§Ù„ØªØ§Ù„ÙŠ (Ø³ÙŠÙ‚ÙˆÙ… Ø¨ØªÙˆØ¬ÙŠÙ‡Ùƒ Ù„Ù„ØªØ·Ø¨ÙŠÙ‚ Ø£Ùˆ Ù„Ù…ØªØ¬Ø± Ø§Ù„ØªØ­Ù…ÙŠÙ„):
$deepLink

(ÙˆÙŽÙ…ÙŽÙ†Ù’ Ø£ÙŽØ­Ù’ÙŠÙŽØ§Ù‡ÙŽØ§ ÙÙŽÙƒÙŽØ£ÙŽÙ†ÙŽÙ‘Ù…ÙŽØ§ Ø£ÙŽØ­Ù’ÙŠÙŽØ§ Ø§Ù„Ù†ÙŽÙ‘Ø§Ø³ÙŽ Ø¬ÙŽÙ…ÙÙŠØ¹Ø§Ù‹)
''';

      // 8. ÙØªØ­ ÙˆØ§Ø¬Ù‡Ø© Ø§Ù„Ù†Ø¸Ø§Ù… Ù„Ù„Ù…Ø´Ø§Ø±ÙƒØ©
      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: shareText,
        subject: 'Ù†Ø¯Ø§Ø¡ Ù„ØªØ¨Ø±Ø¹ Ø¨Ø§Ù„Ø¯Ù…',
      );

    } catch (e) {
      Get.snackbar(
        'Ø®Ø·Ø£',
        'Ù„Ù… Ù†ØªÙ…ÙƒÙ† Ù…Ù† ØªÙˆÙ„ÙŠØ¯ ØµÙˆØ±Ø© Ø§Ù„Ù…Ø´Ø§Ø±ÙƒØ©: $e',
        backgroundColor: AppTheme.errorColor.withValues(alpha: 0.15),
        colorText: AppTheme.errorColor,
      );
    }
  }
}


