import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../data/models/service_type_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../controllers/admin_controller.dart';

class ManageServiceTypesScreen extends StatelessWidget {
  const ManageServiceTypesScreen({super.key});

  IconData _getIconForService(String name, String iconKey) {
    if (iconKey.isNotEmpty) return AppConstants.getIconFromName(iconKey);
    return AppConstants.getServiceIcon(name);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminController>();
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          _buildHeader(context, controller),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('service_types').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return AppTheme.loadingState();
                if (snapshot.hasError) return AppTheme.errorState('حدث خطأ في تحميل البيانات');
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return AppTheme.emptyState('لا توجد أنواع خدمات مضافة', icon: Icons.category_outlined);
                }

                var docs = snapshot.data!.docs;
                var types = docs.map((doc) => ServiceTypeModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
                
                types.sort((a, b) => b.popularity.compareTo(a.popularity));

                return ListView.separated(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
                  itemCount: types.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final type = types[index];
                    return _buildServiceCard(context, type, controller);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AdminController controller) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: AppTheme.glassBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Row(
              children: [
                _buildCircularButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Get.back(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🏷️ أنواع الخدمات',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                              fontFamily: 'Tajawal')),
                      Text('إدارة أبواب الخير والحقول الذكية',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: 'إضافة خدمة جديدة',
                    icon: Icons.add_rounded,
                    isPrimary: true,
                    onTap: () => _showEditTypeDialog(context, null),
                  ),
                ),
                const SizedBox(width: 10),
                _buildCircularButton(
                  icon: Icons.restore_rounded,
                  color: AppTheme.primaryGreen,
                  onTap: () => _showRestoreConfirm(controller),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, ServiceTypeModel type, AdminController controller) {
    final icon = _getIconForService(type.name, type.icon);
    final serviceColor = type.color != null 
        ? Color(int.parse(type.color!.replaceAll('#', '0xFF'))) 
        : AppTheme.primaryGreen;
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: serviceColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: serviceColor, size: 22),
        ),
        title: Text(type.name,
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal')),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'حقول ذكية: ${type.fields.isEmpty ? "لا يوجد" : type.fields.join('، ')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSmallIconBtn(Icons.edit_outlined, Colors.blue, () => _showEditTypeDialog(context, type)),
            const SizedBox(width: 4),
            _buildSmallIconBtn(Icons.delete_outline_rounded, AppTheme.errorColor, () => _showDeleteConfirm(type.id, controller)),
            const VerticalDivider(width: 20, indent: 10, endIndent: 10),
            Switch(
              value: type.isActive,
              activeThumbColor: AppTheme.primaryGreen,
              onChanged: (val) => controller.updateServiceType(type.id, {'isActive': val}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildCircularButton({required IconData icon, required VoidCallback onTap, Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Icon(icon, color: color ?? AppTheme.textPrimary, size: 20),
      ),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required bool isPrimary, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: isPrimary ? AppTheme.primaryGradient : null,
          color: isPrimary ? null : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary ? null : Border.all(color: AppTheme.glassBorder),
          boxShadow: isPrimary ? AppTheme.greenGlow : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isPrimary ? Colors.white : AppTheme.textPrimary, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: isPrimary ? Colors.white : AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(String id, AdminController controller) {
    Get.defaultDialog(
      title: 'حذف نوع الخدمة',
      middleText: 'هل أنت متأكد من حذف هذا النوع؟ سيؤدي ذلك لاختفائه من قائمة التقديم للمستفيدين.',
      textConfirm: 'حذف',
      textCancel: 'إلغاء',
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.errorColor,
      onConfirm: () {
        controller.deleteServiceType(id);
        Get.back();
      },
    );
  }

  void _showRestoreConfirm(AdminController controller) {
    Get.defaultDialog(
      title: 'إعادة التهيئة',
      middleText: 'سيتم استعادة الإعدادات الافتراضية وإصلاح أيقونات وألوان الخدمات الأساسية. هل تود الاستمرار؟',
      textConfirm: 'تأكيد',
      textCancel: 'إلغاء',
      confirmTextColor: Colors.black,
      onConfirm: () {
        controller.seedInitialData();
        Get.back();
      },
    );
  }

  void _showEditTypeDialog(BuildContext context, ServiceTypeModel? type) {
    final nameController = TextEditingController(text: type?.name ?? '');
    final RxString selectedIcon = (type?.icon ?? 'volunteer').obs;
    final Rx<Color> selectedColor = (type?.color != null 
        ? Color(int.parse(type!.color!.replaceAll('#', '0xFF'))) 
        : AppTheme.primaryGreen).obs;
    
    RxList<Map<String, String>> fields = (type?.fields.map((f) {
      String t = type.fieldConfigs[f] ?? 'text';
      String opts = '';
      if (t.startsWith('selection:')) {
         opts = t.replaceFirst('selection:', '');
         t = 'selection';
      }
      return {
        'name': f,
        'type': t,
        'options': opts,
      };
    }).toList() ?? []).obs;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: Get.isDarkMode ? 0.5 : 0.1), blurRadius: 40, spreadRadius: 5)],
        ),
        child: Column(
          children: [
            Container(
              width: 50, height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: AppTheme.glassBorder, borderRadius: BorderRadius.circular(10)),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type == null ? '✨ إنشاء بوابة خير جديدة' : '⚙️ تعديل إعدادات الخدمة',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Tajawal')),
                    const SizedBox(height: 24),
                    
                    _buildLabel('المسمى الرسمي للخدمة'),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: AppTheme.inputDecoration('مثال: كفالة اليتيم، إطعام...', Icons.auto_awesome_outlined),
                    ),
                    const SizedBox(height: 24),

                    _buildLabel('اختر الرمز المعبر'),
                    Obx(() => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: AppConstants.charityIcons.map((item) {
                          bool isSelected = selectedIcon.value == item['name'];
                          return GestureDetector(
                            onTap: () => selectedIcon.value = item['name'],
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder, width: 2),
                                boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.3), blurRadius: 8)] : null,
                              ),
                              child: Icon(item['icon'], color: isSelected ? Colors.white : AppTheme.textSecondary, size: 24),
                            ),
                          );
                        }).toList(),
                      ),
                    )),
                    const SizedBox(height: 24),

                    _buildLabel('لون الهوية البصرية'),
                    Obx(() => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: AppConstants.charityColors.map((item) {
                          final itemColor = item['color'] as Color;
                          bool isSelected = selectedColor.value.toARGB32() == itemColor.toARGB32();
                          return GestureDetector(
                            onTap: () => selectedColor.value = itemColor,
                            child: Container(
                              margin: const EdgeInsetsDirectional.only(start: 12),
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: itemColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: isSelected ? (Get.isDarkMode ? Colors.white : Colors.black) : Colors.transparent, width: 3),
                                boxShadow: isSelected ? [BoxShadow(color: itemColor.withValues(alpha: 0.4), blurRadius: 10)] : null,
                              ),
                              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                            ),
                          );
                        }).toList(),
                      ),
                    )),
                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLabel('تخصيص الحقول الذكية'),
                        _buildSmallActionBtn('أضف حقل', Icons.add_circle_outline, () => fields.add({'name': '', 'type': 'text', 'options': ''})),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Obx(() => Column(
                      children: fields.asMap().entries.map((entry) {
                        int idx = entry.key;
                        var field = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.glassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      onChanged: (v) => fields[idx]['name'] = v,
                                      controller: TextEditingController(text: field['name'])..selection = TextSelection.collapsed(offset: field['name']!.length),
                                      style: TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                                      decoration: InputDecoration(
                                        hintText: 'اسم الحقل (مثل: العنوان)',
                                        hintStyle: TextStyle(color: AppTheme.textHint, fontSize: 13),
                                        border: InputBorder.none,
                                        prefixIcon: const Icon(Icons.edit_note_rounded, size: 20, color: AppTheme.primaryGreen),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: DropdownButton<String>(
                                        value: field['type'],
                                        dropdownColor: AppTheme.surfaceColor,
                                        underline: const SizedBox(),
                                        isExpanded: true,
                                        style: const TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                                        items: [
                                          _dropItem('📝 نص', 'text'),
                                          _dropItem('🔢 رقم', 'number'),
                                          _dropItem('✅ خيارات', 'selection'),
                                          _dropItem('📅 تاريخ', 'date'),
                                          _dropItem('📍 ولاية', 'wilaya'),
                                          _dropItem('🩸 فصيلة دم', 'blood_type'),
                                          _dropItem('🚻 جنس', 'gender'),
                                        ],
                                        onChanged: (v) {
                                          var newField = Map<String, String>.from(fields[idx]);
                                          newField['type'] = v!;
                                          fields[idx] = newField;
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () => fields.removeAt(idx),
                                    child: Icon(Icons.delete_sweep_rounded, color: AppTheme.errorColor.withValues(alpha: 0.8), size: 24),
                                  ),
                                ],
                              ),
                              if (field['type'] == 'selection') ...[
                                const Divider(color: AppTheme.glassBorder),
                                TextField(
                                  onChanged: (v) {
                                    var newField = Map<String, String>.from(fields[idx]);
                                    newField['options'] = v;
                                    fields[idx] = newField;
                                  },
                                  controller: TextEditingController(text: field['options'] ?? '')..selection = TextSelection.collapsed(offset: (field['options'] ?? '').length),
                                  style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                                  decoration: InputDecoration(
                                    hintText: 'الخيارات مفصولة بفاصلة (مثال: نعم,لا)',
                                    hintStyle: TextStyle(color: AppTheme.textHint, fontSize: 11),
                                    border: InputBorder.none,
                                    prefixIcon: const Icon(Icons.list_alt_rounded, size: 16, color: Colors.blueAccent),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    )),
                    const SizedBox(height: 40),
                    _buildActionButton(
                      label: type == null ? 'إطلاق الخدمة الآن' : 'حفظ التعديلات الذكية',
                      icon: type == null ? Icons.rocket_launch_rounded : Icons.save_as_rounded,
                      isPrimary: true,
                      onTap: () async {
                        if (nameController.text.isEmpty) return;
                        
                        final List<String> fieldNames = fields.map((e) => e['name']!).where((e) => e.isNotEmpty).toList();
                        final Map<String, String> fieldConfigs = {
                          for (var f in fields) if (f['name']!.isNotEmpty) f['name']!: f['type'] == 'selection' && f.containsKey('options') && f['options']!.isNotEmpty ? 'selection:${f['options']}' : f['type']!
                        };

                        final String colorHex = '#${selectedColor.value.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

                        final data = {
                          'name': nameController.text,
                          'icon': selectedIcon.value,
                          'color': colorHex,
                          'fields': fieldNames,
                          'fieldConfigs': fieldConfigs,
                          'isActive': type?.isActive ?? true,
                          'updatedAt': FieldValue.serverTimestamp(),
                        };

                        if (type == null) {
                          await FirebaseFirestore.instance.collection('service_types').add({
                            ...data,
                            'createdAt': FieldValue.serverTimestamp(),
                            'popularity': 0,
                          });
                          Get.back();
                          Get.snackbar('🚀 تم الانطلاق', 'تم إنشاء الخدمة الجديدة ودمجها في النظام بنجاح', 
                            backgroundColor: AppTheme.successColor.withValues(alpha: 0.2), colorText: AppTheme.successColor);
                        } else {
                          await Get.find<AdminController>().updateServiceType(type.id, data);
                          Get.back();
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildSmallActionBtn(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryGreen),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  DropdownMenuItem<String> _dropItem(String label, String value) {
    return DropdownMenuItem(value: value, child: Text(label, style: const TextStyle(fontFamily: 'Tajawal')));
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12.0, end: 4),
      child: Text(text, style: TextStyle(color: AppTheme.textPrimary.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Tajawal')),
    );
  }
}
