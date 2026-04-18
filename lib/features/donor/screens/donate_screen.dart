import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
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
  
  bool requestPrayerPost = false;
  String selectedPrayerType = 'deceased';
  final TextEditingController prayerTargetController = TextEditingController();
  final TextEditingController prayerMessageController = TextEditingController();
  String selectedPrayerColor = 'emerald';
  
  // ✨ متغيرات حزب المائة ألف
  double minAmount = 0;
  String? linkedRequestId;
  String? linkedProjectId;

  static const int maxPrayerMessageWords = 20;

  static const List<Map<String, dynamic>> prayerTypes = [
    {'id': 'deceased', 'name': 'صدقة جارية عن متوفى', 'icon': Icons.church},
    {'id': 'healing', 'name': 'دعاء بالشفاء وعافية', 'icon': Icons.healing},
    {'id': 'barakah', 'name': 'دعاء بالرزق والبركة', 'icon': Icons.account_balance_wallet},
    {'id': 'parents', 'name': 'دعاء للوالدين والمودة', 'icon': Icons.family_restroom},
    {'id': 'general', 'name': 'شكر ودعاء عام بالخير', 'icon': Icons.auto_awesome},
  ];

  static const List<Map<String, dynamic>> prayerColors = [
    {'id': 'emerald', 'color': Color(0xFF00695C), 'name': 'أخضر'},
    {'id': 'sapphire', 'color': Color(0xFF1565C0), 'name': 'أزرق'},
    {'id': 'gold', 'color': Color(0xFFC5A059), 'name': 'ذهبي'},
    {'id': 'rose', 'color': Color(0xFFAD1457), 'name': 'وردي'},
    {'id': 'slate', 'color': Color(0xFF37474F), 'name': 'وقور'},
  ];

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
      selectedProjectName = preName;
      // إعادة الضبط بعد تطبيقه
      donorController.preSelectProject('general', 'تبرع عام للجمعية');
    }

    // ✨ التعامل مع معاملات نداء حزب المائة ألف
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      if (args.containsKey('minAmount')) {
        minAmount = double.tryParse(args['minAmount'].toString()) ?? 0;
        selectedAmount = minAmount;
        amountController.text = minAmount.toInt().toString();
      }
      if (args.containsKey('requestId') && args['requestId'].toString().isNotEmpty) {
        linkedRequestId = args['requestId'].toString();
      }
      if (args.containsKey('projectId') && args['projectId'].toString().isNotEmpty) {
        linkedProjectId = args['projectId'].toString();
        selectedProjectId = linkedProjectId!;
        // حاول العثور على اسم المشروع
        final project = donorController.activeProjects.firstWhereOrNull((p) => p.id == linkedProjectId);
        if (project != null) selectedProjectName = project.name;
      }
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    notesController.dispose();
    prayerTargetController.dispose();
    prayerMessageController.dispose();
    super.dispose();
  }

  int _wordCount(String text) {
    return text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  String _trimToWordLimit(String text, int maxWords) {
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length <= maxWords) return text.trim();
    return words.take(maxWords).join(' ');
  }

  void _onDonate() {
    double amount = selectedAmount ?? double.tryParse(amountController.text) ?? 0;
    if (amount <= 0) {
      Get.snackbar('تنبيه', 'يرجى إدخال مبلغ صحيح', backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15));
      return;
    }

    if (amount < minAmount) {
      Get.snackbar(
        'تنبيه', 
        'الحد الأدنى للمساهمة في هذا النداء هو ${minAmount.toInt()} دج',
        backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15)
      );
      return;
    }
    
    final customPrayerMessage = _trimToWordLimit(prayerMessageController.text, maxPrayerMessageWords);

    donorController.makeDonation(
      projectId: selectedProjectId,
      projectName: selectedProjectName,
      amount: amount,
      method: selectedMethod,
      isAnonymous: isAnonymous,
      isRecurring: isRecurring,
      notes: notesController.text,
      requestPrayerPost: requestPrayerPost,
      prayerType: selectedPrayerType,
      prayerTarget: prayerTargetController.text,
      prayerColor: selectedPrayerColor,
      prayerCustomMessage: customPrayerMessage.isEmpty ? null : customPrayerMessage,
      requestId: linkedRequestId, // تمرير معرف الطلب إن وجد
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
            Text('إثبات التبرع (إلزامي) *', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Obx(() => Container(
              decoration: AppTheme.glassDecoration,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (donorController.selectedProofImage.value != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            donorController.selectedProofImage.value!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => donorController.clearProofImage(),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _buildImageSourceButton(
                            label: 'الكاميرا',
                            icon: Icons.camera_alt_outlined,
                            onTap: () => donorController.pickProofImage(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildImageSourceButton(
                            label: 'المعرض',
                            icon: Icons.image_outlined,
                            onTap: () => donorController.pickProofImage(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            )),

            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: AppTheme.inputDecoration('ملاحظة (اختياري)...', Icons.notes),
              style: TextStyle(color: AppTheme.textPrimary),
            ),

            const SizedBox(height: 24),
            // ✨ قسم طلب منشور دعاء
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.goldAccent.withValues(alpha: 0.1), Colors.transparent],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.2)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: AppTheme.goldAccent, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('طلب منشور دعاء احترافي 🌟',
                                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('سيقوم المنسق بمشاركة بطاقة دعاء على فيسبوك',
                                style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                          ],
                        ),
                      ),
                      Switch(
                        value: requestPrayerPost,
                        onChanged: (v) => setState(() => requestPrayerPost = v),
                        activeThumbColor: AppTheme.goldAccent,
                      ),
                    ],
                  ),
                  if (requestPrayerPost) ...[
                    const Divider(height: 24, color: AppTheme.glassBorder),
                    Text('اختر نوع الدعاء:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: prayerTypes.map((type) {
                        final isSelected = selectedPrayerType == type['id'];
                        return GestureDetector(
                          onTap: () => setState(() => selectedPrayerType = type['id'] as String),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.goldAccent.withValues(alpha: 0.15) : AppTheme.cardColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? AppTheme.goldAccent : AppTheme.glassBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(type['icon'] as IconData, color: isSelected ? AppTheme.goldAccent : AppTheme.textHint, size: 16),
                                const SizedBox(width: 6),
                                Text(type['name'] as String, style: TextStyle(color: isSelected ? AppTheme.goldAccent : AppTheme.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text('اسم الشخص المقصود بالدعاء (اختياري):', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: prayerTargetController,
                      decoration: AppTheme.inputDecoration('مثلاً: الوالدين، المرحوم فلان، المريض فلان...', Icons.person_outline),
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    ),
                    const SizedBox(height: 14),
                    Text('النص الذي سيظهر في البطاقة (حد $maxPrayerMessageWords كلمة):', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: prayerMessageController,
                      maxLines: 3,
                      onChanged: (value) {
                        final trimmed = _trimToWordLimit(value, maxPrayerMessageWords);
                        if (trimmed != value.trim()) {
                          prayerMessageController.value = TextEditingValue(
                            text: trimmed,
                            selection: TextSelection.collapsed(offset: trimmed.length),
                          );
                        }
                        setState(() {});
                      },
                      decoration: AppTheme.inputDecoration(
                        'اكتب الدعاء أو الرسالة التي تريد ظهورها في البطاقة...',
                        Icons.edit_note,
                      ),
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_wordCount(prayerMessageController.text)}/$maxPrayerMessageWords كلمة',
                        style: TextStyle(
                          color: _wordCount(prayerMessageController.text) >= maxPrayerMessageWords
                              ? Colors.orange
                              : AppTheme.textHint,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('اختر ثيم البطاقة:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 12),
                    Row(
                      children: prayerColors.map((color) {
                        final isSelected = selectedPrayerColor == color['id'];
                        return GestureDetector(
                          onTap: () => setState(() => selectedPrayerColor = color['id'] as String),
                          child: Container(
                            margin: const EdgeInsetsDirectional.only(end: 12),
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: color['color'] as Color,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2.5),
                              boxShadow: isSelected ? [BoxShadow(color: color['color'] as Color, blurRadius: 8)] : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
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

  Widget _buildImageSourceButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryGreen, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
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

