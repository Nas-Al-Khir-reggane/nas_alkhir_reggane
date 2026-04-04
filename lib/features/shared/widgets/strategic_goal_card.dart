import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/strategic_goal_model.dart';
import '../../../core/routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../donor/controllers/donor_controller.dart';
import '../../../data/models/user_model.dart';
import '../../../core/animations/scroll_animations.dart';
import 'package:intl/intl.dart' as intl;

class StrategicGoalCard extends StatelessWidget {
  final StrategicGoalModel goal;

  const StrategicGoalCard({
    super.key,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getGoalColor(goal.type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Get.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // خلفية خفيفة متدرجة
          Positioned(
            top: -20, right: -20,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: color.withValues(alpha: 0.05),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_getGoalIcon(goal.type), color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGoalTypeLabel(goal.type),
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal',
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              goal.title,
                              style: TextStyle(
                                color: Get.isDarkMode ? Colors.white : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (goal.isCompleted)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        child: const Icon(Icons.check, color: Colors.white, size: 14),
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                Text(
                  goal.description,
                  style: TextStyle(
                    color: Get.isDarkMode ? Colors.white60 : Colors.black54,
                    fontSize: 12,
                    fontFamily: 'Tajawal',
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Progress Section
                    Row(
                      children: [
                        ScrollAnimations.numberCounter(
                          value: goal.currentValue,
                          style: TextStyle(
                            color: color,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        Text(
                          ' / ${goal.targetValue.toInt()} ${goal.unit}',
                          style: TextStyle(
                            color: Get.isDarkMode ? Colors.white38 : Colors.black38,
                            fontSize: 12,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ],
                    ),
                    ScrollAnimations.numberCounter(
                      value: (goal.progressPercentage * 100).toInt(),
                      suffix: '%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: goal.progressPercentage,
                    minHeight: 10,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: Get.isDarkMode ? Colors.white38 : Colors.black38),
                    const SizedBox(width: 6),
                    Text(
                      'ينتهي في: ${intl.DateFormat('yyyy/MM/dd').format(goal.endDate)}',
                      style: TextStyle(
                        color: Get.isDarkMode ? Colors.white38 : Colors.black38,
                        fontSize: 10,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const Spacer(),
                    if (goal.isCompleted)
                      Text(
                        '✨ هدف محقق!',
                        style: TextStyle(color: AppTheme.successColor, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                      ),
                  ],
                ),
                
                // زر المساهمة (يظهر للمتبرعين والمدراء أيضاً)
                if (!goal.isCompleted && (Get.find<AuthController>().currentUser.value?.role == UserRole.donor || 
                    Get.find<AuthController>().currentUser.value?.role == UserRole.superAdmin || 
                    Get.find<AuthController>().currentUser.value?.role == UserRole.admin))
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: GestureDetector(
                      onTap: () {
                        final donorController = Get.find<DonorController>();
                        donorController.preSelectProject(
                          goal.projectId ?? 'general', 
                          goal.projectName ?? 'تبرع عام للجمعية'
                        );
                        Get.toNamed(AppRoutes.donorDonate);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withValues(alpha: 0.8)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 10),
                            Text(
                              'ساهم في هذا التحدي الآن',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal',
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getGoalColor(GoalType type) {
    switch (type) {
      case GoalType.donations: return Colors.orangeAccent;
      case GoalType.beneficiaries: return AppTheme.primaryGreen;
      case GoalType.services: return Colors.blueAccent;
      default: return Colors.purpleAccent;
    }
  }

  IconData _getGoalIcon(GoalType type) {
    switch (type) {
      case GoalType.donations: return Icons.volunteer_activism_rounded;
      case GoalType.beneficiaries: return Icons.people_alt_rounded;
      case GoalType.services: return Icons.settings_suggest_rounded;
      default: return Icons.rocket_launch_rounded;
    }
  }

  String _getGoalTypeLabel(GoalType type) {
    switch (type) {
      case GoalType.donations: return 'تحدي تبرعات';
      case GoalType.beneficiaries: return 'تحدي وصول';
      case GoalType.services: return 'تحدي عملياتي';
      default: return 'تحدي استراتيجي';
    }
  }
}
