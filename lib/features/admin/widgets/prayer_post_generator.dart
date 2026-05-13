import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:get/get.dart';
import '../../../data/models/donation_model.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PRAYER POST GENERATOR  —  v3  (Fixed Layout, QR Bar, Custom Message)
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Design constants ─────────────────────────────────────────────────────────
const double _kSize      = 1080.0;   // card is always square 1080×1080
const double _kPad       = 52.0;     // outer padding
const double _kRadius    = 32.0;
const Color  _kBg        = Color(0xFF07120E);
const Color  _kGold      = Color(0xFFFFD25E);

// ─── Word limit for custom donor message ───────────────────────────────────
const int _kMaxWords = 20;

class PrayerPostGenerator {
  // ─── Public entry-point ────────────────────────────────────────────────────

  static Future<void> sharePrayerPost(
    DonationModel donation,
    BuildContext context,
  ) async {
    // If donor has a custom message show a quick preview dialog first
    final String? finalMessage = await _resolveMessage(context, donation);
    if (finalMessage == null) return; // user cancelled

    try {
      final ctrl   = ScreenshotController();
      final theme  = _theme(donation.prayerColor);
      final prayer = _prayerData(donation.prayerType);
      final amount = donation.amount.toStringAsFixed(0);

      final card = _PrayerCard(
        accentColor:   theme,
        prayer:        prayer,
        customMessage: finalMessage,
        amount:        amount,
      );

      final bytes = await ctrl.captureFromWidget(
        card,
        delay:           const Duration(milliseconds: 120),
        pixelRatio:      2.0,
        targetSize:      const Size(_kSize, _kSize),
      );

      final dir  = await getTemporaryDirectory();
      final file = await File('${dir.path}/prayer_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'تقبّل الله منكم ومنا صالح الأعمال ✨ ${prayer.label}',
      );
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء مشاركة البطاقة: $e');
    }
  }

  // ─── Custom-message dialog ─────────────────────────────────────────────────

