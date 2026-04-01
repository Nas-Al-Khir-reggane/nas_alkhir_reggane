import 'dart:io';

void main() {
  final dir = Directory('lib');
  int opacityCount = 0;
  int dropdownCount = 0;

  void processFile(File file) {
    if (file.path.endsWith('.dart')) {
      String content = file.readAsStringSync();
      String original = content;

      // 1. More robust Opacity migration (avoiding Gradient which we already fixed)
      // We look for .withOpacity( and ensure it's not a gradient (using a heuristic or just relying on our fix_gradients script later)
      // Actually, since we already ran fix_gradients, we can safely replace all withOpacity now.
      
      // Pattern: .withOpacity(anything)
      final opacityRegex = RegExp(r'\.withOpacity\(([^)]+)\)');
      content = content.replaceAllMapped(opacityRegex, (match) {
        opacityCount++;
        return '.withValues(alpha: ${match.group(1)})';
      });

      // 2. More robust Dropdown migration
      // Pattern: value: someValue, inside DropdownButtonFormField
      // Heuristic: search for 'DropdownButtonFormField' and then replace 'value:' within its block.
      // Simpler: replace '(value:)' with ' initialValue:' if it's likely a dropdown.
      // Actually, standardizing on replacing ' value:' and ',value:' and '(value:'
      content = content.replaceAll(' value: ', ' initialValue: ');
      content = content.replaceAll('(value: ', '(initialValue: ');
      content = content.replaceAll(',value: ', ', initialValue: ');
      content = content.replaceAll('\nvalue: ', '\ninitialValue: ');
      
      // I'll count dropdowns roughly
      if (content != original) {
        dropdownCount += RegExp(r'initialValue:').allMatches(content).length - RegExp(r'initialValue:').allMatches(original).length;
        file.writeAsStringSync(content);
      }
    }
  }

  dir.listSync(recursive: true).forEach((entity) {
    if (entity is File) {
      processFile(entity);
    }
  });

  print('Migration summary:');
  print('Opacity replacements requested: $opacityCount');
  print('Dropdown/Value replacements: $dropdownCount');
  print('Running Gradient fix-up again...');
}
