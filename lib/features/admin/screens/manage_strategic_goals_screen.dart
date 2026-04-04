import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/theme/app_theme.dart';
import '../controllers/admin_controller.dart';
import '../../../data/models/strategic_goal_model.dart';

class ManageStrategicGoalsScreen extends StatefulWidget {
  const ManageStrategicGoalsScreen({super.key});

  @override
  State<ManageStrategicGoalsScreen> createState() => _ManageStrategicGoalsScreenState();
}

class _ManageStrategicGoalsScreenState extends State<ManageStrategicGoalsScreen> {
  final controller = Get.find<AdminController>();
  final _formKey = GlobalKey<FormState>();
  
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _targetController = TextEditingController();
  final _unitController = TextEditingController();
  
  GoalType _selectedType = GoalType.donations;
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  String? _selectedProjectId;
  String? _selectedServiceType;
  StrategicGoalModel? _editingGoal;

  @override
  void initState() {
    super.initState();
    // جلب المشاريع النشطة لضمان ظهورها في القائمة عند الربط
    controller.loadActiveProjects();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('إدارة الأهداف التشغيلية', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildInfoBanner(),
          Expanded(
            child: Obx(() => controller.activeGoals.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: controller.activeGoals.length,
                    itemBuilder: (context, index) {
                      final goal = controller.activeGoals[index];
                      return _buildGoalCard(goal);
                    },
                  )),
          ),
        ],
      ),
      floatingActionButton: controller.isSuperAdmin ? FloatingActionButton.extended(
        onPressed: _showAddGoalDialog,
        label: const Text('مستهدف جديد', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.rocket_launch_rounded),
        backgroundColor: AppTheme.primaryGreen,
      ) : null,
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'هذه التحديات تظهر للمتبرعين وللإدارة لتحفيزهم على تحقيق مستهدفات الخير لهذا الشهر.',
              style: TextStyle(color: AppTheme.primaryGreen, fontSize: 12, fontFamily: 'Tajawal', height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(StrategicGoalModel goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getGoalColor(goal.type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getGoalTypeLabel(goal.type),
                  style: TextStyle(color: _getGoalColor(goal.type), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                ),
              ),
              if (controller.isSuperAdmin)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 22),
                      onPressed: () => _showAddGoalDialog(goal),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.primaryGreen, size: 20),
                      onPressed: () => _confirmDeactivate(goal),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                      onPressed: () => _confirmDelete(goal),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(goal.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, fontFamily: 'Tajawal')),
          const SizedBox(height: 4),
          Text(goal.description, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontFamily: 'Tajawal')),
          const SizedBox(height: 20),
          
          // Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${goal.currentValue.toInt()} / ${goal.targetValue.toInt()} ${goal.unit}', 
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')
              ),
              Text('${(goal.progressPercentage * 100).toInt()}%', 
                style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: goal.progressPercentage,
              backgroundColor: Colors.grey[200],
              color: _getGoalColor(goal.type),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('ينتهي في: ${intl.DateFormat('yyyy/MM/dd').format(goal.endDate)}', 
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontFamily: 'Tajawal')
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddGoalDialog([StrategicGoalModel? goal]) {
    setState(() {
      _editingGoal = goal;
      if (goal != null) {
        _titleController.text = goal.title;
        _descController.text = goal.description;
        _targetController.text = goal.targetValue.toString();
        _unitController.text = goal.unit;
        _selectedType = goal.type;
        _endDate = goal.endDate;
        _selectedProjectId = goal.projectId;
        _selectedServiceType = goal.serviceTypeId;
      } else {
        _titleController.clear();
        _descController.clear();
        _targetController.clear();
        _unitController.clear();
        _selectedType = GoalType.donations;
        _endDate = DateTime.now().add(const Duration(days: 30));
        _selectedProjectId = null;
        _selectedServiceType = null;
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddGoalSheet(),
    );
  }

  Widget _buildAddGoalSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20, left: 20, right: 20,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text(_editingGoal == null ? 'إطلاق مستهدف تشغيلي جديد' : 'تعديل بيانات المستهدف', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Tajawal')),
                const SizedBox(height: 20),
                
                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: _inputDecoration('عنوان التحدي', 'مثلاً: تحدي إطعام 500 عائلة'),
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 16),
                
                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: _inputDecoration('الوصف التحفيزي', 'كلمات تشجع الناس على المساهمة'),
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 16),
                
                // Type Dropdown
                DropdownButtonFormField<GoalType>(
                  initialValue: _selectedType,
                  decoration: _inputDecoration('نوع التحدي', ''),
                  items: GoalType.values.map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(_getGoalTypeLabel(e), style: const TextStyle(fontFamily: 'Tajawal')),
                  )).toList(),
                  onChanged: (v) => setSheetState(() => _selectedType = v!),
                ),
                const SizedBox(height: 16),

                // NEW: Service Type selection if Type is 'services'
                if (_selectedType == GoalType.services) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedServiceType,
                    decoration: _inputDecoration('نوع الخدمة المحددة', 'اختر الخدمة المرتبطة بالهدف'),
                    items: [
                      { 'id': 'funeral_transport', 'name': 'إكرام الموتى (نقل)' },
                      { 'id': 'food_aid', 'name': 'مساعدات غذائية' },
                      { 'id': 'medical_aid', 'name': 'مساعدة طبية' },
                      { 'id': 'water_supply', 'name': 'سقي الماء' },
                      { 'id': 'orphans_care', 'name': 'كفالة اليتيم' },
                      { 'id': 'education', 'name': 'تعليم وكفالة طالب' },
                    ].map((s) => DropdownMenuItem(
                      value: s['id'],
                      child: Text(s['name']!, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                    )).toList(),
                    onChanged: (v) => setSheetState(() => _selectedServiceType = v),
                  ),
                  const SizedBox(height: 16),
                ],

                // ارتباط بمشروع (اختياري)
                Obx(() => DropdownButtonFormField<String>(
                  initialValue: _selectedProjectId,
                  isExpanded: true,
                  decoration: _inputDecoration('ربط بمشروع محدد (اختياري)', 'سيتم توجيه المتبرع لهذا المشروع'),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('تبرع عام للجمعية')),
                    ...controller.activeProjectsList.map((p) => DropdownMenuItem<String>(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                    )),
                  ],
                  onChanged: (v) => setSheetState(() => _selectedProjectId = v),
                )),
                const SizedBox(height: 16),
                
                // Target Value & Unit
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _targetController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('المستهدف', 'رقم'),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        decoration: _inputDecoration('الوحدة', 'دج، طرد...'),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // End Date Picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تاريخ نهاية التحدي', style: TextStyle(fontSize: 14, fontFamily: 'Tajawal')),
                  subtitle: Text(intl.DateFormat('yyyy/MM/dd').format(_endDate)),
                  trailing: const Icon(Icons.calendar_month_rounded),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setSheetState(() => _endDate = picked);
                  },
                ),
                
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submitGoal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_editingGoal == null ? 'تفعيل التحدي الآن 🚀' : 'حفظ التعديلات ✨', 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontFamily: 'Tajawal'),
      hintStyle: const TextStyle(fontSize: 12, fontFamily: 'Tajawal'),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  void _submitGoal() {
    if (_formKey.currentState!.validate()) {
      final String? selectedProjectName = _selectedProjectId == null 
          ? null 
          : controller.activeProjectsList.firstWhere((p) => p.id == _selectedProjectId).name;

      if (_editingGoal != null) {
        final updated = _editingGoal!.copyWith(
          title: _titleController.text,
          description: _descController.text,
          type: _selectedType,
          targetValue: double.parse(_targetController.text),
          unit: _unitController.text,
          endDate: _endDate,
          projectId: _selectedProjectId,
          projectName: selectedProjectName,
          serviceTypeId: _selectedServiceType,
        );
        controller.updateStrategicGoal(updated);
      } else {
        final goal = StrategicGoalModel(
          id: '',
          title: _titleController.text,
          description: _descController.text,
          type: _selectedType,
          targetValue: double.parse(_targetController.text),
          unit: _unitController.text,
          startDate: DateTime.now(),
          endDate: _endDate,
          isActive: true,
          projectId: _selectedProjectId,
          projectName: selectedProjectName,
          serviceTypeId: _selectedServiceType,
        );
        controller.addStrategicGoal(goal);
      }
      
      Get.back();
      _titleController.clear();
      _descController.clear();
      _targetController.clear();
      _unitController.clear();
      _editingGoal = null;
    }
  }

  void _confirmDeactivate(StrategicGoalModel goal) {
    Get.dialog(
      AlertDialog(
        title: const Text('إكمال التحدي؟', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: const Text('هل تم تحقيق هذا الهدف وتريد نقله إلى الأرشيف المكتمل؟', style: TextStyle(fontFamily: 'Tajawal')),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              controller.deactivateGoal(goal.id);
              Get.back();
            }, 
            child: const Text('نعم، تم الإكمال', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  void _confirmDelete(StrategicGoalModel goal) {
    Get.dialog(
      AlertDialog(
        title: const Text('حذف التحدي نهائياً؟', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text('هذا الإجراء سيقوم بحذف التحدي تماماً من سجلات النظام ولا يمكن التراجع عنه.', style: TextStyle(fontFamily: 'Tajawal')),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              controller.deleteStrategicGoal(goal.id);
              Get.back();
            }, 
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  Color _getGoalColor(GoalType type) {
    switch (type) {
      case GoalType.donations: return Colors.orange;
      case GoalType.beneficiaries: return AppTheme.primaryGreen;
      case GoalType.services: return Colors.blue;
      default: return Colors.purple;
    }
  }

  String _getGoalTypeLabel(GoalType type) {
    switch (type) {
      case GoalType.donations: return 'تحدي تبرعات';
      case GoalType.beneficiaries: return 'تحدي وصول';
      case GoalType.services: return 'تحدي عملياتي';
      default: return 'تحدي عام';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rocket_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('لا توجد تحديات نشطة حالياً', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Tajawal')),
          const SizedBox(height: 8),
          Text('ابدأ بإطلاق أول مستهدف تشغيلي للجمعية', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontFamily: 'Tajawal')),
        ],
      ),
    );
  }
}
