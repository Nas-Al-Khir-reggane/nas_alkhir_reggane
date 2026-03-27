import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Added for local QR generation
import '../theme/app_theme.dart';
import '../../../data/models/project_model.dart';
import 'geometric_progress.dart';

class ProjectShareCard extends StatelessWidget {
  final ProjectModel project;
  final Color categoryColor;
  final String categoryName;

  const ProjectShareCard({
    super.key,
    required this.project,
    required this.categoryColor,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.darkBg,
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: categoryColor.withValues(alpha: 0.6), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: categoryColor.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: -10,
          )
        ],
      ),
      child: Stack(
        children: [
          // Background Glow Decoration
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: categoryColor.withValues(alpha: 0.1),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Logo & App Name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withValues(alpha: 0.7)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.3), blurRadius: 10)],
                    ),
                    child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'جمعية ناس الخير رقان',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'Tajawal'),
                        ),
                        Text(
                          'معاً لنصنع الفرق الملموس',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.primaryGreen.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w500, fontFamily: 'Tajawal'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: categoryColor.withValues(alpha: 0.4), blurRadius: 8)],
                    ),
                    child: Text(
                      categoryName,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              
              // Project Title
              Text(
                project.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Tajawal',
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              
              // Project Description
              Text(
                project.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5, fontFamily: 'Tajawal', fontWeight: FontWeight.w400),
              ),
              
              const SizedBox(height: 25),
              
              // THE CINEMATIC PROGRESS GRID
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: GoalGridProgress(
                  budget: project.budget,
                  collected: project.collected,
                  categoryId: project.category,
                  activeColor: categoryColor,
                  isScrollable: false,
                  forceComplete: true, 
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Islamic Motivational Quote
              Center(
                child: Text(
                  'قال الله تعالى: {وَمَا تُنفِقُوا مِنْ خَيْرٍ فَإِنَّ اللَّهَ بِهِ عَلِيمٌ}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              const SizedBox(height: 25),
              
              // Footer: Stats & QR Code
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatLine('المبلغ المجمع', '${_formatPrice(project.collected)} دج', AppTheme.primaryGreen),
                          const Divider(color: Colors.white10, height: 20),
                          _buildStatLine('الهدف الإجمالي', '${_formatPrice(project.budget)} دج', Colors.white),
                          const SizedBox(height: 12),
                          // Unit details as requested by user
                          Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, color: AppTheme.textHint, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'وحدات الخير: ${(project.collected/1000).floor()} / ${(project.budget/1000).ceil()}',
                                style: TextStyle(color: AppTheme.textHint, fontSize: 10, fontFamily: 'Tajawal'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // LOCAL QR CODE - FIXED
                  Column(
                    children: [
                       Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(color: categoryColor.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: -5)
                          ],
                        ),
                        child: QrImageView(
                          data: 'https://nasalkheir.org/projects/${project.id}',
                          version: QrVersions.auto,
                          size: 90.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('امسح للمساهمة', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'Tajawal')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatLine(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 10, fontFamily: 'Tajawal')),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Tajawal')),
      ],
    );
  }

  String _formatPrice(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)} مليون';
    if (amount >= 11000) return '${(amount / 1000).toStringAsFixed(0)} ألف';
    if (amount >= 3000) return '${(amount / 1000).toStringAsFixed(0)} آلاف';
    if (amount >= 1000) return 'ألف';
    return amount.toStringAsFixed(0);
  }
}
