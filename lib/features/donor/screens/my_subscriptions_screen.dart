// ✨ NEW
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/donor_controller.dart';
import '../../../data/models/project_model.dart';

class MySubscriptionsScreen extends StatelessWidget {
  const MySubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DonorController donorController = Get.find<DonorController>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('كفالاتي (التبرعات المستمرة)', 
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Obx(() {
        final subscriptions = donorController.activeProjects.where((p) => 
          p.isSubscription && donorController.myDonations.any((d) => d.projectId == p.id)).toList();

        if (subscriptions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.child_care_outlined, size: 80, color: AppTheme.textHint.withValues(alpha: 0.75)),
                const SizedBox(height: 20),
                Text('ليس لديك اشتراكات نشطة حالياً',
                    style: TextStyle(color: AppTheme.textHint, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: subscriptions.length,
          itemBuilder: (context, index) {
            final project = subscriptions[index];
            final firstDonation = donorController.myDonations.firstWhere((d) => d.projectId == project.id);
            final monthlyAmount = firstDonation.amount;
            final startDate = firstDonation.date;
            final monthsCompleted = DateTime.now().difference(startDate).inDays ~/ 30 + 1;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: AppTheme.glassDecoration,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.75),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.volunteer_activism, color: AppTheme.primaryGreen),
                      ),
                      title: Text(project.name, 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('المبلغ الشهري: ${monthlyAmount.toInt()} دج', 
                            style: const TextStyle(color: AppTheme.goldAccent, fontWeight: FontWeight.w600)),
                          Text('تاريخ البدء: ${DateFormat('yyyy/MM/dd').format(startDate)}',
                            style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                        ],
                      ),
                    ),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      width: double.infinity,
                      color: AppTheme.primaryGreen.withValues(alpha: 0.75),
                      child: Row(
                        children: [
                          Icon(Icons.stars, color: _getMilestoneColor(monthsCompleted), size: 18),
                          const SizedBox(width: 8),
                          Text(_getMilestoneMessage(monthsCompleted),
                            style: TextStyle(color: _getMilestoneColor(monthsCompleted), 
                            fontSize: 12, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('أتممت $monthsCompleted أشهر ✓', 
                            style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 11)),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _showEditAmountDialog(context, project, monthlyAmount),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.primaryGreen),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('تعديل المبلغ', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _confirmCancelSubscription(context, project.name),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.errorColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('إلغاء الكفالة', style: TextStyle(color: AppTheme.errorColor, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Color _getMilestoneColor(int months) {
    if (months >= 12) return AppTheme.goldAccent;
    if (months >= 6) return Colors.purpleAccent;
    if (months >= 3) return Colors.blueAccent;
    return AppTheme.primaryGreen;
  }

  String _getMilestoneMessage(int months) {
    if (months >= 12) return 'وسام الوفاء السنوي 🏆';
    if (months >= 6) return 'وسام العطاء المستمر 🌟';
    if (months >= 3) return 'وسام المثابرة 🏅';
    return 'مساهم جديد مميز ✨';
  }

  void _showEditAmountDialog(BuildContext context, ProjectModel project, double currentAmount) {
     final controller = TextEditingController(text: currentAmount.toStringAsFixed(0));
     Get.dialog(
       AlertDialog(
         backgroundColor: AppTheme.surfaceColor,
         title: Text('تعديل مبلغ الكفالة لـ ${project.name}', 
           style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontFamily: 'Tajawal')),
         content: TextField(
           controller: controller,
           keyboardType: TextInputType.number,
           style: TextStyle(color: AppTheme.textPrimary),
           decoration: AppTheme.inputDecoration('المبلغ الجديد (دج)', Icons.monetization_on),
         ),
         actions: [
           TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
           ElevatedButton(
             onPressed: () {
               Get.back();
               Get.snackbar('نجاح', 'تم تحديث مبلغ الكفالة بنجاح', 
                backgroundColor: AppTheme.primaryGreen, colorText: Colors.black);
             },
             style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
             child: const Text('حفظ', style: TextStyle(color: Colors.black)),
           ),
         ],
       ),
     );
  }

  void _confirmCancelSubscription(BuildContext context, String projectName) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('تأكيد الإلغاء', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
        // ✨ MODIFIED: Removed const here to fix "Constant evaluation error"
        content: Text('هل أنت متأكد من رغبتك في إلغاء كفالة "$projectName"؟', 
          style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('تراجع')),
          TextButton(
            onPressed: () {
              Get.back();
              Get.snackbar('تم الإلغاء', 'تم إلغاء الكفالة بنجاح', 
                backgroundColor: AppTheme.errorColor, colorText: Colors.white);
            },
            child: const Text('نعم، إلغاء', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}

