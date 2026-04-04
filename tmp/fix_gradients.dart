// ignore_for_file: avoid_print

import 'dart:io';

void main() {
  final dir = Directory('lib');
  int fixedCount = 0;

  void processFile(File file) {
    String content = file.readAsStringSync();
    if (content.contains('.withValues(alpha:')) {
      // Find cases where it might be a gradient by looking at variable names like 'gradient'
      // or common patterns.
      
      // Specifically fix the one in admin_dashboard.dart first
      if (file.path.endsWith('admin_dashboard.dart')) {
        content = content.replaceAll('gradient: gradient.withValues(alpha: 0.15)', 'gradient: gradient');
        fixedCount++;
      }
      
      // Check for other potential gradient.withValues
      final lines = content.split('\n');
      bool modified = false;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('.withValues(alpha:') && lines[i].toLowerCase().contains('gradient')) {
          // This is likely a gradient.
          print('Suspected Gradient withValues in ${file.path}:${i + 1}');
          // If it's a 'gradient' variable call, remove the .withValues
          lines[i] = lines[i].replaceAll(RegExp(r'gradient\.withValues\(alpha: [0-9\.]+\)'), 'gradient');
          modified = true;
          fixedCount++;
        }
      }
      
      if (modified) {
        content = lines.join('\n');
      }
      
      file.writeAsStringSync(content);
    }
  }

  dir.listSync(recursive: true).forEach((entity) {
    if (entity is File && entity.path.endsWith('.dart')) {
      processFile(entity);
    }
  });

  print('Fixed $fixedCount suspected Gradient withValues calls.');
}
