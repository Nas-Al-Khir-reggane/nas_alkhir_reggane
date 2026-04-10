import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

/// خدمة كشف التحديثات — تتحقق من GitHub Releases
/// تعرض حوار تحديث إذا كانت النسخة القديمة
class AppUpdateService {
  static const String _repoOwner = 'ahmed-majija';
  static const String _repoName = 'nas_alkhir_reggane';

  /// تُستدعى مرة واحدة عند بدء التطبيق
  static Future<void> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.2"

      final response = await http
          .get(
            Uri.parse(
                'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest'),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final latestTag = (data['tag_name'] as String?)
          ?.replaceAll('v', '')
          .trim(); // "1.1.0"
      final releaseNotes = data['body'] as String? ?? '';
      final downloadUrl = _extractApkUrl(data['assets']);
      final htmlUrl = data['html_url'] as String? ?? '';

      if (latestTag == null) return;

      if (_isNewerVersion(currentVersion, latestTag)) {
        // انتظر حتى تظهر الشاشة
        await Future.delayed(const Duration(seconds: 2));
        final context = Get.context;
        if (context != null && context.mounted) {
          _showUpdateDialog(
            context: context,
            currentVersion: currentVersion,
            latestVersion: latestTag,
            releaseNotes: releaseNotes,
            downloadUrl: downloadUrl ?? htmlUrl,
          );
        }
      } else {
        debugPrint('✅ [Update] App is up to date ($currentVersion)');
      }
    } catch (e) {
      debugPrint('⚠️ [Update] Check failed: $e');
    }
  }

  /// مقارنة الإصدارات: true إذا كان latest أحدث من current
  static bool _isNewerVersion(String current, String latest) {
    final c = current.split('.').map(int.tryParse).toList();
    final l = latest.split('.').map(int.tryParse).toList();

    for (int i = 0; i < 3; i++) {
      final cv = i < c.length ? (c[i] ?? 0) : 0;
      final lv = i < l.length ? (l[i] ?? 0) : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  /// استخراج رابط APK من أصول الإصدار
  static String? _extractApkUrl(dynamic assets) {
    if (assets is! List) return null;
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('.apk')) {
        return asset['browser_download_url'] as String?;
      }
    }
    return null;
  }

  /// حوار التحديث الأنيق
  static void _showUpdateDialog({
    required BuildContext context,
    required String currentVersion,
    required String latestVersion,
    required String releaseNotes,
    required String downloadUrl,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.system_update_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تحديث جديد متوفر! 🎉',
                  style: GoogleFonts.tajawal(
                      fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الإصدار الحالي',
                              style: GoogleFonts.tajawal(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                          Text('v$currentVersion',
                              style: GoogleFonts.tajawal(
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الإصدار الجديد',
                              style: GoogleFonts.tajawal(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                          Text('v$latestVersion',
                              style: GoogleFonts.tajawal(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('ما الجديد؟',
                    style: GoogleFonts.tajawal(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    child: Text(
                      releaseNotes,
                      style: GoogleFonts.tajawal(
                          fontSize: 12,
                          height: 1.6,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('لاحقاً',
                  style: GoogleFonts.tajawal(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _launchUrl(downloadUrl);
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text('تحديث الآن',
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
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

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
