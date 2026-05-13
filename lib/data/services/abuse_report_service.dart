import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AbuseReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> submitReport({
    required String reportedId,
    required String reportedType, // e.g., 'user', 'blood_request'
    required String reason,
    String? details,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('يجب تسجيل الدخول للإبلاغ');
      }

      await _firestore.collection('reports').add({
        'reporterId': currentUser.uid,
        'reportedId': reportedId,
        'reportedType': reportedType,
        'reason': reason,
        'details': details ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('فشل في إرسال البلاغ: $e');
    }
  }
}
