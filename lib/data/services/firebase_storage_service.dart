import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// تقوم برفع الوسائط (صور أو صوت أو مستندات) إلى Firebase Storage
  static Future<String?> uploadMedia(File file, String remotePath) async {
    try {
      // 1. التحقق من الامتدادات المدعومة
      final allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.mp3', '.m4a', '.wav', '.ogg', '.pdf'];
      final ext = path.extension(file.path).toLowerCase();
      
      if (!allowedExtensions.contains(ext)) {
        throw Exception('نوع الملف غير مدعوم للرفع. الامتدادات المدعومة: ${allowedExtensions.join(", ")}');
      }

      // 2. التحقق من حجم الملف (أقل من 5 ميجابايت حسب قواعد الحماية)
      final size = await file.length();
      if (size > 5 * 1024 * 1024) {
        throw Exception('حجم الملف كبير جداً. يجب أن يكون أقل من 5 ميجابايت.');
      }

      // 3. رفع الملف إلى Firebase Storage
      final ref = _storage.ref().child(remotePath);
      
      // تحديد نوع المحتوى تلقائياً لتسهيل عرضه في المتصفح/التطبيق
      final metadata = SettableMetadata(
        contentType: _getContentType(ext),
      );

      final uploadTask = await ref.putFile(file, metadata);
      
      // 4. الحصول على رابط التحميل
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Exception during Firebase Storage upload: $e');
      rethrow;
    }
  }

  static String _getContentType(String extension) {
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.pdf':
        return 'application/pdf';
      case '.mp3':
        return 'audio/mpeg';
      case '.m4a':
        return 'audio/mp4';
      case '.wav':
        return 'audio/wav';
      case '.ogg':
        return 'audio/ogg';
      default:
        return 'application/octet-stream';
    }
  }

  /// يقوم بحذف الملف من Firebase Storage باستخدام رابط التحميل (URL)
  static Future<void> deleteMedia(String downloadUrl) async {
    try {
      if (downloadUrl.isEmpty || !downloadUrl.contains('firebasestorage')) return;
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      debugPrint('Successfully deleted file from storage: $downloadUrl');
    } catch (e) {
      debugPrint('Exception during Firebase Storage deletion: $e');
    }
  }
}
