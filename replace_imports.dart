import 'dart:io';
void replaceRegexInFile(String path, String from, String to) {
  final file = File(path);
  if (!file.existsSync()) return;
  var content = file.readAsStringSync();
  final newContent = content.replaceAll(RegExp(from), to);
  if (content != newContent) {
    file.writeAsStringSync(newContent);
    print('Updated regex ' + path);
  }
}
void main() {
  replaceRegexInFile('lib/features/admin/widgets/share_emergency_generator.dart', r"import 'package:intl/intl\.dart';", "");
  replaceRegexInFile('lib/features/chat/screens/chat_screen.dart', r"import 'dart:ui';", "");
  replaceRegexInFile('lib/features/shared/screens/blood_donor_profile_screen.dart', r"import 'dart:ui';", "");
  replaceRegexInFile('lib/features/shared/screens/profile_screen.dart', r"import '.*cached_image_widget\.dart';", "");
  replaceRegexInFile('lib/core/services/init_version.dart', r"\bprint\(", "debugPrint(");
}
