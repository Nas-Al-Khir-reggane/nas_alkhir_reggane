import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        children: [
          // خلفية زخرفية
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGreen.withValues(alpha: 0.08),
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
                color: AppTheme.primaryGreen.withValues(alpha: 0.05),
              ),
            ),
          ),

          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  FadeInDown(
                    child: const AppLogo(size: 90),
                  ),
                  const SizedBox(height: 16),
                  FadeInDown(
                    delay: const Duration(milliseconds: 200),
                    child: const Text(
                      'جمعية ناس الخير رقان',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeInDown(
                    delay: const Duration(milliseconds: 300),
                    child: const Text(
                      'مرحباً بك',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.glassDecoration,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'تسجيل الدخول',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: AppTheme.textPrimary),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryGreen),
                                labelText: 'البريد الإلكتروني',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                                if (!GetUtils.isEmail(value)) return 'البريد الإلكتروني غير صالح';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: AppTheme.textPrimary),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryGreen),
                                labelText: 'كلمة المرور',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: AppTheme.textSecondary,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'يرجى إدخال كلمة المرور';
                                if (value.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),
                            Obx(() => authController.isLoading.value
                                ? const Center(child: CircularProgressIndicator())
                                : SizedBox(
                                    width: double.infinity,
                                    child: AppTheme.gradientButton(
                                      text: 'تسجيل الدخول',
                                      icon: Icons.login,
                                      onPressed: () {
                                        if (_formKey.currentState!.validate()) {
                                          authController.login(
                                            _emailController.text.trim(),
                                            _passwordController.text.trim(),
                                          );
                                        }
                                      },
                                    ),
                                  )),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'ليس لديك حساب؟',
                                  style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Tajawal'),
                                ),
                                TextButton(
                                  onPressed: () => Get.toNamed('/register'),
                                  child: const Text(
                                    'إنشاء حساب',
                                    style: TextStyle(
                                      color: AppTheme.primaryGreen,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    child: OutlinedButton.icon(
                      onPressed: () => Get.toNamed('/guest/request'),
                      icon: const Icon(Icons.person_outline),
                      label: const Text('طلب خدمة بدون تسجيل'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen.withValues(alpha: 0.8),
                        side: BorderSide(color: AppTheme.primaryGreen.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        textStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
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
}
