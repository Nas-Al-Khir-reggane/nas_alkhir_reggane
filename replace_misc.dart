// ignore_for_file: avoid_print, unnecessary_string_escapes
import 'dart:io';
void replaceInFile(String path, Pattern from, String to) {
  final file = File(path);
  if (!file.existsSync()) return;
  var content = file.readAsStringSync();
  final newContent = content.replaceAll(from, to);
  if (content != newContent) {
    file.writeAsStringSync(newContent);
    print('Updated $path');
  }
}
void replaceRegexInFile(String path, String from, String to) {
  final file = File(path);
  if (!file.existsSync()) return;
  var content = file.readAsStringSync();
  final newContent = content.replaceAll(RegExp(from), to);
  if (content != newContent) {
    file.writeAsStringSync(newContent);
    print('Updated regex $path');
  }
}
void main() {
  final formFieldFiles = [
    'lib/features/admin/screens/request_detail_screen.dart',
    'lib/features/auth/screens/register_screen.dart',
    'lib/features/shared/screens/profile_screen.dart',
    'lib/features/beneficiary/screens/new_request_screen.dart'
  ];
  for (var file in formFieldFiles) {
    replaceInFile(file, 'TextFormField(value:', 'TextFormField(initialValue:');
    replaceInFile(file, ' TextFormField(value:', ' TextFormField(initialValue:');
    replaceRegexInFile(file, r'(\b)value:', r'\1initialValue:');
  }
  replaceInFile('lib/features/shared/screens/blood_donor_profile_screen.dart', 'activeColor:', 'activeThumbColor:');
  replaceInFile('lib/features/shared/screens/profile_screen.dart', 'activeColor:', 'activeThumbColor:');
  replaceInFile('lib/core/widgets/update_dialog.dart', 'WillPopScope(', 'PopScope(');
  replaceInFile('lib/core/widgets/update_dialog.dart', 'onWillPop: () async => false,', 'canPop: false,');
  replaceInFile('lib/features/admin/widgets/share_emergency_generator.dart', 'import ''package:intl/intl.dart'';', '');
  replaceInFile('lib/features/chat/screens/chat_screen.dart', 'import ''dart:ui'';', '');
  replaceInFile('lib/features/shared/screens/blood_donor_profile_screen.dart', 'import ''dart:ui'';', '');
  replaceRegexInFile('lib/features/shared/screens/profile_screen.dart', r'import ''.*cached_image_widget\.dart'';', '');
  replaceInFile('lib/core/services/init_version.dart', 'print(', 'debugPrint(');
}
