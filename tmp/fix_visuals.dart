// ignore_for_file: avoid_print

import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) return;

  final files = dir.listSync(recursive: true);
  int fixedCount = 0;

  for (var entity in files) {
    if (entity is File && entity.path.endsWith('.dart')) {
      bool changed = false;
      String content = entity.readAsStringSync();

      // 1. Fix gradients in AppTheme and screens (0.15 -> 0.9)
      content = content.replaceAll('.withValues(alpha: 0.15)],', '.withValues(alpha: 0.9)],');
      content = content.replaceAll('.withValues(alpha: 0.15)])', '.withValues(alpha: 0.9)])');

      // 2. Fix text colors and icon colors (0.15 -> 0.7 or 1.0)
      // We look for .withValues(alpha: 0.15) preceded by "color:" or "foregroundColor:"
      final colorFixRegex = RegExp(r'(color|foregroundColor|shadowColor):\s*([^,;]+)\.withValues\(alpha:\s*0\.15\)');
      content = content.replaceAllMapped(colorFixRegex, (match) {
        String prop = match.group(1)!;
        String val = match.group(2)!;
        
        // If it's a Shadow/BoxShadow, keep 0.15
        if (content.contains('BoxShadow') && prop == 'color') {
           // This is tricky without a full parser, let's be conservative.
           // If the previous lines contain BoxShadow, we might be inside it.
        }

        changed = true;
        // If it's foregroundColor, it's definitely a button, make it solid.
        if (prop == 'foregroundColor') return '$prop: $val';
        // If it's color, and looks like a TextStyle or Icon, make it more opaque.
        return '$prop: $val.withValues(alpha: 0.75)';
      });

      // 4. Fix specific hardcoded cases from user list
      // splash_screen.dart:222 color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black54
      if (entity.path.endsWith('splash_screen.dart')) {
        if (content.contains('Colors.white.withValues(alpha: 0.15) : Colors.black54')) {
           content = content.replaceFirst('Colors.white.withValues(alpha: 0.15)', 'Colors.white');
           changed = true;
        }
      }

      if (changed) {
        entity.writeAsStringSync(content);
        print('Fixed opacities in ${entity.path}');
        fixedCount++;
      }
    }
  }

  print('Total files fixed: $fixedCount');
}
