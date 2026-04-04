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
  UserRole _selectedRole = UserRole.beneficiary;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _selectedAvatar;
  
  String? _selectedBloodType;
  String _selectedGender = 'ذكر';
  String? _selectedWorkerRole;
  final List<String> _selectedServices = []; 
  String? _ghuslExpertise; 
  final _otherServicesController = TextEditingController(); 

  bool _isCompletingProfile = false;
  String? _existingUid;

  final List<Map<String, dynamic>> _workerRoles = [
    {'id': 'funeral_transport', 'name': 'جنائز (نقل)', 'icon': Icons.airport_shuttle_rounded},
    {'id': 'funeral_ghusl', 'name': 'تغسيل الموتى', 'icon': Icons.wash_rounded},
    {'id': 'medical_aid', 'name': 'تمريض / إسعاف', 'icon': Icons.medical_services_rounded},
    {'id': 'food_aid', 'name': 'توزيع مساعدات', 'icon': Icons.shopping_bag_rounded},
    {'id': 'construction', 'name': 'ترميم وصيانة', 'icon': Icons.construction_rounded},
    {'id': 'blood_donation', 'name': 'تبرع بالدم', 'icon': Icons.bloodtype_rounded},
    {'id': 'other', 'name': 'تخصصات أخرى', 'icon': Icons.more_horiz_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _selectedAvatar = DefaultAvatars.getRandomAvatar(_selectedRole, _selectedGender);
    
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
          // خلفية زخرفية موحدة (Unified Background)
          Positioned(top: -80, right: -60, child: _buildBgCircle(320, 0.04)),
          Positioned(bottom: -120, left: -60, child: _buildBgCircle(220, 0.03)),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    FadeInDown(child: const AppLogo(size: 60)),
                    const SizedBox(height: 12),
                    FadeInDown(
                      delay: const Duration(milliseconds: 200),
                      child: Text(
                        'انضم لعائلة ناس الخير',
                        style: TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.w900, 
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    _buildSectionHeader('نوع الحساب', Icons.supervised_user_circle_outlined),
                    const SizedBox(height: 12),
                    _buildRoleSelection(),
                    
                    if (_selectedRole == UserRole.worker) ...[
                      const SizedBox(height: 20),
                      _buildSectionHeader('تخصص التطوع', Icons.handyman_rounded),
                      const SizedBox(height: 12),
                      _buildWorkerRoleSelection(),
                    ],

                    const SizedBox(height: 24),
                    _buildSectionHeader('المعلومات الشخصية', Icons.person_outline_rounded),
                    const SizedBox(height: 12),
                    _buildGenderSelection(),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _nameController,
                      label: 'الاسم الكامل',
                      hint: 'أدخل اسمك الكامل...',
                      icon: Icons.person_pin_rounded,
                      validator: (v) => v!.isEmpty ? 'يرجى إدخال اسمك' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'رقم الهاتف',
                      hint: '0XXXXXXXXX',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      validator: (v) => v!.length < 10 ? 'رقم هاتف غير صحيح' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildBloodTypeDropdown(),

                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _emailController,
                      label: 'البريد الإلكتروني',
                      hint: 'example@mail.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      readOnly: _isCompletingProfile,
                      validator: (v) => v!.isEmpty || !v.contains('@') ? 'بريد إلكتروني غير صالح' : null,
                    ),

                    const SizedBox(height: 24),
                    _buildSectionHeader('الموقع والسكن', Icons.location_on_outlined),
                    const SizedBox(height: 12),
                    _buildLocationDropdowns(),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _addressController,
                      label: 'العنوان التفصيلي',
                      hint: 'الحي، الشارع، رقم المنزل...',
                      icon: Icons.home_work_outlined,
                      maxLines: 2,
                      validator: (v) => v!.isEmpty ? 'يرجى تحديد العنوان' : null,
                    ),

                    if (!_isCompletingProfile) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader('الأمان', Icons.lock_person_outlined),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 12),
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

                    const SizedBox(height: 24),
                    _buildSectionHeader('الصورة الشخصية', Icons.face_retouching_natural_rounded),
                    const SizedBox(height: 12),
                    _buildAvatarSelector(),

                    const SizedBox(height: 40),
                    Obx(() => authController.isLoading.value
                        ? const CircularProgressIndicator()
                        : SizedBox(
                            width: double.infinity,
                            child: AppTheme.gradientButton(
                              text: _isCompletingProfile ? 'حفظ وإكمال الملف' : 'إنشاء حساب جديد',
                              icon: _isCompletingProfile ? Icons.save_rounded : Icons.person_add_alt_1_rounded,
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  if (_selectedBloodType == null) {
                                    Get.snackbar('تنبيه', 'يرجى اختيار فصيلة الدم (إجبارية)', 
                                      backgroundColor: Colors.orange.withValues(alpha: 0.15));
                                    return;
                                  }

                                    if (_isCompletingProfile) {
                                      authController.completeProfile(
                                        uid: _existingUid!,
                                        name: _nameController.text.trim(),
                                        phone: _phoneController.text.trim(),
                                        wilaya: _selectedWilaya!,
                                        commune: _selectedCommune!,
                                        address: _addressController.text.trim(),
                                        email: _emailController.text.trim(),
                                        gender: _selectedGender,
                                        role: _selectedRole,
                                        profileImage: _selectedAvatar,
                                        bloodType: _selectedBloodType!,
                                        workerRole: _selectedWorkerRole,
                                        volunteerServices: _selectedServices,
                                        ghuslExpertise: _ghuslExpertise,
                                        otherServices: _otherServicesController.text.trim(),
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
                                        gender: _selectedGender,
                                        workerRole: _selectedWorkerRole,
                                        volunteerServices: _selectedServices,
                                        ghuslExpertise: _ghuslExpertise,
                                        otherServices: _otherServicesController.text.trim(),
                                      );
                                    }
                                }
                              },
                            ),
                          )),
                    const SizedBox(height: 20),
                    TextButton(
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Tajawal')),
      ],
    );
  }

  Widget _buildRoleSelection() {
    return Row(
      children: [
        _buildRoleCard(UserRole.beneficiary, 'مستفيد', Icons.volunteer_activism_outlined),
        const SizedBox(width: 8),
        _buildRoleCard(UserRole.worker, 'متطوع', Icons.handyman_outlined),
        const SizedBox(width: 8),
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
            _selectedAvatar = DefaultAvatars.getRandomAvatar(role, _selectedGender);
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05) : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline.withValues(alpha: 0.05), 
              width: 1.5
            ),
            boxShadow: isSelected ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05), blurRadius: 10)] : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5), size: 24),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(
                fontSize: 11, 
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
        FadeIn(
          child: Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _workerRoles.map((role) {
              final isSelected = _selectedServices.contains(role['id']);
              return FilterChip(
                showCheckmark: false,
                avatar: Icon(role['icon'], 
                  size: 14, 
                  color: isSelected ? Colors.white : AppTheme.primaryGreen),
                label: Text(role['name'], 
                  style: TextStyle(
                    fontSize: 11, 
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontFamily: 'Tajawal'
                  )),
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedServices.add(role['id']);
                    } else {
                      _selectedServices.remove(role['id']);
                      if (role['id'] == 'funeral_ghusl') _ghuslExpertise = null;
                    }
                  });
                },
                selectedColor: AppTheme.primaryGreen,
                backgroundColor: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder.withValues(alpha: 0.1))
                ),
                elevation: 0,
                pressElevation: 4,
              );
            }).toList(),
          ),
        ),
        if (_selectedServices.contains('funeral_ghusl')) ...[
          const SizedBox(height: 16),
          _buildSectionHeader('مستوى الخبرة في التغسيل', Icons.star_outline_rounded),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildExpertiseChip('خبير / قائد غسل', 'expert'),
              const SizedBox(width: 10),
              _buildExpertiseChip('مساعد متدرب', 'assistant'),
            ],
          ),
        ],
        if (_selectedServices.contains('other')) ...[
          const SizedBox(height: 16),
          _buildTextField(
            controller: _otherServicesController,
            label: 'خدمات تطوعية أخرى',
            hint: 'مثال: صيانة، دعم نفسي...',
            icon: Icons.add_task_rounded,
          ),
        ],
      ],
    );
  }

  Widget _buildExpertiseChip(String label, String value) {
    final isSelected = _ghuslExpertise == value;
    return GestureDetector(
      onTap: () => setState(() => _ghuslExpertise = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.05) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
              size: 16,
              color: isSelected ? AppTheme.primaryGreen : AppTheme.textHint.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Tajawal'
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderSelection() {
    return Row(
      children: [
        _buildChoiceChip('ذكر', Icons.male_rounded),
        const SizedBox(width: 10),
        _buildChoiceChip('أنثى', Icons.female_rounded),
      ],
    );
  }

  Widget _buildChoiceChip(String label, IconData icon) {
    final isSelected = _selectedGender == label;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: isSelected ? Colors.white : null, fontSize: 12, fontFamily: 'Tajawal')),
        ],
      ),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          _selectedGender = label;
          _selectedAvatar = DefaultAvatars.getRandomAvatar(_selectedRole, _selectedGender);
        });
      },
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildBloodTypeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedBloodType,
      decoration: AppTheme.inputDecoration('فصيلة الدم (إجبارية) *', Icons.bloodtype_outlined).copyWith(labelText: 'فصيلة الدم *'),
      items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: (v) => setState(() => _selectedBloodType = v),
      validator: (v) => v == null ? 'فصيلة الدم حقل إجباري' : null,
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
      style: const TextStyle(fontSize: 14),
      decoration: AppTheme.inputDecoration(hint, icon).copyWith(
        labelText: label, 
        suffixIcon: suffixIcon, 
        counterText: '',
        labelStyle: const TextStyle(fontSize: 13)
      ),
      validator: validator,
    );
  }

  Widget _buildLocationDropdowns() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedWilaya,
          decoration: AppTheme.inputDecoration('اختر الولاية...', Icons.map_outlined).copyWith(labelText: 'الولاية'),
          items: AppConstants.algeriaWilayas.map((w) => DropdownMenuItem(value: w, child: Text(w, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: (v) {
            setState(() {
              _selectedWilaya = v;
              _selectedCommune = null;
            });
          },
          validator: (v) => v == null ? 'يرجى تحديد الولاية' : null,
        ),
        if (_selectedWilaya != null) ...[
          const SizedBox(height: 12),
          FadeInDown(
            duration: const Duration(milliseconds: 300),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedCommune,
              decoration: AppTheme.inputDecoration('اختر البلدية...', Icons.location_city_rounded).copyWith(labelText: 'البلدية'),
              items: AppConstants.getCommunesForWilaya(_selectedWilaya!)
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14))))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCommune = v),
              validator: (v) => v == null ? 'يرجى تحديد البلدية' : null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatarSelector() {
    final avatars = DefaultAvatars.getAvatarsForRole(_selectedRole, _selectedGender);
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
              margin: const EdgeInsetsDirectional.only(start: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2.5)
              ),
              child: CircleAvatar(
                radius: 28, 
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
