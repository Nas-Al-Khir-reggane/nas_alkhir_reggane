import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/shared/widgets/rating_dialog.dart';

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
      final context = Get.context;
      if (context != null && context.mounted) {
        _showReviewDialog(context, prefs, dismissed);
      }
    }
  }

  static void _showReviewDialog(
      BuildContext context, SharedPreferences prefs, int dismissed) {
    Get.dialog(
      RatingDialog(
        onSubmit: (rating, comment) async {
          Get.back(); // إغلاق الحوار
          
          try {
            // حفظ التقييم في Firestore
            final user = FirebaseAuth.instance.currentUser;
            await FirebaseFirestore.instance.collection('app_reviews').add({
              'userId': user?.uid,
              'userName': user?.displayName ?? 'مستخدم مجهول',
              'rating': rating,
              'comment': comment,
              'createdAt': FieldValue.serverTimestamp(),
              'platform': GetPlatform.isAndroid ? 'android' : 'ios',
            });

            // تعليم التطبيق كمُقيم
            await prefs.setBool(_ratedKey, true);

            // توجيه لصفحة التحميل
            await _openStore();
          } catch (e) {
            debugPrint('Error saving review: $e');
            // حتى لو فشل الحفظ في Firestore، نحاول فتح صفحة التحميل لضمان تجربة المستخدم
            await _openStore();
          }
        },
      ),
      barrierDismissible: true,
    );
  }

  static Future<void> _openStore() async {
    // صفحة التحميل الرسمية على GitHub Pages
    const downloadPageUrl =
        'https://ahmed-majija.github.io/nas_alkhir_reggane/';
    final uri = Uri.parse(downloadPageUrl);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch $downloadPageUrl: $e');
    }
  }
}