  /// Returns the final message string, or null if cancelled.
  /// If donor already wrote a prayerCustomMessage use it as default.
  static Future<String?> _resolveMessage(
    BuildContext context,
    DonationModel donation,
  ) async {
    final existing = _sanitize(donation.prayerCustomMessage ?? donation.notes);
    final prayer   = _prayerData(donation.prayerType);
    final preset   = existing ?? prayer.dua;

    // Quick share without dialog if no custom-message capability needed
    // (caller passes prayerCustomMessage=null to skip dialog)
    if (donation.prayerCustomMessage != null) return existing ?? prayer.dua;

    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MessageEditorSheet(defaultText: preset, prayer: prayer),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static String? _sanitize(String? msg) {
    if (msg == null || msg.trim().isEmpty) return null;
    final words = msg.trim().split(RegExp(r'\s+'));
    if (words.length > _kMaxWords) {
      return '${words.sublist(0, _kMaxWords).join(' ')}...';
    }
    return words.join(' ');
  }

  static Color _theme(String? key) {
    switch (key) {
      case 'green':
      case 'emerald':  return const Color(0xFF10B981);
      case 'blue':
      case 'sapphire': return const Color(0xFF3B82F6);
      case 'purple':   return const Color(0xFF8B5CF6);
      case 'rose':
      case 'red':      return const Color(0xFFF43F5E);
      default:         return const Color(0xFF14C38E);
    }
  }

  static _PrayerData _prayerData(String? type) {
    switch (type) {
      case 'sadaka':
      case 'ongoing_charity':
        return _PrayerData(
          label: 'صدقة جارية',
          verse: 'مَّن ذَا الَّذِي يُقْرِضُ ٱللَّهَ قَرْضًا حَسَنًا فَيُضَٰعِفَهُۥ لَهُۥٓ أَضْعَافًا كَثِيرَةً',
          dua:   'اللهم اجعلها صدقةً جاريةً مقبولة، ترفع بها الدرجات وتمحو السيئات.',
        );
      case 'shifaa':
      case 'healing':
        return _PrayerData(
          label: 'دعاء بالشفاء',
          verse: 'وَإِذَا مَرِضْتُ فَهُوَ يَشْفِينِ',
          dua:   'اللهم اشفِ مريضهم شفاءً لا يغادر سقمًا، وألبسه لباس الصحة والعافية.',
        );
      case 'deceased':
        return _PrayerData(
          label: 'دعاء للميت',
          verse: 'إِنَّا لِلَّهِ وَإِنَّآ إِلَيْهِ رَٰجِعُونَ',
          dua:   'اللهم ارحم فقيدهم واغفر له وأسكنه فسيح جناتك.',
        );
      default:
        return _PrayerData(
          label: 'دعاء للمتبرع',
          verse: null,
          dua:   'اللهم تقبّل من متبرعنا هذا وبارك له في ماله وأهله.',
        );
    }
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _PrayerData {
  final String  label;
  final String? verse;
  final String  dua;
  const _PrayerData({required this.label, this.verse, required this.dua});
}

// ═══════════════════════════════════════════════════════════════════════════════
// _PrayerCard  —  the actual 1080×1080 card widget
// ═══════════════════════════════════════════════════════════════════════════════

class _PrayerCard extends StatelessWidget {
  final Color       accentColor;
  final _PrayerData prayer;
  final String      customMessage;
  final String      amount;

  const _PrayerCard({
    required this.accentColor,
    required this.prayer,
    required this.customMessage,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: const MediaQueryData(
        size:             Size(_kSize, _kSize),
        devicePixelRatio: 2.0,
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
          color: _kBg,
          child: SizedBox(
            width:  _kSize,
            height: _kSize,
            child: CustomPaint(
              painter: _BgPainter(accentColor),
              child: Padding(
                padding: const EdgeInsets.all(_kPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 1. Header ─────────────────────────────────────────
                    _buildHeader(),

                    const SizedBox(height: 28),
                    _GoldDivider(color: accentColor),
                    const SizedBox(height: 24),

                    // ── 2. Type label pill ────────────────────────────────
                    Center(child: _buildTypePill()),

                    const SizedBox(height: 24),

                    // ── 3. Quranic verse (if any) ─────────────────────────
                    if (prayer.verse != null) ...[
                      _buildVerse(prayer.verse!),
                      const SizedBox(height: 20),
                    ],

                    // ── 4. Main dua / custom message ──────────────────────
                    Expanded(child: _buildDuaBox()),

                    const SizedBox(height: 20),

                    // ── 5. Footer bar (amount | QR | privacy) ────────────
                    _buildFooterBar(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header: logo + title ──────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        // Logo
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape:  BoxShape.circle,
            color:  Colors.white,
            border: Border.all(color: accentColor.withValues(alpha: 0.6), width: 2.5),
            boxShadow: [
              BoxShadow(color: accentColor.withValues(alpha: 0.25), blurRadius: 16, spreadRadius: 2),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/nas_alkhir_app.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.volunteer_activism_rounded, color: accentColor, size: 40),
            ),
          ),
        ),
        const SizedBox(width: 20),

        // Title + subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'جمعية ناس الخير رقان',
                style: GoogleFonts.cairo(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'بطاقة دعاء • Carte de prière',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  color: accentColor.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Type Pill ─────────────────────────────────────────────────────────────
  Widget _buildTypePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _kGold.withValues(alpha: 0.5), width: 1.5),
        color: _kGold.withValues(alpha: 0.08),
      ),
      child: Text(
        prayer.label,
        style: GoogleFonts.amiri(
          fontSize: 38,
          fontWeight: FontWeight.bold,
          color: _kGold,
        ),
      ),
    );
  }

  // ── Quranic verse ─────────────────────────────────────────────────────────
  Widget _buildVerse(String verse) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
          right: BorderSide(color: _kGold.withValues(alpha: 0.7), width: 4),
          left:  BorderSide(color: _kGold.withValues(alpha: 0.7), width: 4),
        ),
      ),
      child: Text(
        '﴿ $verse ﴾',
        textAlign: TextAlign.center,
        maxLines:  3,
        overflow:  TextOverflow.ellipsis,
        style: GoogleFonts.amiri(
          fontSize: 22,
          color:  const Color(0xFFE8D090),
          height: 1.7,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  // ── Main Dua / Custom Message box ─────────────────────────────────────────
  Widget _buildDuaBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kRadius),
        color: Colors.black.withValues(alpha: 0.28),
        border: Border.all(color: accentColor.withValues(alpha: 0.18), width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Opening ornament
          Text('﷽', style: GoogleFonts.amiri(fontSize: 28, color: Colors.white38)),
          const SizedBox(height: 12),

          // Custom message – auto scaled
          Flexible(
            child: Center(
              child: Text(
                customMessage,
                textAlign: TextAlign.center,
                maxLines:  6,
                overflow:  TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize:   30,
                  fontWeight: FontWeight.w600,
                  color:      Colors.white.withValues(alpha: 0.93),
                  height:     1.65,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Ameen
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              color: accentColor.withValues(alpha: 0.12),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              'آمِيـن',
              style: GoogleFonts.amiri(
                fontSize:   28,
                color:      accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer Bar: amount | QR code | privacy ────────────────────────────────
  Widget _buildFooterBar() {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.8),
      ),
      child: Row(
        children: [
          // Amount section
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.volunteer_activism_rounded, color: accentColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المساهمة', style: GoogleFonts.cairo(fontSize: 16, color: Colors.white54)),
                      Text(
                        '$amount دج',
                        style: GoogleFonts.cairo(
                          fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // QR code section
          Container(
            width: 1, height: 80, color: Colors.white.withValues(alpha: 0.12),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                QrImageView(
                  data:            'https://nas-al-khir-reggane.github.io/nas_alkhir_reggane/',
                  version:         QrVersions.auto,
                  size:            82,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color:    Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color:           Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تبرّع معنا',
                  style: GoogleFonts.cairo(fontSize: 13, color: Colors.white38),
                ),
              ],
            ),
          ),
          Container(
            width: 1, height: 80, color: Colors.white.withValues(alpha: 0.12),
          ),

          // Privacy badge
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('فاعل خير', style: GoogleFonts.cairo(fontSize: 16, color: Colors.white54)),
                      Text(
                        'مخفيّ',
                        style: GoogleFonts.cairo(
                          fontSize: 22, fontWeight: FontWeight.w700, color: _kGold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.shield_rounded, color: _kGold, size: 28),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _MessageEditorSheet — bottom sheet for the donor to write/edit their message
// ═══════════════════════════════════════════════════════════════════════════════

class _MessageEditorSheet extends StatefulWidget {
  final String      defaultText;
  final _PrayerData prayer;
  const _MessageEditorSheet({required this.defaultText, required this.prayer});

  @override
  State<_MessageEditorSheet> createState() => _MessageEditorSheetState();
}

class _MessageEditorSheetState extends State<_MessageEditorSheet> {
  late final TextEditingController _ctrl;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.defaultText);
    _wordCount = _countWords(widget.defaultText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int _countWords(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r'\s+')).length;
  }

  String _enforceLimit(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length > _kMaxWords) {
      return words.sublist(0, _kMaxWords).join(' ');
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final bool atLimit = _wordCount >= _kMaxWords;

    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1F18),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: _kGold, size: 28),
                const SizedBox(width: 10),
                Text(
                  'اكتب رسالتك على البطاقة',
                  style: GoogleFonts.cairo(
                    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'الحد الأقصى: $_kMaxWords كلمة',
              style: GoogleFonts.cairo(fontSize: 13, color: Colors.white38),
            ),
            const SizedBox(height: 16),

            // Text field
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: atLimit ? Colors.redAccent.withValues(alpha: 0.6) : Colors.white24,
                ),
              ),
              child: TextField(
                controller:   _ctrl,
                maxLines:     5,
                textAlign:    TextAlign.right,
                style:        GoogleFonts.cairo(fontSize: 18, color: Colors.white, height: 1.6),
                decoration: InputDecoration(
                  border:          InputBorder.none,
                  contentPadding:  const EdgeInsets.all(18),
                  hintText:        'اكتب دعاءك أو رسالتك هنا…',
                  hintStyle:       GoogleFonts.cairo(color: Colors.white30, fontSize: 16),
                ),
                onChanged: (val) {
                  final enforced = _enforceLimit(val);
                  if (enforced != val) {
                    _ctrl.value = _ctrl.value.copyWith(
                      text:           enforced,
                      selection:      TextSelection.collapsed(offset: enforced.length),
                      composing:      TextRange.empty,
                    );
                  }
                  setState(() => _wordCount = _countWords(enforced));
                },
              ),
            ),

            const SizedBox(height: 10),

            // Word counter
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$_wordCount / $_kMaxWords كلمة',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: atLimit ? Colors.redAccent : Colors.white38,
                  fontWeight: atLimit ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Use preset button
            TextButton.icon(
              onPressed: () {
                _ctrl.text = widget.prayer.dua;
                setState(() => _wordCount = _countWords(widget.prayer.dua));
              },
              icon:  const Icon(Icons.refresh_rounded, size: 18, color: _kGold),
              label: Text('استخدم الدعاء الافتراضي', style: GoogleFonts.cairo(color: _kGold, fontSize: 14)),
            ),

            const SizedBox(height: 14),

            // Buttons row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: OutlinedButton.styleFrom(
                      side:         const BorderSide(color: Colors.white24),
                      padding:      const EdgeInsets.symmetric(vertical: 14),
                      shape:        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _wordCount == 0
                        ? null
                        : () => Navigator.pop(context, _ctrl.text.trim()),
                    icon:  const Icon(Icons.share_rounded, size: 20),
                    label: Text('مشاركة البطاقة', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14C38E),
                      foregroundColor: Colors.white,
                      padding:         const EdgeInsets.symmetric(vertical: 14),
                      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Background painter — fixed-size dots, no RenderFlex issues
// ═══════════════════════════════════════════════════════════════════════════════

class _BgPainter extends CustomPainter {
  final Color accent;
  const _BgPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    // Radial gradient fill
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center:  Alignment.center,
          radius:  0.9,
          stops:   const [0.0, 1.0],
          colors:  [accent.withValues(alpha: 0.14), _kBg],
        ).createShader(rect),
    );

    // Subtle dot grid
    final dotPaint = Paint()
      ..color = accent.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }

    // Star-pattern overlay (sparse, only every 3rd cell)
    final starPaint = Paint()
      ..color = accent.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (double x = step * 1.5; x < size.width; x += step * 3) {
      for (double y = step * 1.5; y < size.height; y += step * 3) {
        _drawStar8(canvas, Offset(x, y), 14, starPaint);
      }
    }
  }

  void _drawStar8(Canvas canvas, Offset center, double r, Paint p) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final ir    = i.isEven ? r : r * 0.42;
      final x     = center.dx + ir * math.cos(angle);
      final y     = center.dy + ir * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.accent != accent;
}

// ─── Tiny helper widget ────────────────────────────────────────────────────────

class _GoldDivider extends StatelessWidget {
  final Color color;
  const _GoldDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (i) {
        final isCenter = i == 3;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width:  isCenter ? 12 : 5,
          height: isCenter ? 12 : 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCenter ? _kGold : color.withValues(alpha: 0.4),
          ),
        );
      }),
    );
  }
}
