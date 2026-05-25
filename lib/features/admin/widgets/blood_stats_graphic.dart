import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BloodStatsGraphic extends StatelessWidget {
  final Map<String, int> userCounts;
  final int totalRegisteredUsers;
  final int livesSaved;

  const BloodStatsGraphic({
    super.key,
    required this.userCounts,
    required this.totalRegisteredUsers,
    required this.livesSaved,
  });

  @override
  Widget build(BuildContext context) {
    final totalDonors = userCounts.values.fold(0, (a, b) => a + b);

    return Container(
      width: 480,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF8FAFC), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildMainStats(totalDonors),
          const SizedBox(height: 20),
          _buildSectionTitle('توزيع فصائل دم مجتمع المتبرعين'),
          const SizedBox(height: 12),
          _buildDistributionList(totalDonors),
          const SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/nas_alkhir_app.png',
              width: 70,
              height: 70,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.red.withValues(alpha: 0.1),
                  child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 36),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'مجتمع متبرعي الدم',
          style: GoogleFonts.tajawal(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'جمعية ناس الخير - رقان',
          style: GoogleFonts.tajawal(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMainStats(int totalDonors) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'المتبرعون المسجلون',
            totalDonors.toString(),
            Colors.blueAccent,
            Icons.people_alt_outlined,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildStatCard(
            'حالات إنقاذ ميسرة',
            livesSaved.toString(),
            Colors.green,
            Icons.favorite_border_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.tajawal(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.tajawal(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Text(
        title,
        style: GoogleFonts.tajawal(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildDistributionList(int totalDonors) {
    final labels = ['O+', 'A+', 'B+', 'AB+', 'O-', 'A-', 'B-', 'AB-'];

    // 1. Build Segmented Bar
    final List<Widget> segments = [];
    for (final label in labels) {
      final count = userCounts[label] ?? 0;
      if (count > 0) {
        final color = _getBloodTypeColor(label);
        segments.add(
          Expanded(
            flex: count,
            child: Container(
              height: 16,
              color: color,
            ),
          ),
        );
      }
    }

    // 2. Build Legend Wrap of Pills
    final legendItems = labels.map((label) {
      final count = userCounts[label] ?? 0;
      final percentage = totalDonors > 0 ? (count / totalDonors * 100).toStringAsFixed(1) : '0.0';
      final color = _getBloodTypeColor(label);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$label: %$percentage ($count)',
              style: GoogleFonts.tajawal(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      );
    }).toList();

    return Column(
      children: [
        if (segments.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: segments,
            ),
          ),
          const SizedBox(height: 14),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: legendItems,
        ),
      ],
    );
  }

  Color _getBloodTypeColor(String bloodType) {
    switch (bloodType.toUpperCase()) {
      case 'A+': return const Color(0xFFDC2626); // Deep Red
      case 'A-': return const Color(0xFFEF4444); // Red
      case 'B+': return const Color(0xFFDB2777); // Pink
      case 'B-': return const Color(0xFFEC4899); // Light Pink
      case 'AB+': return const Color(0xFF9333EA); // Purple
      case 'AB-': return const Color(0xFFA855F7); // Light Purple
      case 'O+': return const Color(0xFFEA580C); // Orange
      case 'O-': return const Color(0xFFF97316); // Light Orange
      default: return const Color(0xFFDC2626);
    }
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red[100]!, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🩸 قطرة دم تساوي حياة.. انضم إلينا في تطبيق ناس الخير وسجل فصيلة دمك لتكون جزءاً من مجتمع الإنقاذ والتبرع الميسر.',
                  style: GoogleFonts.tajawal(
                    fontSize: 11.5,
                    color: Colors.red[900],
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(color: Colors.black12),
        const SizedBox(height: 6),
        Text(
          'تطبيق ناس الخير رقان · الدال على الخير كفاعله',
          style: GoogleFonts.tajawal(
            fontSize: 10.5,
            color: Colors.grey[500],
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
