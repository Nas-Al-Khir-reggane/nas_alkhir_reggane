import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/user_model.dart';
import '../../../core/theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final UserModel user;
  final double size;
  final bool showBadge;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.user,
    this.size = 40,
    this.showBadge = true,
    this.onTap,
  });

  String get _avatarUrl {
    final style = user.avatarType ?? 'avataaars';
    final seed = user.avatarSeed ?? user.id;
    // إضافة خلفية متناسقة مع ألوان التطبيق
    final backgroundColor = _getBackgroundColorHex();
    return 'https://api.dicebear.com/7.x/$style/svg?seed=$seed&backgroundColor=$backgroundColor';
  }

  String _getBackgroundColorHex() {
    // استخدام ألوان التطبيق بشكل دوري بناءً على المعرف
    final colors = [
      'c8e6c9', // Green 100
      'e1f5fe', // Light Blue 50
      'fff9c4', // Yellow 100
      'f3e5f5', // Purple 50
      'e8f5e9', // Success Green 50
    ];
    final index = user.id.hashCode % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          _buildAvatarBody(),
          if (showBadge) _buildRoleBadge(),
        ],
      ),
    );
  }

  Widget _buildAvatarBody() {
    // 1. الأولوية للصورة المرفوعة سابقاً (للتوافق)
    if (user.profileImage != null && user.profileImage!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2), width: 1.5),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: user.profileImage!,
            placeholder: (context, url) => Container(color: AppTheme.cardColor),
            errorWidget: (context, url, error) => _buildInitialsAvatar(),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // 2. إذا وجد بذرة (Seed) للأفاتار الذكي
    if (user.avatarSeed != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2), width: 1.5),
          color: Colors.white,
        ),
        child: ClipOval(
          child: FadeIn(
            duration: const Duration(milliseconds: 300),
            child: SvgPicture.network(
              _avatarUrl,
              placeholderBuilder: (context) => Container(color: AppTheme.cardColor),
            ),
          ),
        ),
      );
    }

    // 3. Fallback: الأحرف الأولى
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    final initials = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: AppTheme.primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge() {
    IconData icon;
    Color color;
    
    switch (user.role) {
      case UserRole.superAdmin:
      case UserRole.admin:
        icon = Icons.verified_user;
        color = Colors.amber;
        break;
      case UserRole.worker:
        icon = Icons.volunteer_activism;
        color = AppTheme.primaryGreen;
        break;
      case UserRole.donor:
        icon = Icons.favorite;
        color = Colors.redAccent;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size * 0.3, color: color),
      ),
    );
  }
}
