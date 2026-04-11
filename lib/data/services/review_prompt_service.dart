import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// خدمة حوار التقييم — تعرض حوار لطيف بعد استخدام التطبيق لفترة
class ReviewPromptService {
  static const String _launchCountKey = 'app_launch_count';
  static const String _ratedKey = 'app_rated';
  static const String _dismissedKey = 'review_dismissed_count';
  static const int _launchThreshold = 10; // بعد 10 فتحات

  /// تُستدعى عند كل بدء تشغيل
  static Future<void> trackLaunchAndPrompt() async {
    final prefs = await SharedPreferences.getInstance();

    // إذا قيّم مسبقاً — لا نزعجه
    if (prefs.getBool(_ratedKey) == true) return;

    // إذا رفض 3 مرات — لا نزعجه
    final dismissed = prefs.getInt(_dismissedKey) ?? 0;
    if (dismissed >= 3) return;

    // زيادة عداد الفتح
    final count = (prefs.getInt(_launchCountKey) ?? 0) + 1;
    await prefs.setInt(_launchCountKey, count);

    // عرض الحوار بعد الحد المطلوب
    if (count >= _launchThreshold && count % _launchThreshold == 0) {
      // ملاحظة: تم نقل التحكم في التوقيت إلى AuthController
      final context = Get.context;
      if (context != null && context.mounted) {
        _showReviewDialog(context, prefs, dismissed);
      }
    }
  }

  static void _showReviewDialog(
      BuildContext context, SharedPreferences prefs, int dismissed) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(
                'هل أعجبك التطبيق؟',
                style: GoogleFonts.tajawal(
                    fontSize: 20, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            'رأيك يهمنا! ساعدنا بتقييم التطبيق لنستمر في تطويره وخدمة الجمعية بشكل أفضل.',
            style: GoogleFonts.tajawal(
              fontSize: 14,
              height: 1.7,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                prefs.setInt(_dismissedKey, dismissed + 1);
              },
              child: Text('ليس الآن',
                  style: GoogleFonts.tajawal(color: Colors.grey)),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                prefs.setBool(_ratedKey, true);
                // فتح صفحة التطبيق (يمكن تغييرها لرابط Google Play)
                _openStore();
              },
              icon: const Icon(Icons.star_rounded, size: 20),
              label: Text('قيّم التطبيق',
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openStore() async {
    // رابط Google Play (غيّره عند النشر الفعلي)
    const playStoreUrl =
        'https://github.com/ahmed-majija/nas_alkhir_reggane/releases';
    final uri = Uri.parse(playStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
