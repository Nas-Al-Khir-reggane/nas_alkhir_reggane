import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';
import '../../../core/utils/default_avatars.dart';
import '../controllers/auth_controller.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedAvatar = DefaultAvatars.getRandomAvatar(_selectedRole);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGreen.withAlpha(20),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGreen.withAlpha(13),
              ),
            ),
          ),

          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  FadeInDown(child: const AppLogo(size: 70)),
                  const SizedBox(height: 16),
                  FadeInDown(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      'إنشاء حساب جديد',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  FadeInUp(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.glassDecoration,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildTextField(
                              context,
                              controller: _nameController,
                              label: 'اسم المستخدم',
                              icon: Icons.person_outline,
                              validator: (v) => v!.isEmpty ? 'يرجى إدخال الاسم' : null,
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              context,
                              controller: _phoneController,
                              label: 'رقم الهاتف',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: (v) => v!.isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              context,
                              controller: _emailController,
                              label: 'البريد الإلكتروني',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => !GetUtils.isEmail(v!) ? 'بريد إلكتروني غير صالح' : null,
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              context,
                              controller: _passwordController,
                              label: 'كلمة المرور',
                              icon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              validator: (v) => v!.length < 6 ? '6 أحرف على الأقل' : null,
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              context,
                              controller: _confirmPasswordController,
                              label: 'تأكيد كلمة المرور',
                              icon: Icons.lock_outline,
                              obscureText: _obscureConfirmPassword,
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                              validator: (v) => v != _passwordController.text ? 'كلمة المرور غير متطابقة' : null,
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedWilaya,
                              decoration: const InputDecoration(
                                labelText: 'الولاية',
                                prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.primaryGreen),
                              ),
                              items: AppConstants.algeriaWilayas.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                              onChanged: (v) {
                                setState(() {
                                  _selectedWilaya = v;
                                  _selectedCommune = null;
                                });
                              },
                              validator: (v) => v == null ? 'يرجى اختيار الولاية' : null,
                              dropdownColor: Theme.of(context).colorScheme.surface,
                              style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal'),
                            ),
                            const SizedBox(height: 14),
                            if (_selectedWilaya != null)
                              FadeInDown(
                                duration: const Duration(milliseconds: 300),
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedCommune,
                                  decoration: const InputDecoration(
                                    labelText: 'البلدية',
                                    prefixIcon: Icon(Icons.map_outlined, color: AppTheme.primaryGreen),
                                  ),
                                  items: AppConstants.getCommunesForWilaya(_selectedWilaya!)
                                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                      .toList(),
                                  onChanged: (v) => setState(() => _selectedCommune = v),
                                  validator: (v) => v == null ? 'يرجى اختيار البلدية' : null,
                                  dropdownColor: Theme.of(context).colorScheme.surface,
                                  style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal'),
                                ),
                              ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              context,
                              controller: _addressController,
                              label: 'العنوان التفصيلي',
                              icon: Icons.home_outlined,
                              maxLines: 2,
                              validator: (v) => v!.isEmpty ? 'يرجى إدخال العنوان' : null,
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<UserRole>(
                              initialValue: _selectedRole,
                              decoration: const InputDecoration(
                                labelText: 'نوع الحساب',
                                prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.primaryGreen),
                              ),
                              items: const [
                                DropdownMenuItem(value: UserRole.worker, child: Text('عامل')),
                                DropdownMenuItem(value: UserRole.donor, child: Text('متبرع')),
                                DropdownMenuItem(value: UserRole.beneficiary, child: Text('مستفيد')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _selectedRole = v;
                                    _selectedAvatar = DefaultAvatars.getRandomAvatar(v);
                                  });
                                }
                              },
                              dropdownColor: Theme.of(context).colorScheme.surface,
                              style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal'),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text('اختر صورة مبدئية لحسابك:', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 70,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: 10,
                                itemBuilder: (context, index) {
                                  final avatarUrl = DefaultAvatars.getAvatarsForRole(_selectedRole)[index];
                                  final isSelected = _selectedAvatar == avatarUrl;
                                  return GestureDetector(
                                    onTap: () => setState(() => _selectedAvatar = avatarUrl),
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 12),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
                                          width: 3,
                                        ),
                                        boxShadow: isSelected ? [AppTheme.greenGlow.first] : null,
                                      ),
                                      child: CircleAvatar(
                                        radius: 30,
                                        backgroundColor: AppTheme.darkCard,
                                        backgroundImage: NetworkImage(avatarUrl),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            Obx(() => authController.isLoading.value
                                ? const CircularProgressIndicator()
                                : SizedBox(
                                    width: double.infinity,
                                    child: AppTheme.gradientButton(
                                      text: 'إنشاء الحساب',
                                      icon: Icons.person_add,
                                      onPressed: () {
                                        if (_formKey.currentState!.validate()) {
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
                                          );
                                        }
                                      },
                                    ),
                                  )),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => Get.back(),
                              child: Text(
                                'لديك حساب؟ سجل دخول',
                                style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Tajawal'),
                              ),
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
        ],
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      style: TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }
}
