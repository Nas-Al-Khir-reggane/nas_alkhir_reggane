import 'dart:math';
import '../../data/models/user_model.dart';

class DefaultAvatars {
  static List<String> getAvatarsForRole(UserRole role) {
    String prefix;
    // سنستخدم بذور (seeds) تعطي نتائج رسمية أكثر لكل دور
    switch (role) {
      case UserRole.worker:
        prefix = 'worker_pro';
        break;
      case UserRole.donor:
        prefix = 'donor_neutral';
        break;
      case UserRole.beneficiary:
        prefix = 'user_simple';
        break;
      case UserRole.superAdmin:
      case UserRole.admin:
        prefix = 'admin_office';
        break;
      case UserRole.guest:
      default:
        prefix = 'guest_user';
        break;
    }

    // استخدام نمط notionists الذي يعتبر أكثر رسمية واحترافية
    return List.generate(
      10,
      (index) => 'https://api.dicebear.com/9.x/notionists/png?seed=$prefix${index + 1}&backgroundColor=f8f9fa'
    );
  }

  static String getRandomAvatar(UserRole role) {
    final avatars = getAvatarsForRole(role);
    return avatars[Random().nextInt(avatars.length)];
  }
}
