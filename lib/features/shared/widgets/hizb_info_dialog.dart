import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_controller.dart';

class HizbInfoDialog extends StatelessWidget {
  const HizbInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.goldAccent.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.goldAccent, Color(0xFFB8860B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(31)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.white, size: 60),
                    const SizedBox(height: 12),
                    Text(
                      'حزب المائة ألف',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildStep(
                      Icons.volunteer_activism_rounded,
                      'الفكرة',
                      'تجمع تطوعي من أهل الخير المستعدين للمساهمة الفورية عند النداء.',
                    ),
                    const SizedBox(height: 20),
                    _buildStep(
                      Icons.notifications_active_rounded,
                      'الآلية',
                      'عند وجود حالة طارئة (عملية جراحية، دواء نادر، ضائقة شديدة)، يرسل النظام نداءً للمشتركين.',
                    ),
                    const SizedBox(height: 20),
                    _buildStep(
                      Icons.payments_rounded,
                      'المساهمة',
                      'المساهمة المقترحة هي 1000 دج (مائة ألف) فقط، ليكون الأثر كبيراً بتعدد المساهمين.',
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(color: Colors.white10),
                    ),
                    
                    Text(
                      'قال ﷺ: "أحب الأعمال إلى الله أدومها وإن قل"',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(
                        color: AppTheme.goldAccent,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    Obx(() {
                      final bool isMember = authController.currentUser.value?.isHizbMember ?? false;
                      final bool loading = authController.isLoading.value;
                      
                      return Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: loading ? null : () async {
                                await authController.toggleHizbMembership(!isMember);
                                // تمت إزالة Get.back() لأنها كانت تغلق الـ Snackbar بدلاً من النافذة
                                // الآن سيتم تحديث الزر تلقائياً ليعكس حالة الانضمام الجديدة
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isMember ? AppTheme.errorColor : AppTheme.primaryGreen,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              child: loading 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : Text(
                                    isMember ? 'إلغاء الاشتراك' : 'انضم الآن للحزب',
                                    style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Get.back(),
                            child: Text('إغلاق', style: GoogleFonts.tajawal(color: AppTheme.textSecondary)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.goldAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.goldAccent, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              const SizedBox(height: 4),
              Text(desc, style: GoogleFonts.tajawal(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
