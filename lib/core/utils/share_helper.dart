import 'package:share_plus/share_plus.dart';

/// أداة مشاركة التطبيق مع الأصدقاء
class ShareHelper {
  static const String _appUrl =
      'https://github.com/ahmed-majija/nas_alkhir_reggane/releases';

  static Future<void> shareApp() async {
    const message = '🌿 تطبيق جمعية ناس الخير - رقان\n\n'
        'تطبيق خيري يجمع بين المحسنين والمحتاجين.\n'
        'ساهم في التبرع بالدم، تبرع للمشاريع الخيرية، واطلب المساعدة.\n\n'
        '📲 حمّل التطبيق الآن:\n$_appUrl\n\n'
        '«معاً نبني .. معاً نرحم» 💚';

    await Share.share(message);
  }

  /// مشاركة مشروع خيري محدد
  static Future<void> shareProject(String projectName, String description) async {
    final message = '🌿 مشروع خيري: $projectName\n\n'
        '$description\n\n'
        'ساهم معنا في هذا المشروع عبر تطبيق ناس الخير 💚\n'
        '$_appUrl';

    await Share.share(message);
  }

  /// مشاركة حالة طوارئ
  static Future<void> shareEmergency(String title, String details) async {
    final message = '🚨 حالة طارئة — $title\n\n'
        '$details\n\n'
        'ساعدنا بنشر هذا الطلب! حمّل تطبيق ناس الخير:\n'
        '$_appUrl';

    await Share.share(message);
  }
}
