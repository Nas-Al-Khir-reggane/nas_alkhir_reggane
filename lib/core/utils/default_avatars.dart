import 'dart:math';
import '../../data/models/user_model.dart';

class DefaultAvatars {
  static List<String> getAvatarsForRole(UserRole role, [String gender = 'ذكر']) {
    String prefix;
    switch (role) {
      case UserRole.worker:
        prefix = 'worker';
        break;
      case UserRole.donor:
        prefix = 'donor';
        break;
      case UserRole.superAdmin:
      case UserRole.admin:
      case UserRole.chatModerator:
        prefix = 'admin';
        break;
      default:
        prefix = 'user';
        break;
    }

    String genderSuffix = gender == 'ذكر' ? 'male' : 'female';

    // نستخدم نمط notionists ونقوم بتوليد 40 خياراً لكل دمج (دور + جنس)
    return List.generate(
      40,
      (index) => 'https://api.dicebear.com/9.x/notionists/png?seed=${prefix}_${genderSuffix}_${index + 1}&backgroundColor=f8f9fa'
    );
  }

  static String getRandomAvatar(UserRole role, [String gender = 'ذكر']) {
    final avatars = getAvatarsForRole(role, gender);
    return avatars[Random().nextInt(avatars.length)];
  }
}

