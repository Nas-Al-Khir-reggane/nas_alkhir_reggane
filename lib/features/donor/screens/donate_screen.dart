import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/donor_controller.dart';
import '../../admin/controllers/project_controller.dart';

class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key});

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  final DonorController donorController = Get.find<DonorController>();
  final ProjectController projectController = Get.find<ProjectController>();
  
  String selectedProjectId = 'general';
  String selectedProjectName = 'تبرع عام للجمعية';

  double? selectedAmount;
  final TextEditingController amountController = TextEditingController();
  String selectedMethod = 'cash';
  bool isAnonymous = false;
  bool isRecurring = false;
  final TextEditingController notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // إذا كان هناك مشروع محدد مسبقاً من لوحة المتبرع
    final preId = donorController.preSelectedProjectId.value;
    final preName = donorController.preSelectedProjectName.value;
    if (preId != 'general') {
      selectedProjectId = preId;
      selectedProjectName = preName;
      // إعادة الضبط بعد تطبيقه
      donorController.preSelectProject('general', 'تبرع عام للجمعية');
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _onDonate() {
    double amount = selectedAmount ?? double.tryParse(amountController.text) ?? 0;
    if (amount <= 0) {
      Get.snackbar('تنبيه', 'يرجى إدخال مبلغ صحيح', backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15));
      return;
    }
    
    donorController.makeDonation(
      projectId: selectedProjectId,
      projectName: selectedProjectName,
      amount: amount,
      method: selectedMethod,
      isAnonymous: isAnonymous,
      isRecurring: isRecurring,
      notes: notesController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text('تبرع الآن',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            Text('كل دينار يصنع فرقاً',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 24),

            Text('اختر المشروع *', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            
            Obx(() => Column(
              children: [
                // خيار تبرع عام
                _buildProjectOption(
                  id: 'general',
                  name: 'تبرع عام للجمعية',
                  icon: Icons.volunteer_activism,
                  color: AppTheme.primaryGreen,
                ),
                
                // المشاريع النشطة
                ...donorController.activeProjects.map((project) {
                  final cat = ProjectController.categories.firstWhere(
                    (c) => c['id'] == project.category,
                    orElse: () => ProjectController.categories.last
                  );
                  return _buildProjectOption(
                    id: project.id,
                    name: project.name,
                    icon: cat['icon'],
                    color: cat['color'],
                    progress: project.progressRatio,
                    progressText: '${project.progressPercentage.toStringAsFixed(1)}% مكتمل',
                  );
                }),
              ],
            )),

            const SizedBox(height: 20),
            Text('المبلغ *', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [500, 1000, 2000, 5000, 10000, 20000].map((amount) {
                final isSelected = selectedAmount == amount.toDouble();
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedAmount = amount.toDouble();
                      amountController.text = amount.toString();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppTheme.goldGradient : null,
                      color: !isSelected ? AppTheme.cardColor : null,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSelected ? Colors.transparent : AppTheme.glassBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('${projectController.formatNumber(amount)} دج',
                        style: TextStyle(
                            color: isSelected ? Colors.black : AppTheme.textSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400)),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              onChanged: (val) => setState(() => selectedAmount = null),
              decoration: AppTheme.inputDecoration('أو أدخل مبلغاً مخصصاً...', Icons.attach_money),
              style: TextStyle(color: AppTheme.textPrimary),
            ),

            const SizedBox(height: 20),
            Text('طريقة الدفع *', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                {'id': 'cash', 'name': 'نقدي', 'icon': Icons.payments_outlined},
                {'id': 'bank', 'name': 'تحويل بنكي', 'icon': Icons.account_balance_outlined},
                {'id': 'online', 'name': 'إلكتروني', 'icon': Icons.credit_card_outlined},
              ].map((method) {
                final isSelected = selectedMethod == method['id'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => selectedMethod = method['id'] as String),
                    child: Container(
                      margin: const EdgeInsetsDirectional.only(end: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.15) : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder,
                            width: isSelected ? 2 : 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(method['icon'] as IconData,
                              color: isSelected ? AppTheme.primaryGreen : AppTheme.textHint, size: 22),
                          const SizedBox(height: 6),
                          Text(method['name'] as String,
                              style: TextStyle(
                                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary,
                                  fontSize: 12),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            Container(
              decoration: AppTheme.glassDecoration,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تبرع مجهول',
                              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                          Text('لن يُذكر اسمك',
                              style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      Switch(
                        value: isAnonymous,
                        onChanged: (v) => setState(() => isAnonymous = v),
                        activeTrackColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        activeThumbColor: AppTheme.primaryGreen,
                      ),
                    ],
                  ),
                  const Divider(color: AppTheme.glassBorder),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تبرع شهري متكرر',
                              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                          Text('سيتكرر كل شهر تلقائياً',
                              style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      Switch(
                        value: isRecurring,
                        onChanged: (v) => setState(() => isRecurring = v),
                        activeTrackColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        activeThumbColor: AppTheme.primaryGreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: AppTheme.inputDecoration('ملاحظة (اختياري)...', Icons.notes),
              style: TextStyle(color: AppTheme.textPrimary),
            ),

            const SizedBox(height: 24),
            Obx(() => donorController.isLoading.value
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : AppTheme.gradientButton(
                    text: 'تأكيد التبرع - ${projectController.formatNumber(selectedAmount ?? double.tryParse(amountController.text) ?? 0)} دج',
                    icon: Icons.favorite,
                    onPressed: _onDonate,
                  )),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectOption({
    required String id,
    required String name,
    required IconData icon,
    required Color color,
    double? progress,
    String? progressText,
  }) {
    final isSelected = selectedProjectId == id;
    return GestureDetector(
      onTap: () => setState(() {
        selectedProjectId = id;
        selectedProjectName = name;
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.15) : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder,
              width: isSelected ? 2 : 1),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.all(8),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                  if (progress != null) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: AppTheme.surfaceColor,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primaryGreen),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(progressText!, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ]
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 20),
          ],
        ),
      ),
    );
  }
}

class ThankYouDialog extends StatelessWidget {
  final String name;
  final double amount;
  final String projectName;

  const ThankYouDialog({
    super.key,
    required this.name,
    required this.amount,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    final projectController = Get.find<ProjectController>();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeInDown(
              child: const Icon(Icons.favorite, color: AppTheme.primaryGreen, size: 60),
            ),
            const SizedBox(height: 16),
            Text('جزاك الله خيراً!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('تم تسجيل تبرعك بنجاح', 
                style: TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Container(
              decoration: AppTheme.glassDecoration,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('المبلغ:', style: TextStyle(color: AppTheme.textHint)),
                      Text('${projectController.formatNumber(amount)} دج',
                          style: const TextStyle(color: AppTheme.goldAccent, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('المشروع:', style: TextStyle(color: AppTheme.textHint)),
                      Expanded(
                        child: Text(projectName,
                            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('"عطاءٌ من كسبٍ طيب، يربو عند الله حتى يكون كالجبل.. جزاك الله خيرًا"',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            AppTheme.gradientButton(
              text: 'حسناً',
              icon: Icons.check,
              onPressed: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }
}

