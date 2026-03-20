import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) {
    print('lib directory not found');
    return;
  }

  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  for (final file in files) {
    String content = file.readAsStringSync();
    if (!content.contains('AppBar(') && !content.contains('SliverAppBar(')) {
      continue;
    }

    // Add imports if they don't exist
    if (!content.contains("import 'package:get/get.dart';")) {
      content = "import 'package:get/get.dart';\n" + content;
    }

    // Determine path back to lib/core/constants/app_constants.dart
    // Example: lib\features\admin\screens\admin_dashboard.dart (depth is 3)
    final separator = Platform.pathSeparator;
    final pathParts = file.path.split(separator); // e.g. ["lib", "features", "auth", "screens", "login_screen.dart"]
    // lib is index 0. The depth to lib is pathParts.length - 2
    final depth = pathParts.length - 2;
    String prefix = '';
    for (int i = 0; i < depth; i++) {
      prefix += '../';
    }
    String importConst = "import '${prefix}core/constants/app_constants.dart';";
    
    if (!content.contains('app_constants.dart')) {
      // add import right after the get.dart import
      content = content.replaceFirst("import 'package:get/get.dart';", "import 'package:get/get.dart';\n$importConst");
    }

    final String themeAction = '''
        IconButton(
          icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode),
          onPressed: () => AppConstants.toggleTheme(),
        ),
''';

    // Regex to safely inject actions: [] 
    // This is difficult in regex because of nested parentheses and braces in Dart.
    // Instead of full parsing, let's just do simple replacements.
    
    // 1. If it already has actions: [ ... ]
    if (content.contains('actions: [')) {
      content = content.replaceAll(
        'actions: [', 
        'actions: [\n$themeAction'
      );
    } else {
      // 2. We inject actions right after AppBar( or SliverAppBar(
      // But we have to be careful about SliverAppBar( which doesn't have actions:, we add it right after
      content = content.replaceAll('AppBar(', 'AppBar(\n      actions: [\n$themeAction      ],');
      content = content.replaceAll('SliverAppBar(', 'SliverAppBar(\n      actions: [\n$themeAction      ],');
    }

    file.writeAsStringSync(content);
    print('Updated ${file.path}');
  }
}
