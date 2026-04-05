import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/user_model.dart';
import '../../../core/theme/app_theme.dart';

class MembershipCardWidget extends StatelessWidget {
  final UserModel user;
  final ScreenshotController screenshotController;

  const MembershipCardWidget({
    super.key,
    required this.user,
    required this.screenshotController,
  });

  @override
  Widget build(BuildContext context) {
    return Screenshot(
      controller: screenshotController,
      child: Container(
        width: 350,
        height: 520,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B5E20), // Dark Green
              Color(0xFF2E7D32), // Emerald
              Color(0xFF43A047), // Light Emerald
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative background patterns
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -30,
              child: Transform.rotate(
                angle: 0.5,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withOpacity(0.03),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                children: [
                   // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset(
                        'assets/images/nas_alkhir_app.png',
                        height: 50,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'بطاقة انخراط',
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'ناسى الخير رقان',
                            style: GoogleFonts.tajawal(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 35),

                  // Profile Image
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
                          ? NetworkImage(user.profileImage!)
                          : null,
                      child: user.profileImage == null || user.profileImage!.isEmpty
                          ? const Icon(Icons.person, size: 60, color: Colors.white70)
                          : null,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Name and ID
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      'ID: NKR-${user.id.substring(user.id.length - 6).toUpperCase()}',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Details Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDetailItem('الرتبة', user.role.displayName, Icons.star_border_rounded),
                      _buildDetailItem('الزمرة', user.bloodType ?? '--', Icons.bloodtype_outlined),
                      _buildDetailItem('الولاية', user.wilaya.split(' - ').last, Icons.map_outlined),
                    ],
                  ),

                  const Spacer(),

                  // Bottom QR and Signature
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(
                          data: 'USER:${user.id}',
                          version: QrVersions.auto,
                          size: 65,
                          gapless: false,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_user_rounded, color: Colors.white70, size: 24),
                          const SizedBox(height: 4),
                          Text(
                            'التوقيع الرسمي',
                            style: GoogleFonts.tajawal(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 8,
                            ),
                          ),
                          Text(
                            'إكرام الميت رحمة',
                            style: GoogleFonts.marckScript( // Using a script font for signature feel
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white60, size: 18),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.tajawal(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class MembershipCardDialog extends StatelessWidget {
  final UserModel user;
  final ScreenshotController screenshotController = ScreenshotController();

  MembershipCardDialog({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MembershipCardWidget(
            user: user,
            screenshotController: screenshotController,
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                icon: Icons.share_rounded,
                label: 'مشاركة',
                onPressed: () => _captureAndShare(context),
                primary: true,
              ),
              const SizedBox(width: 20),
              _buildActionButton(
                icon: Icons.close_rounded,
                label: 'إغلاق',
                onPressed: () => Get.back(),
                primary: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool primary,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: primary ? Colors.white : Colors.white10,
        foregroundColor: primary ? const Color(0xFF1B5E20) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: primary ? 5 : 0,
      ),
    );
  }

  Future<void> _captureAndShare(BuildContext context) async {
    try {
      final image = await screenshotController.capture();
      if (image != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/membership_card.png').create();
        await imagePath.writeAsBytes(image);
        
        await Share.shareXFiles(
          [XFile(imagePath.path)],
          text: 'بطاقة عضوية ناس الخير رقان - فخور بانتمائي 🕊️',
        );
      }
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تصوير البطاقة: $e');
    }
  }
}

