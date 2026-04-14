import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/share_helper.dart';

/// شاشة "حول التطبيق"
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('حول التطبيق',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final version = snapshot.data?.version ?? '...';
          final buildNumber = snapshot.data?.buildNumber ?? '...';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              children: [
                // الشعار
                FadeInDown(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      children: [
                        AppLogo(
                          size: 90,
                          showGlow: false,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'جمعية ناس الخير',
                          style: GoogleFonts.tajawal(
                              fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.goldAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'رقّان',
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.goldAccent,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'v$version ($buildNumber)',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // الوصف
                FadeInUp(
                  delay: const Duration(milliseconds: 100),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('عن الجمعية',
                            style: GoogleFonts.tajawal(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.primary)),
                        const SizedBox(height: 12),
                        Text(
                          'جمعية ناس الخير — رقان هي جمعية خيرية تأسست بهدف خدمة المجتمع المحلي في مدينة رقان وضواحيها. '
                          'نعمل على تقديم المساعدات الاجتماعية والصحية والتعليمية للفئات المحتاجة.\n\n'
                          'يهدف هذا التطبيق إلى رقمنة العمل الخيري وتسهيل التواصل بين المتبرعين والمستفيدين والمتطوعين '
                          'لنوصل الخير بأسرع وقت وأقل جهد.',
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            height: 1.8,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // الروابط
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      children: [
                        _buildLinkTile(
                          context,
                          icon: Icons.language_rounded,
                          title: 'الموقع الرسمي',
                          subtitle: 'https://nas-al-khir-reggane.github.io/nas_alkhir_reggane/',
                          color: Colors.blue,
                          onTap: () => _launchUrl(
                              'https://nas-al-khir-reggane.github.io/nas_alkhir_reggane/'),
                        ),
                        _divider(context),
                        _buildLinkTile(
                          context,
                          icon: Icons.code_rounded,
                          title: 'الكود المصدري',
                          subtitle: 'GitHub Repository',
                          color: Colors.grey,
                          onTap: () => _launchUrl(
                              'https://github.com/ahmed-majija/nas_alkhir_reggane'),
                        ),
                        _divider(context),
                        _buildLinkTile(
                          context,
                          icon: Icons.privacy_tip_rounded,
                          title: 'سياسة الخصوصية',
                          subtitle: 'اطلع على حقوقك وحماية بياناتك',
                          color: Colors.green,
                          onTap: () =>
                              Get.toNamed(AppRoutes.privacyPolicy),
                        ),
                        _divider(context),
                        _buildLinkTile(
                          context,
                          icon: Icons.share_rounded,
                          title: 'شارك التطبيق',
                          subtitle: 'ادعُ أصدقاءك لاستخدام التطبيق',
                          color: Colors.orange,
                          onTap: () => ShareHelper.shareApp(),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // فريق التطوير
                FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  child: Container(
                    width: double.infinity, 
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.favorite_rounded,
                            color: Colors.red.shade300, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          'صُنع بحب لخدمة المجتمع',
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '«معاً نبني .. معاً نرحم» 💚',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLinkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: GoogleFonts.tajawal(
              fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(subtitle,
          style: GoogleFonts.tajawal(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      trailing:
          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
        height: 1,
        indent: 60,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.3));
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
