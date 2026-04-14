import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_theme.dart';

class RatingDialog extends StatefulWidget {
  final Function(int rating, String comment) onSubmit;

  const RatingDialog({super.key, required this.onSubmit});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: FadeInUp(
        duration: const Duration(milliseconds: 400),
        child: Container(
          decoration: BoxDecoration(
            color: context.theme.cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
            boxShadow: AppTheme.cardShadow,
            border: Border.all(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Gradient Area
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppTheme.radiusExtraLarge),
                      topRight: Radius.circular(AppTheme.radiusExtraLarge),
                    ),
                  ),
                  child: Column(
                    children: [
                      ZoomIn(
                        delay: const Duration(milliseconds: 200),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'شركاؤنا في الخير',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'رأيكم يهمنا لتطوير خدمات الجمعية',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        'كيف تقيم تجربتك مع التطبيق؟',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Stars Selection
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starIndex = index + 1;
                          final isSelected = starIndex <= _selectedRating;
                          return ZoomIn(
                            delay: Duration(milliseconds: 100 * index),
                            child: IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedRating = starIndex;
                                });
                              },
                              icon: Icon(
                                isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: isSelected ? AppTheme.goldAccent : AppTheme.textHint.withValues(alpha: 0.3),
                                size: 44,
                              ),
                            ),
                          );
                        }),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Comment Field
                      if (_selectedRating > 0)
                        FadeIn(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'أضف تعليقك (اختياري)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _commentController,
                                maxLines: 3,
                                decoration: AppTheme.inputDecoration(
                                  'اكتب هنا...',
                                  Icons.comment_outlined,
                                ),
                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Get.back(),
                              child: Text(
                                'لاحقاً',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: AppTheme.gradientButton(
                              text: 'إرسال التقييم',
                              onPressed: _selectedRating == 0 
                                ? null 
                                : () => widget.onSubmit(_selectedRating, _commentController.text),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
