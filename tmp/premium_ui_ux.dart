import 'dart:io';

void main() {
  final dir = Directory('lib');
  int updatedFiles = 0;

  void processFile(File file) {
    if (!file.path.endsWith('.dart')) return;
    
    String content = file.readAsStringSync();
    String original = content;

    content = content.replaceAll('EdgeInsets.only(left:', 'EdgeInsetsDirectional.only(start:');
    content = content.replaceAll('EdgeInsets.only(right:', 'EdgeInsetsDirectional.only(end:');
    content = content.replaceAll('EdgeInsets.only(left: ', 'EdgeInsetsDirectional.only(start: ');
    content = content.replaceAll('EdgeInsets.only(right: ', 'EdgeInsetsDirectional.only(end: ');
    
    content = content.replaceAllMapped(RegExp(r'EdgeInsets\.fromLTRB\(([^,]+),\s*([^,]+),\s*([^,]+),\s*([^)]+)\)'), (match) {
      return 'EdgeInsetsDirectional.fromSTEB(${match[1]!}, ${match[2]!}, ${match[3]!}, ${match[4]!})';
    });

    content = content.replaceAll('Positioned(right:', 'PositionedDirectional(end:');
    content = content.replaceAll('Positioned(left:', 'PositionedDirectional(start:');
    content = content.replaceAll('Positioned(right: ', 'PositionedDirectional(end: ');
    content = content.replaceAll('Positioned(left: ', 'PositionedDirectional(start: ');

    content = content.replaceAll('Colors.teal', 'AppTheme.primaryGreen');
    content = content.replaceAll('Color(0xFF388E3C)', 'AppTheme.primaryGreen');
    content = content.replaceAll('Color(0xFFFBC02D)', 'AppTheme.goldAccent');
    content = content.replaceAll('Color(0xFF4A148C)', 'AppTheme.primaryGreen');
    content = content.replaceAll('Colors.amber', 'AppTheme.goldAccent');
    content = content.replaceAll('Colors.deepOrange', 'AppTheme.urgentColor');

    if (content != original) {
      updatedFiles++;
      file.writeAsStringSync(content);
      stdout.writeln('Updated: ${file.path}');
    }
  }

  dir.listSync(recursive: true).forEach((entity) {
    if (entity is File) {
      processFile(entity);
    }
  });

  stdout.writeln('Migration Complete. Updated files: $updatedFiles');
}
