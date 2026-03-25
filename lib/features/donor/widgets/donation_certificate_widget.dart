import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';

class DonationCertificateWidget extends StatelessWidget {
  final String donorName;
  final String date;
  final String amount;

  const DonationCertificateWidget({
    super.key,
    required this.donorName,
    required this.date,
    this.amount = "",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.5), width: 2),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: -30,
            left: -30,
            child: Icon(Icons.mosque, 
              size: 200, 
              color: AppTheme.primaryGreen.withValues(alpha: 0.05)
            ),
          ),
          
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppLogo(size: 60, showGlow: false),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("ناس الخير - رقان", 
                        style: TextStyle(
                          color: AppTheme.primaryGreen, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 18,
                          fontFamily: 'Tajawal'
                        )
                      ),
                      Text("Ness Elkhir - Reggane", 
                        style: TextStyle(
                          color: AppTheme.textSecondary, 
                          fontSize: 12,
                          fontFamily: 'Tajawal'
                        )
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              Container(
                height: 2,
                width: 100,
                decoration: const BoxDecoration(gradient: AppTheme.goldGradient),
              ),
              
              const SizedBox(height: 30),

              const Text(
                "شَهَادَةُ شُكْرٍ وَتَقْدِير",
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.goldAccent,
                  letterSpacing: 2,
                ),
              ),
              
              const SizedBox(height: 10),
              
              Text(
                "\"مَن تَصَدَّقَ بعَدْلِ تَمْرَةٍ مِن كَسْبٍ طَيِّب\"",
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 40),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'Tajawal', 
                    color: AppTheme.textPrimary, 
                    fontSize: 17, 
                    height: 1.8
                  ),
                  children: [
                    const TextSpan(text: "بكل فخر واعتزاز، نتقدم بوافر الشكر والتقدير للمتبرع الكريم:\n"),
                    TextSpan(
                      text: "« $donorName »\n",
                      style: const TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.bold, 
                        color: AppTheme.primaryGreen
                      ),
                    ),
                    const TextSpan(text: "على مساهمته الطيبة التي طاب أصلها وزكا ثمرها، سائلين المولى عز وجل أن يبارك له في ماله وأهله ويجعلها في ميزان حسناته."),
                  ],
                ),
              ),

              const SizedBox(height: 50),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("تحريراً في:", style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      Text(date, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.verified_user_outlined, color: AppTheme.primaryGreen, size: 35),
                  ),
                  
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("التوقيع", style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      Text("إدارة التطبيق", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
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
}
