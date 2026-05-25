import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';
import '../../../core/utils/default_avatars.dart';
import '../controllers/auth_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();

  String? _selectedWilaya;
  String? _selectedCommune;
  UserRole _selectedRole = UserRole.worker;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _selectedAvatar;
  
  String? _selectedBloodType;
  String? _selectedGender;
  String? _selectedWorkerRole;
  final List<String> _selectedServices = []; 
  String? _ghuslExpertise; 
  final _otherServicesController = TextEditingController(); 
  
  DateTime? _lastDonationDate;
  bool _hasNeverDonated = false;

  bool _isCompletingProfile = false;
  String? _existingUid;

  final List<Map<String, dynamic>> _workerRoles = [
    {'id': 'funeral_transport', 'name': 'جنائز (نقل)', 'icon': Icons.airport_shuttle_rounded},
    {'id': 'funeral_ghusl', 'name': 'تغسيل الموتى', 'icon': Icons.wash_rounded},
    {'id': 'medical_aid', 'name': 'تمريض / إسعاف', 'icon': Icons.medical_services_rounded},
    {'id': 'blood_donation', 'name': 'تبرع بالدم', 'icon': Icons.bloodtype_rounded},
    {'id': 'food_aid', 'name': 'توزيع مساعدات', 'icon': Icons.shopping_bag_rounded},
    {'id': 'construction', 'name': 'ترميم وصيانة', 'icon': Icons.construction_rounded},
    {'id': 'other', 'name': 'تخصصات أخرى', 'icon': Icons.more_horiz_rounded},
  ];

  @override
  void initState() {
    super.initState();
    if (Get.arguments != null && Get.arguments is Map) {
      final args = Get.arguments as Map;
      if (args['isCompletingProfile'] == true) {
        _isCompletingProfile = true;
        _existingUid = args['uid'];
        _emailController.text = args['email'] ?? '';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _otherServicesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // خلفية زخرفية
          Positioned(top: -80, right: -60, child: _buildBgCircle(320, 0.04)),
          Positioned(bottom: -120, left: -60, child: _buildBgCircle(220, 0.03)),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    FadeInDown(child: const AppLogo(size: 60)),
                    const SizedBox(height: 16),
                    FadeInDown(
                      delay: const Duration(milliseconds: 100),
                      child: Text(
                        _isCompletingProfile ? 'استكمال بياناتك' : 'انضم لعائلة ناس الخير',
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.w900, 
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // البطاقة 1: نوع الحساب
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: _buildCard(
                        title: 'نوع الحساب',
                        icon: Icons.supervised_user_circle_outlined,
                        child: Column(
                          children: [
                            _buildRoleSelection(),
                            if (_selectedRole == UserRole.worker) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Divider(height: 1, thickness: 1),
                              ),
                              _buildWorkerRoleSelection(),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // البطاقة 2: المعلومات الشخصية
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: _buildCard(
                        title: 'المعلومات الشخصية',
                        icon: Icons.person_outline_rounded,
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildTextField(
                                  controller: _nameController,
                                  label: 'الاسم الكامل',
                                  hint: 'الاسم واللقب...',
                                  icon: Icons.person_pin_rounded,
                                  validator: (v) => v!.isEmpty ? 'حقل إجباري' : null,
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: _buildTextField(
                                  controller: _phoneController,
                                  label: 'رقم الهاتف',
                                  hint: '0XXXXXXXXX',
                                  icon: Icons.phone_android_rounded,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  validator: (v) => v!.length < 10 ? 'رقم غير صحيح' : null,
                                )),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _emailController,
                              label: 'البريد الإلكتروني',
                              hint: 'example@mail.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              readOnly: _isCompletingProfile,
                              validator: (v) => v!.isEmpty || !v.contains('@') ? 'بريد غير صالح' : null,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildBloodTypeDropdown()),
                                const SizedBox(width: 12),
                                Expanded(child: _buildGenderSelection()),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildLastDonationDatePicker(),
                          ],
                        ),
                      ),
                    ),

                    // البطاقة 3: الموقع
                    FadeInUp(
                      delay: const Duration(milliseconds: 400),
                      child: _buildCard(
                        title: 'الموقع والسكن',
                        icon: Icons.location_on_outlined,
                        child: Column(
                          children: [
                            _buildLocationDropdowns(),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _addressController,
                              label: 'العنوان التفصيلي',
                              hint: 'الحي، الشارع، رقم المنزل...',
                              icon: Icons.home_work_outlined,
                              maxLines: 2,
                              validator: (v) => v!.isEmpty ? 'حقل إجباري' : null,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // البطاقة 4: الأمان
                    if (!_isCompletingProfile)
                      FadeInUp(
                        delay: const Duration(milliseconds: 500),
                        child: _buildCard(
                          title: 'الأمان',
                          icon: Icons.lock_person_outlined,
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _passwordController,
                                label: 'كلمة المرور',
                                hint: 'أدخل كلمة مرور قوية...',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                validator: (v) => v!.length < 6 ? '6 رموز على الأقل' : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _confirmPasswordController,
                                label: 'تأكيد كلمة المرور',
                                hint: 'أعد كتابة كلمة المرور...',
                                icon: Icons.check_circle_outline_rounded,
                                obscureText: _obscureConfirmPassword,
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                                validator: (v) => v != _passwordController.text ? 'غير متطابقة' : null,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // البطاقة 5: الصورة الشخصية
                    FadeInUp(
                      delay: const Duration(milliseconds: 600),
                      child: _buildCard(
                        title: 'الصورة الشخصية (اختياري)',
                        icon: Icons.face_retouching_natural_rounded,
                        child: _buildAvatarSelector(),
                      ),
                    ),

                    const SizedBox(height: 20),
                    // زر الإرسال
                    FadeInUp(
                      delay: const Duration(milliseconds: 700),
                      child: Obx(() => authController.isLoading.value
                          ? const Center(child: CircularProgressIndicator())
                          : SizedBox(
                              width: double.infinity,
                              child: AppTheme.gradientButton(
                                text: _isCompletingProfile ? 'حفظ وإكمال الملف' : 'إنشاء حساب جديد',
                                icon: _isCompletingProfile ? Icons.save_rounded : Icons.person_add_alt_1_rounded,
                                onPressed: _submitForm,
                              ),
                            )),
                    ),
                    const SizedBox(height: 20),
                    if (!_isCompletingProfile)
                      FadeInUp(
                        delay: const Duration(milliseconds: 800),
                        child: TextButton(
                          onPressed: () => Get.back(),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: 'Tajawal', fontSize: 13),
                              children: [
                                const TextSpan(text: 'لديك حساب؟ '),
                                TextSpan(
                                  text: 'سجل دخولك',
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_selectedGender == null) {
        Get.snackbar('تنبيه', 'يرجى اختيار الجنس (إجباري)', backgroundColor: Colors.orange.withValues(alpha: 0.15));
        return;
      }
      if (_selectedBloodType == null) {
        Get.snackbar('تنبيه', 'يرجى اختيار فصيلة الدم (إجبارية)', backgroundColor: Colors.orange.withValues(alpha: 0.15));
        return;
      }
      if (!_hasNeverDonated && _lastDonationDate == null) {
        Get.snackbar('تنبيه', 'يرجى تحديد تاريخ آخر تبرع أو اختيار "لم يسبق لي التبرع"', backgroundColor: Colors.orange.withValues(alpha: 0.15));
        return;
      }

      final authController = Get.find<AuthController>();
      
      if (_isCompletingProfile) {
        authController.completeProfile(
          uid: _existingUid!,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          wilaya: _selectedWilaya!,
          commune: _selectedCommune!,
          address: _addressController.text.trim(),
          email: _emailController.text.trim(),
          gender: _selectedGender!,
          role: _selectedRole,
          profileImage: _selectedAvatar,
          bloodType: _selectedBloodType!,
          workerRole: _selectedWorkerRole,
          volunteerServices: _selectedServices,
          ghuslExpertise: _ghuslExpertise,
          otherServices: _otherServicesController.text.trim(),
          lastDonatedAt: _lastDonationDate,
        );
      } else {
        authController.register(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          wilaya: _selectedWilaya!,
          commune: _selectedCommune!,
          address: _addressController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          role: _selectedRole,
          profileImage: _selectedAvatar,
          bloodType: _selectedBloodType!,
          gender: _selectedGender!,
          workerRole: _selectedWorkerRole,
          volunteerServices: _selectedServices,
          ghuslExpertise: _ghuslExpertise,
          otherServices: _otherServicesController.text.trim(),
          lastDonatedAt: _lastDonationDate,
        );
      }
    }
  }

  Widget _buildCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildBgCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: opacity),
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Row(
      children: [
        _buildRoleCard(UserRole.worker, 'متطوع', Icons.handyman_outlined),
        const SizedBox(width: 12),
        _buildRoleCard(UserRole.donor, 'متبرع', Icons.favorite_border_rounded),
      ],
    );
  }

  Widget _buildRoleCard(UserRole role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedRole = role;
            _selectedAvatar = DefaultAvatars.getRandomAvatar(role, _selectedGender ?? 'ذكر');
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1), 
              width: 1.5
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5), size: 28),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(
                fontSize: 13, 
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold, 
                color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                fontFamily: 'Tajawal'
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkerRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('تخصص التطوع (اختر تخصصاً واحداً أو أكثر):', 
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
        const SizedBox(height: 16),
        
        // استخدام GridView لتنظيم الخيارات بشكل متناظر (2 في كل صف)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.8,
          ),
          itemCount: 6, // أول 6 تخصصات (أزواج منطقية)
          itemBuilder: (context, index) => _buildServiceItem(_workerRoles[index]),
        ),
        const SizedBox(height: 12),
        // التخصص الأخير "أخرى" يأخذ العرض كاملاً للتوازن
        _buildServiceItem(_workerRoles[6]),

        if (_selectedServices.contains('funeral_ghusl')) ...[
          const SizedBox(height: 20),
          const Text('مستوى الخبرة في التغسيل:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildExpertiseChip('خبير / قائد غسل', 'expert')),
              const SizedBox(width: 12),
              Expanded(child: _buildExpertiseChip('مساعد متدرب', 'assistant')),
            ],
          ),
        ],
        if (_selectedServices.contains('other')) ...[
          const SizedBox(height: 16),
          _buildTextField(
            controller: _otherServicesController,
            label: 'تخصصات أخرى',
            hint: 'مثال: صيانة، طبخ...',
            icon: Icons.add_task_rounded,
          ),
        ],
      ],
    );
  }

  Widget _buildServiceItem(Map<String, dynamic> role) {
    final id = role['id'];
    final name = role['name'];
    final icon = role['icon'];
    final isSelected = _selectedServices.contains(id);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedServices.remove(id);
            if (id == 'funeral_ghusl') _ghuslExpertise = null;
          } else {
            _selectedServices.add(id);
          }
        });
      },
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Theme.of(context).dividerColor.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              size: 20, 
              color: isSelected ? AppTheme.primaryGreen : Colors.grey[500]
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary,
                  fontFamily: 'Tajawal',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpertiseChip(String label, String value) {
    final isSelected = _ghuslExpertise == value;
    return GestureDetector(
      onTap: () => setState(() => _ghuslExpertise = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
              size: 16,
              color: isSelected ? AppTheme.primaryGreen : AppTheme.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'Tajawal'
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderSelection() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _selectedGender,
      decoration: AppTheme.inputDecoration('الجنس', Icons.people_outline_rounded).copyWith(labelText: 'الجنس *', contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16)),
      items: ['ذكر', 'أنثى'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: (v) {
        setState(() {
          _selectedGender = v;
          _selectedAvatar = DefaultAvatars.getRandomAvatar(_selectedRole, _selectedGender!);
        });
      },
      validator: (v) => v == null ? 'إجباري' : null,
    );
  }

  Widget _buildBloodTypeDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _selectedBloodType,
      decoration: AppTheme.inputDecoration('فصيلة الدم', Icons.bloodtype_outlined).copyWith(labelText: 'فصيلة الدم *', contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16)),
      items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: (v) => setState(() => _selectedBloodType = v),
      validator: (v) => v == null ? 'إجباري' : null,
    );
  }

  Widget _buildLastDonationDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: _hasNeverDonated,
                activeColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (val) {
                  setState(() {
                    _hasNeverDonated = val ?? false;
                    if (_hasNeverDonated) _lastDonationDate = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            const Text('لم يسبق لي التبرع بالدم', style: TextStyle(fontSize: 13, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ],
        ),
        if (!_hasNeverDonated) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _lastDonationDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                locale: const Locale('ar', 'DZ'),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: Theme.of(context).colorScheme.primary,
                        onPrimary: Colors.white,
                        surface: Theme.of(context).cardColor,
                        onSurface: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) setState(() => _lastDonationDate = date);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_available_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    _lastDonationDate == null 
                        ? 'تاريخ آخر تبرع *' 
                        : DateFormat('yyyy-MM-dd').format(_lastDonationDate!),
                    style: TextStyle(
                      fontSize: 13,
                      color: _lastDonationDate == null ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface,
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    int maxLines = 1,
    int? maxLength,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      decoration: AppTheme.inputDecoration(hint, icon).copyWith(
        labelText: label, 
        suffixIcon: suffixIcon, 
        counterText: '',
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      validator: validator,
    );
  }

  Widget _buildLocationDropdowns() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedWilaya,
            decoration: AppTheme.inputDecoration('الولاية', Icons.map_outlined).copyWith(labelText: 'الولاية *', contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16)),
            items: AppConstants.algeriaWilayas.map((w) => DropdownMenuItem(value: w, child: Text(w, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) {
              setState(() {
                _selectedWilaya = v;
                _selectedCommune = null;
              });
            },
            validator: (v) => v == null ? 'إجباري' : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedCommune,
            decoration: AppTheme.inputDecoration('البلدية', Icons.location_city_rounded).copyWith(labelText: 'البلدية *', contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16)),
            items: _selectedWilaya == null ? [] : AppConstants.getCommunesForWilaya(_selectedWilaya!)
                .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _selectedCommune = v),
            validator: (v) => v == null ? 'إجباري' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarSelector() {
    final avatars = DefaultAvatars.getAvatarsForRole(_selectedRole, _selectedGender ?? 'ذكر');
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: avatars.length,
        itemBuilder: (context, index) {
          final avatarUrl = avatars[index];
          final isSelected = _selectedAvatar == avatarUrl;
          return GestureDetector(
            onTap: () => setState(() => _selectedAvatar = avatarUrl),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsetsDirectional.only(end: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3)
              ),
              child: CircleAvatar(
                radius: 30, 
                backgroundColor: Theme.of(context).cardColor, 
                backgroundImage: CachedNetworkImageProvider(avatarUrl)
              ),
            ),
          );
        },
      ),
    );
  }
}
