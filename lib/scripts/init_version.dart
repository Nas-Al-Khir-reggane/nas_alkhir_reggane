// ignore_for_file: avoid_print
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';

void main() async {
  // تفعيل واجهة الفلاتر والارتباطات اللازمة
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 جاري الاتصال بـ Firebase...');
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final firestore = FirebaseFirestore.instance;

    print('📝 جاري إنشاء إعدادات الإصدار في Firestore...');
    
    // إنشاء مستند الإصدار الافتراضي
    await firestore.collection('app_config').doc('version').set({
      'latest_version': '1.0.1',
      'build_number': 2,
      'update_url': 'https://play.google.com/store/apps/details?id=com.nasalkheir.reggane',
      'release_notes': 'إصلاحات عامة وتحسينات في الأداء.\n- تحسين سرعة المحادثات.\n- إصلاح مشكلة الإشعارات.',
      'is_required': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('✅ تم تفعيل ميزة التحديث بنجاح!');
    print('📂 المسار في Firestore: app_config/version');
    print('\nيمكنك الآن إغلاق هذا التيرمينال.');
    
  } catch (e) {
    print('❌ حدث خطأ أثناء التفعيل: $e');
  }
}

