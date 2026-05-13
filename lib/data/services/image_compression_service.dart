import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;

class ImageCompressionService {
  /// ضغط الصورة وإرجاع الملف الجديد
  static Future<File?> compressImage(File file) async {
    try {
      final String targetPath = p.join(
        (await path_provider.getTemporaryDirectory()).path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed${p.extension(file.path)}',
      );

      // نقوم بضغط الصورة مع تحديد أبعاد قصوى وجودة متوازنة
      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 60, // تقليل الجودة لتقليل المساحة بشكل كبير
        minWidth: 1024, // تحديد العرض الأقصى لضمان عدم تجاوز الأبعاد الكبيرة
        minHeight: 1024,
        format: CompressFormat.jpeg, // تحويلها لـ JPEG لضمان أقل حجم
      );

      if (result != null) {
        final compressedFile = File(result.path);
        final originalSize = await file.length();
        final compressedSize = await compressedFile.length();
        
        debugPrint('Original size: ${originalSize / 1024} KB');
        debugPrint('Compressed size: ${compressedSize / 1024} KB');
        debugPrint('Reduction: ${((originalSize - compressedSize) / originalSize * 100).toStringAsFixed(1)}%');
        
        return compressedFile;
      }
      return null;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return file; // في حال الفشل نرجع الملف الأصلي
    }
  }
}
