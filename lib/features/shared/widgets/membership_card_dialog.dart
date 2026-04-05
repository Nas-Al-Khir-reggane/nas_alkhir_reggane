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
  final Color cardColor; // إضافة متغير لتغيير اللون

  const MembershipCardWidget({
    super.key,
    required this.user,
    required this.screenshotController,
    this.cardColor = const Color(0xFF1B5E20), // اللون الافتراضي (الأخضر)
  });

  @override
  Widget build(BuildContext context) {
    return Screenshot(
      controller: screenshotController,
      child: Container(
        width: 350,
        height: 540, // تم زيادة الارتفاع قليلاً لتفادي الفيضان
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cardColor, // استخدام اللون المختار
              cardColor.withOpacity(0.8),
              cardColor.withOpacity(0.6),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 25), // تقليل البادينغ العمودي
              child: Column(
                mainAxisSize: MainAxisSize.min, // العناية بحجم العناصر
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
                      radius: 50, // تصغير قطر الصورة قليلاً (كان 55)
                      backgroundColor: Colors.white.withOpacity(0.1),
                      backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
                          ? NetworkImage(user.profileImage!)
                          : null,
                      child: user.profileImage == null || user.profileImage!.isEmpty
                          ? const Icon(Icons.person, size: 60, color: Colors.white70)
                          : null,
                    ),
                  ),

                  const SizedBox(height: 15), // تقليل المسافة (كانت 20)

                  // Name and ID
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    maxLines: 1, // منع السقوط لسطر جديد
                    overflow: TextOverflow.ellipsis, // إضافة نقاط للتعبئة الزائدة
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
                      'nesselkheir-${user.id.substring(user.id.length - 6).toUpperCase()}',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 10, // تصغير حجم الخط قليلاً ليتناسب مع الطول الجديد
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 25), // تقليل المسافة (كانت 30)

                  // Details Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDetailItem('المهمة', user.role.displayName, Icons.star_border_rounded),
                      _buildDetailItem('الزمرة', user.bloodType ?? '--', Icons.bloodtype_outlined),
                      _buildDetailItem('الولاية', user.wilaya.split(' - ').last, Icons.map_outlined),
                    ],
                  ),

                  const SizedBox(height: 20), // مسافة ثابتة بدل Spacer لتفادي الفيضان في التصوير

                  // Bottom QR and Signature
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4), // تقليل البادينغ الداخلي
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: QrImageView(
                          data: 'USER:${user.id}',
                          version: QrVersions.auto,
                          size: 60, // تصغير الـ QR قليلاً (كان 65)
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
                            'معا نبني .. معا نرحم',
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

class MembershipCardDialog extends StatefulWidget { // تحويلها لـ StatefulWidget لتغيير الحالة
  final UserModel user;

  const MembershipCardDialog({super.key, required this.user});

  @override
  State<MembershipCardDialog> createState() => _MembershipCardDialogState();
}

class _MembershipCardDialogState extends State<MembershipCardDialog> {
  final ScreenshotController screenshotController = ScreenshotController();
  Color selectedColor = const Color(0xFF1B5E20); // اللون المبدئي

  final List<Color> cardColors = [
    const Color(0xFF1B5E20), // أخضر (رسمي)
    const Color(0xFF1A237E), // أزرق ملكي
    const Color(0xFFB71C1C), // أحمر دافئ
    const Color(0xFF4A148C), // بنفسجي فاخر
    const Color(0xFF004D40), // تيل عميق
    const Color(0xFF212121), // أسود فخم
    const Color(0xFFBF8F00), // ذهبي/بني محروق
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MembershipCardWidget(
            user: widget.user,
            screenshotController: screenshotController,
            cardColor: selectedColor, // تمرير اللون المحدد
          ),
          const SizedBox(height: 20),
          // محدد الألوان
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: cardColors.map((color) => GestureDetector(
                onTap: () => setState(() => selectedColor = color),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectedColor == color ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      if (selectedColor == color)
                        BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)
                    ],
                  ),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 20),
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
