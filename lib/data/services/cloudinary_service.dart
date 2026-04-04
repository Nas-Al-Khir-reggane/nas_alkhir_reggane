import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class CloudinaryService {
  static const String _cloudName = 'dqy3rn9kc';
  static const String _uploadPreset = 'images-ness_elkheir';
  static const String _apiUrl = 'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload';

  /// تقوم برفع الوسائط (صور أو صوت) إلى Cloudinary
  static Future<String?> uploadMedia(File file) async {
    try {
      // 1. Validate extension
      final allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.mp3', '.m4a', '.wav', '.ogg'];
      final ext = path.extension(file.path).toLowerCase();
      
      if (!allowedExtensions.contains(ext)) {
        throw Exception('نوع الملف غير مدعوم للرفع. الامتدادات المدعومة: ${allowedExtensions.join(", ")}');
      }

      // 2. Prepare HTTP request
      final uri = Uri.parse(_apiUrl);
      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = _uploadPreset;
      // Using resource_type "auto" indirectly by URL path (/auto/upload) 
      // or we can explicitly pass it if using the generic /upload endpoint:
      request.fields['resource_type'] = 'auto';

      final multipartFile = await http.MultipartFile.fromPath('file', file.path);
      request.files.add(multipartFile);

      // 3. Send and await response
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['secure_url'] as String?;
      } else {
        debugPrint('Cloudinary Error: ${response.statusCode} - ${response.body}');
        throw Exception('فشل رفع الملف إلى Cloudinary. الرمز: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Exception during Cloudinary upload: $e');
      rethrow;
    }
  }
}
